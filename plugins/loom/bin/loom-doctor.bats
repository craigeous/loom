#!/usr/bin/env bats
# Test suite for loom-doctor and the loom CLI entry point (slice loom-doctor-foundation).
# Every test builds a throwaway plugin tree + repository under a private mktemp dir,
# stubs host tools through a PATH-prefix directory, and uses no network.
bats_require_minimum_version 1.5.0

BIN="${BATS_TEST_DIRNAME}"
SCHEMA="${BATS_TEST_DIRNAME}/../schemas/loom-doctor-report-v1.schema.json"
SCRIPTS="${BATS_TEST_DIRNAME}/../../../scripts"

IDS="host_and_os required_tools git_identity repo_cleanliness init_mode coordination review_protocol eval_protocol client_adapter hook_trust egress_sandbox"

setup() {
    WORK="$(mktemp -d)"
    WORK="$(CDPATH='' cd -- "$WORK" && pwd -P)"
    BASH_UNDER="${LOOM_TEST_BASH:-bash}"
    PLUGIN="$WORK/plugin"
    REPO="$WORK/repo"
    STUB="$WORK/stub"
    REAL_GIT="$(command -v git)"
    REAL_UNAME="$(command -v uname)"
    REAL_JQ="$(command -v jq)"
    mkdir -p "$PLUGIN/bin" "$PLUGIN/finders" "$STUB" "$WORK/home"
    cp "$BIN/loom-doctor" "$BIN/loom" "$PLUGIN/bin/"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$PLUGIN/bin/loom-review"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$PLUGIN/bin/loom-eval-workspace"
    chmod +x "$PLUGIN/bin/loom-review" "$PLUGIN/bin/loom-eval-workspace"
    for f in correctness tests security; do printf 'finder\n' >"$PLUGIN/finders/review-$f-v1.md"; done

    # Isolated Git configuration: identity comes from a private global file only.
    export HOME="$WORK/home"
    export GIT_CONFIG_SYSTEM=/dev/null
    export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
    printf '[user]\n\tname = Doctor Test\n\temail = doctor@example.com\n' >"$GIT_CONFIG_GLOBAL"
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL LOOM_LEASE_TTL LOOM_DOCTOR_BASH_VERSION

    # Default host stub: a supported macOS host regardless of where the suite runs.
    printf '#!/bin/sh\ncase "$1" in -s) echo "${FAKE_UNAME_S:-Darwin}";; -m) echo "${FAKE_UNAME_M:-arm64}";; -r) echo "${FAKE_UNAME_R:-23.0.0}";; *) exec "%s" "$@";; esac\n' \
        "$REAL_UNAME" >"$STUB/uname"
    chmod +x "$STUB/uname"
    export PATH="$STUB:$PATH"

    git init -q -b main "$REPO"
    mkdir -p "$REPO/.docs/spec" "$REPO/.docs/status"
    : >"$REPO/.docs/spec/README.md"
    for f in roadmap progress handoff; do : >"$REPO/.docs/status/$f.md"; done
    commit_all "init"
}

teardown() {
    if [ -n "${WORK:-}" ] && [ -d "$WORK" ]; then rm -rf "$WORK"; fi
    return 0
}

commit_all() {
    git -C "$REPO" add -A
    git -C "$REPO" -c user.name=T -c user.email=t@example.com commit -q --allow-empty -m "$1"
}

stub() { # <name> <script-body>
    printf '#!/bin/sh\n%s\n' "$2" >"$STUB/$1"
    chmod +x "$STUB/$1"
}

doctor() { (cd "$REPO" && "$BASH_UNDER" "$PLUGIN/bin/loom-doctor" "$@"); }
loom_cli() { (cd "$REPO" && "$BASH_UNDER" "$PLUGIN/bin/loom" "$@"); }

check_field() { # <id> <field> — from the --json report in $output
    printf '%s' "$output" | "$REAL_JQ" -r --arg id "$1" ".checks[] | select(.id==\$id) | .$2"
}

set_schema() {
    local sha
    sha=$(printf '%s' "$1" | git -C "$REPO" hash-object -w --stdin)
    git -C "$REPO" update-ref refs/loom/schema "$sha"
}

set_claim() { # <slice> <blob-text>
    local sha
    sha=$(printf '%b' "$2" | git -C "$REPO" hash-object -w --stdin)
    git -C "$REPO" update-ref "refs/loom/claims/$1" "$sha"
}

schema_check() { # <json-file> [schema-file]
    [ -n "${LOOM_NODE:-}" ] && [ -d "$SCRIPTS/node_modules/ajv" ] || skip "pinned node/ajv not available"
    cat >"$WORK/ajv.cjs" <<'EOF'
const { createRequire } = require("module");
const req = createRequire(process.argv[2] + "/validate-repository.mjs");
const Ajv = req("ajv/dist/2020.js");
const fs = require("fs");
const ajv = new Ajv({ allErrors: true, strict: true, allowUnionTypes: true });
const validate = ajv.compile(JSON.parse(fs.readFileSync(process.argv[3], "utf8")));
const ok = validate(JSON.parse(fs.readFileSync(process.argv[4], "utf8")));
if (!ok) console.log(JSON.stringify(validate.errors));
process.exit(ok ? 0 : 1);
EOF
    "$LOOM_NODE" "$WORK/ajv.cjs" "$SCRIPTS" "$SCHEMA" "$1"
}

# ---------------------------------------------------------------------------
# Output forms, pass baseline, unchecked labels
# ---------------------------------------------------------------------------

@test "clean initialized repo: human report passes with explicit unchecked labels, exit 0" {
    run doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"[PASS] host_and_os:"* ]]
    [[ "$output" == *"[PASS] init_mode: mode=Initialized"* ]]
    [[ "$output" == *"[PASS] coordination: no coordination state"* ]]
    [[ "$output" == *"[UNCHECKED] client_adapter: unchecked:"* ]]
    [[ "$output" == *"[UNCHECKED] hook_trust: unchecked:"* ]]
    [[ "$output" == *"[UNCHECKED] egress_sandbox: unchecked:"* ]]
    [[ "$output" == *"Result: pass"* ]]
    [[ "$output" != *"[FAIL]"* ]]
}

@test "json report lists the fixed ids in order; unchecked items stay unchecked" {
    run doctor --json
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.checks | map(.id) | join(" ")')" = "$IDS" ]
    [ "$(printf '%s' "$output" | jq -r '.schema')" = "loom-doctor-report/v1" ]
    [ "$(printf '%s' "$output" | jq -r '.result')" = "pass" ]
    for id in client_adapter hook_trust egress_sandbox; do
        [ "$(check_field "$id" status)" = "unchecked" ]
    done
}

@test "json report validates against the doctor report schema" {
    run doctor --json
    printf '%s' "$output" >"$WORK/report.json"
    schema_check "$WORK/report.json"
}

@test "schema rejects unexpected properties, reordered ids, and unchecked items reported as pass" {
    run doctor --json
    printf '%s' "$output" | jq '.extra=1' >"$WORK/bad1.json"
    ! schema_check "$WORK/bad1.json"
    printf '%s' "$output" | jq '.checks |= (.[0:2] | reverse) + .[2:]' >"$WORK/bad2.json"
    ! schema_check "$WORK/bad2.json"
    printf '%s' "$output" | jq '.checks[8].status="pass"' >"$WORK/bad3.json"
    ! schema_check "$WORK/bad3.json"
    printf '%s' "$output" | jq '.checks[0].extra=1' >"$WORK/bad4.json"
    ! schema_check "$WORK/bad4.json"
}

@test "doctor is read-only: working tree and refs are unchanged" {
    set_schema 2
    before_refs=$(git -C "$REPO" for-each-ref)
    run doctor
    run doctor --json
    [ -z "$(git -C "$REPO" status --porcelain)" ]
    [ "$(git -C "$REPO" for-each-ref)" = "$before_refs" ]
}

# ---------------------------------------------------------------------------
# Warnings and errors
# ---------------------------------------------------------------------------

@test "dirty tree is a warning with exit 0" {
    printf 'x\n' >"$REPO/untracked.txt"
    run doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN] repo_cleanliness:"* ]]
    [[ "$output" == *"Result: warning"* ]]
    run doctor --json
    [ "$(check_field repo_cleanliness status)" = "warning" ]
    [ "$(printf '%s' "$output" | jq -r .result)" = "warning" ]
}

@test "unsupported OS and architecture are errors, exit 1" {
    FAKE_UNAME_S=Linux FAKE_UNAME_M=aarch64 run doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] host_and_os: unsupported host"* ]]
    FAKE_UNAME_S=Plan9 run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field host_and_os status)" = "error" ]
    [ "$(printf '%s' "$output" | jq -r .result)" = "error" ]
}

@test "supported Linux x86-64 passes; macOS older than 14 fails" {
    FAKE_UNAME_S=Linux FAKE_UNAME_M=x86_64 FAKE_UNAME_R=6.5.0 run doctor --json
    [ "$(check_field host_and_os status)" = "pass" ]
    FAKE_UNAME_R=22.6.0 run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field host_and_os status)" = "error" ]
}

@test "bash below 3.2 is an error" {
    LOOM_DOCTOR_BASH_VERSION=3.1.17 run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field host_and_os status)" = "error" ]
    [[ "$(check_field host_and_os evidence)" == *"3.1.17"* ]]
}

@test "old tool versions are errors naming the tool" {
    stub jq 'echo jq-1.5'
    run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field required_tools status)" = "error" ]
    [[ "$(check_field required_tools evidence)" == *"jq>=1.6"* ]]
}

@test "old git and old node are both reported" {
    stub node 'echo v16.20.0'
    printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "git version 2.30.1"; exit 0; fi\nexec "%s" "$@"\n' "$REAL_GIT" >"$STUB/git"
    chmod +x "$STUB/git"
    run doctor --json
    [ "$status" -eq 1 ]
    [[ "$(check_field required_tools evidence)" == *"git>=2.34"* ]]
    [[ "$(check_field required_tools evidence)" == *"node>=18"* ]]
}

@test "missing SHA-256 tooling is an error; either tool suffices" {
    stub shasum 'exit 127'
    stub sha256sum 'exit 127'
    run doctor --json
    [ "$status" -eq 1 ]
    [[ "$(check_field required_tools evidence)" == *"sha256"* ]]
    stub sha256sum 'cat >/dev/null; echo ok'
    run doctor --json
    [ "$(check_field required_tools status)" = "pass" ]
}

@test "missing jq is an error but --json still emits a report" {
    stub jq 'exit 127'
    run doctor --json
    [ "$status" -eq 1 ]
    [[ "$output" == '{"schema":"loom-doctor-report/v1","result":"error"'* ]]
}

@test "incomplete Git identity is an error" {
    : >"$GIT_CONFIG_GLOBAL"
    run doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] git_identity:"* ]]
    printf '[user]\n\tname = Only Name\n' >"$GIT_CONFIG_GLOBAL"
    run doctor --json
    [ "$(check_field git_identity status)" = "error" ]
}

@test "outside a Git work tree the repo-dependent checks error" {
    mkdir "$WORK/plain"
    run bash -c 'cd "$1" && "$2" "$3" --json' _ "$WORK/plain" "$BASH_UNDER" "$PLUGIN/bin/loom-doctor"
    [ "$status" -eq 1 ]
    for id in repo_cleanliness init_mode coordination; do
        [ "$(check_field "$id" status)" = "error" ]
    done
    [ "$(check_field review_protocol status)" = "pass" ]
}

# ---------------------------------------------------------------------------
# Init-mode classifier
# ---------------------------------------------------------------------------

@test "init mode: Greenfield for an empty-ish repo without .docs" {
    rm -rf "$REPO/.docs"
    printf '# readme\n' >"$REPO/README.md"
    commit_all "greenfield"
    run doctor --json
    [[ "$(check_field init_mode evidence)" == "mode=Greenfield"* ]]
    [ "$(check_field init_mode status)" = "pass" ]
}

@test "init mode: Unaligned-bare for a non-empty repo with no docs spine" {
    rm -rf "$REPO/.docs"
    printf 'int main(){}\n' >"$REPO/main.c"
    commit_all "bare"
    run doctor --json
    [[ "$(check_field init_mode evidence)" == "mode=Unaligned-bare"* ]]
}

@test "init mode: partial .docs is Unaligned, not Initialized" {
    rm "$REPO/.docs/status/handoff.md"
    commit_all "partial"
    run doctor --json
    [[ "$(check_field init_mode evidence)" == "mode=Unaligned-bare"* ]]
}

@test "init mode: Unaligned-migrate when a pre-existing docs spine exists" {
    rm -rf "$REPO/.docs"
    mkdir -p "$REPO/docs/specs"
    printf 's\n' >"$REPO/docs/specs/one.md"
    printf 'int main(){}\n' >"$REPO/main.c"
    commit_all "migrate"
    run doctor --json
    [[ "$(check_field init_mode evidence)" == "mode=Unaligned-migrate"* ]]
}

@test "init mode: Initialized wins over an otherwise empty repo" {
    run doctor --json
    [[ "$(check_field init_mode evidence)" == "mode=Initialized"* ]]
}

# ---------------------------------------------------------------------------
# Coordination state
# ---------------------------------------------------------------------------

@test "coordination: schema 2 with a fresh claim passes" {
    set_schema 2
    set_claim s1 "sid\t$(date +%s)\n"
    run doctor --json
    [ "$status" -eq 0 ]
    [ "$(check_field coordination status)" = "pass" ]
    [[ "$(check_field coordination evidence)" == *"1 claim"* ]]
}

@test "coordination: a claim at or beyond the lease TTL is a stale warning" {
    set_schema 2
    set_claim old "sid\t$(($(date +%s) - 7200))\n"
    run doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN] coordination:"* ]]
    LOOM_LEASE_TTL=100000 run doctor --json
    [ "$(check_field coordination status)" = "pass" ]
    set_claim fresh "sid\t$(date +%s)\n"
    LOOM_LEASE_TTL=0 run doctor --json
    [ "$(check_field coordination status)" = "warning" ]
}

@test "coordination: leading-zero timestamps and TTL normalize like loom-coord" {
    set_schema 2
    set_claim lz "sid\t0$(date +%s)\n"
    LOOM_LEASE_TTL=003600 run doctor --json
    [ "$status" -eq 0 ]
    [ "$(check_field coordination status)" = "pass" ]
}

@test "coordination: unreadable timestamp is an error, never stale" {
    set_schema 2
    set_claim bad "sid\tnot-a-number\n"
    run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field coordination status)" = "error" ]
    [[ "$(check_field coordination evidence)" == *"bad"* ]]
    set_claim bad "sid\n"
    run doctor --json
    [ "$(check_field coordination status)" = "error" ]
}

@test "coordination: incompatible schema version is an error" {
    set_schema 3
    run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field coordination status)" = "error" ]
}

@test "coordination: claims without a schema ref are an error" {
    set_claim orphan "sid\t$(date +%s)\n"
    run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field coordination status)" = "error" ]
}

# ---------------------------------------------------------------------------
# Protocol assets
# ---------------------------------------------------------------------------

@test "missing finder asset fails review_protocol" {
    rm "$PLUGIN/finders/review-security-v1.md"
    run doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] review_protocol:"*"review-security-v1.md"* ]]
}

@test "non-executable loom-review fails review_protocol" {
    chmod -x "$PLUGIN/bin/loom-review"
    run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field review_protocol status)" = "error" ]
}

@test "missing loom-eval-workspace fails eval_protocol only" {
    rm "$PLUGIN/bin/loom-eval-workspace"
    run doctor --json
    [ "$status" -eq 1 ]
    [ "$(check_field eval_protocol status)" = "error" ]
    [ "$(check_field review_protocol status)" = "pass" ]
}

# ---------------------------------------------------------------------------
# Invocation and exit codes
# ---------------------------------------------------------------------------

@test "invalid arguments exit 2 with usage on stderr" {
    for args in "--bogus" "--json extra" "json" "-h" "--json --json"; do
        # shellcheck disable=SC2086
        run --separate-stderr doctor $args
        [ "$status" -eq 2 ]
        [ -z "$output" ]
        [[ "$stderr" == "usage: loom-doctor"* ]]
    done
}

# ---------------------------------------------------------------------------
# loom CLI entry point
# ---------------------------------------------------------------------------

@test "loom doctor dispatches to loom-doctor with the same human report" {
    # loom execs the helper via its own shebang, so the shell-version line may differ.
    run doctor
    expected="$(printf '%s\n' "$output" | grep -v 'host_and_os')"
    run loom_cli doctor
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -v 'host_and_os')" = "$expected" ]
}

@test "loom doctor --json dispatches to loom-doctor --json" {
    run loom_cli doctor --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | jq -e '.schema == "loom-doctor-report/v1"' >/dev/null
}

@test "loom forwards the helper's exit status" {
    rm "$PLUGIN/bin/loom-eval-workspace"
    run loom_cli doctor
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] eval_protocol:"* ]]
}

@test "loom forwards invalid doctor arguments as exit 2" {
    run loom_cli doctor --bogus
    [ "$status" -eq 2 ]
}

@test "loom rejects unsupported and missing commands with exit 2" {
    run --separate-stderr loom_cli status
    [ "$status" -eq 2 ]
    [[ "$stderr" == "usage: loom doctor"* ]]
    run loom_cli
    [ "$status" -eq 2 ]
}

@test "loom resolves its adjacent helper through a symlink" {
    ln -s "$PLUGIN/bin/loom" "$WORK/loom-link"
    run bash -c 'cd "$1" && "$2" "$3" doctor --json' _ "$REPO" "$BASH_UNDER" "$WORK/loom-link"
    [ "$status" -eq 0 ]
    printf '%s' "$output" | jq -e '.result == "pass"' >/dev/null
}

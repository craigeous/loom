#!/usr/bin/env bats
# Test suite for loom-eval-workspace (sanitized evaluation workspace, loom-eval-workspace/v1).
# Every test builds a throwaway repository with no remote; no network is used.
bats_require_minimum_version 1.5.0

EW="${BATS_TEST_DIRNAME}/loom-eval-workspace"
RV="${BATS_TEST_DIRNAME}/loom-review"
SCHEMAS="${BATS_TEST_DIRNAME}/../schemas"
SCRIPTS="${BATS_TEST_DIRNAME}/../../../scripts"
FINDERS="review-correctness/v1 review-tests/v1 review-security/v1"
PINPATH="/usr/bin:/bin"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

asset_of() {
    local b="${1//\//-}"
    printf '%s/../finders/%s.md' "$BATS_TEST_DIRNAME" "$b"
}
pin_of() { shasum -a 256 <"$(asset_of "$1")" | cut -d' ' -f1; }

setup() {
    WORK="$(mktemp -d)"
    WORK="$(CDPATH='' cd -- "$WORK" && pwd -P)"
    REPO="$WORK/repo"
    export TMPDIR="$WORK/tmp"
    export HOME="$WORK/home"
    mkdir -m 700 "$TMPDIR" "$HOME"
    mkdir "$WORK/out"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    git init -q -b main "$REPO"
    git -C "$REPO" config user.email test@example.com
    git -C "$REPO" config user.name Test
    mkdir -p "$REPO/plugins/loom/.claude-plugin" "$REPO/.docs/spec" "$REPO/.docs/adr" "$REPO/.docs/status" \
        "$REPO/.docs/evaluations" "$REPO/.claude" "$REPO/transcripts" "$REPO/scripts"
    printf '{"name":"loom","version":"9.8.7"}\n' >"$REPO/plugins/loom/.claude-plugin/plugin.json"
    printf 'plan v1\n' >"$REPO/.docs/plan.md"
    printf 'spec\n' >"$REPO/.docs/spec/s.md"
    printf 'adr\n' >"$REPO/.docs/adr/a.md"
    printf 'rubric\n' >"$REPO/.docs/rubric.md"
    printf 'status history\n' >"$REPO/.docs/status/progress.md"
    printf 'prior verdict\n' >"$REPO/.docs/evaluations/prior-eval.md"
    printf 'unrelated evaluation CANARY-EVAL\n' >"$REPO/.docs/evaluations/other-eval.md"
    printf 'SECRET=CANARY-CRED\n' >"$REPO/.env"
    printf '{"session":"CANARY-SESSION"}\n' >"$REPO/.claude/session.json"
    printf 'CANARY-TRANSCRIPT\n' >"$REPO/transcripts/t.txt"
    printf 'a\nb\nc\n' >"$REPO/f.txt"
    printf 'one\ntwo\nthree\nfour\nfive\n' >"$REPO/old.txt"
    printf '#!/bin/sh\n' >"$REPO/mode.sh"
    cat >"$REPO/scripts/gate" <<'EOF'
#!/bin/sh
# test gate: behaviour is selected by the pinned environment
echo "gate stdout"
echo "gate stderr" >&2
[ -z "${MARKER:-}" ] || : >"$MARKER"
echo x >written-beside-source.txt
echo x >"$HOME/home.txt"
echo x >"$TMPDIR/tmp.txt"
echo x >"$XDG_CACHE_HOME/cache.txt"
echo x >"$LOOM_EVAL_BUILD/build.txt"
[ -z "${DEP_CHECK:-}" ] || cat "$LOOM_EVAL_DEPS/dep.txt"
[ -z "${TOUCH_SOURCE:-}" ] || { chmod u+w "$TOUCH_SOURCE" "$(dirname "$TOUCH_SOURCE")" && echo tamper >>"$TOUCH_SOURCE"; }
[ -z "${TOUCH_REPO:-}" ] || echo tamper >"$TOUCH_REPO"
[ "${SLEEP:-0}" = 0 ] || sleep "$SLEEP"
exit "${GATE_EXIT:-0}"
EOF
    chmod +x "$REPO/scripts/gate"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m base
    BASE="$(git -C "$REPO" rev-parse HEAD)"
    printf 'a\nB\nc\nd\n' >"$REPO/f.txt"
    git -C "$REPO" mv old.txt new.txt
    printf 'one\ntwo\nTHREE\nfour\nfive\n' >"$REPO/new.txt"
    printf '\000\001\002binary' >"$REPO/bin.dat"
    chmod +x "$REPO/mode.sh"
    printf 'plan v2\n' >"$REPO/.docs/plan.md"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m head
    HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
    printf 'docs only\n' >"$REPO/.docs/note.md"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m docs
    DOCS_SHA="$(git -C "$REPO" rev-parse HEAD)"
    printf 'gate green\n' >"$WORK/evidence.txt"
    printf 'dependency payload\n' >"$WORK/dep.txt"
    OUT="$WORK/out/run1"
}

teardown() {
    if [ -n "${WORK:-}" ] && [ -d "$WORK" ]; then
        chmod -R u+w "$WORK" 2>/dev/null || true
        rm -rf "$WORK"
    fi
}

# ---------------------------------------------------------------- helpers

ew() { run "$LOOM_TEST_BASH" "$EW" "$@"; }

prep_plan() {
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --authority .docs/spec/s.md \
        --authority .docs/adr/a.md --rubric .docs/rubric.md --evidence-sha "$HEAD_SHA" --out "$OUT" "$@"
}

# prep_code <extra args...>: code run for base..head with a docs-only skip is invalid (code
# changed); use review-run helpers or the docs-only range.
code_args() { # sets CODE_ARGS for the given base/head
    CODE_ARGS=(--repo "$REPO" --type code --head "$1" --base "$2" --artifact .docs/plan.md --authority .docs/spec/s.md
        --gate-evidence "$WORK/evidence.txt" --gate-arg scripts/gate --gate-env "PATH=$PINPATH" --out "$OUT")
}

prep_docs_code() { # docs-only range, code type
    code_args "$DOCS_SHA" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only "$@"
}

mk_review_run() { # real loom-review run at HEAD_SHA for BASE..HEAD_SHA; sets RREV and RFINDINGS
    git -C "$REPO" checkout -q "$HEAD_SHA"
    local ph=() id
    for id in $FINDERS; do ph+=(--prompt-hash "$id=$(pin_of "$id")"); done
    run "$RV" prepare --repo "$REPO" --slice demo --base "$BASE" --head "$HEAD_SHA" --plan "$REPO/.docs/plan.md" \
        --spec "$REPO/.docs/spec/s.md" --adr "$REPO/.docs/adr/a.md" --gate-evidence "$WORK/evidence.txt" --run-dir "$WORK/out/rv" "${ph[@]}"
    [ "$status" -eq 0 ]
    RREV="$WORK/out/rv"
    for id in $FINDERS; do
        jq -n --slurpfile m "$RREV/manifest.json" --arg id "$id" '
            ($m[0]) as $m | ($m.finders[] | select(.id == $id)) as $fe
            | {protocol: $m.protocol, run_id: $m.run_id, manifest_sha256: $m.manifest_sha256,
               finder: {id: $id, prompt_version: $fe.prompt.version, prompt_sha256: $fe.prompt.sha256},
               base_sha: $m.base_sha, head_sha: $m.head_sha, diff_sha256: $m.diff_sha256, status: "ran-clean", findings: [],
               provenance: {adapter: $fe.adapter, model_profile: $fe.model_profile, started_at: "2026-01-01T00:00:00Z",
                            finished_at: "2026-01-01T00:01:00Z", truncated: false, exit_status: 0}}' \
            >"$RREV/results/${id//\//__}.json"
    done
    git -C "$REPO" checkout -q main
}

assemble_review() {
    mk_review_run
    git -C "$REPO" checkout -q "$HEAD_SHA"
    run "$RV" assemble "$RREV" --repo "$REPO" --out "$WORK/out/review-findings.md"
    [ "$status" -eq 0 ]
    RFINDINGS="$WORK/out/review-findings.md"
    git -C "$REPO" checkout -q main
}

prep_code_review() {
    assemble_review
    code_args "$HEAD_SHA" "$BASE"
    ew prepare "${CODE_ARGS[@]}" --review-run "$RREV" "$@"
}

schema_check() { # <schema-file> <json-file>
    [ -n "${LOOM_NODE:-}" ] && [ -d "$SCRIPTS/node_modules/ajv" ] || skip "pinned node/ajv not available"
    cat >"$WORK/ajv.cjs" <<'EOF'
const { createRequire } = require("module");
const req = createRequire(process.argv[2] + "/validate-repository.mjs");
const Ajv = req("ajv/dist/2020.js");
const addFormats = req("ajv-formats");
const fs = require("fs");
const ajv = new Ajv({ allErrors: true, strict: true, allowUnionTypes: true });
addFormats(ajv);
const validate = ajv.compile(JSON.parse(fs.readFileSync(process.argv[3], "utf8")));
const ok = validate(JSON.parse(fs.readFileSync(process.argv[4], "utf8")));
if (!ok) console.log(JSON.stringify(validate.errors));
process.exit(ok ? 0 : 1);
EOF
    "$LOOM_NODE" "$WORK/ajv.cjs" "$SCRIPTS" "$1" "$2"
}

# edit_manifest <jq filter>: edit and re-hash so the manifest stays self-consistent
edit_manifest() {
    local m="$OUT/manifest.json" h
    jq -S -c "$1 | del(.manifest_sha256)" "$m" >"$m.new"
    h="$(shasum -a 256 <"$m.new" | cut -d' ' -f1)"
    jq -S -c --arg h "$h" '. + {manifest_sha256: $h}' "$m.new" >"$m"
    rm -f "$m.new"
}

verify() { ew verify "$OUT" --repo "$REPO"; }
status_() { ew status "$OUT" --repo "$REPO" "$@"; }
repo_hash() {
    shasum -a 256 <<<"" >/dev/null
    printf '%s' "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)" | shasum -a 256 | cut -c1-16
}

rmrun() {
    chmod -R u+w "$@" 2>/dev/null
    rm -rf "$@"
}

no_partial() { [ -z "$(find "$WORK/out" -maxdepth 1 -name '.tmp-*' -print)" ] && [ ! -e "$OUT" ]; }

# ---------------------------------------------------------------- plan runs

@test "plan: exports exact objects, canonical schema-valid manifest, exclusions and permissions" {
    prep_plan
    [ "$status" -eq 0 ]
    [ "$output" = "$OUT" ]
    m="$OUT/manifest.json"
    [ "$(jq -S -c . "$m")" = "$(cat "$m")" ]
    [ "$(jq -r .protocol "$m")" = loom-eval-workspace/v1 ]
    [ "$(jq -r .evaluation_type "$m")" = plan ]
    [ "$(jq -r .head_sha "$m")" = "$HEAD_SHA" ]
    [ "$(jq -r .head_tree "$m")" = "$(git -C "$REPO" rev-parse "$HEAD_SHA^{tree}")" ]
    [ "$(jq -r .evidence_sha "$m")" = "$HEAD_SHA" ]
    [ "$(jq -S -c 'del(.manifest_sha256)' "$m" | shasum -a 256 | cut -d' ' -f1)" = "$(jq -r .manifest_sha256 "$m")" ]
    schema_check "$SCHEMAS/loom-eval-workspace-manifest-v1.schema.json" "$m"
    # exact object content, not the live checkout
    [ "$(cat "$OUT/inputs/artifact/.docs/plan.md")" = "plan v2" ]
    cmp "$OUT/source/f.txt" <(git -C "$REPO" cat-file blob "$HEAD_SHA:f.txt")
    [ -x "$OUT/source/mode.sh" ]
    # sanitized: policy exclusions recorded, canaries and history absent
    [ "$(jq -c '[.exclusions[] | .reason] | sort' "$m")" = '["credentials","prior-evaluation","prior-evaluation","session-store","status-history","transcript"]' ]
    [ ! -e "$OUT/source/.git" ] && [ ! -e "$OUT/source/.env" ] && [ ! -e "$OUT/source/.docs/status" ]
    ! grep -rq "CANARY" "$OUT/source" "$OUT/inputs"
    ! grep -rq "Test <test@example.com>\|test@example.com" "$OUT/source" "$OUT/inputs" "$OUT/manifest.json"
    # permissions: private root, read-only judgment inputs, private writable output/scratch
    [ -n "$(find "$OUT" -maxdepth 0 -perm 700)" ]
    [ -z "$(find "$OUT/source" "$OUT/inputs" \( -perm -200 -o -perm -020 -o -perm -002 \) -print)" ]
    for d in output scratch; do
        [ -n "$(find "$OUT/$d" -maxdepth 0 -perm 700)" ]
        : >"$OUT/$d/probe"
    done
    # normalized filesystem metadata
    [ "$(stat -f %Sm -t %Y "$OUT/source/f.txt" 2>/dev/null || date -r "$OUT/source/f.txt" +%Y)" = 2000 ]
    verify
    [ "$status" -eq 0 ]
    status_
    [ "$status" -eq 0 ]
    [ "$output" = "status: prepared" ]
}

@test "plan: without an evidence snapshot the source directory is empty" {
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$OUT"
    [ "$status" -eq 0 ]
    [ -z "$(ls -A "$OUT/source")" ]
    [ "$(jq -r .source_export.file_count "$OUT/manifest.json")" = 0 ]
    verify
    [ "$status" -eq 0 ]
}

@test "plan: evidence snapshot is the complete tree at the declared evidence SHA" {
    prep_plan --run-id run1 2>/dev/null || true
    rmrun "$OUT"
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --evidence-sha "$BASE" --out "$OUT"
    [ "$status" -eq 0 ]
    [ "$(cat "$OUT/source/f.txt")" = "$(printf 'a\nb\nc')" ]
    [ -e "$OUT/source/old.txt" ] && [ ! -e "$OUT/source/new.txt" ]
    [ "$(jq -r .evidence_tree "$OUT/manifest.json")" = "$(git -C "$REPO" rev-parse "$BASE^{tree}")" ]
    # an evidence SHA that is not a local object is infrastructure-blocked
    rmrun "$OUT"
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --evidence-sha 0123456789012345678901234567890123456789 --out "$OUT"
    [ "$status" -eq 4 ]
    no_partial
}

@test "plan: default root is a private 0700 directory outside the repository" {
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --run-id dflt
    [ "$status" -eq 0 ]
    run_dir="$output"
    [ "$run_dir" = "$TMPDIR/loom-eval-$(repo_hash)/dflt" ]
    [ -n "$(find "$TMPDIR/loom-eval-$(repo_hash)" -maxdepth 0 -perm 700)" ]
    [ -n "$(find "$run_dir" -maxdepth 0 -perm 700)" ]
    ew status dflt --repo "$REPO"
    [ "$status" -eq 0 ]
    # a default root that would land inside the repository is rejected
    mkdir -m 700 "$REPO/tmp-inside"
    TMPDIR="$REPO/tmp-inside" ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --run-id inside
    [ "$status" -eq 2 ]
    [[ "$output" == *overlaps* ]]
}

@test "plan: independent runs do not share writable paths" {
    prep_plan
    [ "$status" -eq 0 ]
    OUT2="$WORK/out/run2"
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$OUT2"
    [ "$status" -eq 0 ]
    : >"$OUT/output/only-here"
    [ ! -e "$OUT2/output/only-here" ]
    [ "$(stat -f %i "$OUT/output" 2>/dev/null || stat -c %i "$OUT/output")" != "$(stat -f %i "$OUT2/output" 2>/dev/null || stat -c %i "$OUT2/output")" ]
}

@test "plan: re-review binds the prior verdict and the exact revision diff" {
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --prior-verdict .docs/evaluations/prior-eval.md \
        --prior-sha "$BASE" --out "$OUT"
    [ "$status" -eq 0 ]
    m="$OUT/manifest.json"
    [ "$(jq -r .revision.prior_sha "$m")" = "$BASE" ]
    cmp "$OUT/revision.patch" <(git -C "$REPO" diff --binary --full-index -M -C --no-ext-diff --no-color "$BASE" "$HEAD_SHA")
    [ "$(jq -r .revision.diff_sha256 "$m")" = "$(shasum -a 256 <"$OUT/revision.patch" | cut -d' ' -f1)" ]
    [ "$(cat "$OUT/inputs/prior-verdict/.docs/evaluations/prior-eval.md")" = "prior verdict" ]
    schema_check "$SCHEMAS/loom-eval-workspace-manifest-v1.schema.json" "$m"
    verify
    [ "$status" -eq 0 ]
    : >"$OUT/revision.patch.x" 2>/dev/null || true
    rm -f "$OUT/revision.patch.x"
    chmod u+w "$OUT/revision.patch"
    printf 'x' >>"$OUT/revision.patch"
    chmod a-w "$OUT/revision.patch"
    verify
    [ "$status" -eq 2 ]
    # a prior verdict without its prior SHA, or a non-ancestor, is rejected
    rmrun "$OUT"
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --prior-verdict .docs/evaluations/prior-eval.md --out "$OUT"
    [ "$status" -eq 1 ]
    ew prepare --repo "$REPO" --type plan --head "$BASE" --artifact .docs/plan.md --prior-verdict .docs/evaluations/prior-eval.md --prior-sha "$HEAD_SHA" --out "$OUT"
    [ "$status" -eq 2 ]
    no_partial
}

# ---------------------------------------------------------------- research runs

mk_captures() { # <fresh_until> -> $WORK/cap/index.json
    mkdir -p "$WORK/cap"
    printf 'captured page\n' >"$WORK/cap/page1.txt"
    jq -n --arg h "$(shasum -a 256 <"$WORK/cap/page1.txt" | cut -d' ' -f1)" --arg fu "$1" '
        [{locator: "https://example.test/page", file: "page1.txt", retrieved_at: "2020-01-01T00:00:00Z", fresh_until: $fu,
          status: 200, content_type: "text/html", tool: "fetcher/1", sha256: $h}]' >"$WORK/cap/index.json"
}

@test "research: complete fresh captures with provenance are required and bound" {
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --out "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *captures* ]]
    no_partial
    mk_captures 2099-01-01T00:00:00Z
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/index.json" --out "$OUT"
    [ "$status" -eq 0 ]
    m="$OUT/manifest.json"
    [ "$(jq -r '.captures[0] | .locator + " " + (.status | tostring) + " " + .content_type + " " + .tool' "$m")" = "https://example.test/page 200 text/html fetcher/1" ]
    [ "$(cat "$OUT/inputs/captures/files/page1.txt")" = "captured page" ]
    schema_check "$SCHEMAS/loom-eval-workspace-manifest-v1.schema.json" "$m"
    verify
    [ "$status" -eq 0 ]
}

@test "research: stale, hash-mismatched, incomplete and unsafe captures fail closed" {
    mk_captures 2021-01-01T00:00:00Z
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/index.json" --out "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *stale* ]]
    mk_captures 2099-01-01T00:00:00Z
    printf 'tampered\n' >"$WORK/cap/page1.txt"
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/index.json" --out "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"hash mismatch"* ]]
    mk_captures 2099-01-01T00:00:00Z
    jq 'map(del(.tool))' "$WORK/cap/index.json" >"$WORK/cap/i2.json"
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/i2.json" --out "$OUT"
    [ "$status" -eq 2 ]
    jq 'map(.status = 404)' "$WORK/cap/index.json" >"$WORK/cap/i3.json"
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/i3.json" --out "$OUT"
    [ "$status" -eq 2 ]
    jq 'map(.file = "../page1.txt")' "$WORK/cap/index.json" >"$WORK/cap/i4.json"
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/i4.json" --out "$OUT"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/index.json" --out "$OUT"
    [ "$status" -eq 1 ]
    no_partial
}

# ---------------------------------------------------------------- code runs

@test "code: exact diff with rename, binary and mode metadata; pinned gate; schema valid" {
    prep_code_review --tool-version "git=$(env -i PATH="$PINPATH" git --version | awk '{print $3}')" --dependency "$WORK/dep.txt" --gate-env "FOO=bar"
    [ "$status" -eq 0 ]
    m="$OUT/manifest.json"
    expected="$(git -C "$REPO" diff --binary --full-index -M -C --no-ext-diff --no-color "$BASE" "$HEAD_SHA")"
    [ "$(printf '%s\n' "$expected")" = "$(cat "$OUT/diff.patch")" ]
    [ "$(jq -r .diff_sha256 "$m")" = "$(shasum -a 256 <"$OUT/diff.patch" | cut -d' ' -f1)" ]
    grep -q '^rename from old.txt' "$OUT/diff.patch"
    grep -q '^GIT binary patch' "$OUT/diff.patch"
    grep -q '^old mode 100644' "$OUT/diff.patch"
    [ "$(jq -r .base_sha "$m")" = "$BASE" ]
    [ "$(jq -c .gate.argv "$m")" = '["scripts/gate"]' ]
    [ "$(jq -r .gate.env.FOO "$m")" = bar ]
    [ "$(jq -r '.gate.dependencies[0].path' "$m")" = inputs/deps/dep.txt ]
    [ "$(jq -r .review.status "$m")" = assembled ]
    cmp "$OUT/inputs/review-findings.md" "$RFINDINGS"
    [ -f "$OUT/inputs/gate-evidence" ]
    # code source keeps the complete tree except credentials/session/transcripts
    [ -f "$OUT/source/.docs/status/progress.md" ] && [ ! -e "$OUT/source/.env" ] && [ ! -e "$OUT/source/transcripts" ]
    schema_check "$SCHEMAS/loom-eval-workspace-manifest-v1.schema.json" "$m"
    verify
    [ "$status" -eq 0 ]
}

@test "code: base-not-ancestor, equal ids, bad options and unavailable objects are rejected" {
    code_args "$BASE" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    [[ "$output" == *ancestor* ]]
    code_args "$HEAD_SHA" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    code_args "$DOCS_SHA" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}"
    [ "$status" -eq 1 ]
    ew prepare "${CODE_ARGS[@]}" --docs-only --review-run "$WORK"
    [ "$status" -eq 1 ]
    ew prepare "${CODE_ARGS[@]}" --docs-only --bogus x
    [ "$status" -eq 1 ]
    ew prepare "${CODE_ARGS[@]}" --docs-only --head "$HEAD_SHA"
    [ "$status" -eq 1 ]
    ew prepare "${CODE_ARGS[@]}" --docs-only --gate-env "HOME=/x"
    [ "$status" -eq 2 ]
    ew prepare "${CODE_ARGS[@]}" --docs-only --gate-env "NOPATH"
    [ "$status" -eq 2 ]
    code_args "$DOCS_SHA" 0123456789012345678901234567890123456789
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 4 ]
    # the docs-only skip is invalid when the diff touches code
    code_args "$HEAD_SHA" "$BASE"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    [[ "$output" == *docs-only* ]]
    # a pinned environment must define PATH
    code_args "$DOCS_SHA" "$HEAD_SHA"
    CODE_ARGS=("${CODE_ARGS[@]/PATH=$PINPATH/FOO=1}")
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    no_partial
}

@test "code: docs-only status is recorded explicitly and no review findings are included" {
    prep_docs_code
    [ "$status" -eq 0 ]
    [ "$(jq -r .review.status "$OUT/manifest.json")" = "skipped: docs-only" ]
    [ ! -e "$OUT/inputs/review-findings.md" ]
    schema_check "$SCHEMAS/loom-eval-workspace-manifest-v1.schema.json" "$OUT/manifest.json"
    verify
    [ "$status" -eq 0 ]
}

@test "code: unassembled, invalid, mismatched and bootstrap review findings are rejected" {
    mk_review_run
    code_args "$HEAD_SHA" "$BASE"
    # validated but never assembled
    ew prepare "${CODE_ARGS[@]}" --review-run "$RREV"
    [ "$status" -eq 2 ]
    [[ "$output" == *unassembled* ]]
    no_partial
    # a run missing finder results fails the named validator
    rm "$RREV/results/review-tests__v1.json"
    ew prepare "${CODE_ARGS[@]}" --review-run "$RREV"
    [ "$status" -eq 2 ]
    [[ "$output" == *validate* ]]
    rmrun "$RREV"
    # assembled, then the findings file is edited (bootstrap-style text) after assembly
    assemble_review
    printf '# bootstrap review\n- Protocol: loom-repository-bootstrap/v1\n' >"$RFINDINGS"
    ew prepare "${CODE_ARGS[@]}" --review-run "$RREV"
    [ "$status" -eq 2 ]
    no_partial
    # a review run bound to different commits is rejected
    rmrun "$RREV" "$RFINDINGS"
    assemble_review
    code_args "$DOCS_SHA" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}" --review-run "$RREV"
    [ "$status" -eq 2 ]
    no_partial
}

# ---------------------------------------------------------------- verify / status fail closed

tamper_cases() {
    prep_plan
    [ "$status" -eq 0 ]
    verify
    [ "$status" -eq 0 ]
}

@test "verify: altered source, input, mode, extra and missing files fail closed after a successful verification" {
    tamper_cases
    chmod u+w "$OUT/source" "$OUT/source/f.txt"
    printf 'x' >>"$OUT/source/f.txt"
    verify
    [ "$status" -eq 2 ]
    status_
    [ "$status" -eq 2 ]
    [[ "$output" == "status: invalid"* ]]
    rmrun "$OUT"
    tamper_cases
    chmod u+w "$OUT/inputs/artifact/.docs" "$OUT/inputs/artifact/.docs/plan.md"
    printf 'plan v3\n' >"$OUT/inputs/artifact/.docs/plan.md"
    verify
    [ "$status" -eq 2 ]
    chmod -R u+w "$OUT/inputs"
    rmrun "$OUT"
    tamper_cases
    chmod u+w "$OUT/source/mode.sh"
    chmod 444 "$OUT/source/mode.sh"
    verify
    [ "$status" -eq 2 ]
    chmod -R u+w "$OUT/source"
    rmrun "$OUT"
    tamper_cases
    chmod u+w "$OUT/source"
    : >"$OUT/source/extra.txt"
    chmod a-w "$OUT/source/extra.txt" "$OUT/source"
    verify
    [ "$status" -eq 2 ]
    chmod u+w "$OUT/source"
    rm -f "$OUT/source/extra.txt" "$OUT/source/f.txt"
    verify
    [ "$status" -eq 2 ]
    chmod -R u+w "$OUT"
    rmrun "$OUT"
    tamper_cases
    printf 'x' >>"$OUT/inputs/gate-evidence" 2>/dev/null || true
    chmod -R u+w "$OUT/source"
    verify
    [ "$status" -eq 2 ]
}

@test "verify: manifest edits, bad self-hash, unknown versions and top-level extras are rejected" {
    tamper_cases
    cp "$OUT/manifest.json" "$WORK/m.good"
    jq -S -c '.head_sha = "0000000000000000000000000000000000000000"' "$WORK/m.good" >"$OUT/manifest.json"
    verify
    [ "$status" -eq 2 ]
    [[ "$output" == *self-hash* || "$output" == *manifest_sha256* ]]
    cp "$WORK/m.good" "$OUT/manifest.json"
    edit_manifest '.protocol = "loom-eval-workspace/v2"'
    verify
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown protocol"* ]]
    cp "$WORK/m.good" "$OUT/manifest.json"
    edit_manifest '.surprise = 1'
    verify
    [ "$status" -eq 2 ]
    cp "$WORK/m.good" "$OUT/manifest.json"
    edit_manifest '.files += [.files[0]]'
    verify
    [ "$status" -eq 2 ]
    [[ "$output" == *duplicate* ]]
    cp "$WORK/m.good" "$OUT/manifest.json"
    edit_manifest '.files[0].path = "../escape"'
    verify
    [ "$status" -eq 2 ]
    cp "$WORK/m.good" "$OUT/manifest.json"
    edit_manifest '.head_tree = .head_sha'
    verify
    [ "$status" -eq 2 ]
    cp "$WORK/m.good" "$OUT/manifest.json"
    verify
    [ "$status" -eq 0 ]
    : >"$OUT/stray"
    verify
    [ "$status" -eq 2 ]
    [[ "$output" == *"unexpected top-level"* ]]
    rm "$OUT/stray"
    chmod 755 "$OUT/output"
    verify
    [ "$status" -eq 2 ]
}

@test "verify: symlinks, hardlinks and special files inside the run are rejected" {
    tamper_cases
    chmod u+w "$OUT/source"
    ln -s f.txt "$OUT/source/link"
    verify
    [ "$status" -eq 2 ]
    rm "$OUT/source/link"
    ln "$OUT/source/f.txt" "$OUT/source/hard"
    verify
    [ "$status" -eq 2 ]
    rm "$OUT/source/hard"
    mkfifo "$OUT/source/fifo"
    verify
    [ "$status" -eq 2 ]
    rm "$OUT/source/fifo"
    chmod a-w "$OUT/source"
    verify
    [ "$status" -eq 0 ]
}

@test "verify: unavailable Git objects are infrastructure-blocked, never valid" {
    tamper_cases
    git init -q -b main "$WORK/empty"
    ew verify "$OUT" --repo "$WORK/empty"
    [ "$status" -eq 4 ]
    ew status "$OUT" --repo "$WORK/empty"
    [ "$status" -eq 4 ]
    [[ "$output" == "status: infrastructure-blocked"* ]]
    ew verify "$OUT" --repo "$WORK"
    [ "$status" -eq 4 ]
}

@test "verify: diff, base and dependency bindings are rechecked for code runs" {
    prep_docs_code --dependency "$WORK/dep.txt"
    [ "$status" -eq 0 ]
    verify
    [ "$status" -eq 0 ]
    chmod u+w "$OUT/inputs/deps" "$OUT/inputs/deps/dep.txt"
    printf 'evil\n' >"$OUT/inputs/deps/dep.txt"
    verify
    [ "$status" -eq 2 ]
    rmrun "$OUT"
    prep_docs_code
    chmod u+w "$OUT/diff.patch"
    printf 'x' >>"$OUT/diff.patch"
    verify
    [ "$status" -eq 2 ]
    cp "$OUT/manifest.json" "$WORK/m.good"
    edit_manifest '.base_sha = .head_sha'
    verify
    [ "$status" -eq 2 ]
}

@test "status: incomplete runs exit 3 and a changed run is never valid" {
    mkdir -m 700 "$WORK/out/partial"
    ew status "$WORK/out/partial" --repo "$REPO"
    [ "$status" -eq 3 ]
    prep_plan
    [ "$status" -eq 0 ]
    mkdir "$WORK/out/.tmp-run1.99"
    status_
    [ "$status" -eq 3 ]
    [[ "$output" == *"in flight"* ]]
    rmdir "$WORK/out/.tmp-run1.99"
    status_ --json
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = prepared ]
    chmod u+w "$OUT/source"
    : >"$OUT/source/new-file"
    status_
    [ "$status" -eq 2 ]
    ew status nosuchrun --repo "$REPO"
    [ "$status" -eq 1 ]
    ew status "$OUT" --repo "$REPO" --bogus
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------- unsafe locations and inputs

@test "prepare: unsafe output roots, duplicate and extra inputs are rejected with no partial run" {
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$REPO/out-inside"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$REPO/.git/out-inside"
    [ "$status" -eq 2 ]
    [ ! -e "$REPO/out-inside" ] && [ ! -e "$REPO/.git/out-inside" ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "relative/dir"
    [ "$status" -eq 1 ]
    mkdir "$WORK/out/exists"
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$WORK/out/exists"
    [ "$status" -eq 2 ]
    ln -s "$REPO" "$WORK/out/viarepo"
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$WORK/out/viarepo/inside"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$WORK/out/a/../b"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --artifact .docs/plan.md --out "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *duplicate* ]]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --authority .docs/plan.md --out "$OUT"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/nosuch.md --out "$OUT"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact ../escape.md --out "$OUT"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact /etc/passwd --out "$OUT"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs --out "$OUT"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --type code --out "$OUT"
    [ "$status" -eq 1 ]
    ew prepare --repo "$REPO" --type bogus --head "$HEAD_SHA" --artifact .docs/plan.md --out "$OUT"
    [ "$status" -eq 1 ]
    ew prepare --repo "$REPO" --type plan --head abc123 --artifact .docs/plan.md --out "$OUT"
    [ "$status" -eq 2 ]
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --gate-arg x --out "$OUT"
    [ "$status" -eq 1 ]
    no_partial
}

@test "prepare: tracked symlinks and gitlinks in the exported tree are rejected, not omitted" {
    ln -s f.txt "$REPO/linked"
    git -C "$REPO" add linked
    git -C "$REPO" commit -q -m link
    sha="$(git -C "$REPO" rev-parse HEAD)"
    ew prepare --repo "$REPO" --type plan --head "$sha" --artifact .docs/plan.md --evidence-sha "$sha" --out "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *symlink* ]]
    no_partial
    git -C "$REPO" rm -q --cached linked
    git -C "$REPO" update-index --add --cacheinfo "160000,$BASE,sub"
    git -C "$REPO" commit -q -m gitlink
    sha="$(git -C "$REPO" rev-parse HEAD)"
    ew prepare --repo "$REPO" --type plan --head "$sha" --artifact .docs/plan.md --evidence-sha "$sha" --out "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *gitlink* ]]
    no_partial
}

@test "prepare: external evidence must be a regular, single-link, non-symlink file" {
    code_args "$DOCS_SHA" "$HEAD_SHA"
    ev_args() { CODE_ARGS=("${CODE_ARGS[@]/#$WORK\/evidence.txt/$1}"); }
    cp_args=("${CODE_ARGS[@]}")
    ln -s "$WORK/evidence.txt" "$WORK/ev-link"
    ev_args "$WORK/ev-link"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    CODE_ARGS=("${cp_args[@]}")
    ln "$WORK/evidence.txt" "$WORK/ev-hard"
    ev_args "$WORK/ev-hard"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    rm "$WORK/ev-hard"
    CODE_ARGS=("${cp_args[@]}")
    mkfifo "$WORK/ev-fifo"
    ev_args "$WORK/ev-fifo"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    CODE_ARGS=("${cp_args[@]}")
    ev_args "$WORK/missing"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    CODE_ARGS=("${cp_args[@]}")
    ew prepare "${CODE_ARGS[@]}" --docs-only --dependency "$WORK/ev-link"
    [ "$status" -eq 2 ]
    no_partial
}

# ---------------------------------------------------------------- clean

@test "clean: removes only the selected recognized run" {
    prep_plan
    [ "$status" -eq 0 ]
    OUT2="$WORK/out/run2"
    ew prepare --repo "$REPO" --type plan --head "$HEAD_SHA" --artifact .docs/plan.md --out "$OUT2"
    [ "$status" -eq 0 ]
    ew clean "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ ! -e "$OUT" ] && [ -d "$OUT2" ] && [ -d "$WORK/out" ]
    ew clean "$OUT2" --repo "$REPO" --json
    [ "$status" -eq 1 ]
    ew clean "$OUT2"
    [ "$status" -eq 0 ]
    [ -d "$WORK/out" ] && [ -d "$REPO/.git" ]
}

@test "clean: rejects foreign directories, symlinked roots, malformed manifests, links and the repository" {
    mkdir "$WORK/out/foreign"
    printf 'keep\n' >"$WORK/out/foreign/file"
    ew clean "$WORK/out/foreign" --repo "$REPO"
    [ "$status" -eq 2 ]
    [ -f "$WORK/out/foreign/file" ]
    ew clean "$REPO" --repo "$REPO"
    [ "$status" -eq 2 ]
    [ -d "$REPO/.git" ]
    ew clean "$REPO/.git" --repo "$REPO"
    [ "$status" -eq 2 ]
    prep_plan
    ln -s "$OUT" "$WORK/out/symroot"
    ew clean "$WORK/out/symroot" --repo "$REPO"
    [ "$status" -eq 2 ]
    [ -d "$OUT" ]
    cp "$OUT/manifest.json" "$WORK/m.good"
    printf '{"protocol":"loom-eval-workspace/v1"}\n' >"$OUT/manifest.json"
    ew clean "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [ -d "$OUT" ]
    cp "$WORK/m.good" "$OUT/manifest.json"
    mkdir "$WORK/precious"
    : >"$WORK/precious/data"
    ln -s "$WORK/precious" "$OUT/scratch/escape"
    ew clean "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [ -e "$WORK/precious/data" ] && [ -d "$OUT" ]
    rm "$OUT/scratch/escape"
    : >"$OUT/extra-entry"
    ew clean "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    rm "$OUT/extra-entry"
    ew clean "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ -e "$WORK/precious/data" ]
}

# ---------------------------------------------------------------- Round 0 regressions

excluded_commit() { # <path>: commit a change to an excluded path on top of DOCS_SHA; sets EXCL_SHA
    printf 'changed CANARY-DIFF\n' >"$REPO/$1"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m excluded
    EXCL_SHA="$(git -C "$REPO" rev-parse HEAD)"
}

@test "diff: a code diff or revision diff touching excluded content is rejected, with no partial run" {
    excluded_commit .env
    code_args "$EXCL_SHA" "$DOCS_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    [[ "$output" == *"excluded content: .env"* ]]
    no_partial
    ew prepare --repo "$REPO" --type plan --head "$EXCL_SHA" --artifact .docs/plan.md --prior-verdict .docs/evaluations/prior-eval.md \
        --prior-sha "$DOCS_SHA" --out "$OUT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"excluded content: .env"* ]]
    no_partial
    excluded_commit .docs/status/progress.md
    code_args "$EXCL_SHA" "$DOCS_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 2 ]
    [[ "$output" == *"excluded content: .docs/status/progress.md"* ]]
    no_partial
}

@test "diff: a changed excluded path that is an explicit input is allowed and rechecked by verify" {
    excluded_commit .docs/evaluations/prior-eval.md
    ew prepare --repo "$REPO" --type plan --head "$EXCL_SHA" --artifact .docs/plan.md --prior-verdict .docs/evaluations/prior-eval.md \
        --prior-sha "$DOCS_SHA" --out "$OUT"
    [ "$status" -eq 0 ]
    verify
    [ "$status" -eq 0 ]
}

@test "exclusions: plan, research and code snapshots omit status history and unrelated evaluations" {
    mk_captures 2099-01-01T00:00:00Z
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --evidence-sha "$HEAD_SHA" \
        --captures "$WORK/cap/index.json" --out "$OUT"
    [ "$status" -eq 0 ]
    [ ! -e "$OUT/source/.docs/status" ] && [ ! -e "$OUT/source/.docs/evaluations" ]
    ! grep -rq "CANARY" "$OUT/source" "$OUT/inputs"
    [ "$(jq -c '[.exclusions[] | .reason] | unique' "$OUT/manifest.json")" = '["credentials","prior-evaluation","session-store","status-history","transcript"]' ]
    verify
    [ "$status" -eq 0 ]
    rmrun "$OUT"
    code_args "$DOCS_SHA" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 0 ]
    [ ! -e "$OUT/source/.docs/status" ] && [ ! -e "$OUT/source/.docs/evaluations" ]
    verify
    [ "$status" -eq 0 ]
}

@test "verify: nested unknown manifest properties are rejected" {
    prep_plan
    [ "$status" -eq 0 ]
    local f
    for f in '.source_export.extra = 1' '.exclusions[0].extra = 1' '.files[0].extra = 1'; do
        cp "$OUT/manifest.json" "$WORK/manifest.keep"
        chmod u+w "$OUT/manifest.json" "$OUT" 2>/dev/null || true
        edit_manifest "$f"
        verify
        [ "$status" -eq 2 ]
        [[ "$output" == *"manifest:"* ]]
        cp "$WORK/manifest.keep" "$OUT/manifest.json"
    done
    verify
    [ "$status" -eq 0 ]
    rmrun "$OUT"
    code_args "$DOCS_SHA" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only
    [ "$status" -eq 0 ]
    for f in '.gate.extra = 1' '.review.extra = 1' '.gate.tools = [{name: "git", version: "2", extra: 1}]'; do
        cp "$OUT/manifest.json" "$WORK/manifest.keep"
        edit_manifest "$f"
        verify
        [ "$status" -eq 2 ]
        cp "$WORK/manifest.keep" "$OUT/manifest.json"
    done
    rmrun "$OUT"
    mk_captures 2099-01-01T00:00:00Z
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/index.json" --out "$OUT"
    [ "$status" -eq 0 ]
    edit_manifest '.captures[0].extra = 1'
    verify
    [ "$status" -eq 2 ]
}

@test "verify: manifest schema validates review run_id type and pattern" {
    prep_code_review
    [ "$status" -eq 0 ]
    verify
    [ "$status" -eq 0 ]
    cp "$OUT/manifest.json" "$WORK/manifest.keep"
    edit_manifest '.review.run_id = 123'
    verify
    [ "$status" -eq 2 ]
    [[ "$output" == *"manifest: /review/run_id"* ]]
    cp "$WORK/manifest.keep" "$OUT/manifest.json"
    edit_manifest '.review.run_id = "INVALID_UPPERCASE"'
    verify
    [ "$status" -eq 2 ]
    [[ "$output" == *"manifest: /review/run_id"* ]]
}

@test "verify: expired research captures are infrastructure-blocked (4) in verify and status" {
    mk_captures 2099-01-01T00:00:00Z
    ew prepare --repo "$REPO" --type research --head "$HEAD_SHA" --artifact .docs/plan.md --captures "$WORK/cap/index.json" --out "$OUT"
    [ "$status" -eq 0 ]
    edit_manifest '.captures[0].fresh_until = "2021-01-01T00:00:00Z"'
    verify
    [ "$status" -eq 4 ]
    [[ "$output" == *"expired"* ]]
    status_
    [ "$status" -eq 4 ]
    [[ "$output" == "status: infrastructure-blocked"* ]]
}

@test "verify: run root, output and scratch must be exactly mode 0700" {
    prep_plan
    [ "$status" -eq 0 ]
    local d
    for d in output scratch; do
        chmod 777 "$OUT/$d"
        verify
        [ "$status" -eq 2 ]
        [[ "$output" == *"$d/ is not mode 0700"* ]]
        chmod 750 "$OUT/$d"
        verify
        [ "$status" -eq 2 ]
        chmod 700 "$OUT/$d"
    done
    chmod 777 "$OUT"
    verify
    [ "$status" -eq 2 ]
    [[ "$output" == *"run root is not mode 0700"* ]]
    status_
    [ "$status" -eq 2 ]
    chmod 700 "$OUT"
    verify
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------- usage

@test "usage: unknown subcommands, missing arguments and help exit 1" {
    ew
    [ "$status" -eq 1 ]
    ew bogus
    [ "$status" -eq 1 ]
    ew verify
    [ "$status" -eq 1 ]
    ew status "$OUT" extra --repo "$REPO"
    [ "$status" -eq 1 ]
    ew --help
    [ "$status" -eq 1 ]
    [[ "$output" == *"usage: loom-eval-workspace"* ]]
}

# ---------------------------------------------------------------- gate-rerun

prep_run() { # code run over the docs-only range; extra args appended
    code_args "$DOCS_SHA" "$HEAD_SHA"
    ew prepare "${CODE_ARGS[@]}" --docs-only "$@"
    [ "$status" -eq 0 ]
}
gr() { ew gate-rerun "$OUT" --repo "$REPO"; }
att() { printf '%s/reruns/attempt-%s' "$OUT" "$1"; }
ev() { jq -r "$2" "$(att "$1")/gate-rerun.json"; }
no_exec() { [ -z "$(ls -A "$OUT/scratch")" ]; }
mk_tool() { # <name> <version-line>: a fixture tool on $WORK/tools
    mkdir -p "$WORK/tools"
    printf '#!/bin/sh\necho "%s"\n' "$2" >"$WORK/tools/$1"
    chmod +x "$WORK/tools/$1"
}
wait_for() { # <file>: wait up to 20s for a marker file
    local i=0
    while [ ! -e "$1" ] && [ "$i" -lt 200 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    [ -e "$1" ]
}

@test "gate-rerun: a passing gate records schema-valid evidence, leaves source and checkout untouched and cleans up" {
    prep_run --gate-env "MARKER=$WORK/marker"
    git -C "$REPO" status --porcelain >"$WORK/git.before"
    gr
    [ "$status" -eq 0 ]
    [[ "$output" == *"status: rerun-passed"* ]]
    [ -e "$WORK/marker" ]
    [ "$(ev 1 .result)" = rerun-passed ] && [ "$(ev 1 .completion)" = completed ] && [ "$(ev 1 .exit_status)" = 0 ]
    [ "$(ev 1 .seq)" = 1 ] && [ "$(ev 1 .source_verification.source)" = unchanged ] && [ "$(ev 1 .source_verification.checkout)" = unchanged ]
    [ "$(ev 1 .manifest_sha256)" = "$(jq -r .manifest_sha256 "$OUT/manifest.json")" ]
    [ "$(ev 1 .command_env_sha256)" = "$(jq -r .gate.command_env_sha256 "$OUT/manifest.json")" ]
    [ "$(ev 1 .stdout.sha256)" = "$(shasum -a 256 <"$(att 1)/stdout.log" | cut -d' ' -f1)" ]
    [ "$(ev 1 .stdout.bytes)" = "$(wc -c <"$(att 1)/stdout.log" | tr -d ' ')" ]
    [ "$(cat "$(att 1)/stdout.log")" = "gate stdout" ] && [ "$(cat "$(att 1)/stderr.log")" = "gate stderr" ]
    # writes beside source and into home/config/cache/temp/build land in the copy or private scratch only
    [ "$(ev 1 '.changes | map(select(.kind == "added") | .path) | index("written-beside-source.txt") != null')" = true ]
    [ ! -e "$REPO/written-beside-source.txt" ] && [ -z "$(ls -A "$HOME")" ]
    [ "$(git -C "$REPO" status --porcelain)" = "$(cat "$WORK/git.before")" ]
    no_exec
    schema_check "$SCHEMAS/loom-eval-gate-rerun-v1.schema.json" "$(att 1)/gate-rerun.json"
    verify
    [ "$status" -eq 0 ]
    status_ --json
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = rerun-passed ]
    ew clean "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ ! -e "$OUT" ]
}

@test "gate-rerun: exact argv with spaces and metacharacters runs in an empty pinned environment with reserved redirects" {
    export AMBIENT_CANARY=leak-me
    code_args "$DOCS_SHA" "$HEAD_SHA"
    CODE_ARGS=("${CODE_ARGS[@]/scripts\/gate//bin/sh}")
    ew prepare "${CODE_ARGS[@]}" --docs-only --gate-arg -c --gate-arg 'printf "<%s>" "$@"; echo; env | LC_ALL=C sort' \
        --gate-arg _ --gate-arg 'a b' --gate-arg '$HOME;*|"q"' --gate-env KEEP=pinned
    [ "$status" -eq 0 ]
    gr
    [ "$status" -eq 0 ]
    local out="$(att 1)/stdout.log" k
    [ "$(head -n 1 "$out")" = '<a b><$HOME;*|"q">' ]
    ! grep -q 'AMBIENT_CANARY\|leak-me' "$out"
    grep -qx 'KEEP=pinned' "$out"
    grep -qx "PATH=$PINPATH" "$out"
    # every reserved name is redirected below the private execution tree; deps are read-only inputs
    for k in HOME TMPDIR TMP TEMP XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME CARGO_HOME CARGO_TARGET_DIR GOCACHE GOPATH npm_config_cache PIP_CACHE_DIR LOOM_EVAL_BUILD LOOM_EVAL_SCRATCH; do
        grep -q "^$k=$OUT/scratch/exec\." "$out"
    done
    grep -qx "LOOM_EVAL_DEPS=$OUT/inputs/deps" "$out"
    grep -q '^HOME=.*/scratch/home$' "$out"
    grep -q '^XDG_CACHE_HOME=.*/scratch/xdg/cache$' "$out"
    no_exec
}

@test "gate-rerun: a nonzero gate is rerun-failed (2) and status agrees" {
    prep_run --gate-env GATE_EXIT=3
    gr
    [ "$status" -eq 2 ]
    [[ "$output" == *"status: rerun-failed"* ]]
    [ "$(ev 1 .result)" = rerun-failed ] && [ "$(ev 1 .exit_status)" = 3 ]
    no_exec
    status_
    [ "$status" -eq 2 ]
    [[ "$output" == *"status: rerun-failed"* ]]
    verify
    [ "$status" -eq 0 ]
}

@test "gate-rerun: usage errors exit 1; overrides, non-code runs and bad runs are rejected without evidence" {
    prep_run
    ew gate-rerun
    [ "$status" -eq 1 ]
    ew gate-rerun "$OUT" --repo "$REPO" extra
    [ "$status" -eq 1 ]
    ew gate-rerun "$OUT" --repo "$REPO" --gate-arg true
    [ "$status" -eq 1 ]
    ew gate-rerun "$OUT" --repo "$REPO" --gate-env A=b
    [ "$status" -eq 1 ]
    ew gate-rerun "$OUT" --repo "$REPO" --json
    [ "$status" -eq 1 ]
    ew gate-rerun nosuchrun --repo "$REPO"
    [ "$status" -eq 1 ]
    [ ! -e "$OUT/reruns" ]
    # a changed run: no evidence is written and nothing runs
    rmrun "$OUT"
    prep_run --gate-env "MARKER=$WORK/marker"
    chmod u+w "$OUT/source" "$OUT/source/f.txt"
    echo tamper >>"$OUT/source/f.txt"
    gr
    [ "$status" -eq 2 ]
    [ ! -e "$OUT/reruns" ] && [ ! -e "$WORK/marker" ]
    rmrun "$OUT"
    prep_run
    edit_manifest '.head_tree = .head_sha'
    gr
    [ "$status" -eq 2 ]
    [ ! -e "$OUT/reruns" ]
    rmrun "$OUT"
    prep_plan
    [ "$status" -eq 0 ]
    gr
    [ "$status" -eq 2 ]
    [[ "$output" == *"code run"* ]]
    [ ! -e "$OUT/reruns" ]
}

@test "gate-rerun: pinned tools are probed on the pinned PATH and recorded" {
    mk_tool mytool "mytool 1.2.3 (build 9)"
    code_args "$DOCS_SHA" "$HEAD_SHA"
    CODE_ARGS=("${CODE_ARGS[@]/PATH=$PINPATH/PATH=$WORK/tools:$PINPATH}")
    ew prepare "${CODE_ARGS[@]}" --docs-only --tool-version mytool=1.2.3
    [ "$status" -eq 0 ]
    gr
    [ "$status" -eq 0 ]
    [ "$(ev 1 '.tool_versions | length')" = 1 ] && [ "$(ev 1 '.tool_versions[0].name')" = mytool ]
    [ "$(ev 1 '.tool_versions[0].version')" = "mytool 1.2.3 (build 9)" ]
}

@test "gate-rerun: missing, mismatched, failing or off-PATH tools are infrastructure-blocked (4) with blocked evidence" {
    local variant
    mk_tool mytool "mytool 1.2.30"
    mk_tool badtool "x"
    printf '#!/bin/sh\nexit 1\n' >"$WORK/tools/badtool"
    mk_tool othertool "othertool 1"
    for variant in "mytool=1.2.3" "nosuchtool=1" "badtool=1" "othertool=1"; do
        rm -f "$WORK/marker"
        rmrun "$OUT" 2>/dev/null || true
        code_args "$DOCS_SHA" "$HEAD_SHA"
        # othertool is on the ambient PATH only, never on the pinned PATH
        if [ "$variant" != othertool=1 ]; then CODE_ARGS=("${CODE_ARGS[@]/PATH=$PINPATH/PATH=$WORK/tools:$PINPATH}"); fi
        ew prepare "${CODE_ARGS[@]}" --docs-only --gate-env "MARKER=$WORK/marker" --tool-version "$variant"
        [ "$status" -eq 0 ]
        PATH="$WORK/tools:$PATH" gr
        [ "$status" -eq 4 ]
        [ ! -e "$WORK/marker" ]
        [ "$(ev 1 .completion)" = blocked ] && [ "$(ev 1 .result)" = infrastructure-blocked ] && [ "$(ev 1 .exit_status)" = null ]
        [ "$(ev 1 .stdout.bytes)" = 0 ] && [ "$(ev 1 .stderr.bytes)" = 0 ]
        [ "$(ev 1 .start_inventory.sha256)" = "$(ev 1 .end_inventory.sha256)" ]
        no_exec
        status_
        [ "$status" -eq 4 ]
        [[ "$output" == *"infrastructure-blocked"* ]]
    done
}

@test "gate-rerun: pinned dependencies are provided read-only through LOOM_EVAL_DEPS" {
    prep_run --dependency "$WORK/dep.txt" --gate-env DEP_CHECK=1
    gr
    [ "$status" -eq 0 ]
    [ "$(cat "$(att 1)/stdout.log")" = "$(printf 'gate stdout\ndependency payload')" ]
    verify
    [ "$status" -eq 0 ]
    # a dependency removed from the run fails verification before anything runs
    chmod u+w "$OUT/inputs/deps"
    rm -f "$OUT/inputs/deps/dep.txt"
    gr
    [ "$status" -eq 2 ]
    [ ! -e "$(att 2)" ]
}

@test "gate-rerun: a gate that alters the immutable source is invalid (2) and the run stays invalid" {
    prep_run --gate-env "TOUCH_SOURCE=$OUT/source/f.txt"
    gr
    [ "$status" -eq 2 ]
    [ "$(ev 1 .result)" = invalid ] && [ "$(ev 1 .source_verification.source)" = changed ]
    no_exec
    status_
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid"* ]]
    gr
    [ "$status" -eq 2 ]
    [ ! -e "$(att 2)" ]
}

@test "gate-rerun: a gate that alters the checkout is invalid; ignored files and .git internals are not changes" {
    printf 'ignored.log\n' >"$REPO/.gitignore"
    prep_run --gate-env "TOUCH_REPO=$REPO/ignored.log"
    gr
    [ "$status" -eq 0 ]
    [ "$(ev 1 .source_verification.checkout)" = unchanged ]
    rmrun "$OUT"
    prep_run --gate-env "TOUCH_REPO=$REPO/.git/tamper"
    gr
    [ "$status" -eq 0 ]
    rmrun "$OUT"
    prep_run --gate-env "TOUCH_REPO=$REPO/tampered.txt"
    gr
    [ "$status" -eq 2 ]
    [ "$(ev 1 .result)" = invalid ] && [ "$(ev 1 .source_verification.checkout)" = changed ] && [ "$(ev 1 .completion)" = completed ]
    status_
    [ "$status" -eq 2 ]
    # a later attempt starts from the new checkout state and never overwrites attempt 1
    gr
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
    [ "$(ev 1 .result)" = invalid ]
    [ "$(ev 2 .seq)" = 2 ]
}

@test "gate-rerun: succeeds without a git repository and records the checkout as unchanged" {
    prep_run
    mkdir "$WORK/norepo"
    cd "$WORK/norepo"
    ew gate-rerun "$OUT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"status: rerun-passed"* ]]
    [ "$(ev 1 .result)" = rerun-passed ]
    [ "$(ev 1 .source_verification.source)" = unchanged ] && [ "$(ev 1 .source_verification.checkout)" = unchanged ]
    # verify still needs the repository for object binding
    ew verify "$OUT"
    [ "$status" -eq 4 ]
}

@test "gate-rerun: succeeds against a bare repository with no checkout" {
    prep_run
    git clone --bare --quiet "$REPO" "$WORK/bare.git"
    ew gate-rerun "$OUT" --repo "$WORK/bare.git"
    [ "$status" -eq 0 ]
    [ "$(ev 1 .result)" = rerun-passed ]
    [ "$(ev 1 .source_verification.source)" = unchanged ] && [ "$(ev 1 .source_verification.checkout)" = unchanged ]
    ew verify "$OUT" --repo "$WORK/bare.git"
    [ "$status" -eq 0 ]
}

@test "gate-rerun: a corrupted execution copy is invalid (2) and the gate never runs" {
    mkdir "$WORK/shim"
    cat >"$WORK/shim/cp" <<'SHIM'
#!/bin/sh
/bin/cp "$@"
rc=$?
for last; do :; done
chmod u+w "$last/f.txt"
echo corrupt >>"$last/f.txt"
exit $rc
SHIM
    chmod +x "$WORK/shim/cp"
    prep_run --gate-env "MARKER=$WORK/marker"
    PATH="$WORK/shim:$PATH" gr
    [ "$status" -eq 2 ]
    [ ! -e "$WORK/marker" ]
    [ "$(ev 1 .completion)" = invalid ] && [ "$(ev 1 .result)" = invalid ] && [ "$(ev 1 .exit_status)" = null ]
    no_exec
}

@test "gate-rerun: repeat attempts never overwrite and the latest attempt decides status" {
    prep_run
    gr
    [ "$status" -eq 0 ]
    cp "$(att 1)/gate-rerun.json" "$WORK/attempt1.json"
    gr
    [ "$status" -eq 0 ]
    [ "$(ev 2 .seq)" = 2 ]
    cmp -s "$WORK/attempt1.json" "$(att 1)/gate-rerun.json"
    [ -f "$(att 1)/stdout.log" ] && [ -f "$(att 2)/stdout.log" ]
    status_
    [ "$status" -eq 0 ]
    # a killed or in-progress latest attempt is incomplete and never falls back to the earlier pass
    mkdir -m 700 "$(att 3)"
    status_
    [ "$status" -eq 3 ]
    [[ "$output" == *"status: incomplete"* ]]
    verify
    [ "$status" -eq 0 ]
    gr
    [ "$status" -eq 0 ]
    [ "$(ev 4 .seq)" = 4 ]
    status_
    [ "$status" -eq 0 ]
    # sequence gaps are invalid
    mv "$(att 4)" "$(att 7)"
    status_
    [ "$status" -eq 2 ]
}

@test "gate-rerun: status rejects corrupt, stale, cross-run and tampered evidence" {
    prep_run
    gr
    [ "$status" -eq 0 ]
    local e filter
    e="$(att 1)/gate-rerun.json"
    cp "$e" "$WORK/good.json"
    for filter in '.result = "rerun-failed"' '.manifest_sha256 = ("0" * 64)' '.run_id = "other-run"' '.command_env_sha256 = ("1" * 64)' \
        '.seq = 2' '. + {extra: 1}' '.stdout.bytes = 99' '.source_verification.checkout = "changed"'; do
        jq -c "$filter" "$WORK/good.json" >"$e"
        status_
        [ "$status" -eq 2 ]
        [[ "$output" == *"status: invalid"* ]]
    done
    printf 'not json' >"$e"
    status_
    [ "$status" -eq 2 ]
    cp "$WORK/good.json" "$e"
    status_
    [ "$status" -eq 0 ]
    echo extra >>"$(att 1)/stdout.log"
    status_
    [ "$status" -eq 2 ]
    printf 'gate stdout\n' >"$(att 1)/stdout.log"
    status_
    [ "$status" -eq 0 ]
    printf 'xxxxxxx\n' >"$(att 1)/stderr.log"
    status_
    [ "$status" -eq 2 ]
    printf 'gate stderr\n' >"$(att 1)/stderr.log"
    # evidence copied from another run cannot vouch for this one
    local first="$OUT"
    OUT="$WORK/out/run2"
    prep_run
    mkdir -m 700 "$OUT/reruns" "$OUT/reruns/attempt-1"
    cp "$first/reruns/attempt-1/"* "$OUT/reruns/attempt-1/"
    status_
    [ "$status" -eq 2 ]
    # a changed run is never masked by an earlier pass
    OUT="$first"
    status_
    [ "$status" -eq 0 ]
    chmod u+w "$OUT/source" "$OUT/source/f.txt"
    echo tamper >>"$OUT/source/f.txt"
    status_
    [ "$status" -eq 2 ]
}

@test "gate-rerun: catchable interruption terminates the gate group, records interrupted evidence and exits 4" {
    prep_run --gate-env "MARKER=$WORK/started" --gate-env SLEEP=47
    "$LOOM_TEST_BASH" "$EW" gate-rerun "$OUT" --repo "$REPO" >"$WORK/gr.out" 2>&1 &
    local pid=$! rc=0
    wait_for "$WORK/started"
    kill -TERM "$pid"
    wait "$pid" || rc=$?
    [ "$rc" -eq 4 ]
    ! pgrep -f 'sleep 47' >/dev/null
    [ "$(ev 1 .completion)" = interrupted ] && [ "$(ev 1 .result)" = infrastructure-blocked ] && [ "$(ev 1 .exit_status)" = null ]
    no_exec
    status_
    [ "$status" -eq 4 ]
    verify
    [ "$status" -eq 0 ]
}

@test "gate-rerun: a hard kill leaves an incomplete attempt that can never pass" {
    prep_run --gate-env "MARKER=$WORK/started" --gate-env SLEEP=53
    "$LOOM_TEST_BASH" "$EW" gate-rerun "$OUT" --repo "$REPO" >"$WORK/gr.out" 2>&1 &
    local pid=$! gpid pg
    wait_for "$WORK/started"
    gpid="$(pgrep -f 'sleep 53' | head -n 1)"
    pg="$(ps -o pgid= -p "$gpid" | tr -d ' ')"
    kill -KILL "$pid"
    wait "$pid" || true
    kill -KILL -- "-$pg" 2>/dev/null || true
    [ ! -e "$(att 1)/gate-rerun.json" ]
    status_
    [ "$status" -eq 3 ]
    # the stale execution tree is runner-owned scratch; clean still removes the run
    ew clean "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ ! -e "$OUT" ]
}

@test "gate-rerun: usage text lists the subcommand" {
    ew --help
    [[ "$output" == *"gate-rerun <run-dir|run-id>"* ]]
}

# ---------------------------------------------------------------- record

PLAN_REL=.docs/slice-plans/ci-baseline.md
ADR23_REL=.docs/ADR/0023-repository-self-hosting-bootstrap-transition.md
rec_commit() {
    # an eligible bootstrap repository by default: ADR 0023 present and an authoritative active phase
    mkdir -p "$REPO/.docs/ADR" "$REPO/.git/loom"
    # a blob's id is its content hash, so the cited authority snapshot cannot be forged; borrow the real Loom object database
    printf '%s\n' "$(git -C "$BATS_TEST_DIRNAME" rev-parse --path-format=absolute --git-common-dir)/objects" >"$REPO/.git/objects/info/alternates"
    [ -e "$REPO/$ADR23_REL" ] || printf '# ADR 23\n\nStatus: Accepted\n\nAuthority snapshot: 316ae4bc964fb422134151478b6369e1f9b4cfa5\nEvidence mode: loom-repository-bootstrap/v1\n' >"$REPO/$ADR23_REL"
    [ -e "$REPO/.git/loom/bootstrap-phase" ] || printf 'active\n' >"$REPO/.git/loom/bootstrap-phase"
    mkdir -p "$(dirname -- "$REPO/$1")"
    printf '%s\n' "$2" >"$REPO/$1"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m "$1"
}
rec_head() { git -C "$REPO" rev-parse HEAD; }
art_status() { sed -n 's/^Status: //p' "$REPO/${1:-$PLAN_REL}" | head -n 1; }

rec_plan() {
    local st="${1:-Plan Review}"
    shift || true
    rec_commit "$PLAN_REL" $'# Demo\n\nStatus: '"$st"$'\n\n## Content\n'
    ew prepare --repo "$REPO" --type plan --head "$(rec_head)" --artifact "$PLAN_REL" --authority .docs/spec/s.md --out "$OUT" "$@"
    [ "$status" -eq 0 ]
}

rec_code() {
    rec_commit "$PLAN_REL" $'# Demo\n\nStatus: In Progress\n\n## Content\n'
    local base
    base="$(rec_head)"
    rec_commit "$PLAN_REL" $'# Demo\n\nStatus: Implemented\n\n## Content\n'
    local gargs=(--gate-arg /usr/bin/true)
    if [ $# -gt 0 ]; then gargs=("$@"); fi
    ew prepare --repo "$REPO" --type code --head "$(rec_head)" --base "$base" --artifact "$PLAN_REL" --authority .docs/spec/s.md --docs-only \
        --gate-evidence "$WORK/evidence.txt" --gate-env "PATH=$PINPATH" "${gargs[@]}" --out "$OUT"
    [ "$status" -eq 0 ] || {
        echo "CODE PREP FAILED: $output"
        false
    }
    ew gate-rerun "$OUT" --repo "$REPO" || true
}

mk_verdict() {
    local m="$OUT/manifest.json"
    local t
    t="$(jq -r .evaluation_type "$m")"
    local run_id
    run_id="$(jq -r .run_id "$m")"
    local m_sha
    m_sha="$(jq -r .manifest_sha256 "$m")"
    local h_sha
    h_sha="$(jq -r .head_sha "$m")"
    local b_sha
    b_sha="$(jq -r '.base_sha // empty' "$m")"
    local art
    art="$(jq -r '.files[] | select(.role == "artifact") | .path | sub("^inputs/artifact/"; "")' "$m")"
    local auth
    auth="$(jq -c '[.files[] | select(.role == "authority") | .path | sub("^inputs/authority/"; "")]' "$m")"

    local code_fields="{}"
    if [ "$t" = code ]; then
        local ev_dir ev_seq ev_path ev_sha ev_res
        ev_dir="$(ls "$OUT/reruns" | sort -V | tail -n 1)"
        ev_seq="${ev_dir#attempt-}"
        ev_path="$OUT/reruns/$ev_dir/gate-rerun.json"
        ev_sha="$(shasum -a 256 <"$ev_path" | cut -d' ' -f1)"
        ev_res="$(jq -r .result "$ev_path")"
        code_fields="$(jq -n -c --argjson seq "$ev_seq" --arg res "$ev_res" --arg h "$ev_sha" \
            '{rerun_attempt: {seq: $seq, result: $res, evidence_sha256: $h}, local_review: [{finding_id: "COR-1", disposition: "resolved", rationale: "verified"}]}')"
    fi

    jq -n -c \
        --arg proto "loom-eval-verdict/v1" \
        --arg rid "$run_id" \
        --arg msha "$m_sha" \
        --arg etype "$t" \
        --arg art "$art" \
        --arg hsha "$h_sha" \
        --arg bsha "$b_sha" \
        --argjson auth "$auth" \
        --argjson code "$code_fields" \
        '{
            protocol: $proto,
            run_id: $rid,
            manifest_sha256: $msha,
            evaluation_type: $etype,
            artifact: $art,
            head_sha: $hsha,
            verdict: "PASS",
            round: 0,
            title: "Demo Review",
            authority: $auth,
            findings: [],
            required_changes: [],
            notes: ["all checks passed"]
        } + (if $bsha != "" then {base_sha: $bsha} else {} end) + $code' >"$OUT/output/verdict.json"

    if [ $# -gt 0 ]; then
        local tmp
        tmp="$(mktemp)"
        jq "$1" "$OUT/output/verdict.json" >"$tmp" && mv "$tmp" "$OUT/output/verdict.json"
    fi
}

@test "record: valid plan evaluation records report and transitions to Approved" {
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = recorded ]
    [ "$(jq -r .verdict <<<"$output")" = PASS ]
    [ "$(jq -r .artifact_status <<<"$output")" = Approved ]
    [ "$(art_status)" = Approved ]
    local rep="$REPO/.docs/evaluations/ci-baseline-plan-eval.md"
    [ -f "$rep" ]
    grep -qx 'Status: Evaluated' "$rep"
    grep -qx 'Verdict: PASS' "$rep"
    grep -qx 'Round: 0' "$rep"
}

@test "record: valid ADR evaluation transitions to Accepted" {
    local adr=.docs/adr/0099-test.md
    rec_commit "$adr" $'# ADR 99\n\nStatus: Plan Review\n\n## Content\n'
    ew prepare --repo "$REPO" --type plan --head "$(rec_head)" --artifact "$adr" --authority .docs/spec/s.md --out "$OUT"
    [ "$status" -eq 0 ] || {
        echo "ADR PREP FAILED: $output"
        false
    }
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ] || {
        echo "ADR RECORD FAILED: $output"
        false
    }
    [ "$(jq -r .artifact_status <<<"$output")" = Accepted ]
    [ "$(art_status "$adr")" = Accepted ]
    [ -f "$REPO/.docs/evaluations/0099-test-eval.md" ]
}

@test "record: valid plan FAIL transitions to Draft" {
    rec_plan
    mk_verdict '.verdict = "FAIL" | .required_changes = ["fix the design"] | .findings = [{severity: "BLOCKER", title: "b", detail: "d"}]'
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = recorded ]
    [ "$(jq -r .verdict <<<"$output")" = FAIL ]
    [ "$(jq -r .artifact_status <<<"$output")" = Draft ]
    [ "$(art_status)" = Draft ]
    local rep="$REPO/.docs/evaluations/ci-baseline-plan-eval.md"
    [ -f "$rep" ]
    grep -qx 'Verdict: FAIL' "$rep"
    grep -q '## Required changes' "$rep"
}

@test "record: valid code evaluation with passing rerun records report and transitions to Ready to Publish" {
    rec_code
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = recorded ]
    [ "$(jq -r .verdict <<<"$output")" = PASS ]
    [ "$(jq -r .artifact_status <<<"$output")" = "Ready to Publish" ]
    [ "$(art_status)" = "Ready to Publish" ]
    local rep="$REPO/.docs/evaluations/ci-baseline-eval.md"
    [ -f "$rep" ]
    grep -qx 'Verdict: PASS' "$rep"
    grep -q '## Gate rerun evidence' "$rep"
    grep -q '## Local review adjudication' "$rep"
}

@test "record: valid code FAIL with failing rerun transitions to In Progress" {
    rec_code --gate-arg /usr/bin/false
    [ "$(ev 1 .result)" = rerun-failed ]
    mk_verdict '.verdict = "FAIL" | .required_changes = ["fix failure"] | .findings = [{severity: "MAJOR", title: "m", detail: "d"}]'
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .verdict <<<"$output")" = FAIL ]
    [ "$(jq -r .artifact_status <<<"$output")" = "In Progress" ]
    [ "$(art_status)" = "In Progress" ]
}

@test "record: code PASS with failed rerun attempt fails closed (exit 2)" {
    rec_code --gate-arg /usr/bin/false
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"a PASS verdict requires a passing gate rerun"* ]]
    [ "$(art_status)" = Implemented ]
}

@test "record: schema error in verdict.json fails closed (exit 2)" {
    rec_plan
    mk_verdict 'del(.verdict)'
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [ ! -e "$REPO/.docs/evaluations/ci-baseline-plan-eval.md" ]
}

@test "record: PASS carrying BLOCKER or MAJOR finding fails closed (exit 2)" {
    rec_plan
    mk_verdict '.findings = [{severity: "BLOCKER", title: "bad", detail: "blocker present"}]'
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
}

@test "record: verdict round mismatch against expected round fails closed (exit 2)" {
    rec_plan
    mk_verdict '.round = 2'
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"does not match expected round 0"* ]]
}

@test "record: bound prior verdict replacement succeeds for successor round" {
    rec_commit .docs/evaluations/ci-baseline-plan-eval.md $'# Prior\n\nStatus: Evaluated\nRound: 0\nVerdict: FAIL\n\n## Findings\n'
    local prior_sha
    prior_sha="$(rec_head)"
    rec_commit "$PLAN_REL" $'# Demo\n\nStatus: Plan Review\n\n## Revised\n'
    ew prepare --repo "$REPO" --type plan --head "$(rec_head)" --artifact "$PLAN_REL" --authority .docs/spec/s.md \
        --prior-verdict .docs/evaluations/ci-baseline-plan-eval.md --prior-sha "$prior_sha" --out "$OUT"
    [ "$status" -eq 0 ] || {
        echo "PRIOR PREP FAILED: $output"
        false
    }
    mk_verdict '.round = 1'
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ] || {
        echo "PRIOR RECORD FAILED: $output"
        false
    }
    [ "$(jq -r .artifact_status <<<"$output")" = Approved ]
    local rep="$REPO/.docs/evaluations/ci-baseline-plan-eval.md"
    grep -qx 'Round: 1' "$rep"
    grep -qx 'Verdict: PASS' "$rep"
}

@test "record: differing existing report without bound prior verdict fails closed (exit 2)" {
    rec_commit .docs/evaluations/ci-baseline-plan-eval.md $'# Prior un-bound report\n'
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"a different report already exists"* ]]
}

@test "record: identical existing report succeeds idempotently (exit 0)" {
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = recorded ]
}

@test "record: checkout artifact blob mismatch against reviewed head fails closed (exit 2)" {
    rec_plan
    mk_verdict
    # Tamper with the checkout artifact after head
    printf $'# Demo\n\nStatus: Plan Review\n\n## Tampered\n' >"$REPO/$PLAN_REL"
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"checkout artifact does not match the reviewed head"* ]]
}

@test "record: missing output/verdict.json fails with exit 3" {
    rec_plan
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 3 ]
    [[ "$output" == *"verdict.json is missing"* ]]
}

@test "record: extra or non-regular files in output/ fails closed (exit 2)" {
    rec_plan
    mk_verdict
    touch "$OUT/output/extra.txt"
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"output must contain exactly verdict.json"* ]]
}

@test "record: --claimed-gate holds status advance and reports gate-held" {
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO" --claimed-gate review-gate
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = gate-held ]
    [ "$(jq -r .claimed_gate <<<"$output")" = review-gate ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: duplicate object keys in verdict.json are rejected before validation" {
    rec_plan
    mk_verdict
    sed -i.bak 's/^{/{"verdict":"FAIL",/' "$OUT/output/verdict.json"
    rm -f "$OUT/output/verdict.json.bak"
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"duplicate object keys"* ]]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: nested duplicate object keys in verdict.json are rejected" {
    rec_plan
    mk_verdict
    jq -c '. + {findings: []}' "$OUT/output/verdict.json" | sed 's/"findings":\[\]/"findings":[],"notes":[],"notes":[]/' >"$WORK/dup.json"
    cp "$WORK/dup.json" "$OUT/output/verdict.json"
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"duplicate object keys"* ]]
}

@test "record: --bootstrap-phase publication-intent holds the transition" {
    rec_plan
    printf 'publication-intent\n' >"$REPO/.git/loom/bootstrap-phase"
    mk_verdict
    ew record "$OUT" --repo "$REPO" --bootstrap-phase publication-intent
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: omitted bootstrap phase with a held authoritative phase is state-held" {
    rec_plan
    printf 'publication-intent\n' >"$REPO/.git/loom/bootstrap-phase"
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: omitted bootstrap phase with no authoritative phase is state-held" {
    rec_plan
    rm "$REPO/.git/loom/bootstrap-phase"
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
    # a supplied active phase does not prove an absent authoritative phase
    ew record "$OUT" --repo "$REPO" --bootstrap-phase active
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: a supplied phase contradicting the authoritative phase fails closed (exit 2)" {
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO" --bootstrap-phase publication-intent
    [ "$status" -eq 2 ]
    [[ "$output" == *"contradicts the authoritative bootstrap phase 'active'"* ]]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: authoritative active phase advances with and without a matching supplied phase" {
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO" --bootstrap-phase active
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = recorded ]
    [ "$(art_status)" = Approved ]
}

@test "record: ineligible repository (no ADR 0023) is state-held" {
    rec_plan
    rm "$REPO/$ADR23_REL"
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: repository with placeholder ADR 0023 and active marker remains state-held" {
    mkdir -p "$REPO/.docs/ADR"
    printf '# ADR 23\n\nStatus: Accepted\n' >"$REPO/$ADR23_REL"
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: ADR 0023 that is a symlink makes the repository ineligible" {
    rec_plan
    rm "$REPO/$ADR23_REL"
    ln -s "$REPO/.docs/spec/s.md" "$REPO/$ADR23_REL"
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: a slice outside the ADR 0023 closed list is state-held" {
    PLAN_REL=.docs/slice-plans/not-listed.md
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = state-held ]
    [ "$(art_status)" = "Plan Review" ]
}

@test "record: ADR 0023 PASS cannot self-ratify into Accepted" {
    PLAN_REL=.docs/adr/0023-demo.md
    rec_plan
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status <<<"$output")" = ratification-held ]
    [ "$(art_status)" = "Plan Review" ]
}

# negative regressions: each guard fails closed (exit 2), leaves the artifact status unchanged and writes no report
neg_plan() { # <label> <expected-error-text> <jq mutation>
    rec_plan
    mk_verdict "$3"
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$2"* ]]
    [ "$(art_status)" = "Plan Review" ]
    [ ! -e "$REPO/.docs/evaluations/ci-baseline-plan-eval.md" ]
}
neg_code() { # <label> <expected-error-text> <jq mutation>
    rec_code
    mk_verdict "$3"
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"$2"* ]]
    [ "$(art_status)" = Implemented ]
    [ ! -e "$REPO/.docs/evaluations/ci-baseline-eval.md" ]
}
BIND_ERR="verdict does not match the run, manifest, artifact, revisions or authority bindings"
RERUN_ERR="verdict gate rerun reference does not match the latest attempt"

@test "record: tampered verdict run_id fails closed" {
    neg_plan run_id "$BIND_ERR" '.run_id = "run-tampered-0000"'
}

@test "record: tampered verdict manifest_sha256 fails closed" {
    neg_plan manifest "$BIND_ERR" '.manifest_sha256 = ("0" * 64)'
}

@test "record: tampered verdict head_sha fails closed" {
    neg_plan head "$BIND_ERR" '.head_sha = ("0" * 40)'
}

@test "record: tampered verdict artifact path fails closed" {
    neg_plan artifact "$BIND_ERR" '.artifact = ".docs/slice-plans/other.md"'
}

@test "record: tampered verdict authority fails closed" {
    neg_plan authority "$BIND_ERR" '.authority = [".docs/spec/other.md"]'
}

@test "record: tampered rerun_attempt.seq fails closed" {
    neg_code seq "$RERUN_ERR" '.rerun_attempt.seq = 99'
}

@test "record: tampered rerun_attempt.evidence_sha256 fails closed" {
    neg_code evidence "$RERUN_ERR" '.rerun_attempt.evidence_sha256 = ("0" * 64)'
}

@test "record: tampered rerun_attempt.result fails closed" {
    neg_code result "$RERUN_ERR" '.rerun_attempt.result = "rerun-failed"'
}

@test "record: reviewed artifact status mismatch fails closed" {
    rec_plan Draft
    mk_verdict
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"reviewed artifact status is not 'Plan Review'"* ]]
    [ "$(art_status)" = Draft ]
    [ ! -e "$REPO/.docs/evaluations/ci-baseline-plan-eval.md" ]
}

@test "record: illegal status transition fails closed" {
    rec_plan
    mk_verdict
    sed -i.bak 's/^Status: Plan Review$/Status: Landed/' "$REPO/$PLAN_REL"
    rm -f "$REPO/$PLAN_REL.bak"
    ew record "$OUT" --repo "$REPO"
    [ "$status" -eq 2 ]
    [[ "$output" == *"illegal transition from 'Landed' to 'Approved'"* ]]
    [ "$(art_status)" = Landed ]
    [ ! -e "$REPO/.docs/evaluations/ci-baseline-plan-eval.md" ]
}

@test "record: usage text lists the subcommand" {
    ew --help
    [[ "$output" =~ record[[:space:]]+"<run-dir|run-id>" ]]
}

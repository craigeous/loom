#!/usr/bin/env bats
# Test suite for loom-review (loom-local-review/v1 run helper, ADR 0021).
# Every test builds a throwaway repository with no remote; no network is used.
bats_require_minimum_version 1.5.0

RV="${BATS_TEST_DIRNAME}/loom-review"
SCHEMAS="${BATS_TEST_DIRNAME}/../schemas"
SCRIPTS="${BATS_TEST_DIRNAME}/../../../scripts"
FINDERS="review-correctness/v1 review-tests/v1 review-security/v1"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
}

# asset_of / pin_of: shipped prompt asset and its independently computed SHA-256
asset_of() {
    local b="${1//\//-}"
    printf '%s/../finders/%s.md' "$BATS_TEST_DIRNAME" "$b"
}
pin_of() { shasum -a 256 <"$(asset_of "$1")" | cut -d' ' -f1; }

setup() {
    WORK="$(mktemp -d)"
    WORK="$(CDPATH='' cd -- "$WORK" && pwd -P)"
    REPO="$WORK/repo"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    git init -q -b main "$REPO"
    git -C "$REPO" config user.email test@example.com
    git -C "$REPO" config user.name Test
    mkdir -p "$REPO/plugins/loom/.claude-plugin"
    printf '{"name":"loom","version":"9.8.7"}\n' >"$REPO/plugins/loom/.claude-plugin/plugin.json"
    printf 'plan\n' >"$REPO/plan.md"
    printf 'spec\n' >"$REPO/spec.md"
    printf 'adr\n' >"$REPO/adr.md"
    printf 'a\nb\nc\n' >"$REPO/f.txt"
    printf 'one\ntwo\nthree\nfour\nfive\n' >"$REPO/old.txt"
    printf 'gone\n' >"$REPO/del.txt"
    printf '#!/bin/sh\n' >"$REPO/mode.sh"
    printf 'ignored\n' >"$REPO/ignored.txt"
    printf '$Format:%%H$\n' >"$REPO/subst.txt"
    printf 'crlf\n' >"$REPO/crlf.txt"
    printf 'ignored.txt export-ignore\nsubst.txt export-subst\ncrlf.txt text eol=crlf\n' >"$REPO/.gitattributes"
    ln -s plan.md "$REPO/plan-link.md"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m base
    BASE="$(git -C "$REPO" rev-parse HEAD)"
    printf 'a\nB\nc\nd\n' >"$REPO/f.txt"
    git -C "$REPO" mv old.txt new.txt
    printf 'one\ntwo\nTHREE\nfour\nfive\n' >"$REPO/new.txt"
    git -C "$REPO" rm -q del.txt
    printf 'added\n' >"$REPO/added.txt"
    chmod +x "$REPO/mode.sh"
    printf '\000\001\002binary' >"$REPO/bin.dat"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m head
    HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
    EVIDENCE="$WORK/evidence.txt"
    printf 'gate green\n' >"$EVIDENCE"
    PH_ARGS=()
    for id in $FINDERS; do
        PH_ARGS+=(--prompt-hash "$id=$(pin_of "$id")" --finder-profile "$id=claude:sonnet-test")
    done
    REVIEW_ROOT="$REPO/.git/loom/review"
}

teardown() {
    if [ -n "${WORK:-}" ] && [ -d "$WORK" ]; then
        chmod -R u+w "$WORK" 2>/dev/null || true
        rm -rf "$WORK"
    fi
}

# ---------------------------------------------------------------- helpers

prep() {
    run "$LOOM_TEST_BASH" "$RV" prepare --repo "$REPO" --slice demo --base "$BASE" --head "$HEAD_SHA" \
        --plan "$REPO/plan.md" --spec "$REPO/spec.md" --adr "$REPO/adr.md" --gate-evidence "$EVIDENCE" \
        "${PH_ARGS[@]}" "$@"
}

prepared() {
    prep
    [ "$status" -eq 0 ]
    RUN="$output"
    [ -d "$RUN" ]
}

no_run_dir() {
    [ ! -d "$REVIEW_ROOT" ] || [ -z "$(ls -A "$REVIEW_ROOT")" ]
}

val() { run "$LOOM_TEST_BASH" "$RV" validate "$RUN" --repo "$REPO" "$@"; }
stat_() { run "$LOOM_TEST_BASH" "$RV" status "$RUN" --repo "$REPO" "$@"; }

rfile() { printf '%s/results/%s.json' "$RUN" "${1//\//__}"; }

# mkres <finder-id> <status> [findings-json-array]
mkres() {
    local id="$1" st="$2" fnd="${3:-[]}"
    mkdir -p "$RUN/results"
    jq -n --slurpfile m "$RUN/manifest.json" --arg id "$id" --arg st "$st" --argjson f "$fnd" '
        ($m[0]) as $m | ($m.finders[] | select(.id == $id)) as $fe
        | {protocol: $m.protocol, run_id: $m.run_id, manifest_sha256: $m.manifest_sha256,
           finder: {id: $id, prompt_version: $fe.prompt.version, prompt_sha256: $fe.prompt.sha256},
           base_sha: $m.base_sha, head_sha: $m.head_sha, diff_sha256: $m.diff_sha256, status: $st, findings: $f,
           provenance: {adapter: $fe.adapter, model_profile: $fe.model_profile,
                        started_at: "2026-01-01T00:00:00Z", finished_at: "2026-01-01T00:01:00Z",
                        truncated: false, exit_status: 0}}' >"$(rfile "$id")"
}

# finding <id> <finder> <file> [line] [line_end]
finding() {
    jq -n -c --arg id "$1" --arg finder "$2" --arg file "$3" --arg line "${4:-}" --arg end "${5:-}" '
        {id: $id, finder: $finder, confidence: 0.8, severity: "MAJOR", file: $file,
         claim: "claim\ntext", evidence: "evidence", verification: "verify it"}
        + (if $line != "" then {line: ($line | tonumber)} else {} end)
        + (if $end != "" then {line_end: ($end | tonumber)} else {} end)'
}

mkclean() {
    local id
    for id in $FINDERS; do mkres "$id" ran-clean; done
}

mkmixed() {
    mkres review-correctness/v1 ran-with-findings "[$(finding COR-1 review-correctness/v1 f.txt 2)]"
    mkres review-tests/v1 ran-clean
    mkres review-security/v1 ran-with-findings "[$(finding SEC-1 review-security/v1 new.txt 3)]"
}

# edit_res <finder-id> <jq filter>
edit_res() {
    local f
    f="$(rfile "$1")"
    jq -c "$2" "$f" >"$f.new"
    mv "$f.new" "$f"
}

# edit_manifest <jq filter>: edit and re-hash so the manifest stays self-consistent
edit_manifest() {
    local m="$RUN/manifest.json" h
    jq -S -c "$1 | del(.manifest_sha256)" "$m" >"$m.new"
    h="$(shasum -a 256 <"$m.new" | cut -d' ' -f1)"
    jq -S -c --arg h "$h" '. + {manifest_sha256: $h}' "$m.new" >"$m"
    rm -f "$m.new"
}

assert_invalid() {
    [ "$status" -eq 2 ]
    [[ "$output" == *"aggregate: invalid"* ]]
    [[ "$output" != *"aggregate: ran-clean"* ]]
}

writable_source() { chmod -R u+w "$RUN/source"; }

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

# ---------------------------------------------------------------- prepare: accept

@test "prepare: records exact SHAs, tree, diff hash, inventory, ranges and provenance" {
    prepared
    m="$RUN/manifest.json"
    [ "$(jq -r .protocol "$m")" = "loom-local-review/v1" ]
    [ "$(jq -r .base_sha "$m")" = "$BASE" ]
    [ "$(jq -r .head_sha "$m")" = "$HEAD_SHA" ]
    [ "$(jq -r .head_tree "$m")" = "$(git -C "$REPO" rev-parse "$HEAD_SHA^{tree}")" ]
    expected="$(git -C "$REPO" diff --binary --full-index -M -C --no-ext-diff --no-color "$BASE" "$HEAD_SHA" | shasum -a 256 | cut -d' ' -f1)"
    [ "$(jq -r .diff_sha256 "$m")" = "$expected" ]
    cmp -s "$RUN/diff.patch" <(git -C "$REPO" diff --binary --full-index -M -C --no-ext-diff --no-color "$BASE" "$HEAD_SHA")
    # inventory
    [ "$(jq -r '.files[] | select(.path == "new.txt") | .status + ":" + .old_path' "$m")" = "R:old.txt" ]
    [ "$(jq -r '.files[] | select(.path == "bin.dat") | "\(.status) \(.binary) \(.added) \(.ranges | length)"' "$m")" = "A true null 0" ]
    [ "$(jq -r '.files[] | select(.path == "added.txt") | .status' "$m")" = "A" ]
    [ "$(jq -r '.files[] | select(.path == "del.txt") | .status + " " + .ranges[0].side' "$m")" = "D old" ]
    [ "$(jq -r '.files[] | select(.path == "mode.sh") | "\(.old_mode) \(.new_mode)"' "$m")" = "100644 100755" ]
    # ranges match hunks: f.txt changes line 2 and appends line 4; the rename edits line 3
    [ "$(jq -c '[.files[] | select(.path == "f.txt") | .ranges[] | [.side, .start, .end]]' "$m")" = '[["new",2,2],["new",4,4]]' ]
    [ "$(jq -c '[.files[] | select(.path == "new.txt") | .ranges[] | [.side, .start, .end]]' "$m")" = '[["new",3,3]]' ]
    # provenance
    [ "$(jq -r .loom_version "$m")" = "9.8.7" ]
    [ "$(jq -r .helper_version "$m")" = "loom-review/1" ]
    [ "$(jq -r '.finders[] | select(.id == "review-tests/v1") | .adapter + "|" + .model_profile + "|" + .prompt.sha256' "$m")" = "claude|sonnet-test|$(pin_of review-tests/v1)" ]
    # inputs hashed
    [ "$(jq -r '.inputs[] | select(.kind == "plan") | .sha256' "$m")" = "$(shasum -a 256 <"$REPO/plan.md" | cut -d' ' -f1)" ]
    [ "$(jq -r '.inputs[] | select(.kind == "gate-evidence") | .sha256' "$m")" = "$(shasum -a 256 <"$EVIDENCE" | cut -d' ' -f1)" ]
    [ "$(jq '.inputs | length' "$m")" -eq 4 ]
    # manifest hash recomputes
    [ "$(jq -S -c 'del(.manifest_sha256)' "$m" | shasum -a 256 | cut -d' ' -f1)" = "$(jq -r .manifest_sha256 "$m")" ]
}

@test "prepare: source export matches ls-tree and ignores export attributes; no .git" {
    prepared
    [ ! -e "$RUN/source/.git" ]
    [ -f "$RUN/source/ignored.txt" ]
    [ "$(cat "$RUN/source/subst.txt")" = '$Format:%H$' ]
    [ "$(wc -c <"$RUN/source/crlf.txt" | tr -d ' ')" -eq 5 ]
    [ -L "$RUN/source/plan-link.md" ]
    [ -x "$RUN/source/mode.sh" ]
    expected="$(git -C "$REPO" ls-tree -r "$HEAD_SHA" | wc -l | tr -d ' ')"
    [ "$(jq -r .source_export.file_count "$RUN/manifest.json")" = "$expected" ]
    while IFS=$'\t' read -r meta path; do
        set -- $meta
        mode="$1" oid="$3"
        if [ "$mode" = 120000 ]; then
            [ "$(printf '%s' "$(readlink "$RUN/source/$path")" | git -C "$REPO" hash-object --stdin)" = "$oid" ]
        else
            [ "$(git -C "$REPO" hash-object --no-filters "$RUN/source/$path")" = "$oid" ]
        fi
    done < <(git -C "$REPO" ls-tree -r "$HEAD_SHA")
}

@test "prepare: manifest is schema-valid" {
    prepared
    schema_check "$SCHEMAS/loom-local-review-manifest-v1.schema.json" "$RUN/manifest.json"
}

@test "prepare: accepts untracked gate evidence inside the repo; other untracked file rejects" {
    printf 'ev\n' >"$REPO/evidence-in.txt"
    EVIDENCE="$REPO/evidence-in.txt"
    prepared
    [ "$(jq -r '.inputs[] | select(.kind == "gate-evidence") | .path' "$RUN/manifest.json")" = "gate-evidence" ]
    chmod -R u+w "$REVIEW_ROOT"
    rm -rf "$REVIEW_ROOT"
    printf 'other\n' >"$REPO/other-untracked.txt"
    prep
    [ "$status" -eq 2 ]
    no_run_dir
}

@test "prepare: leaves the run directory private and the tree untouched" {
    prepared
    [ -z "$(git -C "$REPO" status --porcelain)" ]
    [ "$(find "$REVIEW_ROOT" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" -eq 1 ]
}

# ---------------------------------------------------------------- prepare: reject

@test "prepare rejects abbreviated, symbolic, range and nonexistent revisions" {
    for bad in "${HEAD_SHA:0:12}" main HEAD "$BASE..$HEAD_SHA" "$HEAD_SHA^" ffffffffffffffffffffffffffffffffffffffff; do
        prep --head "$bad"
        [ "$status" -eq 2 ]
        no_run_dir
        prep --base "$bad"
        [ "$status" -eq 2 ]
        no_run_dir
    done
    git -C "$REPO" tag t1 "$HEAD_SHA"
    prep --head t1
    [ "$status" -eq 2 ]
    no_run_dir
}

@test "prepare rejects base == head and base not an ancestor" {
    prep --base "$HEAD_SHA"
    [ "$status" -eq 2 ]
    no_run_dir
    prep --base "$HEAD_SHA" --head "$BASE"
    [ "$status" -eq 2 ]
    no_run_dir
}

@test "prepare rejects a dirty tracked file, other untracked file, and HEAD != head" {
    printf 'dirty\n' >>"$REPO/f.txt"
    prep
    [ "$status" -eq 2 ]
    no_run_dir
    git -C "$REPO" checkout -q f.txt
    printf 'x\n' >"$REPO/untracked.txt"
    prep
    [ "$status" -eq 2 ]
    no_run_dir
    rm "$REPO/untracked.txt"
    git -C "$REPO" commit -q --allow-empty -m later
    prep
    [ "$status" -eq 2 ]
    no_run_dir
}

@test "prepare rejects missing, symlinked, out-of-repo plan and modified spec" {
    prep --plan "$REPO/nope.md"
    [ "$status" -eq 2 ]
    prep --plan "$REPO/plan-link.md"
    [ "$status" -eq 2 ]
    printf 'outside\n' >"$WORK/outside-plan.md"
    prep --plan "$WORK/outside-plan.md"
    [ "$status" -eq 2 ]
    no_run_dir
    printf 'more\n' >>"$REPO/spec.md"
    prep
    [ "$status" -eq 2 ]
    no_run_dir
}

@test "prepare rejects a gitlink in the diff" {
    mkdir "$REPO/sub"
    git -C "$REPO" update-index --add --cacheinfo "160000,$BASE,sub"
    git -C "$REPO" commit -q -m gitlink
    prep --base "$HEAD_SHA" --head "$(git -C "$REPO" rev-parse HEAD)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"gitlink"* ]]
    no_run_dir
}

@test "prepare defaults omitted --prompt-hash and --finder-profile to pinned hash and claude:sonnet" {
    run "$LOOM_TEST_BASH" "$RV" prepare --repo "$REPO" --slice demo --base "$BASE" --head "$HEAD_SHA" \
        --plan "$REPO/plan.md" --gate-evidence "$EVIDENCE"
    [ "$status" -eq 0 ]
    RUN="$output"
    for id in $FINDERS; do
        [ "$(jq -r --arg i "$id" '.finders[] | select(.id == $i) | .prompt.sha256 + "|" + .adapter + "|" + .model_profile' "$RUN/manifest.json")" = "$(pin_of "$id")|claude|sonnet" ]
    done
    mkclean
    val
    [ "$status" -eq 0 ]
}

@test "prepare: explicit --prompt-hash mismatch fails closed with exit 2" {
    run "$LOOM_TEST_BASH" "$RV" prepare --repo "$REPO" --slice demo --base "$BASE" --head "$HEAD_SHA" \
        --plan "$REPO/plan.md" --gate-evidence "$EVIDENCE" --prompt-hash "review-tests/v1=$(printf 'a%.0s' $(seq 64))"
    [ "$status" -eq 2 ]
    [[ "$output" == *"pinned"* ]]
    no_run_dir
}

@test "prepare rejects malformed overrides" {
    run "$LOOM_TEST_BASH" "$RV" prepare --repo "$REPO" --slice demo --base "$BASE" --head "$HEAD_SHA" \
        --plan "$REPO/plan.md" --gate-evidence "$EVIDENCE" --prompt-hash "review-tests/v1=nothex"
    [ "$status" -eq 2 ]
    no_run_dir
    run "$LOOM_TEST_BASH" "$RV" prepare --repo "$REPO" --slice demo --base "$BASE" --head "$HEAD_SHA" \
        --plan "$REPO/plan.md" --gate-evidence "$EVIDENCE" --finder-profile "review-tests/v1=noadapter"
    [ "$status" -eq 2 ]
    no_run_dir
}

@test "prepare/validate: prompt byte drift or missing asset fails closed (script-relative root)" {
    root="$WORK/plugin"
    mkdir -p "$root/bin" "$root/finders"
    cp "$RV" "$root/bin/loom-review"
    cp "${BATS_TEST_DIRNAME}"/../finders/*.md "$root/finders/"
    args=(prepare --repo "$REPO" --slice demo --base "$BASE" --head "$HEAD_SHA" --plan "$REPO/plan.md" --gate-evidence "$EVIDENCE")
    run "$LOOM_TEST_BASH" "$root/bin/loom-review" "${args[@]}"
    [ "$status" -eq 0 ]
    RUN="$output"
    chmod -R u+w "$RUN"
    rm -rf "$RUN"
    printf 'x' >>"$root/finders/review-tests-v1.md"
    run "$LOOM_TEST_BASH" "$root/bin/loom-review" "${args[@]}"
    [ "$status" -eq 2 ]
    no_run_dir
    rm "$root/finders/review-tests-v1.md"
    run "$LOOM_TEST_BASH" "$root/bin/loom-review" "${args[@]}"
    [ "$status" -eq 2 ]
    no_run_dir
}

@test "validate rejects a manifest whose prompt hash is not the pinned hash" {
    prepared
    mkclean
    edit_manifest '(.finders[] | select(.id == "review-tests/v1") | .prompt.sha256) = ("b" * 64)'
    val
    assert_invalid
}

@test "prepare rejects an existing run and an unknown flag" {
    prepared
    prep
    [ "$status" -eq 2 ]
    prep --bogus x
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------- network-silent

@test "network-silent: no network command is invoked across all subcommands" {
    mkdir "$WORK/shims"
    for c in curl wget ssh; do
        printf '#!/bin/sh\ntouch "%s/net-called"\nexit 99\n' "$WORK" >"$WORK/shims/$c"
        chmod +x "$WORK/shims/$c"
    done
    export PATH="$WORK/shims:$PATH" GIT_ALLOW_PROTOCOL=none
    [ -z "$(git -C "$REPO" remote)" ]
    prepared
    mkclean
    val
    [ "$status" -eq 0 ]
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/out.md"
    [ "$status" -eq 0 ]
    stat_
    run "$LOOM_TEST_BASH" "$RV" clean --all --repo "$REPO"
    [ "$status" -eq 0 ]
    [ ! -e "$WORK/net-called" ]
}

# ---------------------------------------------------------------- validate: accept

@test "validate accepts mixed results with the right aggregate and schema-valid results" {
    prepared
    mkmixed
    val
    [ "$status" -eq 0 ]
    [[ "$output" == *"review-correctness/v1: ran-with-findings"* ]]
    [[ "$output" == *"review-tests/v1: ran-clean"* ]]
    [[ "$output" == *"aggregate: ran-with-findings"* ]]
    schema_check "$SCHEMAS/loom-local-review-findings-v1.schema.json" "$(rfile review-correctness/v1)"
}

@test "validate: all-clean results yield ran-clean" {
    prepared
    mkclean
    val
    [ "$status" -eq 0 ]
    [[ "$output" == *"aggregate: ran-clean"* ]]
    [ "$(jq -r .aggregate "$RUN/state.json")" = "ran-clean" ]
}

@test "validate accepts old-side finding on a deleted file and file-level binary finding" {
    prepared
    mkres review-correctness/v1 ran-with-findings "[$(finding COR-1 review-correctness/v1 del.txt 1), $(finding COR-2 review-correctness/v1 bin.dat)]"
    mkres review-tests/v1 ran-clean
    mkres review-security/v1 ran-clean
    val
    [ "$status" -eq 0 ]
    [[ "$output" == *"aggregate: ran-with-findings"* ]]
}

# ---------------------------------------------------------------- validate: reject

@test "validate rejects a missing finder and never reports ran-clean" {
    prepared
    mkclean
    rm "$(rfile review-tests/v1)"
    val
    assert_invalid
    [[ "$output" == *"review-tests/v1: invalid (missing)"* ]]
}

@test "validate rejects duplicate and extra result files" {
    prepared
    mkclean
    cp "$(rfile review-tests/v1)" "$RUN/results/copy.json"
    val
    assert_invalid
    [[ "$output" == *"duplicate result for review-tests/v1"* ]]
    rm "$RUN/results/copy.json"
    printf '{}' >"$RUN/results/extra.json"
    val
    assert_invalid
    [[ "$output" == *"extra result file"* ]]
}

@test "validate rejects invalid JSON, invalid UTF-8 and schema violations" {
    prepared
    mkclean
    printf '{not json' >"$(rfile review-tests/v1)"
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    printf '{"a":"\377"}' >"$(rfile review-tests/v1)"
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '. + {extra: 1}'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 'del(.provenance)'
    val
    assert_invalid
}

@test "validate rejects unknown protocol, prompt version/hash, manifest hash and run id mismatch" {
    prepared
    mkclean
    edit_res review-tests/v1 '.protocol = "loom-local-review/v2"'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.finder.prompt_version = "v2"'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.finder.prompt_sha256 = ("b" * 64)'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.manifest_sha256 = ("c" * 64)'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.run_id = "other"'
    val
    assert_invalid
}

@test "validate rejects a manifest with an unknown protocol major" {
    prepared
    mkclean
    jq -c '.protocol = "loom-local-review/v2"' "$RUN/manifest.json" >"$RUN/m.new"
    mv "$RUN/m.new" "$RUN/manifest.json"
    val
    assert_invalid
    [[ "$output" == *"protocol"* ]]
}

@test "validate rejects failed, truncated and nonzero-exit results" {
    prepared
    mkclean
    mkres review-tests/v1 failed
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.provenance.truncated = true'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.provenance.exit_status = 1'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.provenance.exit_status = "0"'
    val
    assert_invalid
}

@test "validate rejects status/finding inconsistency in both directions" {
    prepared
    mkclean
    mkres review-tests/v1 ran-clean "[$(finding TST-1 review-tests/v1 f.txt 2)]"
    val
    assert_invalid
    mkres review-tests/v1 ran-with-findings "[]"
    val
    assert_invalid
}

@test "validate rejects provenance and binding mismatches in results" {
    prepared
    mkclean
    edit_res review-tests/v1 '.provenance.adapter = "other"'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.provenance.model_profile = "other"'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.base_sha = .head_sha'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.head_sha = .base_sha'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.diff_sha256 = ("d" * 64)'
    val
    assert_invalid
}

@test "validate rejects a modified source export (edited, added, removed, chmod'd, attribute-omitted)" {
    prepared
    mkclean
    writable_source
    echo x >>"$RUN/source/f.txt"
    val
    assert_invalid
    git -C "$REPO" show "$HEAD_SHA:f.txt" >"$RUN/source/f.txt"
    touch "$RUN/source/extra.txt"
    val
    assert_invalid
    rm "$RUN/source/extra.txt"
    rm "$RUN/source/ignored.txt"
    val
    assert_invalid
    git -C "$REPO" show "$HEAD_SHA:ignored.txt" >"$RUN/source/ignored.txt"
    chmod +x "$RUN/source/f.txt"
    val
    assert_invalid
    chmod -x "$RUN/source/f.txt"
    val
    [ "$status" -eq 0 ]
}

@test "validate rejects modified diff and input files" {
    prepared
    mkclean
    echo x >>"$RUN/diff.patch"
    val
    assert_invalid
    git -C "$REPO" diff --binary --full-index -M -C --no-ext-diff --no-color "$BASE" "$HEAD_SHA" >"$RUN/diff.patch"
    echo x >>"$RUN/inputs/plan-0"
    val
    assert_invalid
}

@test "validate rejects swapped head_tree/SHAs/files[] even when the manifest is re-hashed" {
    prepared
    mkclean
    cp "$RUN/manifest.json" "$WORK/manifest.orig"
    edit_manifest ".head_tree = \"$(git -C "$REPO" rev-parse "$BASE^{tree}")\""
    val
    assert_invalid
    cp "$WORK/manifest.orig" "$RUN/manifest.json"
    edit_manifest '(.files[] | select(.path == "f.txt") | .ranges) = [{side: "new", start: 1, end: 9}]'
    val
    assert_invalid
    cp "$WORK/manifest.orig" "$RUN/manifest.json"
    edit_manifest ".head_sha = \"$BASE\" | .base_sha = \"$HEAD_SHA\""
    val
    assert_invalid
}

@test "validate fails closed when the repository or objects are unavailable" {
    prepared
    mkclean
    run "$LOOM_TEST_BASH" "$RV" validate "$RUN" --repo "$WORK/no-such-repo"
    assert_invalid
    [[ "$output" == *"unverifiable"* ]]
    git init -q "$WORK/empty"
    run "$LOOM_TEST_BASH" "$RV" validate "$RUN" --repo "$WORK/empty"
    assert_invalid
    [[ "$output" == *"unverifiable"* ]]
}

@test "validate rejects invalid ranges (wrong side, missing side)" {
    prepared
    mkclean
    cp "$RUN/manifest.json" "$WORK/manifest.orig"
    edit_manifest '(.files[] | select(.path == "f.txt") | .ranges[0].side) = "old"'
    val
    assert_invalid
    cp "$WORK/manifest.orig" "$RUN/manifest.json"
    edit_manifest '(.files[] | select(.path == "f.txt") | .ranges[0]) |= del(.side)'
    val
    assert_invalid
}

@test "validate rejects findings at invalid locations" {
    prepared
    mkres review-tests/v1 ran-clean
    mkres review-security/v1 ran-clean
    for spec in "plan.md 1" "f.txt 3" "nope.txt 1" "del.txt 7" "bin.dat 1" "f.txt"; do
        set -- $spec
        mkres review-correctness/v1 ran-with-findings "[$(finding COR-1 review-correctness/v1 "$@")]"
        val
        assert_invalid
    done
    mkres review-correctness/v1 ran-with-findings "[$(finding COR-1 review-correctness/v1 f.txt 2 4)]"
    val
    [ "$status" -eq 0 ]
}

@test "validate rejects duplicate finding ids" {
    prepared
    mkres review-correctness/v1 ran-with-findings "[$(finding COR-1 review-correctness/v1 f.txt 2), $(finding COR-1 review-correctness/v1 f.txt 4)]"
    mkres review-tests/v1 ran-clean
    mkres review-security/v1 ran-clean
    val
    assert_invalid
}

# ---------------------------------------------------------------- assemble

@test "assemble refuses invalid and pending runs without writing" {
    prepared
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/out/review.md"
    [ "$status" -eq 2 ]
    [ ! -e "$WORK/out/review.md" ]
    mkclean
    rm "$(rfile review-security/v1)"
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/out/review.md"
    [ "$status" -eq 2 ]
    [ ! -e "$WORK/out/review.md" ]
}

@test "assemble output is identity-neutral, deterministic and sorted" {
    prepared
    mkres review-correctness/v1 ran-with-findings "[$(finding COR-2 review-correctness/v1 new.txt 3), $(finding COR-1 review-correctness/v1 f.txt 4)]"
    mkres review-tests/v1 ran-with-findings "[$(finding TST-1 review-tests/v1 f.txt 2)]"
    mkres review-security/v1 ran-clean
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/a.md"
    [ "$status" -eq 0 ]
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/b.md"
    [ "$status" -eq 0 ]
    cmp -s "$WORK/a.md" "$WORK/b.md"
    ! grep -iE "Test|test@example|$(hostname)|$WORK|$HOME|$USER" "$WORK/a.md"
    [ "$(grep '^## ' "$WORK/a.md" | tr '\n' '|')" = "## Provenance|## TST-1 — proposed MAJOR|## COR-1 — proposed MAJOR|## COR-2 — proposed MAJOR|" ]
    grep -q 'Claim: claim text' "$WORK/a.md"
    grep -q 'Location: f.txt:2' "$WORK/a.md"
    [ "$(jq -r .assembled.output_sha256 "$RUN/state.json")" = "$(shasum -a 256 <"$WORK/a.md" | cut -d' ' -f1)" ]
}

@test "assemble works for a run directory containing whitespace" {
    prepared
    mkres review-correctness/v1 ran-with-findings "[$(finding COR-1 review-correctness/v1 f.txt 4)]"
    mkres review-tests/v1 ran-clean
    mkres review-security/v1 ran-clean
    mkdir "$WORK/spaced dir"
    mv "$RUN" "$WORK/spaced dir/run 1"
    RUN="$WORK/spaced dir/run 1"
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/spaced.md"
    [ "$status" -eq 0 ]
    grep -q '^## COR-1 — proposed MAJOR' "$WORK/spaced.md"
}

@test "assemble defaults to .docs/evaluations/<slice>-review-findings.md" {
    prepared
    mkclean
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO"
    [ "$status" -eq 0 ]
    [ -f "$REPO/.docs/evaluations/demo-review-findings.md" ]
}

@test "assemble is atomic: a read-only target directory leaves nothing behind" {
    prepared
    mkclean
    mkdir "$WORK/ro"
    chmod 555 "$WORK/ro"
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/ro/review.md"
    chmod 755 "$WORK/ro"
    [ "$status" -ne 0 ]
    [ -z "$(ls -A "$WORK/ro")" ]
}

# ---------------------------------------------------------------- status

@test "status: prepared -> collecting -> validated -> assembled with exit codes" {
    prepared
    stat_
    [ "$status" -eq 3 ]
    [[ "$output" == *"phase: prepared"* ]]
    [[ "$output" == *"review-tests/v1: pending"* ]]
    mkres review-correctness/v1 ran-clean
    stat_
    [ "$status" -eq 3 ]
    [[ "$output" == *"phase: collecting"* ]]
    mkres review-tests/v1 ran-clean
    mkres review-security/v1 ran-clean
    val
    [ "$status" -eq 0 ]
    stat_
    [ "$status" -eq 0 ]
    [[ "$output" == *"phase: validated"* ]]
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/out.md"
    [ "$status" -eq 0 ]
    stat_
    [ "$status" -eq 0 ]
    [[ "$output" == *"phase: assembled"* ]]
}

@test "status: invalid exits 2, missing run exits 1, --json parses" {
    prepared
    mkclean
    rm "$(rfile review-tests/v1)"
    val
    [ "$status" -eq 2 ]
    stat_ --json
    [ "$status" -eq 2 ]
    [ "$(printf '%s' "$output" | jq -r .aggregate)" = "invalid" ]
    [ "$(printf '%s' "$output" | jq -r .phase)" = "validated" ]
    run "$LOOM_TEST_BASH" "$RV" status "$WORK/nope" --repo "$REPO"
    [ "$status" -eq 1 ]
    run "$LOOM_TEST_BASH" "$RV" status no-such-run --repo "$REPO"
    [ "$status" -eq 1 ]
}

@test "status never writes" {
    prepared
    mkclean
    val
    before="$(find "$RUN" -type f -exec shasum -a 256 {} + | LC_ALL=C sort)"
    stat_
    stat_ --json
    after="$(find "$RUN" -type f -exec shasum -a 256 {} + | LC_ALL=C sort)"
    [ "$before" = "$after" ]
    rm "$RUN/state.json"
    stat_
    [ ! -e "$RUN/state.json" ]
}

@test "status: validate with zero results reports invalid (not prepared), exit 2" {
    prepared
    val
    [ "$status" -eq 2 ]
    stat_
    [ "$status" -eq 2 ]
    [[ "$output" == *"phase: validated"* ]]
    [[ "$output" == *"aggregate: invalid"* ]]
}

@test "status: a result changed after a valid verdict is stale -> collecting, exit 3" {
    prepared
    mkclean
    val
    [ "$status" -eq 0 ]
    edit_res review-tests/v1 '.provenance.finished_at = "2026-02-02T00:00:00Z"'
    stat_
    [ "$status" -eq 3 ]
    [[ "$output" == *"phase: collecting"* ]]
    [[ "$output" != *"aggregate:"* ]]
}

# ---------------------------------------------------------------- clean

@test "clean removes only the named run, including read-only source" {
    prepared
    first="$RUN"
    prep --run-id second
    [ "$status" -eq 0 ]
    run "$LOOM_TEST_BASH" "$RV" clean second --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$output" = "second" ]
    [ ! -e "$REVIEW_ROOT/second" ]
    [ -d "$first" ]
}

@test "clean --all and --older-than" {
    prepared
    prep --run-id second
    [ "$status" -eq 0 ]
    touch -t 202001010000 "$REVIEW_ROOT/second"
    run "$LOOM_TEST_BASH" "$RV" clean --older-than 5 --repo "$REPO"
    [ "$status" -eq 0 ]
    [ "$output" = "second" ]
    [ -d "$RUN" ]
    run "$LOOM_TEST_BASH" "$RV" clean --all --repo "$REPO"
    [ "$status" -eq 0 ]
    [ ! -e "$RUN" ]
    [ -d "$REPO" ]
}

@test "clean refuses paths outside the root, symlinked runs, and dirs without a manifest" {
    prepared
    mkdir "$WORK/victim"
    printf '{"protocol":"loom-local-review/v1"}' >"$WORK/victim/manifest.json"
    run "$LOOM_TEST_BASH" "$RV" clean "$WORK/victim" --repo "$REPO"
    [ "$status" -eq 2 ]
    run "$LOOM_TEST_BASH" "$RV" clean ../../victim --repo "$REPO"
    [ "$status" -eq 2 ]
    ln -s "$WORK/victim" "$REVIEW_ROOT/linked"
    run "$LOOM_TEST_BASH" "$RV" clean linked --repo "$REPO"
    [ "$status" -eq 2 ]
    run "$LOOM_TEST_BASH" "$RV" clean --all --repo "$REPO"
    [ -d "$WORK/victim" ]
    [ -L "$REVIEW_ROOT/linked" ]
    mkdir "$REVIEW_ROOT/nomanifest"
    run "$LOOM_TEST_BASH" "$RV" clean nomanifest --repo "$REPO"
    [ "$status" -eq 2 ]
    [ -d "$REVIEW_ROOT/nomanifest" ]
    mkdir "$REVIEW_ROOT/wrongproto"
    printf '{"protocol":"other"}' >"$REVIEW_ROOT/wrongproto/manifest.json"
    run "$LOOM_TEST_BASH" "$RV" clean wrongproto --repo "$REPO"
    [ "$status" -eq 2 ]
}

@test "clean never touches committed review-findings files" {
    prepared
    mkclean
    mkdir -p "$REPO/.docs/evaluations"
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO"
    [ "$status" -eq 0 ]
    run "$LOOM_TEST_BASH" "$RV" clean --all --repo "$REPO"
    [ "$status" -eq 0 ]
    [ -f "$REPO/.docs/evaluations/demo-review-findings.md" ]
}

# ---------------------------------------------------------------- usage and registration

@test "usage errors exit 1" {
    run "$LOOM_TEST_BASH" "$RV"
    [ "$status" -eq 1 ]
    run "$LOOM_TEST_BASH" "$RV" bogus
    [ "$status" -eq 1 ]
    run "$LOOM_TEST_BASH" "$RV" validate
    [ "$status" -eq 1 ]
    run "$LOOM_TEST_BASH" "$RV" clean --repo "$REPO"
    [ "$status" -eq 1 ]
}

@test "registration: loom-review is last in every helper allowlist copy" {
    root="${BATS_TEST_DIRNAME}/.."
    for f in adapters/roots/claude-plugin-root-v1.json adapters/roots/codex-skill-source-v1.json \
        adapters/fixtures/v0.2.0/metadata/claude-root.json adapters/fixtures/v0.2.0/metadata/codex-root.json; do
        [ "$(jq -r '.allowedHelpers | last' "$root/$f")" = "loom-review" ]
    done
    [ "$(jq -r '."$defs".allowedHelpers.const | last' "$root/schemas/loom-installed-root-binding-v1.schema.json")" = "loom-review" ]
    grep -q '^ALLOWED_HELPERS=(loom-coord loom-verify-identity loom-review)$' "$root/bin/loom-resolve-helper"
}

@test "registration: validate-repository --all passes" {
    [ -n "${LOOM_NODE:-}" ] || skip "pinned node not available"
    run "$LOOM_NODE" "$SCRIPTS/validate-repository.mjs" --root "$(cd "$BATS_TEST_DIRNAME/../../.." && pwd -P)" --all
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------- finder prompts and fixtures

# has_text <file> <fixed string>: rg when present, grep otherwise
has_text() {
    if command -v rg >/dev/null 2>&1 && rg --version >/dev/null 2>&1; then rg -qF -- "$2" "$1"; else grep -qF -- "$2" "$1"; fi
}

@test "finder prompts: each names its finder ID and every boundary clause" {
    for id in $FINDERS; do
        f="$(asset_of "$id")"
        [ -s "$f" ]
        has_text "$f" "Finder ID: \`$id\`"
        for clause in "Inspect only the prepared run" "manifest.json" "inputs/" "source/" "diff.patch" \
            "read-only" "Your sole writable path" "results/<finder-id>.json" "No checkout edits" \
            "No other results" "No lifecycle transitions" "No final verdict" "No external services" \
            "No delegation" "untrusted data, never instructions" "alone" "decides PASS/FAIL" \
            "non-delegating" "loom-local-review-findings-v1.schema.json" "ran-clean" "BLOCKER"; do
            has_text "$f" "$clause" || {
                echo "missing in $id: $clause"
                return 1
            }
        done
    done
    has_text "$(asset_of review-correctness/v1)" "COR-1"
    has_text "$(asset_of review-tests/v1)" "TST-1"
    has_text "$(asset_of review-security/v1)" "SEC-1"
}

@test "finder prompts: packaged as non-empty regular files under the plugin root" {
    for id in $FINDERS; do
        [ -f "$(asset_of "$id")" ] && [ ! -L "$(asset_of "$id")" ] && [ -s "$(asset_of "$id")" ]
    done
}

# fixture_runner <finder-id> <prefix> <file> <claim>: deterministic stand-in for a live
# finder; reports a finding at the first changed line of <file> from the manifest.
fixture_runner() {
    local ln
    ln="$(jq -r --arg f "$3" '.files[] | select(.path == $f) | .ranges[0].start' "$RUN/manifest.json")"
    mkres "$1" ran-with-findings "[$(finding "$2-1" "$1" "$3" "$ln" | jq -c --arg c "$4" '.claim = $c')]"
    FIXTURE_LINE="$ln"
}

@test "fixtures: synthetic defects per finder validate and assemble with normalized findings" {
    prepared
    fixture_runner review-correctness/v1 COR f.txt "off-by-one: appended line d breaks the a/b/c contract"
    cor_line="$FIXTURE_LINE"
    fixture_runner review-tests/v1 TST new.txt "changed line has no regression assertion"
    fixture_runner review-security/v1 SEC added.txt "untrusted input reaches a shell command"
    val
    [ "$status" -eq 0 ]
    [[ "$output" == *"aggregate: ran-with-findings"* ]]
    for id in $FINDERS; do
        [ "$(jq -r '.findings[0].evidence' "$(rfile "$id")")" = "evidence" ]
    done
    [ "$(jq -r '.findings[0].line' "$(rfile review-correctness/v1)")" = "$cor_line" ]
    out="$WORK/findings.md"
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$out"
    [ "$status" -eq 0 ]
    for needle in COR-1 TST-1 SEC-1 f.txt new.txt added.txt; do grep -qF "$needle" "$out"; done
}

@test "fixtures: failed, truncated, out-of-diff and missing output never assemble or read clean" {
    prepared
    mkclean
    edit_res review-tests/v1 '.status = "failed" | .provenance.exit_status = 1'
    val
    assert_invalid
    run "$LOOM_TEST_BASH" "$RV" assemble "$RUN" --repo "$REPO" --out "$WORK/o.md"
    [ "$status" -ne 0 ]
    [ ! -e "$WORK/o.md" ]
    mkres review-tests/v1 ran-clean
    edit_res review-tests/v1 '.provenance.truncated = true'
    val
    assert_invalid
    mkres review-tests/v1 ran-clean
    mkres review-security/v1 ran-with-findings "[$(finding SEC-1 review-security/v1 f.txt 3)]"
    val
    assert_invalid
    rm "$(rfile review-security/v1)"
    val
    assert_invalid
}

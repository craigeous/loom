#!/usr/bin/env bats
# Test suite for precompact-write-ahead-backstop.sh (ADR 0013 §Decision 5 policy;
# spec 08 wire adapters + per-session state). Each test uses an isolated temp git
# repo so marker/log writes never touch loom's own .git/. The hook receives "cwd"
# in the JSON so it resolves the correct repo (cwd-independence).
# The code evaluator re-runs this suite as the shell gate's TEST step.
bats_require_minimum_version 1.5.0

HOOK="${BATS_TEST_DIRNAME}/precompact-write-ahead-backstop.sh"

setup_file() {
    : "${LOOM_TEST_BASH:?LOOM_TEST_BASH is required}"
    : "${LOOM_EXPECTED_BASH_VERSION:?LOOM_EXPECTED_BASH_VERSION is required}"
    case "$LOOM_TEST_BASH" in /*) ;; *) return 1 ;; esac
    [ -x "$LOOM_TEST_BASH" ]
    [[ "$($LOOM_TEST_BASH -c 'printf %s "$BASH_VERSION"')" =~ $LOOM_EXPECTED_BASH_VERSION ]]
    REAL_ROOT="$(CDPATH='' cd -- "${BATS_TEST_DIRNAME}/.." && pwd -P)"
    export REAL_ROOT
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# make_repo — init a temp git repo with a .docs/ commit; sets REPO, DOCS_SHA
make_repo() {
    REPO="$(mktemp -d)"
    git -C "$REPO" init -q
    git -C "$REPO" config user.email "test@example.com"
    git -C "$REPO" config user.name "Test"
    mkdir -p "$REPO/.docs/status"
    printf 'initial\n' >"$REPO/.docs/status/handoff.md"
    git -C "$REPO" add .docs
    git -C "$REPO" commit -q -m "seed docs"
    DOCS_SHA=$(git -C "$REPO" log -1 --format=%H -- .docs)
}

# add_docs_commit — add a new .docs/ commit in REPO; updates DOCS_SHA
add_docs_commit() {
    printf 'updated\n' >"$REPO/.docs/status/handoff.md"
    git -C "$REPO" add .docs
    git -C "$REPO" commit -q -m "advance docs"
    DOCS_SHA=$(git -C "$REPO" log -1 --format=%H -- .docs)
}

# session_dir <session-id> — path to that session's state directory
session_dir() {
    printf '%s/.git/loom/precompact/%s' "$REPO" "$1"
}

# write_marker <session-id> <sha> — write SHA into that session's marker file
write_marker() {
    local sid="$1" sha="$2" dir
    dir="$(session_dir "$sid")"
    mkdir -p "$dir"
    printf '%s\n' "$sha" >"$dir/marker"
}

# read_marker <session-id> — outputs that session's marker file contents
read_marker() {
    cat "$(session_dir "$1")/marker" 2>/dev/null
}

# mk_json trigger session — build hook JSON with cwd pointing at REPO
mk_json() {
    local trigger="$1" session="${2:-testsession}"
    if [ -n "$trigger" ]; then
        printf '{"trigger":"%s","session_id":"%s","cwd":"%s"}' "$trigger" "$session" "$REPO"
    else
        printf '{"session_id":"%s","cwd":"%s"}' "$session" "$REPO"
    fi
}

# backstop <json> -- run the hook against the real (validated) Claude root
backstop() {
    run env CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$HOOK" <<<"$1"
}

# backstop_codex <json> -- run the hook against the real (validated) Codex root
backstop_codex() {
    run env PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$HOOK" <<<"$1"
}

teardown() {
    if [ -n "${REPO:-}" ] && [ -d "$REPO" ]; then rm -rf "$REPO"; fi
    if [ -n "${OTHERDIR:-}" ] && [ -d "$OTHERDIR" ]; then rm -rf "$OTHERDIR"; fi
    if [ -n "${NOTREPO:-}" ] && [ -d "$NOTREPO" ]; then rm -rf "$NOTREPO"; fi
    return 0
}

# ---------------------------------------------------------------------------
# T1 — progress advanced → allow (manual and auto)
# ---------------------------------------------------------------------------

@test "T1a progress-advanced manual -> status 0, marker updated" {
    make_repo
    write_marker s1 "0000000000000000000000000000000000000000"
    backstop "$(mk_json manual s1)"
    [ "$status" -eq 0 ]
    [ "$(read_marker s1)" = "$DOCS_SHA" ]
}

@test "T1b progress-advanced auto -> status 0, marker updated" {
    make_repo
    write_marker s2 "0000000000000000000000000000000000000000"
    backstop "$(mk_json auto s2)"
    [ "$status" -eq 0 ]
    [ "$(read_marker s2)" = "$DOCS_SHA" ]
}

# ---------------------------------------------------------------------------
# T2 — no-progress + manual -> block, marker unchanged
# ---------------------------------------------------------------------------

@test "T2 no-progress manual -> status 2, exact single-line reason, marker unchanged" {
    make_repo
    write_marker s3 "$DOCS_SHA"
    backstop "$(mk_json manual s3)"
    [ "$status" -eq 2 ]
    [ "$output" = "loom write-ahead backstop: .docs/ has not advanced before manual compaction (ADR 0013); commit a .docs/ checkpoint, then retry." ]
    [ "$(read_marker s3)" = "$DOCS_SHA" ]
}

@test "T2codex no-progress manual -> exit 0, exact continue/stopReason JSON" {
    make_repo
    write_marker s3c "$DOCS_SHA"
    backstop_codex "$(mk_json manual s3c)"
    [ "$status" -eq 0 ]
    expected='{"continue":false,"stopReason":"loom write-ahead backstop: .docs/ has not advanced before manual compaction (ADR 0013); commit a .docs/ checkpoint, then retry."}'
    [ "$output" = "$expected" ]
}

# ---------------------------------------------------------------------------
# T3 — no-progress + auto -> never-wedge (exit 0), bounded log appended
# ---------------------------------------------------------------------------

@test "T3 no-progress auto -> status 0, log line appended, marker unchanged" {
    make_repo
    write_marker sess-abc "$DOCS_SHA"
    backstop "$(mk_json auto sess-abc)"
    [ "$status" -eq 0 ]
    LOG="$(session_dir sess-abc)/log"
    [ -f "$LOG" ]
    grep -q "$DOCS_SHA" "$LOG"
    [ "$(read_marker sess-abc)" = "$DOCS_SHA" ]
}

# ---------------------------------------------------------------------------
# T4 — marker-absent first-run -> record + allow
# ---------------------------------------------------------------------------

@test "T4 first-run no marker -> status 0, marker created with current SHA" {
    make_repo
    backstop "$(mk_json manual s4)"
    [ "$status" -eq 0 ]
    [ "$(read_marker s4)" = "$DOCS_SHA" ]
}

# ---------------------------------------------------------------------------
# T5 — marker read/write round-trip
# ---------------------------------------------------------------------------

@test "T5 round-trip: first-run allow, then no-progress block, then advance allow" {
    make_repo
    backstop "$(mk_json manual s5)"
    [ "$status" -eq 0 ]
    [ "$(read_marker s5)" = "$DOCS_SHA" ]

    backstop "$(mk_json manual s5)"
    [ "$status" -eq 2 ]
    [ "$(read_marker s5)" = "$DOCS_SHA" ]

    add_docs_commit

    backstop "$(mk_json manual s5)"
    [ "$status" -eq 0 ]
    [ "$(read_marker s5)" = "$DOCS_SHA" ]
}

# ---------------------------------------------------------------------------
# T6 — malformed/unknown trigger fails closed (spec 08; obsolete field removed)
# ---------------------------------------------------------------------------

@test "T6a missing trigger field fails closed (malformed)" {
    make_repo
    write_marker s6 "$DOCS_SHA"
    backstop "$(mk_json '' s6)"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-compact." ]
}

@test "T6b unknown trigger value fails closed (malformed)" {
    make_repo
    write_marker s6b "$DOCS_SHA"
    JSON="$(printf '{"trigger":"bogus","session_id":"s6b","cwd":"%s"}' "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-compact." ]
}

@test "T6c the obsolete compaction_trigger field is not recognized -> missing trigger -> malformed" {
    make_repo
    write_marker s6c "$DOCS_SHA"
    JSON="$(printf '{"compaction_trigger":"manual","session_id":"s6c","cwd":"%s"}' "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-compact." ]
}

@test "T6d trigger wrong JSON type fails closed (malformed)" {
    make_repo
    JSON="$(printf '{"trigger":7,"session_id":"s6d","cwd":"%s"}' "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
}

@test "T6e invalid JSON fails closed (malformed)" {
    backstop 'not json'
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-compact." ]
}

@test "T6f malformed on codex wire uses the JSON continue/stopReason envelope" {
    backstop_codex 'not json'
    [ "$status" -eq 0 ]
    expected='{"continue":false,"stopReason":"Loom hook input invalid for pre-compact."}'
    [ "$output" = "$expected" ]
}

# ---------------------------------------------------------------------------
# T7 — session_id validation (injection-safety)
# ---------------------------------------------------------------------------

@test "T7a missing session_id fails closed (malformed)" {
    make_repo
    JSON="$(printf '{"trigger":"manual","cwd":"%s"}' "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-compact." ]
}

@test "T7b session_id with a path separator fails closed (path-traversal attempt)" {
    make_repo
    JSON="$(printf '{"trigger":"manual","session_id":"../../etc","cwd":"%s"}' "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
    [ "$output" = "Loom hook input invalid for pre-compact." ]
    # rejected before any session directory was ever created (no traversal)
    [ ! -d "$REPO/.git/loom/precompact" ]
}

@test "T7c session_id with embedded whitespace/control-shaped content fails closed" {
    make_repo
    JSON="$(printf '{"trigger":"manual","session_id":"s x","cwd":"%s"}' "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
}

@test "T7d session_id over the length bound fails closed" {
    make_repo
    LONG=$(printf 'a%.0s' $(seq 1 129))
    JSON="$(printf '{"trigger":"manual","session_id":"%s","cwd":"%s"}' "$LONG" "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
}

@test "T7e session_id at the exact length bound (128) is accepted" {
    make_repo
    LONG=$(printf 'a%.0s' $(seq 1 128))
    JSON="$(printf '{"trigger":"manual","session_id":"%s","cwd":"%s"}' "$LONG" "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 0 ]
    [ "$(read_marker "$LONG")" = "$DOCS_SHA" ]
}

# ---------------------------------------------------------------------------
# T8 — fail-open: not a git repo / empty stdin
# ---------------------------------------------------------------------------

@test "T8a not a git repo -> status 0 (fail-open)" {
    NOTREPO="$(mktemp -d)"
    JSON="$(printf '{"trigger":"manual","session_id":"s8","cwd":"%s"}' "$NOTREPO")"
    backstop "$JSON"
    [ "$status" -eq 0 ]
}

@test "T8b empty stdin -> status 0 (fail-open)" {
    run env CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$HOOK" </dev/null
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T9 — jq absent: fails closed (no grep/sed fallback exists any more)
# ---------------------------------------------------------------------------

@test "T9 jq absent -> fails closed (root validation cannot succeed without jq)" {
    make_repo
    write_marker s9 "$DOCS_SHA"
    stub="$(mktemp -d)"
    for t in cat grep sed tr head date mkdir printf dirname mv tail; do
        for d in /usr/bin /bin; do
            [ -x "$d/$t" ] && {
                ln -s "$d/$t" "$stub/$t"
                break
            }
        done
    done
    GIT_PATH="$(command -v git)"
    ln -s "$GIT_PATH" "$stub/git"
    JSON="$(mk_json manual s9)"
    run env PATH="$stub" CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$HOOK" <<<"$JSON"
    rm -rf "$stub"
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# T10 — cwd-independence
# ---------------------------------------------------------------------------

@test "T10 cwd-independence: running from unrelated dir uses cwd from JSON" {
    make_repo
    write_marker s10 "$DOCS_SHA"
    OTHERDIR="$(mktemp -d)"
    JSON="$(mk_json manual s10)"
    run env CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" -c "cd '$OTHERDIR' && exec \"\$1\" \"\$2\"" -- "$LOOM_TEST_BASH" "$HOOK" <<<"$JSON"
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# T11 — concurrent/independent sessions never share state
# ---------------------------------------------------------------------------

@test "T11 one session's checkpoint never authorizes another session's manual compaction" {
    make_repo
    # s11a has already advanced (marker == current SHA) -> would block if shared.
    write_marker s11a "$DOCS_SHA"
    # s11b has no marker at all -> first-run for that session -> allow + record.
    backstop "$(mk_json manual s11b)"
    [ "$status" -eq 0 ]
    [ "$(read_marker s11b)" = "$DOCS_SHA" ]
    # s11a is untouched by s11b's run and still independently blocks.
    backstop "$(mk_json manual s11a)"
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# T12 — bounded/injection-safe log
# ---------------------------------------------------------------------------

@test "T12 the no-progress-auto log is capped at LOOM_PRECOMPACT_LOG_CAP lines" {
    make_repo
    write_marker s12 "$DOCS_SHA"
    for _ in 1 2 3 4 5; do
        run env CLAUDE_PLUGIN_ROOT="$REAL_ROOT" LOOM_PRECOMPACT_LOG_CAP=3 "$LOOM_TEST_BASH" "$HOOK" <<<"$(mk_json auto s12)"
        [ "$status" -eq 0 ]
    done
    LOG="$(session_dir s12)/log"
    [ "$(wc -l <"$LOG" | tr -d ' ')" -eq 3 ]
}

@test "T13 an interrupted marker write leaves the prior marker intact (atomic rename)" {
    make_repo
    write_marker s13 "0000000000000000000000000000000000000000"
    dir="$(session_dir s13)"
    mkdir -p "$dir"
    # A stray, unrenamed temp file (as an interrupted write would leave behind)
    # must never be mistaken for the marker.
    printf 'garbage' >"$dir/.tmp.stray.123"
    backstop "$(mk_json manual s13)"
    [ "$status" -eq 0 ]
    [ "$(read_marker s13)" = "$DOCS_SHA" ]
}

# ---------------------------------------------------------------------------
# RED-GREEN sentinel — proves the trigger-enum guard is exercised
# ---------------------------------------------------------------------------

@test "RED-GREEN: a recognized trigger still proceeds while an unrecognized one is rejected" {
    make_repo
    write_marker rg1 "0000000000000000000000000000000000000000"
    backstop "$(mk_json manual rg1)"
    [ "$status" -eq 0 ]
    JSON="$(printf '{"trigger":"weird","session_id":"rg2","cwd":"%s"}' "$REPO")"
    backstop "$JSON"
    [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# hook-wire-v1 fixture conformance (spec 08) — pre-compact half of the
# Cartesian product (claude/codex x allow/block/malformed); the identity-guard
# bats suite covers the pre-tool-use half. Byte-exact via cmp, not string
# comparison. The checked-in fixture omits "cwd" (environment-specific); it is
# injected here against a freshly built temp repo. "allow" relies on the
# fixture session's marker being genuinely absent (first-run); "block" pre-
# seeds that session's marker to the fresh repo's current .docs SHA
# (no-progress); "malformed" needs neither since it fails before repo access.
# ---------------------------------------------------------------------------

FIXTURE_ROOT="${BATS_TEST_DIRNAME}/fixtures/hook-wire-v1"

fixture_env_var() {
    case "$1" in
    codex) printf 'PLUGIN_ROOT' ;;
    *) printf 'CLAUDE_PLUGIN_ROOT' ;;
    esac
}

# assert_fixture <client> <case> — byte-compares stdout/stderr/exit for
# fixtures/hook-wire-v1/<client>/pre-compact/<case>.* against a live run.
assert_fixture() {
    local client="$1" case_name="$2" dir env_var session input
    local out_file err_file actual_exit expected_exit
    dir="$FIXTURE_ROOT/$client/pre-compact"

    run jq -e '(.trigger | type == "string") and (.session_id | type == "string")' "$dir/$case_name.input.json"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]

    make_repo
    session=$(jq -r '.session_id' "$dir/$case_name.input.json")
    if [ "$case_name" = "block" ]; then
        write_marker "$session" "$DOCS_SHA"
    fi
    input=$(jq --arg cwd "$REPO" '. + {cwd: $cwd}' "$dir/$case_name.input.json")

    env_var="$(fixture_env_var "$client")"
    out_file="$(mktemp)"
    err_file="$(mktemp)"
    # not wrapped in `run`: an unguarded nonzero exit here (the block cases
    # legitimately exit 2) would otherwise trip bats' own errexit and abort
    # the test before the byte comparisons run.
    printf '%s' "$input" | env "$env_var=$REAL_ROOT" "$LOOM_TEST_BASH" "$HOOK" >"$out_file" 2>"$err_file" && actual_exit=0 || actual_exit=$?
    expected_exit=$(tr -d '\n' <"$dir/$case_name.exit")

    cmp -s "$out_file" "$dir/$case_name.stdout"
    local stdout_match=$?
    cmp -s "$err_file" "$dir/$case_name.stderr"
    local stderr_match=$?
    rm -f "$out_file" "$err_file"

    [ "$actual_exit" -eq "$expected_exit" ]
    [ "$stdout_match" -eq 0 ]
    [ "$stderr_match" -eq 0 ]
}

@test "fixture claude/pre-compact/allow" { assert_fixture claude allow; }

@test "fixture claude/pre-compact/block" { assert_fixture claude block; }

@test "fixture claude/pre-compact/malformed" { assert_fixture claude malformed; }

@test "fixture codex/pre-compact/allow" { assert_fixture codex allow; }

@test "fixture codex/pre-compact/block" { assert_fixture codex block; }

@test "fixture codex/pre-compact/malformed" { assert_fixture codex malformed; }

@test "root: Codex prefers its valid PLUGIN_ROOT when both compatibility roots validate" {
    make_repo
    write_marker s-both "$DOCS_SHA"
    run env PLUGIN_ROOT="$REAL_ROOT" CLAUDE_PLUGIN_ROOT="$REAL_ROOT" "$LOOM_TEST_BASH" "$HOOK" <<<"$(mk_json manual s-both)"
    [ "$status" -eq 0 ]
    expected='{"continue":false,"stopReason":"loom write-ahead backstop: .docs/ has not advanced before manual compaction (ADR 0013); commit a .docs/ checkpoint, then retry."}'
    [ "$output" = "$expected" ]
}

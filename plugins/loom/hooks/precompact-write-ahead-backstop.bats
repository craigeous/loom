#!/usr/bin/env bats
# Test suite for precompact-write-ahead-backstop.sh (ADR 0013 §Decision 5).
# Drives the hook with hook-shaped JSON on stdin; asserts exit code and side effects.
# Each test uses an isolated temp git repo so marker/log writes never touch loom's .git/.
# The hook receives "cwd" in the JSON so it resolves the correct repo (cwd-independence).
# The code evaluator re-runs this suite as the shell gate's TEST step.

HOOK="${BATS_TEST_DIRNAME}/precompact-write-ahead-backstop.sh"

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

# write_marker SHA — write SHA into the marker file
write_marker() {
    local sha="$1"
    mkdir -p "$REPO/.git/loom"
    printf '%s\n' "$sha" >"$REPO/.git/loom/precompact-marker"
}

# read_marker — outputs the marker file contents
read_marker() {
    cat "$REPO/.git/loom/precompact-marker" 2>/dev/null
}

# mk_json trigger session — build hook JSON with cwd pointing at REPO
mk_json() {
    local trigger="$1"
    local session="${2:-testsession}"
    if [ -n "$trigger" ]; then
        printf '{"compaction_trigger":"%s","session_id":"%s","cwd":"%s"}' \
            "$trigger" "$session" "$REPO"
    else
        printf '{"session_id":"%s","cwd":"%s"}' "$session" "$REPO"
    fi
}

# backstop JSON — run the hook with the given JSON on stdin
# Sets $status and $output (bats run convention)
backstop() {
    local json="$1"
    run sh "$HOOK" <<<"$json"
}

# ---------------------------------------------------------------------------
# T1 — progress advanced → allow (manual and auto)
# ---------------------------------------------------------------------------

@test "T1a progress-advanced manual → status 0, marker updated" {
    make_repo
    write_marker "0000000000000000000000000000000000000000"
    backstop "$(mk_json manual s1)"
    [ "$status" -eq 0 ]
    [ "$(read_marker)" = "$DOCS_SHA" ]
    rm -rf "$REPO"
}

@test "T1b progress-advanced auto → status 0, marker updated" {
    make_repo
    write_marker "0000000000000000000000000000000000000000"
    backstop "$(mk_json auto s2)"
    [ "$status" -eq 0 ]
    [ "$(read_marker)" = "$DOCS_SHA" ]
    rm -rf "$REPO"
}

# ---------------------------------------------------------------------------
# T2 — no-progress + manual → block (exit 2), marker unchanged
# ---------------------------------------------------------------------------

@test "T2 no-progress manual → status 2, remediation in output, marker unchanged" {
    make_repo
    write_marker "$DOCS_SHA"
    backstop "$(mk_json manual s3)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"no-progress"* ]] || [[ "$output" == *"handoff"* ]]
    [ "$(read_marker)" = "$DOCS_SHA" ]
    rm -rf "$REPO"
}

# ---------------------------------------------------------------------------
# T3 — no-progress + auto → never-wedge (exit 0), log appended, marker unchanged
# ---------------------------------------------------------------------------

@test "T3 no-progress auto → status 0, log line appended, marker unchanged" {
    make_repo
    write_marker "$DOCS_SHA"
    backstop "$(mk_json auto sess-abc)"
    [ "$status" -eq 0 ]
    LOG="$REPO/.git/loom/precompact.log"
    [ -f "$LOG" ]
    grep -q "sess-abc" "$LOG"
    [ "$(read_marker)" = "$DOCS_SHA" ]
    rm -rf "$REPO"
}

# ---------------------------------------------------------------------------
# T4 — marker-absent first-run → record + allow
# ---------------------------------------------------------------------------

@test "T4 first-run no marker → status 0, marker created with current SHA" {
    make_repo
    rm -f "$REPO/.git/loom/precompact-marker"
    backstop "$(mk_json manual s4)"
    [ "$status" -eq 0 ]
    [ "$(read_marker)" = "$DOCS_SHA" ]
    rm -rf "$REPO"
}

# ---------------------------------------------------------------------------
# T5 — marker read/write round-trip
# ---------------------------------------------------------------------------

@test "T5 round-trip: first-run allow, then no-progress block, then advance allow" {
    make_repo

    # Pass 1: first-run (no marker) → allow, marker created
    backstop "$(mk_json manual s5a)"
    [ "$status" -eq 0 ]
    [ "$(read_marker)" = "$DOCS_SHA" ]

    # Pass 2: same SHA, manual → block, marker still same
    backstop "$(mk_json manual s5b)"
    [ "$status" -eq 2 ]
    [ "$(read_marker)" = "$DOCS_SHA" ]

    # Advance .docs/ and commit
    add_docs_commit

    # Pass 3: new SHA, manual → allow, marker updated to new SHA
    backstop "$(mk_json manual s5c)"
    [ "$status" -eq 0 ]
    [ "$(read_marker)" = "$DOCS_SHA" ]

    rm -rf "$REPO"
}

# ---------------------------------------------------------------------------
# T6 — empty/unknown trigger → treated as auto (never-wedge)
# ---------------------------------------------------------------------------

@test "T6 no compaction_trigger field (empty) → treated as auto, status 0" {
    make_repo
    write_marker "$DOCS_SHA"
    # Pass JSON without compaction_trigger
    backstop "$(mk_json '' s6)"
    [ "$status" -eq 0 ]
    rm -rf "$REPO"
}

# ---------------------------------------------------------------------------
# T7 — fail-open: not a git repo
# ---------------------------------------------------------------------------

@test "T7 not a git repo → status 0 (fail-open)" {
    NOTREPO="$(mktemp -d)"
    # cwd points at a non-git dir; git rev-parse --show-toplevel will fail
    JSON="$(printf '{"compaction_trigger":"manual","session_id":"s7","cwd":"%s"}' "$NOTREPO")"
    backstop "$JSON"
    [ "$status" -eq 0 ]
    rm -rf "$NOTREPO"
}

# ---------------------------------------------------------------------------
# T8 — fail-open: empty stdin
# ---------------------------------------------------------------------------

@test "T8 empty stdin → status 0 (fail-open)" {
    run sh "$HOOK" </dev/null
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# T9 (optional) — jq-absent fallback: grep/sed extracts trigger correctly
# ---------------------------------------------------------------------------

@test "T9 jq-absent fallback: manual no-progress still blocks (exit 2)" {
    make_repo
    write_marker "$DOCS_SHA"
    stub="$(mktemp -d)"
    # Symlink everything except jq
    for t in cat grep sed tr head date mkdir printf; do
        for d in /usr/bin /bin; do
            [ -x "$d/$t" ] && {
                ln -s "$d/$t" "$stub/$t"
                break
            }
        done
    done
    # git is required — find and link it
    GIT_PATH="$(command -v git)"
    ln -s "$GIT_PATH" "$stub/git"
    JSON="$(mk_json manual s9)"
    run env PATH="$stub" /bin/sh "$HOOK" <<<"$JSON"
    rm -rf "$stub"
    [ "$status" -eq 2 ]
    rm -rf "$REPO"
}

# ---------------------------------------------------------------------------
# T10 — cwd-independence: hook invoked from outside the repo still resolves correctly
# ---------------------------------------------------------------------------

@test "T10 cwd-independence: running from unrelated dir uses cwd from JSON" {
    make_repo
    write_marker "$DOCS_SHA"
    # Run from a completely different directory; the hook must use cwd from JSON
    OTHERDIR="$(mktemp -d)"
    JSON="$(mk_json manual s10)"
    run sh -c "cd '$OTHERDIR' && sh '$HOOK'" <<<"$JSON"
    # no-progress + manual → block (proves hook resolved REPO, not OTHERDIR)
    [ "$status" -eq 2 ]
    rm -rf "$OTHERDIR"
    rm -rf "$REPO"
}

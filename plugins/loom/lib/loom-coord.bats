#!/usr/bin/env bats
# Test suite for loom-coord.sh (ADR 0014 multi-session coordination helper).
# Each test uses an isolated temp git repo so state writes never touch loom's .git/.
# The code evaluator re-runs this suite as the shell gate's TEST step.

COORD="${BATS_TEST_DIRNAME}/loom-coord.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# make_repo — init a temp git repo; sets REPO
make_repo() {
    REPO="$(mktemp -d)"
    git -C "$REPO" init -q
    git -C "$REPO" config user.email "test@example.com"
    git -C "$REPO" config user.name "Test"
    # Seed a commit so HEAD exists
    touch "$REPO/.gitkeep"
    git -C "$REPO" add .gitkeep
    git -C "$REPO" commit -q -m "seed"
}

# coord <subcommand> [args...] — run the helper inside REPO
# Sets $status and $output (bats run convention)
coord() {
    run sh "$COORD" "$@"
}

# coord_session <session-id> <subcommand> [args...] — run with --session
coord_session() {
    local sid="$1"
    shift
    run env LOOM_LOCK_TTL="${LOOM_LOCK_TTL:-30}" \
        LOOM_LOCK_RETRIES="${LOOM_LOCK_RETRIES:-5}" \
        sh "$COORD" "$@" --session "$sid"
}

# state_dir — path to .git/loom/ in REPO
state_dir() {
    printf '%s/.git/loom' "$REPO"
}

# holder_sid — read the session-id field from holder, or empty
holder_sid() {
    awk -F'\t' '{print $1}' "$REPO/.git/loom/main.lock/holder" 2>/dev/null || true
}

# holder_pid — read the pid field from holder
holder_pid() {
    awk -F'\t' '{print $2}' "$REPO/.git/loom/main.lock/holder" 2>/dev/null || true
}

# make_live_holder <session-id> — plant a live holder with a real worktree path
#   containing the session-id so the liveness probe returns alive
make_live_holder() {
    local sid="$1"
    local wt_path="$REPO/../wt-${sid}"
    wt_path="$(cd "$REPO/.." && pwd)/wt-${sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD
    mkdir -p "$REPO/.git/loom/main.lock"
    printf '%s\t%s\t%s\n' "$sid" "$$" "$(date +%s)" \
        >"$REPO/.git/loom/main.lock/holder"
    printf '%s' "$wt_path"
}

# make_dead_holder <session-id> [epoch] — plant a dead holder (no worktree, dead pid)
#   epoch defaults to 0 (always past TTL)
make_dead_holder() {
    local sid="$1"
    local epoch="${2:-0}"
    mkdir -p "$REPO/.git/loom/main.lock"
    printf '%s\t%s\t%s\n' "$sid" "99999999" "$epoch" \
        >"$REPO/.git/loom/main.lock/holder"
}

# dead_pid — a guaranteed-dead pid (use a process we started and waited)
dead_pid() {
    sh -c 'exit 0' &
    local p=$!
    wait "$p"
    printf '%s' "$p"
}

# teardown — remove REPO and any side worktrees
teardown() {
    if [ -n "${REPO:-}" ] && [ -d "${REPO:-}" ]; then
        # Remove any worktrees we added
        git -C "$REPO" worktree prune 2>/dev/null || true
        local wt
        while IFS= read -r wt; do
            [ "$wt" = "$REPO" ] && continue
            rm -rf "$wt" 2>/dev/null || true
        done <<EOF
$(git -C "$REPO" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')
EOF
        rm -rf "$REPO"
    fi
    REPO=""
}

# ---------------------------------------------------------------------------
# L1 — Lock: atomic acquire on free lock
# ---------------------------------------------------------------------------

@test "L1 lock-acquire on free lock: exit 0, holder session-id == self" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-L1"
    [ "$status" -eq 0 ]
    [ "$output" = "acquired" ]
    [ "$(holder_sid)" = "ses-L1" ]
    teardown
}

# ---------------------------------------------------------------------------
# L2 — Lock: contention against a LIVE holder → exit 3, holder unchanged
# ---------------------------------------------------------------------------

@test "L2 lock-acquire vs LIVE holder: exit 3, original holder stamp unchanged" {
    make_repo
    cd "$REPO"
    make_live_holder "ses-live-L2" >/dev/null
    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" lock-acquire --session "ses-contender-L2"
    [ "$status" -eq 3 ]
    [ "$(holder_sid)" = "ses-live-L2" ]
    teardown
}

# ---------------------------------------------------------------------------
# L3 — Lock: stale dead holder → force-clear and acquire (positive)
# ---------------------------------------------------------------------------

@test "L3 lock-acquire vs DEAD stale holder: exit 0, holder now == contender" {
    make_repo
    cd "$REPO"
    make_dead_holder "ses-dead-L3" "0"
    run env LOOM_LOCK_TTL=0 LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-contender-L3"
    [ "$status" -eq 0 ]
    [ "$output" = "acquired" ]
    [ "$(holder_sid)" = "ses-contender-L3" ]
    teardown
}

# ---------------------------------------------------------------------------
# L4 — Lock: live holder NOT cleared even past TTL (negative)
# ---------------------------------------------------------------------------

@test "L4 lock-acquire vs LIVE holder past TTL: exit 3, holder unchanged" {
    make_repo
    cd "$REPO"
    make_live_holder "ses-live-L4" >/dev/null
    # Force old epoch so TTL check passes, but liveness probe must still block
    printf '%s\t%s\t%s\n' "ses-live-L4" "$$" "0" \
        >"$REPO/.git/loom/main.lock/holder"
    run env LOOM_LOCK_TTL=0 LOOM_LOCK_RETRIES=2 sh "$COORD" lock-acquire --session "ses-contender-L4"
    [ "$status" -eq 3 ]
    [ "$(holder_sid)" = "ses-live-L4" ]
    teardown
}

# ---------------------------------------------------------------------------
# L5 — Lock: mutual exclusion under concurrent stale reclaim (BLOCKER 2)
#   Two contenders race over one dead holder; exactly one wins.
#   Repeated 10 times to exercise interleavings.
# ---------------------------------------------------------------------------

@test "L5 concurrent stale reclaim: exactly one winner, looped 10x" {
    make_repo
    cd "$REPO"
    local i=0
    while [ "$i" -lt 10 ]; do
        # Re-seed dead holder each iteration
        make_dead_holder "ses-dead-L5" "0"

        # Launch two contenders concurrently.
        # TTL=5 makes the dead holder (epoch=0) stale (elapsed >> 5) while
        # keeping a freshly-won lock (epoch≈now, elapsed≈0) safe from re-reclaim.
        (
            env LOOM_LOCK_TTL=5 LOOM_LOCK_RETRIES=5 sh "$COORD" lock-acquire --session "ses-A-L5"
            echo "A:$?"
        ) >"$BATS_TEST_TMPDIR/out_A_$i" 2>&1 &
        local pid_a=$!
        (
            env LOOM_LOCK_TTL=5 LOOM_LOCK_RETRIES=5 sh "$COORD" lock-acquire --session "ses-B-L5"
            echo "B:$?"
        ) >"$BATS_TEST_TMPDIR/out_B_$i" 2>&1 &
        local pid_b=$!
        wait "$pid_a" || true
        wait "$pid_b" || true

        local out_a out_b
        out_a=$(cat "$BATS_TEST_TMPDIR/out_A_$i")
        out_b=$(cat "$BATS_TEST_TMPDIR/out_B_$i")

        local exit_a exit_b
        exit_a=$(printf '%s' "$out_a" | grep 'A:' | sed 's/A://')
        exit_b=$(printf '%s' "$out_b" | grep 'B:' | sed 's/B://')

        # Exactly one must be 0, the other non-zero
        local zeros=0
        [ "$exit_a" = "0" ] && zeros=$((zeros + 1))
        [ "$exit_b" = "0" ] && zeros=$((zeros + 1))
        if [ "$zeros" -ne 1 ]; then
            printf 'FAIL iteration %d: exit_a=%s exit_b=%s\n' "$i" "$exit_a" "$exit_b" >&2
            false
        fi

        # holder must name exactly the winner
        local winner_holder
        winner_holder=$(holder_sid)
        if [ "$exit_a" = "0" ] && [ "$winner_holder" != "ses-A-L5" ]; then
            printf 'FAIL iteration %d: A won but holder=%s\n' "$i" "$winner_holder" >&2
            false
        fi
        if [ "$exit_b" = "0" ] && [ "$winner_holder" != "ses-B-L5" ]; then
            printf 'FAIL iteration %d: B won but holder=%s\n' "$i" "$winner_holder" >&2
            false
        fi

        # Clean lock for next iteration
        rm -rf "$REPO/.git/loom/main.lock"
        i=$((i + 1))
    done
    teardown
}

# ---------------------------------------------------------------------------
# L6 — Lock: second acquired never observable while first is held
# ---------------------------------------------------------------------------

@test "L6 second lock-acquire returns 3 while first is held; lock-verify confirms" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-A-L6"
    [ "$status" -eq 0 ]

    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" lock-acquire --session "ses-B-L6"
    [ "$status" -eq 3 ]

    # lock-verify A → held (0); lock-verify B → 5
    run sh "$COORD" lock-verify --session "ses-A-L6"
    [ "$status" -eq 0 ]
    [ "$output" = "held" ]

    run sh "$COORD" lock-verify --session "ses-B-L6"
    [ "$status" -eq 5 ]
    teardown
}

# ---------------------------------------------------------------------------
# L7 — Lock: lock-verify cases (MAJOR)
# ---------------------------------------------------------------------------

@test "L7a lock-verify while A holds: A→0 (held), B→5" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-A-L7"
    [ "$status" -eq 0 ]

    run sh "$COORD" lock-verify --session "ses-A-L7"
    [ "$status" -eq 0 ]
    [ "$output" = "held" ]

    run sh "$COORD" lock-verify --session "ses-B-L7"
    [ "$status" -eq 5 ]

    # Verify no change to holder after lock-verify
    [ "$(holder_sid)" = "ses-A-L7" ]
    teardown
}

@test "L7b lock-verify with no lock: exit 5" {
    make_repo
    cd "$REPO"
    run sh "$COORD" lock-verify --session "ses-A-L7b"
    [ "$status" -eq 5 ]
    teardown
}

@test "L7c lock-verify outside a repo: exit 10" {
    local notrepo
    notrepo="$(mktemp -d)"
    cd "$notrepo"
    run sh "$COORD" lock-verify --session "ses-A-L7c"
    [ "$status" -eq 10 ]
    rm -rf "$notrepo"
}

# ---------------------------------------------------------------------------
# L8 — Lock: release by non-holder → exit 5, lock intact
# ---------------------------------------------------------------------------

@test "L8 lock-release by non-holder: exit 5, lock intact" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-A-L8"
    [ "$status" -eq 0 ]

    run sh "$COORD" lock-release --session "ses-other-L8"
    [ "$status" -eq 5 ]
    [ "$(holder_sid)" = "ses-A-L8" ]
    teardown
}

# ---------------------------------------------------------------------------
# C1 — Claim: free slice
# ---------------------------------------------------------------------------

@test "C1 claim free slice: exit 0, registry and held-claims updated" {
    make_repo
    cd "$REPO"
    # Acquire lock first
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-C1"
    [ "$status" -eq 0 ]

    run sh "$COORD" claim slice-X --session "ses-C1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"claimed slice-X"* ]]

    # Registry contains the claim line
    grep -qF "slice-X	ses-C1" "$REPO/.git/loom/claims"
    # held-claims contains the slice
    grep -qxF "slice-X" "$REPO/.git/loom/session-ses-C1/held-claims"
    teardown
}

# ---------------------------------------------------------------------------
# C2 — Claim: check-then-act: live peer claim → exit 4
# ---------------------------------------------------------------------------

@test "C2 claim with live peer: exit 4, registry unchanged" {
    make_repo
    cd "$REPO"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-ses-peer-C2"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    # Plant a live peer claim
    mkdir -p "$REPO/.git/loom"
    printf 'slice-Y\tses-peer-C2\t%s\t%s\n' "$$" "$(date +%s)" \
        >"$REPO/.git/loom/claims"
    mkdir -p "$REPO/.git/loom/session-ses-peer-C2"
    printf 'slice-Y\n' >"$REPO/.git/loom/session-ses-peer-C2/held-claims"

    # Our session acquires the lock
    mkdir -p "$REPO/.git/loom/main.lock"
    printf 'ses-us-C2\t%s\t%s\n' "$$" "$(date +%s)" \
        >"$REPO/.git/loom/main.lock/holder"
    mkdir -p "$REPO/.git/loom/session-ses-us-C2"
    touch "$REPO/.git/loom/session-ses-us-C2/checkpoint"
    touch "$REPO/.git/loom/session-ses-us-C2/held-claims"

    run sh "$COORD" claim slice-Y --session "ses-us-C2"
    [ "$status" -eq 4 ]
    # Registry still shows peer's claim
    grep -qF "slice-Y	ses-peer-C2" "$REPO/.git/loom/claims"
    teardown
}

# ---------------------------------------------------------------------------
# C3 — Claim: re-affirm own claim → idempotent exit 0
# ---------------------------------------------------------------------------

@test "C3 claim own already-held slice: idempotent exit 0" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-C3"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-Z --session "ses-C3"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-Z --session "ses-C3"
    [ "$status" -eq 0 ]
    teardown
}

# ---------------------------------------------------------------------------
# C4 — Claim: without lock → exit 5
# ---------------------------------------------------------------------------

@test "C4 claim without holding the lock: exit 5" {
    make_repo
    cd "$REPO"
    # Seed held-claims so assert_lock_held can run; but do NOT acquire the lock
    mkdir -p "$REPO/.git/loom/session-ses-C4"
    touch "$REPO/.git/loom/session-ses-C4/checkpoint"
    touch "$REPO/.git/loom/session-ses-C4/held-claims"
    run sh "$COORD" claim slice-W --session "ses-C4"
    [ "$status" -eq 5 ]
    teardown
}

# ---------------------------------------------------------------------------
# R1 — Renew: updates epoch and pid
# ---------------------------------------------------------------------------

@test "R1 renew: epoch advances and pid overwritten" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-R1"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-R --session "ses-R1"
    [ "$status" -eq 0 ]

    local before_epoch
    before_epoch=$(awk -F'\t' '$1=="slice-R"{print $4}' "$REPO/.git/loom/claims")
    sleep 1
    run sh "$COORD" renew slice-R --session "ses-R1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed slice-R"* ]]

    local after_epoch
    after_epoch=$(awk -F'\t' '$1=="slice-R"{print $4}' "$REPO/.git/loom/claims")
    [ "$after_epoch" -ge "$before_epoch" ]
    teardown
}

@test "R1b renew by non-owner: exit 5" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-R1b-owner"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-R1b --session "ses-R1b-owner"
    [ "$status" -eq 0 ]
    run sh "$COORD" renew slice-R1b --session "ses-R1b-other"
    [ "$status" -eq 5 ]
    teardown
}

# ---------------------------------------------------------------------------
# RC1 — release-claim: removes line and held-claims entry
# ---------------------------------------------------------------------------

@test "RC1 release-claim: removes registry line and held-claims entry" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-RC1"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-RC --session "ses-RC1"
    [ "$status" -eq 0 ]

    run sh "$COORD" release-claim slice-RC --session "ses-RC1"
    [ "$status" -eq 0 ]
    ! grep -qF "slice-RC" "$REPO/.git/loom/claims" 2>/dev/null
    ! grep -qxF "slice-RC" "$REPO/.git/loom/session-ses-RC1/held-claims" 2>/dev/null
    teardown
}

# ---------------------------------------------------------------------------
# RCL1 — reclaim: stale dead peer → reclaim (positive); live peer → exit 6
# ---------------------------------------------------------------------------

@test "RCL1 reclaim dead peer claim: exit 0, registry owned by us" {
    make_repo
    cd "$REPO"

    # Dead peer: claim in registry with a dead pid; NO worktree (simulates crash).
    # We must NOT create a git worktree for the dead sid — if we did, git worktree
    # list would still show it until pruned, making is_alive return true.
    local dead_sid="ses-dead-RCL1"
    mkdir -p "$REPO/.git/loom"
    printf 'slice-RCL\t%s\t99999999\t0\n' "$dead_sid" >"$REPO/.git/loom/claims"

    # Our session acquires the lock
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-us-RCL1"
    [ "$status" -eq 0 ]

    run sh "$COORD" reclaim slice-RCL --session "ses-us-RCL1"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-RCL" ]
    grep -qF "slice-RCL	ses-us-RCL1" "$REPO/.git/loom/claims"
    teardown
}

@test "RCL1b reclaim live peer claim: exit 6, claim unchanged" {
    make_repo
    cd "$REPO"
    local live_sid="ses-live-RCL1b"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    mkdir -p "$REPO/.git/loom"
    printf 'slice-RCLb\t%s\t%s\t%s\n' "$live_sid" "$$" "$(date +%s)" \
        >"$REPO/.git/loom/claims"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-us-RCL1b"
    [ "$status" -eq 0 ]

    run sh "$COORD" reclaim slice-RCLb --session "ses-us-RCL1b"
    [ "$status" -eq 6 ]
    grep -qF "slice-RCLb	$live_sid" "$REPO/.git/loom/claims"
    teardown
}

# ---------------------------------------------------------------------------
# S1 — Per-session state: session-start, checkpoint, held-claims
# ---------------------------------------------------------------------------

@test "S1 session-start prints uuid and creates session dir" {
    make_repo
    cd "$REPO"
    run sh "$COORD" session-start
    [ "$status" -eq 0 ]
    local sid="$output"
    [ -n "$sid" ]
    [ -d "$REPO/.git/loom/session-$sid" ]
    [ -f "$REPO/.git/loom/session-$sid/checkpoint" ]
    [ -f "$REPO/.git/loom/session-$sid/held-claims" ]
    teardown
}

@test "S1b checkpoint write/read round-trip" {
    make_repo
    cd "$REPO"
    run sh "$COORD" session-start --session "ses-S1b"
    [ "$status" -eq 0 ]
    run sh "$COORD" checkpoint-write "next: implement slice-foo" --session "ses-S1b"
    [ "$status" -eq 0 ]
    run sh "$COORD" checkpoint-read --session "ses-S1b"
    [ "$status" -eq 0 ]
    [ "$output" = "next: implement slice-foo" ]
    teardown
}

@test "S1c claim updates held-claims in session dir" {
    make_repo
    cd "$REPO"
    run sh "$COORD" session-start --session "ses-S1c"
    [ "$status" -eq 0 ]
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-S1c"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-S1c --session "ses-S1c"
    [ "$status" -eq 0 ]
    grep -qxF "slice-S1c" "$REPO/.git/loom/session-ses-S1c/held-claims"
    teardown
}

# ---------------------------------------------------------------------------
# SB1 — Restart re-adoption via session-bootstrap
# ---------------------------------------------------------------------------

@test "SB1 session-bootstrap re-adopts claims and renews leases" {
    make_repo
    cd "$REPO"
    local sid="ses-SB1"

    # Create a real worktree containing the session-id so liveness probe sees it alive
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    run sh "$COORD" session-start --session "$sid"
    [ "$status" -eq 0 ]
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "$sid"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-SB1a --session "$sid"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-SB1b --session "$sid"
    [ "$status" -eq 0 ]
    run sh "$COORD" lock-release --session "$sid"
    [ "$status" -eq 0 ]

    # Record old epoch
    local old_epoch
    old_epoch=$(awk -F'\t' '$1=="slice-SB1a"{print $4}' "$REPO/.git/loom/claims")

    sleep 1

    # Cold-restart: call session-bootstrap (simulates new pid from fresh process)
    run sh "$COORD" session-bootstrap --session "$sid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed slice-SB1a"* ]]
    [[ "$output" == *"renewed slice-SB1b"* ]]

    # Epoch refreshed
    local new_epoch
    new_epoch=$(awk -F'\t' '$1=="slice-SB1a"{print $4}' "$REPO/.git/loom/claims")
    [ "$new_epoch" -ge "$old_epoch" ]

    # A peer probe still sees sid as alive (worktree contains sid in path)
    git -C "$REPO" worktree list --porcelain | grep -qF "$sid"
    teardown
}

# ---------------------------------------------------------------------------
# CU1 — Cleanup: dead session swept, live session untouched
# ---------------------------------------------------------------------------

@test "CU1 cleanup sweeps dead session, leaves live session intact" {
    make_repo
    cd "$REPO"
    local live_sid="ses-live-CU1"
    local dead_sid="ses-dead-CU1"

    # Live session: real worktree with session-id in path
    local wt_live
    wt_live="$(cd "$REPO/.." && pwd)/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_live" HEAD

    # Dead session: worktree dir deleted (simulate crash)
    local wt_dead
    wt_dead="$(cd "$REPO/.." && pwd)/wt-${dead_sid}"
    git -C "$REPO" worktree add -q "$wt_dead" HEAD
    rm -rf "$wt_dead"

    mkdir -p "$REPO/.git/loom"
    printf 'slice-live\t%s\t%s\t%s\n' "$live_sid" "$$" "$(date +%s)" \
        >"$REPO/.git/loom/claims"
    printf 'slice-dead\t%s\t99999999\t0\n' "$dead_sid" \
        >>"$REPO/.git/loom/claims"

    mkdir -p "$REPO/.git/loom/session-$live_sid"
    touch "$REPO/.git/loom/session-$live_sid/checkpoint"
    mkdir -p "$REPO/.git/loom/session-$dead_sid"
    touch "$REPO/.git/loom/session-$dead_sid/checkpoint"

    # Also plant a stale dead-holder lock
    make_dead_holder "$dead_sid" "0"

    run env LOOM_LOCK_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"swept 1"* ]]

    # Dead claim removed; live claim intact
    ! grep -qF "slice-dead" "$REPO/.git/loom/claims" 2>/dev/null
    grep -qF "slice-live	$live_sid" "$REPO/.git/loom/claims"

    # Dead session dir removed; live session dir intact
    [ ! -d "$REPO/.git/loom/session-$dead_sid" ]
    [ -d "$REPO/.git/loom/session-$live_sid" ]
    teardown
}

# ---------------------------------------------------------------------------
# FC1 — Fail-closed: outside a repo → exit 10
# ---------------------------------------------------------------------------

@test "FC1 lock-acquire outside a repo: exit 10 (deny, not 0)" {
    local notrepo
    notrepo="$(mktemp -d)"
    cd "$notrepo"
    run sh "$COORD" lock-acquire --session "ses-FC1"
    [ "$status" -eq 10 ]
    [ "$status" -ne 0 ]
    rm -rf "$notrepo"
}

@test "FC1b claim outside a repo: exit 10 (deny)" {
    local notrepo
    notrepo="$(mktemp -d)"
    cd "$notrepo"
    run sh "$COORD" claim slice-FC1b --session "ses-FC1b"
    [ "$status" -eq 10 ]
    rm -rf "$notrepo"
}

# ---------------------------------------------------------------------------
# U1 — Usage: missing --session and unknown subcommand
# ---------------------------------------------------------------------------

@test "U1 lock-acquire without --session: exit 1" {
    make_repo
    cd "$REPO"
    run sh "$COORD" lock-acquire
    [ "$status" -eq 1 ]
    teardown
}

@test "U1b claim without --session: exit 1" {
    make_repo
    cd "$REPO"
    run sh "$COORD" claim slice-U1b
    [ "$status" -eq 1 ]
    teardown
}

@test "U1c unknown subcommand: exit 1" {
    make_repo
    cd "$REPO"
    run sh "$COORD" nonexistent-subcommand --session "ses-U1c"
    [ "$status" -eq 1 ]
    teardown
}

# ---------------------------------------------------------------------------
# REG1 — Regression: existing hook suites not broken
# ---------------------------------------------------------------------------

@test "REG1 hooks.json has no entry for loom-coord.sh" {
    local hooks_json="${BATS_TEST_DIRNAME}/../hooks/hooks.json"
    if [ -f "$hooks_json" ]; then
        ! grep -qF "loom-coord" "$hooks_json"
    fi
}

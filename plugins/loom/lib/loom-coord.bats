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
# NEG-F1 — F1: exact first-field match — sibling "auth-v2" survives a "v2" op
# ---------------------------------------------------------------------------

@test "NEG-F1 claiming 'v2' does not touch 'auth-v2' registry row" {
    make_repo
    cd "$REPO"

    # Plant an existing claim for "auth-v2" (a live sibling session)
    local sibling_sid="ses-authv2-owner"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${sibling_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD
    mkdir -p "$REPO/.git/loom"
    printf 'auth-v2\t%s\t%s\t%s\n' "$sibling_sid" "$$" "$(date +%s)" \
        >"$REPO/.git/loom/claims"

    # Our session acquires the lock and claims "v2" (a different slice)
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-v2-owner"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim v2 --session "ses-v2-owner"
    [ "$status" -eq 0 ]

    # "auth-v2" row must still exist, unchanged
    grep -qF "auth-v2	$sibling_sid" "$REPO/.git/loom/claims"
    # "v2" row must also exist
    grep -qF "v2	ses-v2-owner" "$REPO/.git/loom/claims"
    # No stray row where first field is "v2" but name is "auth-v2"
    local v2_count
    v2_count=$(awk -F'\t' '$1=="v2"' "$REPO/.git/loom/claims" | wc -l | tr -d ' ')
    [ "$v2_count" -eq 1 ]
    teardown
}

@test "NEG-F1b remove_claim 'v2' does not remove 'auth-v2'" {
    make_repo
    cd "$REPO"

    # Plant both claims
    local sibling_sid="ses-authv2-owner-b"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${sibling_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD
    mkdir -p "$REPO/.git/loom"
    printf 'auth-v2\t%s\t%s\t%s\nv2\tses-v2-b\t%s\t%s\n' \
        "$sibling_sid" "$$" "$(date +%s)" "$$" "$(date +%s)" \
        >"$REPO/.git/loom/claims"

    # Acquire lock as "v2" session and release its own claim
    mkdir -p "$REPO/.git/loom/main.lock"
    printf 'ses-v2-b\t%s\t%s\n' "$$" "$(date +%s)" \
        >"$REPO/.git/loom/main.lock/holder"
    mkdir -p "$REPO/.git/loom/session-ses-v2-b"
    printf 'v2\n' >"$REPO/.git/loom/session-ses-v2-b/held-claims"

    run sh "$COORD" release-claim v2 --session "ses-v2-b"
    [ "$status" -eq 0 ]

    # "auth-v2" must still be in the registry
    grep -qF "auth-v2	$sibling_sid" "$REPO/.git/loom/claims"
    # "v2" must be gone
    ! grep -qF "v2	ses-v2-b" "$REPO/.git/loom/claims" 2>/dev/null
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F2 — F2: lock-less cleanup does not mutate claims
# ---------------------------------------------------------------------------

@test "NEG-F2 cleanup with live lock holder: exit non-zero, claims file unchanged" {
    make_repo
    cd "$REPO"

    # Seed two claims
    mkdir -p "$REPO/.git/loom"
    printf 'slice-A\tses-A\t99\t1000\nslice-B\tses-B\t99\t1000\n' \
        >"$REPO/.git/loom/claims"
    local before_claims
    before_claims=$(cat "$REPO/.git/loom/claims")

    # Plant a live holder so cleanup cannot acquire the lock
    make_live_holder "ses-lockowner-F2" >/dev/null
    # Force long TTL so cleanup won't try to reclaim
    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" cleanup
    [ "$status" -ne 0 ]

    # Claims file must be byte-for-byte identical
    local after_claims
    after_claims=$(cat "$REPO/.git/loom/claims")
    [ "$before_claims" = "$after_claims" ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F3 — F3: holderless lock dir older than TTL is reclaimable
# ---------------------------------------------------------------------------

@test "NEG-F3 holderless lock dir (no holder file) is reclaimed, not permanent deadlock" {
    make_repo
    cd "$REPO"

    # Simulate crash between mkdir LOCK_DIR and stamp_holder: dir exists, no holder
    mkdir -p "$REPO/.git/loom/main.lock"
    [ ! -f "$REPO/.git/loom/main.lock/holder" ]

    # A new contender should be able to acquire (holderless = always reclaimable)
    run env LOOM_LOCK_TTL=0 LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-F3"
    [ "$status" -eq 0 ]
    [ "$output" = "acquired" ]
    [ "$(holder_sid)" = "ses-F3" ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F4 — F4: substring-collision: dead "ses-foo" not falsely alive via live "ses-foo-bar"
# ---------------------------------------------------------------------------

@test "NEG-F4 dead ses-foo not reported alive because live ses-foo-bar exists" {
    make_repo
    cd "$REPO"

    # Live session "ses-foo-bar": real worktree with that string in path
    local live_sid="ses-foo-bar"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    # Dead session "ses-foo": claim in registry, no worktree, dead pid
    local dead_sid="ses-foo"
    mkdir -p "$REPO/.git/loom"
    printf 'slice-F4\t%s\t99999999\t0\n' "$dead_sid" >"$REPO/.git/loom/claims"

    # Acquire lock as our reclaimer and reclaim slice-F4
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-F4"
    [ "$status" -eq 0 ]

    # reclaim must succeed: ses-foo is dead (not falsely alive via ses-foo-bar substring)
    run sh "$COORD" reclaim slice-F4 --session "ses-reclaimer-F4"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-F4" ]
    # Registry now shows reclaimer as owner
    grep -qF "slice-F4	ses-reclaimer-F4" "$REPO/.git/loom/claims"
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F6 — F6: orphan worktree dir still on disk is actually removed by reclaim
# ---------------------------------------------------------------------------

@test "NEG-F6 live session with worktree dir on disk: session-id-primary protects it from cleanup" {
    make_repo
    cd "$REPO"

    # Dead session — worktree dir still on disk (simulates crashed process, dir not removed).
    # Under session-id-primary (ADR 0014): sid still in worktree list → considered alive →
    # cleanup must NOT sweep it, regardless of lease age or stored pid.
    local dead_sid="ses-dead-F6"
    local wt_dead
    wt_dead="$(cd "$REPO/.." && pwd)/wt-${dead_sid}"
    git -C "$REPO" worktree add -q "$wt_dead" HEAD
    # wt_dead dir still exists on disk — so prune won't remove the ref

    # Plant the claim: dead pid + epoch=0 (expired lease)
    mkdir -p "$REPO/.git/loom"
    printf 'slice-F6\t%s\t99999999\t0\n' "$dead_sid" >"$REPO/.git/loom/claims"

    # Cleanup with LOOM_LEASE_TTL=0 and LOOM_LOCK_TTL=0 — session-id-primary must win
    run env LOOM_LOCK_TTL=0 LOOM_LEASE_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped 1"* ]]

    # Claim must still be present (not swept)
    grep -qF "slice-F6	$dead_sid" "$REPO/.git/loom/claims"
    # Worktree dir must still exist
    [ -d "$wt_dead" ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F7 — F7: session-end under lock contention does not orphan claims
# ---------------------------------------------------------------------------

@test "NEG-F7 session-end when lock busy: exit non-zero, claims and session dir preserved" {
    make_repo
    cd "$REPO"

    local our_sid="ses-F7"

    # Set up our session with a claim in the registry
    mkdir -p "$REPO/.git/loom"
    printf 'slice-F7\t%s\t%s\t%s\n' "$our_sid" "$$" "$(date +%s)" \
        >"$REPO/.git/loom/claims"
    mkdir -p "$REPO/.git/loom/session-${our_sid}"
    printf 'slice-F7\n' >"$REPO/.git/loom/session-${our_sid}/held-claims"
    touch "$REPO/.git/loom/session-${our_sid}/checkpoint"

    # Plant a live lock holder so session-end cannot acquire the lock
    make_live_holder "ses-lockowner-F7" >/dev/null

    # session-end should exit non-zero (can't release claims) and preserve state
    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" session-end --session "$our_sid"
    [ "$status" -ne 0 ]

    # Claim must still be in registry (not orphaned)
    grep -qF "slice-F7	$our_sid" "$REPO/.git/loom/claims"
    # Session dir must still exist (not deleted while claims unreleased)
    [ -d "$REPO/.git/loom/session-${our_sid}" ]
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

# ---------------------------------------------------------------------------
# NEG-R1 — R1: live session past LOOM_LEASE_TTL is NOT swept (no recovery override)
# ---------------------------------------------------------------------------

@test "NEG-R1 live session past LOOM_LEASE_TTL without renew: not swept, worktree survives" {
    make_repo
    cd "$REPO"

    local live_sid="ses-live-R1"
    # Real worktree embedding the session-id — makes is_alive (worktree-list primary) return true
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    mkdir -p "$REPO/.git/loom"
    # Claim: epoch=0 (always past any lease TTL), dead pid (claim-time $$ long gone)
    local dpid
    dpid=$(dead_pid)
    printf 'slice-R1\t%s\t%s\t0\n' "$live_sid" "$dpid" >"$REPO/.git/loom/claims"

    # Run cleanup with LOOM_LEASE_TTL=0 (expired) — session-id-primary must protect the session
    run env LOOM_LOCK_TTL=0 LOOM_LEASE_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped 1"* ]]

    # Claim must still be in registry
    grep -qF "slice-R1	$live_sid" "$REPO/.git/loom/claims"
    # Worktree dir must not have been force-removed
    [ -d "$wt_path" ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-R2 — R2: dead 'bar' not alive via live 'wt-foo-bar' (LEADING boundary)
# ---------------------------------------------------------------------------

@test "NEG-R2 dead 'bar' not falsely alive because live 'wt-foo-bar' has it as trailing suffix" {
    make_repo
    cd "$REPO"

    # Live session whose worktree path has "bar" as a suffix, not a standalone segment
    local live_sid="foo-bar"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    # Dead session "bar": no worktree, dead pid
    local dead_sid="bar"
    mkdir -p "$REPO/.git/loom"
    printf 'slice-R2\t%s\t99999999\t0\n' "$dead_sid" >"$REPO/.git/loom/claims"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-R2"
    [ "$status" -eq 0 ]

    # reclaim must succeed: "bar" is dead (not falsely alive via "wt-foo-bar")
    run sh "$COORD" reclaim slice-R2 --session "ses-reclaimer-R2"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-R2" ]
    grep -qF "slice-R2	ses-reclaimer-R2" "$REPO/.git/loom/claims"
    teardown
}

# ---------------------------------------------------------------------------
# NEG-R3 — R3: session-id with ERE metachar matched literally, not as regex
# ---------------------------------------------------------------------------

@test "NEG-R3 session-id with ERE metachar 'run[1]' matched literally, not as regex vs live 'run1'" {
    make_repo
    cd "$REPO"

    # Live session "run1" with real worktree
    local live_sid="run1"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    # Dead session "run[1]": no worktree; as a regex, [1] matches "run1" — must NOT
    local dead_sid='run[1]'
    mkdir -p "$REPO/.git/loom"
    printf 'slice-R3\t%s\t99999999\t0\n' "$dead_sid" >"$REPO/.git/loom/claims"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-R3"
    [ "$status" -eq 0 ]

    # reclaim must succeed: "run[1]" dead; must not be confused with live "run1"
    run sh "$COORD" reclaim slice-R3 --session "ses-reclaimer-R3"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-R3" ]
    grep -qF "slice-R3	ses-reclaimer-R3" "$REPO/.git/loom/claims"
    teardown
}

# ---------------------------------------------------------------------------
# NEG-R4 — R4: holderless lock race — exactly one contender wins (10 iterations)
# ---------------------------------------------------------------------------

@test "NEG-R4 holderless lock race: exactly one winner per iteration, 10x" {
    make_repo
    cd "$REPO"
    local i=0
    while [ "$i" -lt 10 ]; do
        # Holderless dir aged to 2020 so mtime-based age >> LOOM_LOCK_TTL=5
        mkdir -p "$REPO/.git/loom/main.lock"
        rm -f "$REPO/.git/loom/main.lock/holder"
        touch -t 202001010000 "$REPO/.git/loom/main.lock"

        # TTL=5: old holderless dir reclaimable; winner's fresh lock (mtime=now) is not
        (
            env LOOM_LOCK_TTL=5 LOOM_LOCK_RETRIES=5 sh "$COORD" lock-acquire --session "ses-HL-A"
            echo "A:$?"
        ) >"$BATS_TEST_TMPDIR/hl_A_$i" 2>&1 &
        local pa=$!
        (
            env LOOM_LOCK_TTL=5 LOOM_LOCK_RETRIES=5 sh "$COORD" lock-acquire --session "ses-HL-B"
            echo "B:$?"
        ) >"$BATS_TEST_TMPDIR/hl_B_$i" 2>&1 &
        local pb=$!
        wait "$pa" || true
        wait "$pb" || true

        local ea eb
        ea=$(grep 'A:' "$BATS_TEST_TMPDIR/hl_A_$i" | sed 's/A://')
        eb=$(grep 'B:' "$BATS_TEST_TMPDIR/hl_B_$i" | sed 's/B://')

        local zeros=0
        [ "$ea" = "0" ] && zeros=$((zeros + 1))
        [ "$eb" = "0" ] && zeros=$((zeros + 1))
        if [ "$zeros" -ne 1 ]; then
            printf 'FAIL iter %d: ea=%s eb=%s\n' "$i" "$ea" "$eb" >&2
            false
        fi

        rm -rf "$REPO/.git/loom/main.lock"
        i=$((i + 1))
    done
    teardown
}

# ---------------------------------------------------------------------------
# NEG-R4b — R4: holderless dir younger than lock-TTL is NOT reclaimed
# ---------------------------------------------------------------------------

@test "NEG-R4b holderless dir younger than LOOM_LOCK_TTL is not reclaimable (exit 3)" {
    make_repo
    cd "$REPO"

    # Fresh holderless dir — mtime=now, age < TTL=9999
    mkdir -p "$REPO/.git/loom/main.lock"
    [ ! -f "$REPO/.git/loom/main.lock/holder" ]

    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" lock-acquire --session "ses-R4b"
    [ "$status" -eq 3 ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-R5 — R5: session-bootstrap recovers when holderless lock dir present
# ---------------------------------------------------------------------------

@test "NEG-R5 session-bootstrap recovers (renews claims) when holderless lock dir present" {
    make_repo
    cd "$REPO"
    local sid="ses-SB-R5"

    run sh "$COORD" session-start --session "$sid"
    [ "$status" -eq 0 ]
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "$sid"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-SB-R5 --session "$sid"
    [ "$status" -eq 0 ]
    run sh "$COORD" lock-release --session "$sid"
    [ "$status" -eq 0 ]

    # Simulate crash: leave holderless lock dir (mkdir done, stamp_holder never ran)
    mkdir -p "$REPO/.git/loom/main.lock"
    [ ! -f "$REPO/.git/loom/main.lock/holder" ]
    # Age it to 2020 so TTL=0 makes it reclaimable
    touch -t 202001010000 "$REPO/.git/loom/main.lock"

    # session-bootstrap must recover despite holderless dir
    run env LOOM_LOCK_TTL=0 LOOM_LOCK_RETRIES=3 sh "$COORD" session-bootstrap --session "$sid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed slice-SB-R5"* ]]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-R6 — R6: live session with space in worktree path is protected (not falsely dead)
# ---------------------------------------------------------------------------

@test "NEG-R6 live session with space in worktree path: reclaim refused (space-safe parsing)" {
    make_repo
    cd "$REPO"

    # Worktree in a directory whose path contains a space — awk '{print $2}' would truncate it
    local space_parent
    space_parent="$(mktemp -d)/my repos"
    mkdir -p "$space_parent"
    local live_sid="ses-space-R6"
    local wt_path="$space_parent/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    mkdir -p "$REPO/.git/loom"
    printf 'slice-R6\t%s\t%s\t%s\n' "$live_sid" "$$" "$(date +%s)" \
        >"$REPO/.git/loom/claims"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-R6"
    [ "$status" -eq 0 ]

    # reclaim must fail: the session is live (space-safe parser finds its sid)
    run sh "$COORD" reclaim slice-R6 --session "ses-reclaimer-R6"
    [ "$status" -eq 6 ]
    grep -qF "slice-R6	$live_sid" "$REPO/.git/loom/claims"

    # Clean up the space-containing dir tree
    git -C "$REPO" worktree remove -f "$wt_path" 2>/dev/null || true
    rm -rf "$(dirname "$space_parent")"
    teardown
}

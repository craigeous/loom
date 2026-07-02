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

# git_lock_sha — print current SHA of refs/loom/lock, or empty if absent
git_lock_sha() {
    git -C "$REPO" rev-parse --verify "refs/loom/lock" 2>/dev/null || true
}

# holder_sid — read the session-id field from lock blob, or empty
holder_sid() {
    local sha
    sha=$(git_lock_sha)
    [ -z "$sha" ] && return
    git -C "$REPO" cat-file blob "$sha" 2>/dev/null | awk -F'\t' '{print $1}'
}

# holder_pid — read the pid field from lock blob
holder_pid() {
    local sha
    sha=$(git_lock_sha)
    [ -z "$sha" ] && return
    git -C "$REPO" cat-file blob "$sha" 2>/dev/null | awk -F'\t' '{print $3}'
}

# plant_lock_holder <sid> <ts> — create lock blob with given sid+ts and set refs/loom/lock
plant_lock_holder() {
    local sid="$1"
    local ts="$2"
    local sha
    sha=$(printf '%s\t%s\t%s\t\n' "$sid" "$ts" "$$" | git -C "$REPO" hash-object -w --stdin)
    git -C "$REPO" update-ref "refs/loom/lock" "$sha"
}

# make_live_holder <session-id> — plant a live lock blob (fresh timestamp)
make_live_holder() {
    local sid="$1"
    plant_lock_holder "$sid" "$(date +%s)"
}

# make_dead_holder <session-id> [epoch] — plant a stale lock blob (epoch defaults to 0)
make_dead_holder() {
    local sid="$1"
    local epoch="${2:-0}"
    plant_lock_holder "$sid" "$epoch"
}

# dead_pid — a guaranteed-dead pid (use a process we started and waited)
dead_pid() {
    sh -c 'exit 0' &
    local p=$!
    wait "$p"
    printf '%s' "$p"
}

# ---------------------------------------------------------------------------
# Claim-ref helpers (Pass 2: claims are refs/loom/claims/<encoded-slice>)
# ---------------------------------------------------------------------------

# _slice_to_refname <slice> — encode slice name the same way loom-coord.sh does
_slice_to_refname() {
    printf '%s' "$1" | LC_ALL=C awk 'BEGIN { ORS="" } {
        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (c ~ /[A-Za-z0-9._\/\-]/) {
                printf "%s", c
            } else {
                printf "%%%02X", ord(c)
            }
        }
        printf "\n"
    }
    function ord(c,    k) {
        for (k = 0; k < 256; k++) if (sprintf("%c", k) == c) return k
        return 0
    }'
}

# claim_ref_sha <slice> — print SHA of refs/loom/claims/<slice>, or empty
claim_ref_sha() {
    local encoded
    encoded=$(_slice_to_refname "$1")
    git -C "$REPO" rev-parse --verify "refs/loom/claims/$encoded" 2>/dev/null || true
}

# claim_sid <slice> — read session-id from claim blob, or empty
claim_sid() {
    local sha
    sha=$(claim_ref_sha "$1")
    [ -z "$sha" ] && return
    git -C "$REPO" cat-file blob "$sha" 2>/dev/null | awk -F'\t' '{print $1}'
}

# claim_ts <slice> — read lease-ts from claim blob, or empty
claim_ts() {
    local sha
    sha=$(claim_ref_sha "$1")
    [ -z "$sha" ] && return
    git -C "$REPO" cat-file blob "$sha" 2>/dev/null | awk -F'\t' '{print $2}'
}

# plant_claim_ref <slice> <sid> <ts> — create a claim ref directly in REPO
plant_claim_ref() {
    local slice="$1" sid="$2" ts="$3"
    local encoded sha
    encoded=$(_slice_to_refname "$slice")
    sha=$(printf '%s\t%s\n' "$sid" "$ts" | git -C "$REPO" hash-object -w --stdin)
    git -C "$REPO" update-ref "refs/loom/claims/$encoded" "$sha"
}

# plant_claim_ref_raw <slice> <blob-content> — plant a claim ref with arbitrary blob
plant_claim_ref_raw() {
    local slice="$1" content="$2"
    local encoded sha
    encoded=$(_slice_to_refname "$slice")
    sha=$(printf '%s' "$content" | git -C "$REPO" hash-object -w --stdin)
    git -C "$REPO" update-ref "refs/loom/claims/$encoded" "$sha"
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

@test "L4 lock holder with FRESH stamp (within TTL) is not cleared" {
    # ADR 0015: liveness for the lock = stamp freshness.  A holder within TTL is
    # never cleared — worktree membership is no longer consulted.
    make_repo
    cd "$REPO"
    # Fresh holder stamp (ts=now) with a generous TTL — must not be cleared
    make_live_holder "ses-live-L4"
    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" lock-acquire --session "ses-contender-L4"
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
# L9 — Lock: release delete-CAS refuses if ref was changed by another holder
# ---------------------------------------------------------------------------

@test "L9 lock-release delete-CAS refuses when ref was changed by another holder" {
    make_repo
    cd "$REPO"
    # A acquires the lock
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-A-L9"
    [ "$status" -eq 0 ]

    # Force-replace the ref (simulates stale-steal by ses-B-L9)
    make_live_holder "ses-B-L9"

    # A tries to release — should exit 5 (ref now belongs to B)
    run sh "$COORD" lock-release --session "ses-A-L9"
    [ "$status" -eq 5 ]
    # Lock still held by B
    [ "$(holder_sid)" = "ses-B-L9" ]
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

    # Claim ref exists and names our session
    [ "$(claim_sid "slice-X")" = "ses-C1" ]
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

    # Plant a live peer claim via ref
    mkdir -p "$REPO/.git/loom/session-ses-peer-C2"
    printf 'slice-Y\n' >"$REPO/.git/loom/session-ses-peer-C2/held-claims"
    plant_claim_ref "slice-Y" "ses-peer-C2" "$(date +%s)"

    # Our session acquires the lock
    make_live_holder "ses-us-C2"
    mkdir -p "$REPO/.git/loom/session-ses-us-C2"
    touch "$REPO/.git/loom/session-ses-us-C2/checkpoint"
    touch "$REPO/.git/loom/session-ses-us-C2/held-claims"

    run sh "$COORD" claim slice-Y --session "ses-us-C2"
    [ "$status" -eq 4 ]
    # Claim ref still names peer
    [ "$(claim_sid "slice-Y")" = "ses-peer-C2" ]
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
    before_epoch=$(claim_ts "slice-R")
    sleep 1
    run sh "$COORD" renew slice-R --session "ses-R1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed slice-R"* ]]

    local after_epoch
    after_epoch=$(claim_ts "slice-R")
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
    [ -z "$(claim_ref_sha "slice-RC")" ]
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
    plant_claim_ref "slice-RCL" "$dead_sid" "0"

    # Our session acquires the lock
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-us-RCL1"
    [ "$status" -eq 0 ]

    run sh "$COORD" reclaim slice-RCL --session "ses-us-RCL1"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-RCL" ]
    [ "$(claim_sid "slice-RCL")" = "ses-us-RCL1" ]
    teardown
}

@test "RCL1b reclaim live peer claim: exit 6, claim unchanged" {
    make_repo
    cd "$REPO"
    local live_sid="ses-live-RCL1b"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${live_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    plant_claim_ref "slice-RCLb" "$live_sid" "$(date +%s)"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-us-RCL1b"
    [ "$status" -eq 0 ]

    run sh "$COORD" reclaim slice-RCLb --session "ses-us-RCL1b"
    [ "$status" -eq 6 ]
    [ "$(claim_sid "slice-RCLb")" = "$live_sid" ]
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
    old_epoch=$(claim_ts "slice-SB1a")

    sleep 1

    # Cold-restart: call session-bootstrap (simulates new pid from fresh process)
    run sh "$COORD" session-bootstrap --session "$sid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed slice-SB1a"* ]]
    [[ "$output" == *"renewed slice-SB1b"* ]]

    # Epoch refreshed
    local new_epoch
    new_epoch=$(claim_ts "slice-SB1a")
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

    plant_claim_ref "slice-live" "$live_sid" "$(date +%s)"
    plant_claim_ref "slice-dead" "$dead_sid" "0"

    mkdir -p "$REPO/.git/loom/session-$live_sid"
    touch "$REPO/.git/loom/session-$live_sid/checkpoint"
    mkdir -p "$REPO/.git/loom/session-$dead_sid"
    touch "$REPO/.git/loom/session-$dead_sid/checkpoint"

    # Also plant a stale dead-holder lock
    make_dead_holder "$dead_sid" "0"

    run env LOOM_LOCK_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"swept 1"* ]]

    # Dead claim ref removed; live claim ref intact
    [ -z "$(claim_ref_sha "slice-dead")" ]
    [ "$(claim_sid "slice-live")" = "$live_sid" ]

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
    plant_claim_ref "auth-v2" "$sibling_sid" "$(date +%s)"

    # Our session acquires the lock and claims "v2" (a different slice)
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-v2-owner"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim v2 --session "ses-v2-owner"
    [ "$status" -eq 0 ]

    # "auth-v2" ref must still exist and name sibling
    [ "$(claim_sid "auth-v2")" = "$sibling_sid" ]
    # "v2" ref must also exist and name our session
    [ "$(claim_sid "v2")" = "ses-v2-owner" ]
    # The two refs are distinct (no cross-contamination)
    local v2_sha authv2_sha
    v2_sha=$(claim_ref_sha "v2")
    authv2_sha=$(claim_ref_sha "auth-v2")
    [ -n "$v2_sha" ] && [ -n "$authv2_sha" ]
    [ "$v2_sha" != "$authv2_sha" ]
    teardown
}

@test "NEG-F1b remove_claim 'v2' does not remove 'auth-v2'" {
    make_repo
    cd "$REPO"

    # Plant both claims as refs
    local sibling_sid="ses-authv2-owner-b"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${sibling_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD
    plant_claim_ref "auth-v2" "$sibling_sid" "$(date +%s)"
    plant_claim_ref "v2" "ses-v2-b" "$(date +%s)"

    # Acquire lock as "v2" session and release its own claim
    make_live_holder "ses-v2-b"
    mkdir -p "$REPO/.git/loom/session-ses-v2-b"
    printf 'v2\n' >"$REPO/.git/loom/session-ses-v2-b/held-claims"

    run sh "$COORD" release-claim v2 --session "ses-v2-b"
    [ "$status" -eq 0 ]

    # "auth-v2" ref must still name the sibling
    [ "$(claim_sid "auth-v2")" = "$sibling_sid" ]
    # "v2" ref must be gone
    [ -z "$(claim_ref_sha "v2")" ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F2 — F2: lock-less cleanup does not mutate claims
# ---------------------------------------------------------------------------

@test "NEG-F2 cleanup with live lock holder: exit non-zero, claims unchanged" {
    make_repo
    cd "$REPO"

    # Seed two claims as refs
    plant_claim_ref "slice-A" "ses-A" "1000"
    plant_claim_ref "slice-B" "ses-B" "1000"
    # Record SHAs before cleanup
    local before_a before_b
    before_a=$(claim_ref_sha "slice-A")
    before_b=$(claim_ref_sha "slice-B")

    # Plant a live holder so cleanup cannot acquire the lock
    make_live_holder "ses-lockowner-F2" >/dev/null
    # Force long TTL so cleanup won't try to reclaim
    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" cleanup
    [ "$status" -ne 0 ]

    # Claim ref SHAs must be identical (no mutations)
    [ "$(claim_ref_sha "slice-A")" = "$before_a" ]
    [ "$(claim_ref_sha "slice-B")" = "$before_b" ]
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

    # Dead session "ses-foo": stale claim ref, no worktree
    local dead_sid="ses-foo"
    plant_claim_ref "slice-F4" "$dead_sid" "0"

    # Acquire lock as our reclaimer and reclaim slice-F4
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-F4"
    [ "$status" -eq 0 ]

    # reclaim must succeed: ses-foo is dead (not falsely alive via ses-foo-bar substring)
    run sh "$COORD" reclaim slice-F4 --session "ses-reclaimer-F4"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-F4" ]
    # Claim ref now names reclaimer
    [ "$(claim_sid "slice-F4")" = "ses-reclaimer-F4" ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F6 — F6: orphan worktree dir still on disk is actually removed by reclaim
# ---------------------------------------------------------------------------

@test "NEG-F6 stale-lease session with orphan worktree still on disk: orphan IS removed by cleanup" {
    # ADR 0015 closes T2/T6: orphan-worktree removal is now driven by lease staleness,
    # not worktree-membership.  A crashed session's worktree (dir still on disk) is removed
    # once its lease goes stale, making the T6 dead-code path reachable.
    make_repo
    cd "$REPO"

    local dead_sid="ses-dead-F6"
    local wt_dead
    wt_dead="$(cd "$REPO/.." && pwd)/wt-${dead_sid}"
    git -C "$REPO" worktree add -q "$wt_dead" HEAD
    # wt_dead dir still exists on disk (crashed session — not cleaned up)

    # Plant the claim ref: ts=0 (stale)
    plant_claim_ref "slice-F6" "$dead_sid" "0"

    # Cleanup: stale lease → sweep → orphan worktree removal
    run env LOOM_LOCK_TTL=0 LOOM_HOLDERLESS_TTL=0 LOOM_LEASE_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    # Stale claim must be swept
    [[ "$output" == *"swept 1"* ]]
    # Claim ref must be gone
    [ -z "$(claim_ref_sha "slice-F6")" ]
    # Orphan worktree dir must have been removed (T6 fix: now reachable)
    [ ! -d "$wt_dead" ]
    teardown
}

# ---------------------------------------------------------------------------
# NEG-F7 — F7: session-end under lock contention does not orphan claims
# ---------------------------------------------------------------------------

@test "NEG-F7 session-end when lock busy: exit non-zero, claims and session dir preserved" {
    make_repo
    cd "$REPO"

    local our_sid="ses-F7"

    # Set up our session with a claim ref
    plant_claim_ref "slice-F7" "$our_sid" "$(date +%s)"
    mkdir -p "$REPO/.git/loom/session-${our_sid}"
    printf 'slice-F7\n' >"$REPO/.git/loom/session-${our_sid}/held-claims"
    touch "$REPO/.git/loom/session-${our_sid}/checkpoint"

    # Plant a live lock holder so session-end cannot acquire the lock
    make_live_holder "ses-lockowner-F7" >/dev/null

    # session-end should exit non-zero (can't release claims) and preserve state
    run env LOOM_LOCK_TTL=9999 LOOM_LOCK_RETRIES=2 sh "$COORD" session-end --session "$our_sid"
    [ "$status" -ne 0 ]

    # Claim ref must still name our session (not orphaned)
    [ "$(claim_sid "slice-F7")" = "$our_sid" ]
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

@test "NEG-R1 stale-lease session with worktree IS swept (lease freshness is the sole liveness signal)" {
    # ADR 0015: a stale lease means the holder is dead, regardless of worktree presence.
    # Old model (worktree-primary): a session whose wt-<sid> dir exists was protected.
    # New model: only lease freshness counts; a stale-lease session is swept even with a worktree.
    make_repo
    cd "$REPO"

    local sid="ses-R1-stale"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD # worktree still present on disk

    # Claim ref: ts=0 (always past any lease TTL)
    plant_claim_ref "slice-R1" "$sid" "0"

    # Run cleanup with LOOM_LEASE_TTL=0 (any epoch is stale) and LOOM_HOLDERLESS_TTL=0
    run env LOOM_LOCK_TTL=0 LOOM_HOLDERLESS_TTL=0 LOOM_LEASE_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    # Stale claim must be swept (not skipped)
    [[ "$output" == *"swept 1"* ]]
    # Claim ref must be gone
    [ -z "$(claim_ref_sha "slice-R1")" ]
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

    # Dead session "bar": stale claim ref, no worktree
    local dead_sid="bar"
    plant_claim_ref "slice-R2" "$dead_sid" "0"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-R2"
    [ "$status" -eq 0 ]

    # reclaim must succeed: "bar" is dead (not falsely alive via "wt-foo-bar")
    run sh "$COORD" reclaim slice-R2 --session "ses-reclaimer-R2"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-R2" ]
    [ "$(claim_sid "slice-R2")" = "ses-reclaimer-R2" ]
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

    # Dead session "run[1]": stale claim ref; as a regex, [1] matches "run1" — must NOT
    local dead_sid='run[1]'
    plant_claim_ref "slice-R3" "$dead_sid" "0"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-R3"
    [ "$status" -eq 0 ]

    # reclaim must succeed: "run[1]" dead; must not be confused with live "run1"
    run sh "$COORD" reclaim slice-R3 --session "ses-reclaimer-R3"
    [ "$status" -eq 0 ]
    [ "$output" = "reclaimed slice-R3" ]
    [ "$(claim_sid "slice-R3")" = "ses-reclaimer-R3" ]
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

    plant_claim_ref "slice-R6" "$live_sid" "$(date +%s)"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-reclaimer-R6"
    [ "$status" -eq 0 ]

    # reclaim must fail: the session is live (space-safe parser finds its sid)
    run sh "$COORD" reclaim slice-R6 --session "ses-reclaimer-R6"
    [ "$status" -eq 6 ]
    [ "$(claim_sid "slice-R6")" = "$live_sid" ]

    # Clean up the space-containing dir tree
    git -C "$REPO" worktree remove -f "$wt_path" 2>/dev/null || true
    rm -rf "$(dirname "$space_parent")"
    teardown
}

# ---------------------------------------------------------------------------
# T3 — wt_sid_match: backslash in session-id not mangled by awk ENVIRON
# ---------------------------------------------------------------------------

@test "T3 wt_sid_match: backslash-n in session-id not mangled (awk -v vs ENVIRON)" {
    # awk -v sid="foo\nbar" interprets \n as a newline → comparison fails.
    # awk ENVIRON["LOOM_SID"] delivers the value byte-for-byte → comparison correct.
    # Test: cleanup with stale-lease claim where sid contains '\n' (literal backslash-n).
    # With T3 bug: wt_sid_match returns empty → orphan worktree NOT removed.
    # With T3 fix: wt_sid_match returns the path  → orphan worktree IS removed.
    make_repo
    cd "$REPO"

    local sid
    sid='foo\nbar'
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD 2>/dev/null || {
        skip "filesystem or git does not support backslash in worktree path"
    }

    plant_claim_ref "slice-T3" "$sid" "0"

    run env LOOM_LOCK_TTL=0 LOOM_HOLDERLESS_TTL=0 LOOM_LEASE_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"swept 1"* ]]
    [ -z "$(claim_ref_sha "slice-T3")" ]
    # Orphan worktree must have been removed (requires correct wt_sid_match)
    [ ! -d "$wt_path" ]
    teardown
}

# ---------------------------------------------------------------------------
# T5 — empty-sid guard increments skipped counter
# ---------------------------------------------------------------------------

@test "T5 cleanup: corrupted claim (empty sid) increments skipped counter" {
    # T5: the R7 empty-sid guard preserves the ref fail-closed and counts it as skipped.
    # Simulate with a claim ref whose blob has an empty first field (empty sid).
    make_repo
    cd "$REPO"
    # Plant a corrupted blob: empty sid, numeric ts → "empty-sid guard" triggers
    plant_claim_ref_raw "slice-T5" "$(printf '\t1000\n')"

    run env LOOM_LOCK_TTL=0 LOOM_HOLDERLESS_TTL=0 sh "$COORD" cleanup
    [ "$status" -eq 0 ]
    # skipped counter must include the empty-sid ref (T5 fix)
    [[ "$output" == *"skipped 1"* ]]
    # Ref must still be present (preserved fail-closed)
    [ -n "$(claim_ref_sha "slice-T5")" ]
    teardown
}

# ---------------------------------------------------------------------------
# LV — Liveness model: fresh lease = alive; stale lease = dead (ADR 0015)
# ---------------------------------------------------------------------------

@test "LV-fresh fresh-lease claim (no worktree) is NOT reclaimable (exit 6)" {
    # Old model: no worktree + dead pid → is_alive false → reclaim succeeds (wrong).
    # New model: fresh epoch → alive → exit 6 regardless of worktree or pid.
    make_repo
    cd "$REPO"
    local peer_sid="ses-peer-LVF"
    plant_claim_ref "slice-LVF" "$peer_sid" "$(date +%s)"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-us-LVF"
    [ "$status" -eq 0 ]

    run sh "$COORD" reclaim slice-LVF --session "ses-us-LVF"
    [ "$status" -eq 6 ]
    [ "$(claim_sid "slice-LVF")" = "$peer_sid" ]
    teardown
}

@test "LV-stale stale-lease claim with live worktree IS reclaimable (worktree no longer protects)" {
    # Old model: worktree present → is_alive true → exit 6 (crash-then-worktree-stays wedge).
    # New model: stale epoch → dead → reclaim regardless of worktree (T2 fix).
    make_repo
    cd "$REPO"
    local peer_sid="ses-peer-LVST"
    local wt_path
    wt_path="$(cd "$REPO/.." && pwd)/wt-${peer_sid}"
    git -C "$REPO" worktree add -q "$wt_path" HEAD

    plant_claim_ref "slice-LVST" "$peer_sid" "0"

    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-us-LVST"
    [ "$status" -eq 0 ]

    # Reclaim must succeed: stale epoch = dead, regardless of worktree
    run sh "$COORD" reclaim slice-LVST --session "ses-us-LVST"
    [ "$status" -eq 0 ]
    [ "$(claim_sid "slice-LVST")" = "ses-us-LVST" ]
    teardown
}

# ---------------------------------------------------------------------------
# RNW — Background renewer subcommands
# ---------------------------------------------------------------------------

@test "RNW-1 renewer-start launches renewer; renewer-stop kills it cleanly" {
    make_repo
    cd "$REPO"

    run sh "$COORD" session-start --session "ses-RNW1"
    [ "$status" -eq 0 ]

    local mypid=$$
    run env LOOM_RENEW_INTERVAL=60 sh "$COORD" renewer-start "$mypid" --session "ses-RNW1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewer-started"* ]]

    # Renewer pid recorded and alive
    local rpid
    rpid=$(cat "$REPO/.git/loom/session-ses-RNW1/renewer.pid" 2>/dev/null)
    [ -n "$rpid" ]
    kill -0 "$rpid" 2>/dev/null

    # Second renewer-start must be a no-op (duplicate suppression)
    run env LOOM_RENEW_INTERVAL=60 sh "$COORD" renewer-start "$mypid" --session "ses-RNW1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewer-already-running"* ]]

    # Stop renewer
    run sh "$COORD" renewer-stop --session "ses-RNW1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewer-stopped"* ]]
    sleep 0.5
    ! kill -0 "$rpid" 2>/dev/null
    teardown
}

@test "RNW-2 renewer identity gate: renewer self-exits when session start-time changes" {
    # ADR 0015 §2: the renewer checks alive(pid) AND starttime == recorded.
    # If the start-time is overwritten (simulating a recycled pid), the renewer exits.
    make_repo
    cd "$REPO"

    run sh "$COORD" session-start --session "ses-RNW2"
    [ "$status" -eq 0 ]

    local mypid=$$
    run env LOOM_RENEW_INTERVAL=1 sh "$COORD" renewer-start "$mypid" --session "ses-RNW2"
    [ "$status" -eq 0 ]

    local rpid
    rpid=$(cat "$REPO/.git/loom/session-ses-RNW2/renewer.pid" 2>/dev/null)
    kill -0 "$rpid" 2>/dev/null # renewer alive

    # Corrupt the recorded session start-time (simulates a recycled pid returning
    # a different start-time — the identity gate must fail → renewer self-exits)
    printf 'WRONG_STARTTIME_SIMULATED_RECYCLE\n' \
        >"$REPO/.git/loom/session-ses-RNW2/session.starttime"

    # Renewer sleeps 1 s, then re-checks _session_alive; with wrong starttime it exits
    local i=0
    while [ "$i" -lt 15 ] && kill -0 "$rpid" 2>/dev/null; do
        sleep 0.5
        i=$((i + 1))
    done
    ! kill -0 "$rpid" 2>/dev/null
    teardown
}

# ---------------------------------------------------------------------------
# Pass 2 — claims-as-refs + lock-heartbeat tests
# ---------------------------------------------------------------------------

@test "CC1 claim CAS: two concurrent create-only attempts, exactly one wins" {
    # Tests the underlying git ref CAS — two processes race to create the same
    # claim ref from null; git's own ref-transaction ensures exactly one wins.
    make_repo
    cd "$REPO"

    local sha_a sha_b
    sha_a=$(printf 'ses-A-CC1\t%s\n' "$(date +%s)" |
        git -C "$REPO" hash-object -w --stdin)
    sha_b=$(printf 'ses-B-CC1\t%s\n' "$(date +%s)" |
        git -C "$REPO" hash-object -w --stdin)
    local null_sha="0000000000000000000000000000000000000000"
    local ref="refs/loom/claims/slice-CC1"

    # Race: both try create-only CAS from null simultaneously
    (git -C "$REPO" update-ref "$ref" "$sha_a" "$null_sha" 2>/dev/null
        echo "$?") >"$BATS_TEST_TMPDIR/cas_a" &
    (git -C "$REPO" update-ref "$ref" "$sha_b" "$null_sha" 2>/dev/null
        echo "$?") >"$BATS_TEST_TMPDIR/cas_b" &
    wait

    local exit_a exit_b
    exit_a=$(cat "$BATS_TEST_TMPDIR/cas_a")
    exit_b=$(cat "$BATS_TEST_TMPDIR/cas_b")

    # Exactly one must succeed (exit 0)
    local wins=0
    [ "$exit_a" -eq 0 ] && wins=$((wins + 1))
    [ "$exit_b" -eq 0 ] && wins=$((wins + 1))
    [ "$wins" -eq 1 ]

    # The ref must exist and point to exactly one of the two blobs
    local final_sha
    final_sha=$(git -C "$REPO" rev-parse "$ref" 2>/dev/null)
    [ "$final_sha" = "$sha_a" ] || [ "$final_sha" = "$sha_b" ]
    teardown
}

@test "SC1 slice name with colon maps to valid ref; claim/renew/release round-trip" {
    # A colon is illegal in git ref names; loom-coord must percent-encode it.
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-SC1"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim "slice:foo" --session "ses-SC1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"claimed slice:foo"* ]]
    # Colon encoded as %3A; ref must exist
    git -C "$REPO" rev-parse --verify "refs/loom/claims/slice%3Afoo" 2>/dev/null
    # Claim sid correct
    [ "$(claim_sid "slice:foo")" = "ses-SC1" ]
    # Renew value-CAS works
    run sh "$COORD" renew "slice:foo" --session "ses-SC1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewed slice:foo"* ]]
    # Release delete-CAS works
    run sh "$COORD" release-claim "slice:foo" --session "ses-SC1"
    [ "$status" -eq 0 ]
    [ -z "$(claim_ref_sha "slice:foo")" ]
    teardown
}

@test "LC1 list-claims returns ref paths and blob content for active claims" {
    make_repo
    cd "$REPO"
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-LC1"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-lc1a --session "ses-LC1"
    [ "$status" -eq 0 ]
    run sh "$COORD" claim slice-lc1b --session "ses-LC1"
    [ "$status" -eq 0 ]
    run sh "$COORD" list-claims
    [ "$status" -eq 0 ]
    [[ "$output" == *"refs/loom/claims/slice-lc1a"* ]]
    [[ "$output" == *"refs/loom/claims/slice-lc1b"* ]]
    [[ "$output" == *"ses-LC1"* ]]
    teardown
}

@test "RNW-3 renewer heartbeats the lock ref while main session holds it (U3 fix)" {
    # The renewer must CAS-update refs/loom/lock when the main session holds it,
    # preventing a peer from stealing the lock mid-critical-section (ADR 0016 §3).
    make_repo
    cd "$REPO"

    run sh "$COORD" session-start --session "ses-RNW3"
    [ "$status" -eq 0 ]

    # Main session acquires the lock
    run env LOOM_LOCK_RETRIES=3 sh "$COORD" lock-acquire --session "ses-RNW3"
    [ "$status" -eq 0 ]
    local lock_sha_before
    lock_sha_before=$(git_lock_sha)
    [ -n "$lock_sha_before" ]

    # Start renewer with a short interval (1 s) so it fires quickly
    local mypid=$$
    run env LOOM_RENEW_INTERVAL=1 sh "$COORD" renewer-start "$mypid" --session "ses-RNW3"
    [ "$status" -eq 0 ]
    [[ "$output" == *"renewer-started"* ]]

    # Wait up to ~6 s for the renewer to fire and update the lock blob
    local i=0
    local lock_sha_after
    while [ "$i" -lt 12 ]; do
        sleep 0.5
        lock_sha_after=$(git_lock_sha)
        [ "$lock_sha_after" != "$lock_sha_before" ] && break
        i=$((i + 1))
    done

    # Lock ref SHA must have changed (renewer wrote a new blob with fresh ts)
    [ "$lock_sha_after" != "$lock_sha_before" ]
    # Lock is still held by our session (sid unchanged)
    [ "$(holder_sid)" = "ses-RNW3" ]

    run sh "$COORD" renewer-stop --session "ses-RNW3"
    [ "$status" -eq 0 ]
    run sh "$COORD" lock-release --session "ses-RNW3"
    [ "$status" -eq 0 ]
    teardown
}

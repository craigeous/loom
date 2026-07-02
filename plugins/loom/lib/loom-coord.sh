#!/bin/sh
# shellcheck disable=SC3043  # local is supported by all real sh implementations
# loom-coord.sh — Multi-session lock/claim coordination helper (ADR 0014)
#
# Hand-invoked CLI helper (NOT a hook — not registered in hooks.json).
# Serializes N independent /loom:run sessions writing to the shared main
# checkout through a cross-session mkdir lock and a slice-lease protocol.
#
# FAIL DIRECTION: fail-closed (opposite of the guard hooks).
#   The guard hooks fail-open (false block > missed guard).
#   A coordination helper must fail-closed: on any tooling/parse ambiguity
#   it denies — never grants a lock or claim it cannot prove is safe —
#   because a falsely-granted lock or double-granted claim corrupts main.
#   Every error branch exits non-zero; exit 0 means "provably safe".
#
# State paths (all under <git-dir>/loom/, untracked, per-repo):
#   $STATE_DIR/main.lock/           — lock dir (mkdir atomic)
#   $STATE_DIR/main.lock/holder     — <session-id>\t<pid>\t<epoch>
#   $STATE_DIR/claims               — TSV: <slice>\t<session-id>\t<pid>\t<epoch>
#   $STATE_DIR/session-<id>/        — per-session dir
#   $STATE_DIR/session-<id>/checkpoint    — write-ahead next action
#   $STATE_DIR/session-<id>/held-claims   — one slice name per line
#   $STATE_DIR/session-<id>/session.pid   — stable session process pid
#   $STATE_DIR/session-<id>/session.starttime — session process start-time
#   $STATE_DIR/session-<id>/renewer.pid   — background renewer pid
#   $STATE_DIR/session-<id>/renewer.starttime — renewer start-time
#   $STATE_DIR/.main.lock.reclaiming.<session-id>.<pid>.<epoch>  — CAS cap dir
#
# Exit codes:
#   0  — success
#   1  — usage / missing-argument error
#   3  — lock busy (backoff exhausted)
#   4  — claim taken by a live peer (caller must abort + re-select)
#   5  — precondition violation (lock not held by self / claim not owned by self)
#   6  — reclaim refused (target holder still alive)
#   10 — fail-closed: tooling/parse ambiguity (git unavailable, not a repo,
#         unreadable state) — deny

# ---------------------------------------------------------------------------
# Tunable parameters (overridable via env)
# ---------------------------------------------------------------------------
LOOM_LOCK_TTL="${LOOM_LOCK_TTL:-30}"
LOOM_LEASE_TTL="${LOOM_LEASE_TTL:-3600}"
LOOM_LOCK_RETRIES="${LOOM_LOCK_RETRIES:-5}"
LOOM_RENEW_INTERVAL="${LOOM_RENEW_INTERVAL:-1200}"
# LOOM_HOLDERLESS_TTL — age-gate for a holderless lock dir (no holder file).
# Defaults to 2 s — short enough that reclaim fits within the ~6 s backoff
# budget, long enough to cover the non-atomic mkdir→stamp_holder window.
# Set to 0 (or equal to LOOM_LOCK_TTL when LOOM_LOCK_TTL=0) to make any
# holderless dir immediately reclaimable (used by tests).
LOOM_HOLDERLESS_TTL="${LOOM_HOLDERLESS_TTL:-2}"

# ---------------------------------------------------------------------------
# Arg parsing — subcommand and --session
# ---------------------------------------------------------------------------
SUBCOMMAND=""
SESSION_ID="${LOOM_SESSION_ID:-}"
EXTRA_ARGS=""

if [ $# -eq 0 ]; then
    printf 'loom-coord: no subcommand given\n' >&2
    exit 1
fi

SUBCOMMAND="$1"
shift

# Parse remaining args for --session and positional
while [ $# -gt 0 ]; do
    case "$1" in
    --session)
        if [ $# -lt 2 ]; then
            printf 'loom-coord: --session requires a value\n' >&2
            exit 1
        fi
        SESSION_ID="$2"
        shift 2
        ;;
    --session=*)
        SESSION_ID="${1#--session=}"
        shift
        ;;
    *)
        if [ -z "$EXTRA_ARGS" ]; then
            EXTRA_ARGS="$1"
        else
            EXTRA_ARGS="$EXTRA_ARGS $1"
        fi
        shift
        ;;
    esac
done

# ---------------------------------------------------------------------------
# State resolution — fail-closed on any git error
# ---------------------------------------------------------------------------
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    printf 'loom-coord: not a git repo or git unavailable\n' >&2
    exit 10
fi

GITDIR=$(git -C "$REPO_ROOT" rev-parse --git-dir 2>/dev/null)
if [ -z "$GITDIR" ]; then
    printf 'loom-coord: cannot resolve git-dir\n' >&2
    exit 10
fi
case "$GITDIR" in
/*) ;;
*) GITDIR="$REPO_ROOT/$GITDIR" ;;
esac

STATE_DIR="$GITDIR/loom"
LOCK_DIR="$STATE_DIR/main.lock"
HOLDER_FILE="$LOCK_DIR/holder"
CLAIMS="$STATE_DIR/claims"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

now() {
    date +%s 2>/dev/null
}

# dir_mtime_epoch <dir> — print directory mtime as epoch seconds; empty on failure.
# Feature-detects GNU stat (-c %Y) first so Linux/dash works; falls back to
# BSD stat (-f %m).  BSD-first order was T1: on GNU/Linux `stat -f` outputs a
# multi-line filesystem block to stdout AND exits 1, so the `||` appended the
# real mtime to that garbage, causing integer-parse failures.
dir_mtime_epoch() {
    local _mt
    _mt=$(stat -c %Y "$1" 2>/dev/null) && {
        printf '%s\n' "$_mt"
        return 0
    }
    stat -f %m "$1" 2>/dev/null
}

# process_starttime <pid> — print the start-time of a process; empty on failure.
# Portable: tries Linux /proc/<pid>/stat (field 22, jiffies since boot — stable,
# locale-independent) first; falls back to BSD/macOS `ps -o lstart=`.
process_starttime() {
    local _pid="$1"
    local _f="/proc/$_pid/stat"
    if [ -f "$_f" ]; then
        awk '{print $22}' "$_f" 2>/dev/null
        return
    fi
    ps -o lstart= -p "$_pid" 2>/dev/null
}

# wt_sid_match <sid> — read git worktree list --porcelain from stdin;
# print the first worktree path whose LAST PATH SEGMENT equals "wt-<sid>".
# Uses awk ENVIRON (not -v) to avoid escape-sequence processing: awk -v applies
# backslash escape processing to the value, so a session-id like "foo\nbar"
# becomes "foo<newline>bar" and never matches the literal last segment (T3 fix).
# ENVIRON delivers the value byte-for-byte with no interpretation.
wt_sid_match() {
    local sid="$1"
    [ -z "$sid" ] && return
    LOOM_SID="$sid" awk '
        BEGIN { sid = ENVIRON["LOOM_SID"] }
        /^worktree / {
            path = substr($0, 10)
            n = split(path, parts, "/")
            if (parts[n] == "wt-" sid) { print path; exit }
        }
    '
}

# claim_is_fresh <epoch> — returns 0 (alive/fresh) if the claim epoch is within
# LOOM_LEASE_TTL of now.  This is the SOLE liveness signal for claims (ADR 0015):
# worktree-list membership and the process pid are NOT liveness gates.
claim_is_fresh() {
    local _epoch="$1"
    local _now
    _now=$(now)
    [ $((_now - _epoch)) -lt "$LOOM_LEASE_TTL" ]
}

# _session_alive <sess_dir> — returns 0 if the recorded session process is alive
# under the reuse-robust identity gate: pid alive AND start-time still matches.
# Used by the background renewer as its loop condition.
_session_alive() {
    local _sd="$1" _spid _sst _cur_st
    _spid=$(cat "$_sd/session.pid" 2>/dev/null) || return 1
    [ -z "$_spid" ] && return 1
    _sst=$(cat "$_sd/session.starttime" 2>/dev/null) || return 1
    kill -0 "$_spid" 2>/dev/null || return 1
    _cur_st=$(process_starttime "$_spid")
    [ "$_cur_st" = "$_sst" ]
}

# _renewer_alive <sess_dir> — returns 0 if the recorded renewer process is alive
# under the reuse-robust identity gate.  Used for duplicate-suppression in
# renewer-start.
_renewer_alive() {
    local _sd="$1" _rpid _rst _cur_st
    _rpid=$(cat "$_sd/renewer.pid" 2>/dev/null) || return 1
    [ -z "$_rpid" ] && return 1
    _rst=$(cat "$_sd/renewer.starttime" 2>/dev/null) || return 1
    kill -0 "$_rpid" 2>/dev/null || return 1
    _cur_st=$(process_starttime "$_rpid")
    [ "$_cur_st" = "$_rst" ]
}

# lock_held_by_self — exits 0 if $SESSION_ID currently holds the lock
lock_held_by_self() {
    if [ ! -f "$HOLDER_FILE" ]; then
        return 1
    fi
    local h_sid
    h_sid=$(awk -F'\t' '{print $1}' "$HOLDER_FILE" 2>/dev/null)
    [ "$h_sid" = "$SESSION_ID" ]
}

# read_holder — prints holder stamp or empty; returns 1 if unreadable
read_holder() {
    if [ ! -f "$HOLDER_FILE" ]; then
        printf ''
        return 1
    fi
    cat "$HOLDER_FILE" 2>/dev/null
}

# stamp_holder — write <SESSION_ID>\t<pid>\t<epoch> to holder
stamp_holder() {
    printf '%s\t%s\t%s\n' "$SESSION_ID" "$$" "$(now)" >"$HOLDER_FILE"
}

# backoff_sleep <attempt>  (0-indexed; 0.2 0.4 0.8 1.6 3.2)
backoff_sleep() {
    local attempt="$1"
    # Use bc for fractional sleep; fall back to integer ceiling
    local frac
    case "$attempt" in
    0) frac="0.2" ;;
    1) frac="0.4" ;;
    2) frac="0.8" ;;
    3) frac="1.6" ;;
    *) frac="3.2" ;;
    esac
    if sleep "$frac" 2>/dev/null; then
        return 0
    fi
    # integer fallback: ceiling of frac
    case "$attempt" in
    0 | 1) sleep 1 ;;
    2) sleep 1 ;;
    3) sleep 2 ;;
    *) sleep 4 ;;
    esac
}

# read_claim <slice> — prints the TSV line for slice, or empty
# Uses exact first-field match (awk) to avoid substring collisions (e.g. "v2" != "auth-v2")
read_claim() {
    local slice="$1"
    if [ ! -f "$CLAIMS" ]; then
        printf ''
        return 0
    fi
    awk -F'\t' -v s="$slice" '$1==s' "$CLAIMS" 2>/dev/null | head -1
}

# write_claim <slice> <session-id> <pid> <epoch> — atomic TSV upsert
write_claim() {
    local slice="$1" sid="$2" pid="$3" epoch="$4"
    mkdir -p "$STATE_DIR"
    local tmp
    tmp="${CLAIMS}.tmp.$$"
    if [ -f "$CLAIMS" ]; then
        awk -F'\t' -v s="$slice" '$1!=s' "$CLAIMS" 2>/dev/null >"$tmp" || true
    else
        : >"$tmp"
    fi
    printf '%s\t%s\t%s\t%s\n' "$slice" "$sid" "$pid" "$epoch" >>"$tmp"
    mv "$tmp" "$CLAIMS"
}

# remove_claim <slice> — remove TSV line for slice
remove_claim() {
    local slice="$1"
    if [ ! -f "$CLAIMS" ]; then
        return 0
    fi
    local tmp
    tmp="${CLAIMS}.tmp.$$"
    awk -F'\t' -v s="$slice" '$1!=s' "$CLAIMS" 2>/dev/null >"$tmp" || true
    mv "$tmp" "$CLAIMS"
}

# held_claims_file — path to the session's held-claims file
held_claims_file() {
    printf '%s/session-%s/held-claims' "$STATE_DIR" "$SESSION_ID"
}

# add_held_claim <slice>
add_held_claim() {
    local slice="$1"
    local hcf
    hcf=$(held_claims_file)
    mkdir -p "${STATE_DIR}/session-${SESSION_ID}" 2>/dev/null || true
    if ! grep -qxF "$slice" "$hcf" 2>/dev/null; then
        printf '%s\n' "$slice" >>"$hcf"
    fi
}

# remove_held_claim <slice>
remove_held_claim() {
    local slice="$1"
    local hcf
    hcf=$(held_claims_file)
    if [ ! -f "$hcf" ]; then
        return 0
    fi
    local tmp
    tmp="${hcf}.tmp.$$"
    grep -vxF "$slice" "$hcf" 2>/dev/null >"$tmp" || true
    mv "$tmp" "$hcf"
}

# assert_session — exit 1 if SESSION_ID is empty
assert_session() {
    if [ -z "$SESSION_ID" ]; then
        printf 'loom-coord %s: --session <id> required (or LOOM_SESSION_ID)\n' "$SUBCOMMAND" >&2
        exit 1
    fi
}

# try_acquire_holderless — single-source holderless-lock reclaim (T7).
# Called when LOCK_DIR exists but HOLDER_FILE does not.
# Uses LOOM_HOLDERLESS_TTL (not LOOM_LOCK_TTL) so reclaim fits within the ~6 s
# backoff budget; LOOM_LOCK_TTL=0 tests set LOOM_HOLDERLESS_TTL=0 implicitly via
# the default formula or explicitly to keep NEG-F3/NEG-R5 working.
# Returns 0 on successful acquisition via clear_and_own; 1 otherwise.
try_acquire_holderless() {
    local _h_mt _h_age
    _h_mt=$(dir_mtime_epoch "$LOCK_DIR")
    if [ -n "$_h_mt" ]; then
        _h_age=$(($(now) - _h_mt))
        if [ "$_h_age" -ge "$LOOM_HOLDERLESS_TTL" ] && clear_and_own; then
            return 0
        fi
    fi
    return 1
}

# assert_lock_held — exit 5 if caller does not hold the lock
assert_lock_held() {
    if ! lock_held_by_self; then
        printf 'loom-coord %s: precondition failed — lock not held by session %s\n' "$SUBCOMMAND" "$SESSION_ID" >&2
        exit 5
    fi
}

# ---------------------------------------------------------------------------
# Atomic clear-and-own (rename-capture CAS) for stale lock reclaim
# Returns 0 on successful ownership, 1 if lost the race (caller back-off)
# ---------------------------------------------------------------------------
clear_and_own() {
    # Read the observed holder stamp — may be empty for a holderless lock dir
    # (crash between mkdir LOCK_DIR and stamp_holder leaves no holder file).
    # The caller has already verified that a stamped holder is stale (elapsed >= TTL);
    # we do NOT re-check is_alive here — under ADR 0015 the liveness gate for
    # locks is stamp freshness, and the ABA check below is the correctness guard.
    local h_obs
    h_obs=$(cat "$HOLDER_FILE" 2>/dev/null) || h_obs=""

    local cap_epoch
    cap_epoch=$(now)
    local CAP
    CAP="${STATE_DIR}/.main.lock.reclaiming.${SESSION_ID}.$$.${cap_epoch}"

    # Attempt atomic rename (only one concurrent mv of $LOCK_DIR can win)
    if ! mv "$LOCK_DIR" "$CAP" 2>/dev/null; then
        # Lost the rename race — another contender captured it
        return 1
    fi

    # ABA check: verify the captured dir still holds the stamp we observed.
    # If h_obs was empty (holderless), cap_stamp must also be empty; a non-empty
    # cap_stamp means a live peer stamped the dir in the window.
    local cap_stamp
    cap_stamp=$(cat "$CAP/holder" 2>/dev/null) || cap_stamp=""

    if [ "$cap_stamp" != "$h_obs" ]; then
        # ABA: stamp changed — another contender reclaimed and re-stamped; restore
        if [ ! -d "$LOCK_DIR" ]; then
            mv "$CAP" "$LOCK_DIR" 2>/dev/null || rm -rf "$CAP"
        else
            rm -rf "$CAP"
        fi
        return 1
    fi

    # Captured a genuinely stale dir — destroy it and seize with mkdir
    rm -rf "$CAP"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # A peer re-created the lock between our rm and mkdir — lost
        return 1
    fi

    # Own it
    stamp_holder
    # Confirm holder == self (INV-1)
    local confirm
    confirm=$(awk -F'\t' '{print $1}' "$HOLDER_FILE" 2>/dev/null)
    if [ "$confirm" != "$SESSION_ID" ]; then
        rm -rf "$LOCK_DIR"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Subcommand: lock-acquire
# ---------------------------------------------------------------------------
cmd_lock_acquire() {
    assert_session
    mkdir -p "$STATE_DIR"

    local attempt=0
    while true; do
        # Try atomic mkdir
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            stamp_holder
            # Confirm INV-1
            local confirm
            confirm=$(awk -F'\t' '{print $1}' "$HOLDER_FILE" 2>/dev/null)
            if [ "$confirm" != "$SESSION_ID" ]; then
                rm -rf "$LOCK_DIR"
                printf 'loom-coord lock-acquire: holder confirm failed\n' >&2
                exit 10
            fi
            printf 'acquired\n'
            exit 0
        fi

        # Lock exists — check if stale (ADR 0015: liveness = stamp freshness for lock)
        if [ -f "$HOLDER_FILE" ]; then
            local h_epoch cur_epoch elapsed
            h_epoch=$(awk -F'\t' '{print $3}' "$HOLDER_FILE" 2>/dev/null)
            cur_epoch=$(now)
            elapsed=$((cur_epoch - h_epoch))

            if [ "$elapsed" -ge "$LOOM_LOCK_TTL" ]; then
                # Stamp stale (holder crashed) — attempt CAS clear-and-own
                if clear_and_own; then
                    printf 'acquired\n'
                    exit 0
                fi
                # Lost the CAS race — fall through to backoff
            fi
        elif [ -d "$LOCK_DIR" ]; then
            # Holderless lock dir (crash between mkdir and stamp_holder).
            # Use LOOM_HOLDERLESS_TTL (short, fits within backoff budget) — T4 fix.
            if try_acquire_holderless; then
                printf 'acquired\n'
                exit 0
            fi
        fi

        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$LOOM_LOCK_RETRIES" ]; then
            printf 'loom-coord lock-acquire: lock busy after %d retries\n' "$LOOM_LOCK_RETRIES" >&2
            exit 3
        fi
        backoff_sleep "$((attempt - 1))"
    done
}

# ---------------------------------------------------------------------------
# Subcommand: lock-release
# ---------------------------------------------------------------------------
cmd_lock_release() {
    assert_session
    if ! lock_held_by_self; then
        printf 'loom-coord lock-release: lock not held by session %s\n' "$SESSION_ID" >&2
        exit 5
    fi
    rm -rf "$LOCK_DIR"
}

# ---------------------------------------------------------------------------
# Subcommand: lock-holder
# ---------------------------------------------------------------------------
cmd_lock_holder() {
    if [ -f "$HOLDER_FILE" ]; then
        cat "$HOLDER_FILE" 2>/dev/null
    fi
}

# ---------------------------------------------------------------------------
# Subcommand: lock-verify
# ---------------------------------------------------------------------------
cmd_lock_verify() {
    assert_session
    if [ ! -f "$HOLDER_FILE" ]; then
        printf 'loom-coord lock-verify: no lock held\n' >&2
        exit 5
    fi
    local h_sid
    if ! h_sid=$(awk -F'\t' '{print $1}' "$HOLDER_FILE" 2>/dev/null) || [ -z "$h_sid" ]; then
        printf 'loom-coord lock-verify: cannot read holder\n' >&2
        exit 10
    fi
    if [ "$h_sid" = "$SESSION_ID" ]; then
        printf 'held\n'
        exit 0
    fi
    printf 'loom-coord lock-verify: lock held by %s, not %s\n' "$h_sid" "$SESSION_ID" >&2
    exit 5
}

# ---------------------------------------------------------------------------
# Subcommand: claim <slice>
# ---------------------------------------------------------------------------
cmd_claim() {
    assert_session
    assert_lock_held
    local slice="$EXTRA_ARGS"
    if [ -z "$slice" ]; then
        printf 'loom-coord claim: slice name required\n' >&2
        exit 1
    fi

    mkdir -p "$STATE_DIR"
    # Re-read registry under the held lock (check-then-act)
    local line sid pid epoch cur
    line=$(read_claim "$slice")
    cur=$(now)

    if [ -n "$line" ]; then
        sid=$(printf '%s' "$line" | awk -F'\t' '{print $2}')
        epoch=$(printf '%s' "$line" | awk -F'\t' '{print $4}')

        if [ "$sid" = "$SESSION_ID" ]; then
            # Own claim — idempotent re-affirm
            printf 'claimed %s %s %s\n' "$slice" "$SESSION_ID" "$epoch"
            exit 0
        fi

        # Another session's claim — liveness = lease freshness (ADR 0015)
        if claim_is_fresh "$epoch"; then
            printf 'loom-coord claim: slice %s has live claim by %s\n' "$slice" "$sid" >&2
            exit 4
        fi

        # Stale claim — overwrite
    fi

    write_claim "$slice" "$SESSION_ID" "$$" "$cur"
    add_held_claim "$slice"
    printf 'claimed %s %s %s\n' "$slice" "$SESSION_ID" "$cur"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: renew <slice>
# ---------------------------------------------------------------------------
cmd_renew() {
    assert_session
    assert_lock_held
    local slice="$EXTRA_ARGS"
    if [ -z "$slice" ]; then
        printf 'loom-coord renew: slice name required\n' >&2
        exit 1
    fi

    local line sid
    line=$(read_claim "$slice")
    if [ -z "$line" ]; then
        printf 'loom-coord renew: no claim found for %s\n' "$slice" >&2
        exit 5
    fi
    sid=$(printf '%s' "$line" | awk -F'\t' '{print $2}')
    if [ "$sid" != "$SESSION_ID" ]; then
        printf 'loom-coord renew: slice %s not owned by %s\n' "$slice" "$SESSION_ID" >&2
        exit 5
    fi

    local cur
    cur=$(now)
    write_claim "$slice" "$SESSION_ID" "$$" "$cur"
    printf 'renewed %s %s\n' "$slice" "$cur"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: release-claim <slice>
# ---------------------------------------------------------------------------
cmd_release_claim() {
    assert_session
    assert_lock_held
    local slice="$EXTRA_ARGS"
    if [ -z "$slice" ]; then
        printf 'loom-coord release-claim: slice name required\n' >&2
        exit 1
    fi

    local line sid
    line=$(read_claim "$slice")
    if [ -n "$line" ]; then
        sid=$(printf '%s' "$line" | awk -F'\t' '{print $2}')
        if [ "$sid" != "$SESSION_ID" ]; then
            printf 'loom-coord release-claim: slice %s not owned by %s\n' "$slice" "$SESSION_ID" >&2
            exit 5
        fi
    fi
    remove_claim "$slice"
    remove_held_claim "$slice"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: reclaim <slice>
# ---------------------------------------------------------------------------
cmd_reclaim() {
    assert_session
    assert_lock_held
    local slice="$EXTRA_ARGS"
    if [ -z "$slice" ]; then
        printf 'loom-coord reclaim: slice name required\n' >&2
        exit 1
    fi

    local line sid epoch
    line=$(read_claim "$slice")
    if [ -z "$line" ]; then
        printf 'loom-coord reclaim: no claim found for %s\n' "$slice" >&2
        exit 5
    fi
    sid=$(printf '%s' "$line" | awk -F'\t' '{print $2}')
    epoch=$(printf '%s' "$line" | awk -F'\t' '{print $4}')

    if [ "$sid" = "$SESSION_ID" ]; then
        # Own claim — nothing to reclaim
        printf 'loom-coord reclaim: already owner of %s\n' "$slice" >&2
        exit 5
    fi

    # Liveness = lease freshness (ADR 0015): a fresh lease means holder is alive.
    # Worktree-list membership and pid are NOT liveness signals.
    if claim_is_fresh "$epoch"; then
        printf 'loom-coord reclaim: holder %s of %s still has a fresh lease\n' "$sid" "$slice" >&2
        exit 6
    fi

    # Stale lease (holder crashed/stopped) — prune orphan worktree, overwrite claim.
    # wt_sid_match is used here for ORPHAN REMOVAL targeting only (not liveness).
    git -C "$REPO_ROOT" worktree prune 2>/dev/null || true
    local wt_path
    wt_path=$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | wt_sid_match "$sid")
    if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
        git -C "$REPO_ROOT" worktree remove -f "$wt_path" 2>/dev/null || true
    fi

    local cur
    cur=$(now)
    write_claim "$slice" "$SESSION_ID" "$$" "$cur"
    add_held_claim "$slice"
    printf 'reclaimed %s\n' "$slice"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: list-claims
# ---------------------------------------------------------------------------
cmd_list_claims() {
    if [ -f "$CLAIMS" ]; then
        cat "$CLAIMS"
    fi
}

# ---------------------------------------------------------------------------
# Subcommand: session-start
# ---------------------------------------------------------------------------
cmd_session_start() {
    # Mint uuid if --session not supplied
    if [ -z "$SESSION_ID" ]; then
        if command -v uuidgen >/dev/null 2>&1; then
            SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
        else
            SESSION_ID=$(od -An -N16 -tx1 /dev/urandom 2>/dev/null |
                tr -d ' \n' |
                sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
            if [ -z "$SESSION_ID" ]; then
                printf 'loom-coord session-start: cannot mint uuid\n' >&2
                exit 10
            fi
        fi
    fi

    local sess_dir
    sess_dir="$STATE_DIR/session-$SESSION_ID"
    mkdir -p "$sess_dir"
    # Idempotent — only create files if absent
    if [ ! -f "$sess_dir/checkpoint" ]; then
        : >"$sess_dir/checkpoint"
    fi
    if [ ! -f "$sess_dir/held-claims" ]; then
        : >"$sess_dir/held-claims"
    fi
    printf '%s\n' "$SESSION_ID"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: checkpoint-write
# ---------------------------------------------------------------------------
cmd_checkpoint_write() {
    assert_session
    local sess_dir="$STATE_DIR/session-$SESSION_ID"
    if [ ! -d "$sess_dir" ]; then
        printf 'loom-coord checkpoint-write: session %s not started\n' "$SESSION_ID" >&2
        exit 5
    fi
    if [ -n "$EXTRA_ARGS" ]; then
        printf '%s\n' "$EXTRA_ARGS" >"$sess_dir/checkpoint"
    else
        cat >"$sess_dir/checkpoint"
    fi
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: checkpoint-read
# ---------------------------------------------------------------------------
cmd_checkpoint_read() {
    assert_session
    local sess_dir="$STATE_DIR/session-$SESSION_ID"
    if [ -f "$sess_dir/checkpoint" ]; then
        cat "$sess_dir/checkpoint"
    fi
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: session-bootstrap (cold-restart re-adoption, self-locking)
# ---------------------------------------------------------------------------
cmd_session_bootstrap() {
    assert_session
    local sess_dir="$STATE_DIR/session-$SESSION_ID"
    if [ ! -d "$sess_dir" ]; then
        printf 'loom-coord session-bootstrap: session %s not found\n' "$SESSION_ID" >&2
        exit 5
    fi

    # Acquire lock to renew claims (inline acquire loop — no exit, returns 0/1;
    # nested function definition avoided to stay shellcheck-clean per prior round).
    local _sb_got_lock=0
    local _sb_attempt=0
    mkdir -p "$STATE_DIR"
    while true; do
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            stamp_holder
            local _sb_confirm
            _sb_confirm=$(awk -F'\t' '{print $1}' "$HOLDER_FILE" 2>/dev/null)
            if [ "$_sb_confirm" != "$SESSION_ID" ]; then
                rm -rf "$LOCK_DIR"
            else
                _sb_got_lock=1
            fi
            break
        fi
        if [ -f "$HOLDER_FILE" ]; then
            local _sb_h_epoch _sb_elapsed _sb_cur_epoch
            _sb_h_epoch=$(awk -F'\t' '{print $3}' "$HOLDER_FILE" 2>/dev/null)
            _sb_cur_epoch=$(now)
            _sb_elapsed=$((_sb_cur_epoch - _sb_h_epoch))
            if [ "$_sb_elapsed" -ge "$LOOM_LOCK_TTL" ] && clear_and_own; then
                _sb_got_lock=1
                break
            fi
        elif [ -d "$LOCK_DIR" ]; then
            if try_acquire_holderless; then
                _sb_got_lock=1
                break
            fi
        fi
        _sb_attempt=$((_sb_attempt + 1))
        if [ "$_sb_attempt" -ge "$LOOM_LOCK_RETRIES" ]; then
            break
        fi
        backoff_sleep "$((_sb_attempt - 1))"
    done

    if [ "$_sb_got_lock" -ne 1 ]; then
        printf 'loom-coord session-bootstrap: could not acquire lock\n' >&2
        exit 3
    fi

    # Renew each held claim
    local hcf="$sess_dir/held-claims"
    if [ -f "$hcf" ]; then
        while IFS= read -r slice; do
            [ -z "$slice" ] && continue
            local line sid
            line=$(read_claim "$slice")
            if [ -n "$line" ]; then
                sid=$(printf '%s' "$line" | awk -F'\t' '{print $2}')
                if [ "$sid" = "$SESSION_ID" ]; then
                    local cur
                    cur=$(now)
                    write_claim "$slice" "$SESSION_ID" "$$" "$cur"
                    printf 'renewed %s %s\n' "$slice" "$cur"
                fi
            fi
        done <"$hcf"
    fi

    rm -rf "$LOCK_DIR"

    # Print checkpoint
    local chk="$sess_dir/checkpoint"
    if [ -f "$chk" ]; then
        printf 'checkpoint: '
        cat "$chk"
    fi
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: session-end
# ---------------------------------------------------------------------------
cmd_session_end() {
    assert_session
    local sess_dir="$STATE_DIR/session-$SESSION_ID"

    # Release any still-held claims (self-locking).
    # IMPORTANT: do NOT rm -rf the session dir when got_lock=0 — that would orphan
    # claim registry rows (no held-claims backref → permanent double-grant risk).
    if [ -f "$sess_dir/held-claims" ]; then
        local attempt=0
        local got_lock=0
        mkdir -p "$STATE_DIR"
        while [ "$attempt" -lt "$LOOM_LOCK_RETRIES" ]; do
            if mkdir "$LOCK_DIR" 2>/dev/null; then
                stamp_holder
                got_lock=1
                break
            fi
            # Stale-lock handling: if the lock is past TTL and held by a dead session,
            # reclaim it so session-end can release our claims properly.
            if [ -f "$HOLDER_FILE" ]; then
                local h_epoch elapsed cur_epoch
                h_epoch=$(awk -F'\t' '{print $3}' "$HOLDER_FILE" 2>/dev/null)
                cur_epoch=$(now)
                elapsed=$((cur_epoch - h_epoch))
                if [ "$elapsed" -ge "$LOOM_LOCK_TTL" ] && clear_and_own; then
                    got_lock=1
                    break
                fi
            elif [ -d "$LOCK_DIR" ]; then
                if try_acquire_holderless; then
                    got_lock=1
                    break
                fi
            fi
            attempt=$((attempt + 1))
            backoff_sleep "$((attempt - 1))"
        done

        if [ "$got_lock" -eq 1 ]; then
            while IFS= read -r slice; do
                [ -z "$slice" ] && continue
                local line sid
                line=$(read_claim "$slice")
                if [ -n "$line" ]; then
                    sid=$(printf '%s' "$line" | awk -F'\t' '{print $2}')
                    if [ "$sid" = "$SESSION_ID" ]; then
                        remove_claim "$slice"
                    fi
                fi
            done <"$sess_dir/held-claims"
            rm -rf "$LOCK_DIR"
            # Only remove session dir after claims have been released
            rm -rf "$sess_dir"
        else
            printf 'loom-coord session-end: could not acquire lock; claims not released\n' >&2
            exit 3
        fi
    else
        # No held-claims file — safe to remove the session dir directly
        rm -rf "$sess_dir"
    fi
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: cleanup (self-locking sweep)
# ---------------------------------------------------------------------------
cmd_cleanup() {
    mkdir -p "$STATE_DIR"

    # Prune stale worktree refs
    git -C "$REPO_ROOT" worktree prune 2>/dev/null || true

    # Acquire lock (with stale-lock and holderless handling)
    local attempt=0
    local got_lock=0
    local cleanup_sid="${SESSION_ID:-cleanup-$$}"
    while [ "$attempt" -lt "$LOOM_LOCK_RETRIES" ]; do
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            if [ -n "$SESSION_ID" ]; then
                stamp_holder
            else
                printf '%s\t0\t%s\n' "$cleanup_sid" "$(now)" >"$HOLDER_FILE"
            fi
            got_lock=1
            break
        fi
        # Check if stale (holder stamp too old) or holderless
        if [ -f "$HOLDER_FILE" ]; then
            local h_epoch elapsed cur_epoch
            h_epoch=$(awk -F'\t' '{print $3}' "$HOLDER_FILE" 2>/dev/null)
            cur_epoch=$(now)
            elapsed=$((cur_epoch - h_epoch))
            if [ "$elapsed" -ge "$LOOM_LOCK_TTL" ]; then
                if SESSION_ID="$cleanup_sid" clear_and_own; then
                    got_lock=1
                    break
                fi
            fi
        elif [ -d "$LOCK_DIR" ]; then
            if SESSION_ID="$cleanup_sid" try_acquire_holderless; then
                got_lock=1
                break
            fi
        fi
        attempt=$((attempt + 1))
        backoff_sleep "$((attempt - 1))"
    done

    local swept=0
    local skipped=0

    # CLAIMS mutation MUST be under the lock (F2: mutual exclusion on shared store)
    if [ "$got_lock" -eq 1 ]; then
        if [ -f "$CLAIMS" ]; then
            local tmp
            tmp="${CLAIMS}.tmp.$$"
            : >"$tmp"
            # Hoist worktree list once for the entire sweep (for orphan-removal lookups only)
            local wt_list
            wt_list=$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null)
            while IFS='	' read -r slice sid pid epoch; do
                [ -z "$slice" ] && continue
                # R7: empty-sid guard — preserve row fail-closed (can't assess liveness).
                # T5 fix: count as skipped so the summary is accurate.
                if [ -z "$sid" ]; then
                    printf '%s\t%s\t%s\t%s\n' "$slice" "$sid" "$pid" "$epoch" >>"$tmp"
                    skipped=$((skipped + 1))
                    continue
                fi
                # Liveness = lease freshness (ADR 0015): worktree-list membership and
                # the stored pid are NOT liveness signals; a fresh epoch means alive.
                if claim_is_fresh "$epoch"; then
                    printf '%s\t%s\t%s\t%s\n' "$slice" "$sid" "$pid" "$epoch" >>"$tmp"
                    skipped=$((skipped + 1))
                else
                    # Stale lease — holder crashed/stopped.  Orphan-worktree removal is
                    # now reachable (T2/T6 fix): driven by lease staleness, not membership.
                    local wt_path
                    wt_path=$(printf '%s\n' "$wt_list" | wt_sid_match "$sid")
                    if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
                        git -C "$REPO_ROOT" worktree remove -f "$wt_path" 2>/dev/null || true
                    fi
                    # Remove dead session dir
                    if [ -d "$STATE_DIR/session-$sid" ]; then
                        rm -rf "$STATE_DIR/session-$sid"
                    fi
                    swept=$((swept + 1))
                fi
            done <"$CLAIMS"
            mv "$tmp" "$CLAIMS"
        fi
        rm -rf "$LOCK_DIR"
    else
        # Could not acquire lock — refuse to mutate shared state (fail-closed)
        printf 'loom-coord cleanup: could not acquire lock; claims sweep skipped\n' >&2
        # Sweep orphaned CAP dirs (safe — they are ours, no lock needed)
        for cap_dir in "$STATE_DIR"/.main.lock.reclaiming.*; do
            [ -d "$cap_dir" ] || continue
            rm -rf "$cap_dir"
        done
        exit 3
    fi

    # Sweep orphaned CAP dirs
    for cap_dir in "$STATE_DIR"/.main.lock.reclaiming.*; do
        [ -d "$cap_dir" ] || continue
        rm -rf "$cap_dir"
    done

    printf 'swept %d dead claims; skipped %d live claims\n' "$swept" "$skipped"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: renewer-start <session-pid>
# ---------------------------------------------------------------------------
cmd_renewer_start() {
    assert_session
    local sess_dir="$STATE_DIR/session-$SESSION_ID"
    if [ ! -d "$sess_dir" ]; then
        printf 'loom-coord renewer-start: session %s not found\n' "$SESSION_ID" >&2
        exit 5
    fi

    local spid="$EXTRA_ARGS"
    if [ -z "$spid" ]; then
        printf 'loom-coord renewer-start: <session-pid> required\n' >&2
        exit 1
    fi

    # Capture reuse-robust identity of the stable session process (ADR 0015 §2)
    local sst
    sst=$(process_starttime "$spid")
    if [ -z "$sst" ]; then
        printf 'loom-coord renewer-start: cannot read start-time for pid %s\n' "$spid" >&2
        exit 10
    fi
    printf '%s\n' "$spid" >"$sess_dir/session.pid"
    printf '%s\n' "$sst" >"$sess_dir/session.starttime"

    # Check-then-launch: do not start a second renewer (duplicate suppression)
    if _renewer_alive "$sess_dir"; then
        printf 'renewer-already-running\n'
        exit 0
    fi

    # Resolve absolute path to this script for the renewer's lock-acquire callbacks
    local _coord
    _coord="$(cd "$(dirname -- "$0")" 2>/dev/null && pwd)/$(basename -- "$0")"

    # Capture locals needed inside the detached subshell
    local _sid="$SESSION_ID"
    local _sdir="$sess_dir"
    local _interval="$LOOM_RENEW_INTERVAL"
    local _root="$REPO_ROOT"

    # Launch detached background renewer.  Uses _session_alive (inherited function)
    # with the reuse-robust identity gate: exits when session pid dies or start-time
    # changes (recycled pid).  Renews held claims under the lock on each interval.
    # stdin/stdout/stderr are closed (redirected to /dev/null) so the subshell does
    # not hold inherited file descriptors open — prevents callers that capture output
    # (e.g. bats `run`) from hanging.
    (
        cd "$_root" 2>/dev/null || exit 1
        while _session_alive "$_sdir"; do
            _hcf="$_sdir/held-claims"
            if [ -f "$_hcf" ] && grep -q . "$_hcf" 2>/dev/null; then
                if sh "$_coord" lock-acquire --session "$_sid" >/dev/null 2>&1; then
                    while IFS= read -r _s; do
                        [ -z "$_s" ] && continue
                        sh "$_coord" renew "$_s" --session "$_sid" >/dev/null 2>&1 || true
                    done <"$_hcf"
                    sh "$_coord" lock-release --session "$_sid" >/dev/null 2>&1 || true
                fi
            fi
            sleep "$_interval" 2>/dev/null || true
        done
    ) </dev/null >/dev/null 2>&1 &
    local rpid=$!
    local rst
    rst=$(process_starttime "$rpid")
    printf '%s\n' "$rpid" >"$sess_dir/renewer.pid"
    if [ -n "$rst" ]; then
        printf '%s\n' "$rst" >"$sess_dir/renewer.starttime"
    fi
    printf 'renewer-started pid=%s\n' "$rpid"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: renewer-stop
# ---------------------------------------------------------------------------
cmd_renewer_stop() {
    assert_session
    local sess_dir="$STATE_DIR/session-$SESSION_ID"
    if [ ! -d "$sess_dir" ]; then
        printf 'loom-coord renewer-stop: session %s not found\n' "$SESSION_ID" >&2
        exit 5
    fi

    local rpid rst cur_st
    rpid=$(cat "$sess_dir/renewer.pid" 2>/dev/null) || rpid=""
    if [ -z "$rpid" ]; then
        printf 'no-renewer\n'
        exit 0
    fi
    rst=$(cat "$sess_dir/renewer.starttime" 2>/dev/null) || rst=""

    # Only kill if the recorded renewer pid is still the one we started (identity gate)
    if kill -0 "$rpid" 2>/dev/null; then
        if [ -z "$rst" ]; then
            kill "$rpid" 2>/dev/null || true
        else
            cur_st=$(process_starttime "$rpid")
            if [ "$cur_st" = "$rst" ]; then
                kill "$rpid" 2>/dev/null || true
            fi
        fi
    fi
    rm -f "$sess_dir/renewer.pid" "$sess_dir/renewer.starttime"
    printf 'renewer-stopped\n'
    exit 0
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "$SUBCOMMAND" in
lock-acquire) cmd_lock_acquire ;;
lock-release) cmd_lock_release ;;
lock-holder) cmd_lock_holder ;;
lock-verify) cmd_lock_verify ;;
claim) cmd_claim ;;
renew) cmd_renew ;;
release-claim) cmd_release_claim ;;
reclaim) cmd_reclaim ;;
list-claims) cmd_list_claims ;;
session-start) cmd_session_start ;;
checkpoint-write) cmd_checkpoint_write ;;
checkpoint-read) cmd_checkpoint_read ;;
session-bootstrap) cmd_session_bootstrap ;;
session-end) cmd_session_end ;;
cleanup) cmd_cleanup ;;
renewer-start) cmd_renewer_start ;;
renewer-stop) cmd_renewer_stop ;;
*)
    printf 'loom-coord: unknown subcommand: %s\n' "$SUBCOMMAND" >&2
    exit 1
    ;;
esac

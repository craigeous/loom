#!/bin/sh
# shellcheck disable=SC3043  # local is supported by all real sh implementations
# loom-coord.sh — Multi-session lock/claim coordination helper (ADR 0014)
#
# Hand-invoked CLI helper (NOT a hook — not registered in hooks.json).
# Serializes N independent /loom:run sessions writing to the shared main
# checkout through a git-CAS lock (refs/loom/lock) and a slice-lease protocol.
#
# FAIL DIRECTION: fail-closed (opposite of the guard hooks).
#   The guard hooks fail-open (false block > missed guard).
#   A coordination helper must fail-closed: on any tooling/parse ambiguity
#   it denies — never grants a lock or claim it cannot prove is safe —
#   because a falsely-granted lock or double-granted claim corrupts main.
#   Every error branch exits non-zero; exit 0 means "provably safe".
#
# State paths:
#   refs/loom/lock                  — git ref (git-CAS lock; blob = {sid}\t{ts}\t{pid}\t\n)
#   refs/loom/claims/<slice>        — git ref per slice (blob = {sid}\t{ts}\n)
#   $STATE_DIR/session-<id>/        — per-session dir
#   $STATE_DIR/session-<id>/checkpoint    — write-ahead next action
#   $STATE_DIR/session-<id>/held-claims   — one slice name per line
#   $STATE_DIR/session-<id>/session.pid   — stable session process pid
#   $STATE_DIR/session-<id>/session.starttime — session process start-time
#   $STATE_DIR/session-<id>/renewer.pid   — background renewer pid
#   $STATE_DIR/session-<id>/renewer.starttime — renewer start-time
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
# Lock-heartbeat cadence (V1 fix): must be strictly < LOOM_LOCK_TTL (~TTL/3).
# Default derived from LOOM_LOCK_TTL; override with LOOM_LOCK_RENEW_INTERVAL.
_default_lri=$((LOOM_LOCK_TTL / 3))
[ "$_default_lri" -lt 1 ] && _default_lri=1
LOOM_LOCK_RENEW_INTERVAL="${LOOM_LOCK_RENEW_INTERVAL:-$_default_lri}"

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
LOCK_REF="refs/loom/lock"
CLAIMS_REF_PREFIX="refs/loom/claims"
NULL_SHA="0000000000000000000000000000000000000000"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

now() {
    date +%s 2>/dev/null
}

# read_lock_sha — print current SHA of refs/loom/lock, or empty if absent
read_lock_sha() {
    git -C "$REPO_ROOT" rev-parse --verify "$LOCK_REF" 2>/dev/null || true
}

# decode_lock_field <sha> <field-number> — read lock blob and print the Nth tab field
decode_lock_field() {
    local _sha="$1" _field="$2"
    git -C "$REPO_ROOT" cat-file blob "$_sha" 2>/dev/null |
        awk -F'\t' -v f="$_field" '{print $f}'
}

# _make_blob_for <sid> — write {sid}\t{ts}\t{pid}\t\n blob; print SHA or empty on failure
_make_blob_for() {
    local _msid="$1"
    printf '%s\t%s\t%s\t\n' "$_msid" "$(now)" "$$" |
        git -C "$REPO_ROOT" hash-object -w --stdin 2>/dev/null
}

# process_starttime <pid> — print the start-time of a process; empty on failure.
# Portable: tries Linux /proc/<pid>/stat (field 22, jiffies since boot — stable,
# locale-independent) first; falls back to BSD/macOS `ps -o lstart=`.
#
# Field 22 MUST be located by splitting on the LAST ')' because the comm field
# (field 2) is wrapped in parens and may itself contain spaces or ')' (e.g.
# "(a b) c)" is a legal comm).  Naïve `awk '{print $22}'` gives the wrong field
# in that case.  After the last ')', the fields are:
#   state(1) ppid(2) pgrp(3) session(4) tty_nr(5) tpgid(6) flags(7) minflt(8)
#   cminflt(9) majflt(10) cmajflt(11) utime(12) stime(13) cutime(14) cstime(15)
#   priority(16) nice(17) num_threads(18) itrealvalue(19) starttime(20)
process_starttime() {
    local _pid="$1"
    local _f="/proc/$_pid/stat"
    if [ -f "$_f" ]; then
        awk '{
            last = 0
            for (i = 1; i <= length($0); i++) {
                if (substr($0, i, 1) == ")") last = i
            }
            if (last == 0) next
            rest = substr($0, last + 2)
            n = split(rest, a, " ")
            if (n >= 20) print a[20]
        }' "$_f" 2>/dev/null
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
# Fail-closed (U2): empty or non-numeric epoch is UNPARSEABLE → treat as FRESH
# (live). Never classify an unreadable lease as stale — that would allow reclaim
# of a live holder whose epoch write was partial or corrupt.
claim_is_fresh() {
    local _epoch="$1"
    local _now
    case "$_epoch" in
    '' | *[!0-9]*) return 0 ;;
    esac
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

# lock_held_by_self — exits 0 if $SESSION_ID currently holds refs/loom/lock
lock_held_by_self() {
    local _sha _sid
    _sha=$(read_lock_sha)
    [ -z "$_sha" ] && return 1
    _sid=$(decode_lock_field "$_sha" 1)
    [ "$_sid" = "$SESSION_ID" ]
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

# slice_to_refname <slice> — map a slice name to a safe git ref path component.
# Uses git hash-object (SHA-1 of the slice bytes, no store) so the result always
# passes git check-ref-format regardless of the slice name (V5 fix: handles
# ".lock", "..", leading/trailing "."/"/", "@{", etc.) and is case-sensitive by
# construction (SHA-1 is byte-exact), solving case-fold collisions on APFS (V6).
# The original slice name is stored as field 3 of the claim blob.
slice_to_refname() {
    printf '%s' "$1" | git -C "$REPO_ROOT" hash-object --stdin 2>/dev/null
}

# claim_ref_for <slice> — full ref path for a slice claim
claim_ref_for() {
    printf '%s/%s' "$CLAIMS_REF_PREFIX" "$(slice_to_refname "$1")"
}

# _make_claim_blob_for <sid> <slice> — write {sid}\t{ts}\t{slice}\n blob; print SHA or empty.
# Field 3 (slice) lets list-claims recover the original slice name from the hash-keyed ref.
_make_claim_blob_for() {
    local _csid="$1" _cslice="$2"
    printf '%s\t%s\t%s\n' "$_csid" "$(now)" "$_cslice" |
        git -C "$REPO_ROOT" hash-object -w --stdin 2>/dev/null
}

# read_claim_sha <slice> — print current SHA of refs/loom/claims/<slice>, or empty
read_claim_sha() {
    local _ref
    _ref=$(claim_ref_for "$1")
    git -C "$REPO_ROOT" rev-parse --verify "$_ref" 2>/dev/null || true
}

# decode_claim_field <sha> <field-number> — read claim blob and print Nth tab field
decode_claim_field() {
    local _sha="$1" _field="$2"
    git -C "$REPO_ROOT" cat-file blob "$_sha" 2>/dev/null |
        awk -F'\t' -v f="$_field" '{print $f}'
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

# assert_lock_held — exit 5 if caller does not hold the lock
assert_lock_held() {
    if ! lock_held_by_self; then
        printf 'loom-coord %s: precondition failed — lock not held by session %s\n' "$SUBCOMMAND" "$SESSION_ID" >&2
        exit 5
    fi
}

# ---------------------------------------------------------------------------
# Subcommand: lock-acquire
# ---------------------------------------------------------------------------
cmd_lock_acquire() {
    assert_session

    local attempt=0
    while true; do
        # Try create-only CAS: succeeds only if refs/loom/lock is absent
        local new_sha
        new_sha=$(_make_blob_for "$SESSION_ID")
        if [ -z "$new_sha" ]; then
            printf 'loom-coord lock-acquire: cannot create holder blob\n' >&2
            exit 10
        fi
        if git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$new_sha" "$NULL_SHA" 2>/dev/null; then
            printf 'acquired\n'
            exit 0
        fi

        # Lock ref exists — check if stale (ADR 0015: liveness = ts freshness)
        local cur_sha
        cur_sha=$(read_lock_sha)
        if [ -n "$cur_sha" ]; then
            local h_ts
            h_ts=$(decode_lock_field "$cur_sha" 2)
            case "$h_ts" in
            '' | *[!0-9]*)
                # Non-numeric ts → treat as fresh (fail-closed); fall through
                ;;
            *)
                local cur_epoch elapsed
                cur_epoch=$(now)
                elapsed=$((cur_epoch - h_ts))
                if [ "$elapsed" -ge "$LOOM_LOCK_TTL" ]; then
                    # Stale — attempt value-CAS steal (ABA-safe: old-value = exact read SHA)
                    new_sha=$(_make_blob_for "$SESSION_ID")
                    if [ -n "$new_sha" ] &&
                        git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$new_sha" "$cur_sha" 2>/dev/null; then
                        printf 'acquired\n'
                        exit 0
                    fi
                    # Lost CAS race — fall through to backoff
                fi
                ;;
            esac
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
    # Re-read current SHA (renewer may have updated the blob's ts since acquire)
    local cur_sha
    cur_sha=$(read_lock_sha)
    if [ -z "$cur_sha" ]; then
        printf 'loom-coord lock-release: lock not held by session %s\n' "$SESSION_ID" >&2
        exit 5
    fi
    local h_sid
    h_sid=$(decode_lock_field "$cur_sha" 1)
    if [ "$h_sid" != "$SESSION_ID" ]; then
        printf 'loom-coord lock-release: lock not held by session %s\n' "$SESSION_ID" >&2
        exit 5
    fi
    # Delete-CAS with retry while sid==self (V4 fix): the session's own renewer may
    # value-CAS-update the lock blob (keeping sid=self, bumping ts) between our read
    # and the delete.  The delete-CAS correctly refuses (SHA changed), but the lock is
    # still ours.  Re-read + retry converges because the renewer only bumps ts —
    # sid stays self — so the next delete-CAS wins.  Exit 5 only when sid≠self or
    # the ref is already gone (someone else stole/released it).
    while true; do
        if git -C "$REPO_ROOT" update-ref -d "$LOCK_REF" "$cur_sha" 2>/dev/null; then
            break # Released successfully
        fi
        # CAS refused — re-read current state
        cur_sha=$(read_lock_sha)
        if [ -z "$cur_sha" ]; then
            break # Ref already gone — idempotent success
        fi
        h_sid=$(decode_lock_field "$cur_sha" 1)
        if [ "$h_sid" != "$SESSION_ID" ]; then
            printf 'loom-coord lock-release: lock not held by session %s\n' "$SESSION_ID" >&2
            exit 5
        fi
        # Still ours (renewer bumped ts) — retry the delete-CAS
    done
}

# ---------------------------------------------------------------------------
# Subcommand: lock-holder
# ---------------------------------------------------------------------------
cmd_lock_holder() {
    local _sha
    _sha=$(read_lock_sha)
    if [ -n "$_sha" ]; then
        git -C "$REPO_ROOT" cat-file blob "$_sha" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Subcommand: lock-verify
# ---------------------------------------------------------------------------
cmd_lock_verify() {
    assert_session
    local cur_sha
    cur_sha=$(read_lock_sha)
    if [ -z "$cur_sha" ]; then
        printf 'loom-coord lock-verify: no lock held\n' >&2
        exit 5
    fi
    local h_sid
    h_sid=$(decode_lock_field "$cur_sha" 1)
    if [ -z "$h_sid" ]; then
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

    # Check-then-act under the held lock; CAS on the claim ref provides extra safety.
    local _ref cur_sha cur_sid cur_ts new_sha
    _ref=$(claim_ref_for "$slice")
    cur_sha=$(read_claim_sha "$slice")

    if [ -n "$cur_sha" ]; then
        cur_sid=$(decode_claim_field "$cur_sha" 1)
        cur_ts=$(decode_claim_field "$cur_sha" 2)

        if [ "$cur_sid" = "$SESSION_ID" ]; then
            # Own claim — idempotent re-affirm
            printf 'claimed %s %s %s\n' "$slice" "$SESSION_ID" "$cur_ts"
            exit 0
        fi

        # Another session's claim — liveness = lease freshness (ADR 0015)
        if claim_is_fresh "$cur_ts"; then
            printf 'loom-coord claim: slice %s has live claim by %s\n' "$slice" "$cur_sid" >&2
            exit 4
        fi

        # Stale claim — value-CAS steal from exact read SHA
        new_sha=$(_make_claim_blob_for "$SESSION_ID" "$slice")
        if [ -z "$new_sha" ]; then
            printf 'loom-coord claim: cannot create claim blob\n' >&2
            exit 10
        fi
        if ! git -C "$REPO_ROOT" update-ref "$_ref" "$new_sha" "$cur_sha" 2>/dev/null; then
            printf 'loom-coord claim: slice %s claimed by another session\n' "$slice" >&2
            exit 4
        fi
        add_held_claim "$slice"
        printf 'claimed %s %s %s\n' "$slice" "$SESSION_ID" "$(now)"
        exit 0
    fi

    # Absent — create-only CAS from null OID
    new_sha=$(_make_claim_blob_for "$SESSION_ID" "$slice")
    if [ -z "$new_sha" ]; then
        printf 'loom-coord claim: cannot create claim blob\n' >&2
        exit 10
    fi
    if ! git -C "$REPO_ROOT" update-ref "$_ref" "$new_sha" "$NULL_SHA" 2>/dev/null; then
        printf 'loom-coord claim: slice %s claimed by another session\n' "$slice" >&2
        exit 4
    fi
    add_held_claim "$slice"
    printf 'claimed %s %s %s\n' "$slice" "$SESSION_ID" "$(now)"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: renew <slice>
# No lock required — value-CAS on the per-slice ref is atomic.  The renewer
# calls this directly without acquiring the lock (ADR 0016 §2).
# ---------------------------------------------------------------------------
cmd_renew() {
    assert_session
    local slice="$EXTRA_ARGS"
    if [ -z "$slice" ]; then
        printf 'loom-coord renew: slice name required\n' >&2
        exit 1
    fi

    local _ref cur_sha cur_sid new_sha
    _ref=$(claim_ref_for "$slice")
    cur_sha=$(read_claim_sha "$slice")
    if [ -z "$cur_sha" ]; then
        printf 'loom-coord renew: no claim found for %s\n' "$slice" >&2
        exit 5
    fi
    cur_sid=$(decode_claim_field "$cur_sha" 1)
    if [ "$cur_sid" != "$SESSION_ID" ]; then
        printf 'loom-coord renew: slice %s not owned by %s\n' "$slice" "$SESSION_ID" >&2
        exit 5
    fi

    new_sha=$(_make_claim_blob_for "$SESSION_ID" "$slice")
    if [ -z "$new_sha" ]; then
        printf 'loom-coord renew: cannot create claim blob\n' >&2
        exit 10
    fi
    # Value-CAS on exact read SHA
    if ! git -C "$REPO_ROOT" update-ref "$_ref" "$new_sha" "$cur_sha" 2>/dev/null; then
        printf 'loom-coord renew: CAS failed for %s (concurrent update)\n' "$slice" >&2
        exit 5
    fi
    printf 'renewed %s %s\n' "$slice" "$(now)"
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

    local _ref cur_sha cur_sid
    _ref=$(claim_ref_for "$slice")
    cur_sha=$(read_claim_sha "$slice")
    if [ -n "$cur_sha" ]; then
        cur_sid=$(decode_claim_field "$cur_sha" 1)
        if [ "$cur_sid" != "$SESSION_ID" ]; then
            printf 'loom-coord release-claim: slice %s not owned by %s\n' "$slice" "$SESSION_ID" >&2
            exit 5
        fi
        # Delete-CAS: only if ref still equals our blob SHA
        git -C "$REPO_ROOT" update-ref -d "$_ref" "$cur_sha" 2>/dev/null || true
    fi
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

    local _ref cur_sha cur_sid cur_ts new_sha
    _ref=$(claim_ref_for "$slice")
    cur_sha=$(read_claim_sha "$slice")
    if [ -z "$cur_sha" ]; then
        printf 'loom-coord reclaim: no claim found for %s\n' "$slice" >&2
        exit 5
    fi
    cur_sid=$(decode_claim_field "$cur_sha" 1)
    cur_ts=$(decode_claim_field "$cur_sha" 2)

    if [ "$cur_sid" = "$SESSION_ID" ]; then
        printf 'loom-coord reclaim: already owner of %s\n' "$slice" >&2
        exit 5
    fi

    # Liveness = lease freshness (ADR 0015): a fresh lease means holder is alive.
    # Worktree-list membership and pid are NOT liveness signals.
    if claim_is_fresh "$cur_ts"; then
        printf 'loom-coord reclaim: holder %s of %s still has a fresh lease\n' "$cur_sid" "$slice" >&2
        exit 6
    fi

    # V3 fix: CAS steal FIRST; only destroy the orphan worktree after the CAS confirms
    # the old holder is provably stale and unchanged.  Never remove resources before
    # the CAS that authorises it — a holder that renewed in the TOCTOU window would
    # have its worktree destroyed even though the CAS would correctly refuse (V3).
    new_sha=$(_make_claim_blob_for "$SESSION_ID" "$slice")
    if [ -z "$new_sha" ]; then
        printf 'loom-coord reclaim: cannot create claim blob\n' >&2
        exit 10
    fi
    # Value-CAS steal from exact read SHA (ABA-safe)
    if ! git -C "$REPO_ROOT" update-ref "$_ref" "$new_sha" "$cur_sha" 2>/dev/null; then
        printf 'loom-coord reclaim: CAS failed for %s — holder renewed (still alive)\n' "$slice" >&2
        exit 4
    fi
    # CAS succeeded — orphan worktree cleanup is now safe
    git -C "$REPO_ROOT" worktree prune 2>/dev/null || true
    local wt_path
    wt_path=$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null | wt_sid_match "$cur_sid")
    if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
        git -C "$REPO_ROOT" worktree remove -f "$wt_path" 2>/dev/null || true
    fi
    add_held_claim "$slice"
    printf 'reclaimed %s\n' "$slice"
    exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: list-claims
# ---------------------------------------------------------------------------
cmd_list_claims() {
    local refs_tmp
    refs_tmp=$(mktemp)
    git -C "$REPO_ROOT" for-each-ref \
        --format='%(refname) %(objectname)' \
        "$CLAIMS_REF_PREFIX/" 2>/dev/null >"$refs_tmp" || true
    while IFS=' ' read -r refname sha; do
        [ -z "$refname" ] && continue
        local _sid _ts _slice
        _sid=$(git -C "$REPO_ROOT" cat-file blob "$sha" 2>/dev/null | awk -F'\t' '{print $1}')
        _ts=$(git -C "$REPO_ROOT" cat-file blob "$sha" 2>/dev/null | awk -F'\t' '{print $2}')
        _slice=$(git -C "$REPO_ROOT" cat-file blob "$sha" 2>/dev/null | awk -F'\t' '{print $3}')
        [ -z "$_sid" ] && continue
        # Print: <original-slice-name or refname>\t<sid>\t<ts>
        if [ -n "$_slice" ]; then
            printf '%s\t%s\t%s\n' "$_slice" "$_sid" "$_ts"
        else
            printf '%s\t%s\t%s\n' "$refname" "$_sid" "$_ts"
        fi
    done <"$refs_tmp"
    rm -f "$refs_tmp"
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

    # Acquire lock to renew claims (git-CAS inline loop)
    local _sb_got_lock=0
    local _sb_attempt=0
    while true; do
        local _sb_new_sha
        _sb_new_sha=$(_make_blob_for "$SESSION_ID")
        if [ -n "$_sb_new_sha" ] &&
            git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$_sb_new_sha" "$NULL_SHA" 2>/dev/null; then
            _sb_got_lock=1
            break
        fi
        local _sb_cur_sha
        _sb_cur_sha=$(read_lock_sha)
        if [ -n "$_sb_cur_sha" ]; then
            local _sb_h_ts _sb_now _sb_elapsed
            _sb_h_ts=$(decode_lock_field "$_sb_cur_sha" 2)
            case "$_sb_h_ts" in
            '' | *[!0-9]*) ;;
            *)
                _sb_now=$(now)
                _sb_elapsed=$((_sb_now - _sb_h_ts))
                if [ "$_sb_elapsed" -ge "$LOOM_LOCK_TTL" ]; then
                    _sb_new_sha=$(_make_blob_for "$SESSION_ID")
                    if [ -n "$_sb_new_sha" ] &&
                        git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$_sb_new_sha" "$_sb_cur_sha" 2>/dev/null; then
                        _sb_got_lock=1
                        break
                    fi
                fi
                ;;
            esac
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

    # Renew each held claim via value-CAS on the claim ref
    local hcf="$sess_dir/held-claims"
    if [ -f "$hcf" ]; then
        while IFS= read -r slice; do
            [ -z "$slice" ] && continue
            local _ref cur_sha cur_sid new_sha
            _ref=$(claim_ref_for "$slice")
            cur_sha=$(read_claim_sha "$slice")
            if [ -n "$cur_sha" ]; then
                cur_sid=$(decode_claim_field "$cur_sha" 1)
                if [ "$cur_sid" = "$SESSION_ID" ]; then
                    new_sha=$(_make_claim_blob_for "$SESSION_ID" "$slice")
                    if [ -n "$new_sha" ] &&
                        git -C "$REPO_ROOT" update-ref "$_ref" "$new_sha" "$cur_sha" 2>/dev/null; then
                        printf 'renewed %s %s\n' "$slice" "$(now)"
                    fi
                fi
            fi
        done <"$hcf"
    fi

    # Release lock (delete-CAS)
    local _sb_rel_sha
    _sb_rel_sha=$(read_lock_sha)
    if [ -n "$_sb_rel_sha" ]; then
        git -C "$REPO_ROOT" update-ref -d "$LOCK_REF" "$_sb_rel_sha" 2>/dev/null || true
    fi

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
        while [ "$attempt" -lt "$LOOM_LOCK_RETRIES" ]; do
            local _se_new_sha
            _se_new_sha=$(_make_blob_for "$SESSION_ID")
            if [ -n "$_se_new_sha" ] &&
                git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$_se_new_sha" "$NULL_SHA" 2>/dev/null; then
                got_lock=1
                break
            fi
            local _se_cur_sha
            _se_cur_sha=$(read_lock_sha)
            if [ -n "$_se_cur_sha" ]; then
                local _se_h_ts _se_now _se_elapsed
                _se_h_ts=$(decode_lock_field "$_se_cur_sha" 2)
                case "$_se_h_ts" in
                '' | *[!0-9]*) ;;
                *)
                    _se_now=$(now)
                    _se_elapsed=$((_se_now - _se_h_ts))
                    if [ "$_se_elapsed" -ge "$LOOM_LOCK_TTL" ]; then
                        _se_new_sha=$(_make_blob_for "$SESSION_ID")
                        if [ -n "$_se_new_sha" ] &&
                            git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$_se_new_sha" "$_se_cur_sha" 2>/dev/null; then
                            got_lock=1
                            break
                        fi
                    fi
                    ;;
                esac
            fi
            attempt=$((attempt + 1))
            backoff_sleep "$((attempt - 1))"
        done

        if [ "$got_lock" -eq 1 ]; then
            while IFS= read -r slice; do
                [ -z "$slice" ] && continue
                local _ref cur_sha cur_sid
                _ref=$(claim_ref_for "$slice")
                cur_sha=$(read_claim_sha "$slice")
                if [ -n "$cur_sha" ]; then
                    cur_sid=$(decode_claim_field "$cur_sha" 1)
                    if [ "$cur_sid" = "$SESSION_ID" ]; then
                        git -C "$REPO_ROOT" update-ref -d "$_ref" "$cur_sha" 2>/dev/null || true
                    fi
                fi
            done <"$sess_dir/held-claims"
            # Release lock (delete-CAS) then remove session dir
            local _se_rel_sha
            _se_rel_sha=$(read_lock_sha)
            if [ -n "$_se_rel_sha" ]; then
                git -C "$REPO_ROOT" update-ref -d "$LOCK_REF" "$_se_rel_sha" 2>/dev/null || true
            fi
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

    # Acquire lock (git-CAS inline loop)
    local attempt=0
    local got_lock=0
    local cleanup_sid="${SESSION_ID:-cleanup-$$}"
    while [ "$attempt" -lt "$LOOM_LOCK_RETRIES" ]; do
        local _cl_new_sha
        _cl_new_sha=$(_make_blob_for "$cleanup_sid")
        if [ -n "$_cl_new_sha" ] &&
            git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$_cl_new_sha" "$NULL_SHA" 2>/dev/null; then
            got_lock=1
            break
        fi
        local _cl_cur_sha
        _cl_cur_sha=$(read_lock_sha)
        if [ -n "$_cl_cur_sha" ]; then
            local _cl_h_ts _cl_now _cl_elapsed
            _cl_h_ts=$(decode_lock_field "$_cl_cur_sha" 2)
            case "$_cl_h_ts" in
            '' | *[!0-9]*) ;;
            *)
                _cl_now=$(now)
                _cl_elapsed=$((_cl_now - _cl_h_ts))
                if [ "$_cl_elapsed" -ge "$LOOM_LOCK_TTL" ]; then
                    _cl_new_sha=$(_make_blob_for "$cleanup_sid")
                    if [ -n "$_cl_new_sha" ] &&
                        git -C "$REPO_ROOT" update-ref "$LOCK_REF" "$_cl_new_sha" "$_cl_cur_sha" 2>/dev/null; then
                        got_lock=1
                        break
                    fi
                fi
                ;;
            esac
        fi
        attempt=$((attempt + 1))
        backoff_sleep "$((attempt - 1))"
    done

    local swept=0
    local skipped=0

    # Claims mutation MUST be under the lock (F2: mutual exclusion on shared store).
    # Iterate refs/loom/claims/* via a temp file to avoid subshell counter issues.
    if [ "$got_lock" -eq 1 ]; then
        local refs_tmp
        refs_tmp=$(mktemp)
        git -C "$REPO_ROOT" for-each-ref \
            --format='%(refname) %(objectname)' \
            "$CLAIMS_REF_PREFIX/" 2>/dev/null >"$refs_tmp" || true

        # Hoist worktree list once for the entire sweep (orphan-removal lookups only)
        local wt_list
        wt_list=$(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null)

        while IFS=' ' read -r refname sha; do
            [ -z "$refname" ] && continue
            local sid ts
            sid=$(git -C "$REPO_ROOT" cat-file blob "$sha" 2>/dev/null |
                awk -F'\t' '{print $1}')
            ts=$(git -C "$REPO_ROOT" cat-file blob "$sha" 2>/dev/null |
                awk -F'\t' '{print $2}')

            # R7: empty-sid or non-numeric ts → preserve fail-closed, count as skipped
            case "$ts" in
            '' | *[!0-9]*)
                skipped=$((skipped + 1))
                continue
                ;;
            esac
            if [ -z "$sid" ]; then
                skipped=$((skipped + 1))
                continue
            fi

            # Liveness = lease freshness (ADR 0015)
            if claim_is_fresh "$ts"; then
                skipped=$((skipped + 1))
            else
                # V2 fix: delete-CAS FIRST; destroy resources only after the CAS
                # confirms the claim was stale and unchanged.  If the holder renewed
                # in the snapshot→destroy window (SHA changed), the CAS fails and we
                # skip destruction — the holder is alive, its worktree survives.
                if git -C "$REPO_ROOT" update-ref -d "$refname" "$sha" 2>/dev/null; then
                    # CAS succeeded — safe to clean up orphan worktree + session dir
                    local wt_path
                    wt_path=$(printf '%s\n' "$wt_list" | wt_sid_match "$sid")
                    if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
                        git -C "$REPO_ROOT" worktree remove -f "$wt_path" 2>/dev/null || true
                    fi
                    if [ -d "$STATE_DIR/session-$sid" ]; then
                        rm -rf "$STATE_DIR/session-$sid"
                    fi
                    swept=$((swept + 1))
                else
                    # CAS refused — holder renewed (alive); skip destruction
                    skipped=$((skipped + 1))
                fi
            fi
        done <"$refs_tmp"
        rm -f "$refs_tmp"
        # Release lock (delete-CAS)
        local _cl_rel_sha
        _cl_rel_sha=$(read_lock_sha)
        if [ -n "$_cl_rel_sha" ]; then
            git -C "$REPO_ROOT" update-ref -d "$LOCK_REF" "$_cl_rel_sha" 2>/dev/null || true
        fi
    else
        # Could not acquire lock — refuse to mutate shared state (fail-closed)
        printf 'loom-coord cleanup: could not acquire lock; claims sweep skipped\n' >&2
        exit 3
    fi

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
    # Atomic writes: write to a temp file then mv into place so readers never see
    # a partial value (secondary fix).
    local _atmp
    _atmp="${sess_dir}/session.pid.tmp.$$"
    printf '%s\n' "$spid" >"$_atmp" && mv "$_atmp" "${sess_dir}/session.pid"
    _atmp="${sess_dir}/session.starttime.tmp.$$"
    printf '%s\n' "$sst" >"$_atmp" && mv "$_atmp" "${sess_dir}/session.starttime"

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
    local _lock_interval="$LOOM_LOCK_RENEW_INTERVAL"
    local _root="$REPO_ROOT"

    # Launch detached background renewer.  Uses _session_alive (inherited function)
    # with the reuse-robust identity gate: exits when session pid dies or start-time
    # changes (recycled pid).
    #
    # V1 fix — two cadences, decoupled:
    #   Lock heartbeat:  every _lock_interval (~LOOM_LOCK_TTL/3, default 10s).
    #                    Keeps refs/loom/lock alive across long critical sections.
    #   Claim heartbeat: every LOOM_RENEW_INTERVAL (default 1200s).
    #                    Claims have a much longer TTL (3600s); infrequent renewal OK.
    # The loop sleeps _lock_interval per tick; claims are renewed every
    # (_interval/_lock_interval) ticks.
    #
    # stdin/stdout/stderr are closed (redirected to /dev/null) so the subshell does
    # not hold inherited file descriptors open — prevents callers that capture output
    # (e.g. bats `run`) from hanging.
    (
        cd "$_root" 2>/dev/null || exit 1
        _tick=0
        _lease_every=$((_interval / _lock_interval))
        [ "$_lease_every" -lt 1 ] && _lease_every=1
        while _session_alive "$_sdir"; do
            sleep "$_lock_interval" 2>/dev/null || true
            _tick=$((_tick + 1))

            # Lock heartbeat every tick (fast cadence — must stay below LOOM_LOCK_TTL)
            _lsha=$(git -C "$_root" rev-parse --verify "refs/loom/lock" 2>/dev/null || true)
            if [ -n "$_lsha" ]; then
                _lsid=$(git -C "$_root" cat-file blob "$_lsha" 2>/dev/null |
                    awk -F'\t' '{print $1}')
                if [ "$_lsid" = "$_sid" ]; then
                    _nlsha=$(printf '%s\t%s\t%s\t\n' "$_sid" "$(date +%s)" "$$" |
                        git -C "$_root" hash-object -w --stdin 2>/dev/null || true)
                    if [ -n "$_nlsha" ]; then
                        git -C "$_root" update-ref \
                            "refs/loom/lock" "$_nlsha" "$_lsha" 2>/dev/null || true
                    fi
                fi
            fi

            # Claim heartbeat every _lease_every ticks (slow cadence — claims have long TTL)
            if [ $((_tick % _lease_every)) -eq 0 ]; then
                _hcf="$_sdir/held-claims"
                if [ -f "$_hcf" ]; then
                    while IFS= read -r _s; do
                        [ -z "$_s" ] && continue
                        sh "$_coord" renew "$_s" --session "$_sid" >/dev/null 2>&1 || true
                    done <"$_hcf"
                fi
            fi
        done
    ) </dev/null >/dev/null 2>&1 &
    local rpid=$!
    local rst
    rst=$(process_starttime "$rpid")
    local _rtmp
    _rtmp="${sess_dir}/renewer.pid.tmp.$$"
    printf '%s\n' "$rpid" >"$_rtmp" && mv "$_rtmp" "${sess_dir}/renewer.pid"
    if [ -n "$rst" ]; then
        _rtmp="${sess_dir}/renewer.starttime.tmp.$$"
        printf '%s\n' "$rst" >"$_rtmp" && mv "$_rtmp" "${sess_dir}/renewer.starttime"
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

    # Identity gate (U5): only kill if start-time is known AND matches the live pid.
    # Empty rst means process_starttime failed at renewer-start time; we cannot
    # confirm identity → do NOT kill (the pid may have been recycled by an unrelated
    # process since the renewer died).
    if kill -0 "$rpid" 2>/dev/null; then
        if [ -n "$rst" ]; then
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

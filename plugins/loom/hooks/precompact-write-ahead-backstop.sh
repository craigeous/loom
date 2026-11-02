#!/usr/bin/env bash
# precompact-write-ahead-backstop.sh — PreCompact hook guard
# (ADR 0013 §Decision 5 policy; spec 08 wire and per-session state)
#
# POLICY: enforces the write-ahead invariant — before a manual compaction,
# .docs/ must have advanced (been committed to) since the session's last
# recorded checkpoint. An automatic compaction never blocks (never-wedge); a
# no-progress event is recorded to that session's bounded log instead.
#
# State is per validated session under
#   <git-common-dir>/loom/precompact/<session-id>/marker  (progress anchor: the
#     session's loom-coord checkpoint hash when coordinated, else the last
#     .docs/-touching commit SHA)
#   <git-common-dir>/loom/precompact/<session-id>/log     (bounded no-progress-auto log)
# writes are atomic (write-to-temp, rename-into-place); the log is capped at
# LOOM_PRECOMPACT_LOG_CAP lines. session_id is validated against a strict
# allowlist charset before it is ever used as a path component or log field
# (injection-safe); one session's checkpoint never authorizes another's manual
# compaction because each session's state lives in its own directory.
#
# WIRE (spec 08 -> Hook normalization and output adapters): this single
# physical hook, reached through the one shared plugins/loom/hooks/hooks.json
# manifest, selects its client wire adapter at runtime from whichever of
# PLUGIN_ROOT (Codex) or CLAUDE_PLUGIN_ROOT (Claude) resolves to a validated
# physical loom plugin root. The only accepted `trigger` values are `manual`
# and `auto`; the obsolete `compaction_trigger` field is not read. Invalid
# JSON, a missing/wrong-typed/unknown trigger, or a missing/invalid
# session_id fails closed through the fixed reason "Loom hook input invalid
# for pre-compact." — independent of any repository/marker state.
#
# jq 1.6+ is a hard runtime floor (spec 10); there is deliberately no
# grep/sed fallback for JSON parsing — root/type/trigger validation all
# require real JSON semantics a text fallback cannot provide correctly.

EVENT="pre-compact"
INVALID_REASON="Loom hook input invalid for ${EVENT}."
LOOM_PRECOMPACT_LOG_CAP="${LOOM_PRECOMPACT_LOG_CAP:-200}"

# --- root validation shared by both client bindings (spec 10) ---
_loom_hook_validate_root() {
    local candidate="$1" relpath="$2" canon manifest name version
    [ -n "$candidate" ] || return 1
    case "$candidate" in
    /*) ;;
    *) return 1 ;;
    esac
    [ -d "$candidate" ] || return 1
    canon=$(CDPATH='' cd -- "$candidate" 2>/dev/null && pwd -P) || return 1
    manifest="$canon/$relpath"
    [ -f "$manifest" ] || return 1
    name=$(jq -r '.name // empty' "$manifest" 2>/dev/null) || return 1
    version=$(jq -r '.version // empty' "$manifest" 2>/dev/null) || return 1
    [ "$name" = "loom" ] && [ "$version" = "0.2.0" ] || return 1
}

# _loom_hook_select_client — prints "codex" or "claude" and
# returns 0 only when exactly one valid root validates. Ambiguous (multiple valid)
# or zero valid roots fail closed with return 1 (ADR 0030 decision 3).
_loom_hook_select_client() {
    local codex_ok=1 n=0
    _loom_hook_validate_root "${PLUGIN_ROOT:-}" ".codex-plugin/plugin.json" && codex_ok=0 && n=$((n + 1))
    _loom_hook_validate_root "${CLAUDE_PLUGIN_ROOT:-}" ".claude-plugin/plugin.json" && n=$((n + 1))
    [ "$n" -eq 1 ] || return 1
    if [ "$codex_ok" -eq 0 ]; then
        printf 'codex'
    else
        printf 'claude'
    fi
}

# _loom_hook_sanitize_reason <reason> — bounds/normalizes a policy reason to
# the spec 08 contract (single UTF-8 line, control-character-free, <=512 bytes).
_loom_hook_sanitize_reason() {
    local reason="$1" bytes
    case "$reason" in
    *$'\n'*)
        printf 'Loom hook policy returned an invalid reason.'
        return
        ;;
    esac
    if printf '%s' "$reason" | LC_ALL=C grep -q '[[:cntrl:]]'; then
        printf 'Loom hook policy returned an invalid reason.'
        return
    fi
    bytes=$(printf '%s' "$reason" | wc -c | tr -d ' ')
    if [ "$bytes" -gt 512 ]; then
        printf 'Loom hook policy returned an invalid reason.'
        return
    fi
    printf '%s' "$reason"
}

# _loom_hook_allow — exit 0, empty stdout/stderr (identical for both clients).
_loom_hook_allow() {
    exit 0
}

# _loom_hook_block <client> <reason> — emits the exact client wire envelope.
_loom_hook_block() {
    local client="$1" reason reason_json
    reason=$(_loom_hook_sanitize_reason "$2")
    case "$client" in
    codex)
        reason_json=$(jq -Rn --arg r "$reason" '$r')
        printf '{"continue":false,"stopReason":%s}\n' "$reason_json"
        exit 0
        ;;
    claude | *)
        printf '%s\n' "$reason" >&2
        exit 2
        ;;
    esac
}

# _loom_valid_session_id <sid> — loom-coord's identifier grammar:
# ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ with no ".." substring.
_loom_valid_session_id() {
    local sid="$1"
    [ -n "$sid" ] && [ "${#sid}" -le 128 ] || return 1
    case "$sid" in
    [!A-Za-z0-9]* | *[!A-Za-z0-9._-]* | *..*) return 1 ;;
    esac
    return 0
}

# _loom_mktemp <dir> — temp file in the target directory (same filesystem so
# the final rename is atomic); falls back when mktemp is absent from PATH.
_loom_mktemp() {
    local dir="$1"
    mktemp "$dir/.tmp.XXXXXX" 2>/dev/null || {
        local tmp="$dir/.tmp.$$.$RANDOM"
        : >"$tmp" || return 1
        printf '%s' "$tmp"
    }
}

# _loom_atomic_write <path> <content> — write-to-temp then rename-into-place.
_loom_atomic_write() {
    local path="$1" content="$2" dir tmp
    dir=$(dirname -- "$path")
    mkdir -p "$dir" 2>/dev/null || return 1
    tmp=$(_loom_mktemp "$dir") || return 1
    if ! printf '%s\n' "$content" >"$tmp" || ! mv -f -- "$tmp" "$path"; then
        rm -f -- "$tmp"
        return 1
    fi
}

# _loom_append_bounded_log <path> <line> — append, keep only the last
# LOOM_PRECOMPACT_LOG_CAP lines (positive decimal integer without leading
# zero, else 200), control characters stripped, written atomically.
_loom_append_bounded_log() {
    local path="$1" line="$2" dir tmp keep cap="$LOOM_PRECOMPACT_LOG_CAP"
    case "$cap" in
    [1-9] | [1-9][0-9]*) ;;
    *) cap=200 ;;
    esac
    case "$cap" in
    *[!0-9]*) cap=200 ;;
    esac
    dir=$(dirname -- "$path")
    mkdir -p "$dir" 2>/dev/null || return 1
    tmp=$(_loom_mktemp "$dir") || return 1
    keep=$((cap - 1))
    if [ -f "$path" ] && [ "$keep" -gt 0 ]; then
        tail -n "$keep" "$path" >"$tmp" 2>/dev/null || : >"$tmp"
    else
        : >"$tmp"
    fi
    if ! printf '%s\n' "$line" | LC_ALL=C tr -d '\000-\010\013-\037\177' >>"$tmp" ||
        ! mv -f -- "$tmp" "$path"; then
        rm -f -- "$tmp"
        return 1
    fi
}

# --- resolve client (spec 10 root binding) ---
CLIENT=$(_loom_hook_select_client) || _loom_hook_block "claude" "$INVALID_REASON"

# --- read all stdin ---
INPUT=$(cat)

# --- empty stdin → nothing to guard, fail-open ---
if [ -z "$INPUT" ]; then
    _loom_hook_allow
fi

# --- validate JSON shape ---
if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
    _loom_hook_block "$CLIENT" "$INVALID_REASON"
fi

# --- both fields must be JSON strings before any string extraction ---
if ! printf '%s' "$INPUT" | jq -e '(.trigger | type == "string") and (.session_id | type == "string")' >/dev/null 2>&1; then
    _loom_hook_block "$CLIENT" "$INVALID_REASON"
fi

# --- trigger: only "manual" and "auto" are accepted current input ---
TRIGGER=$(printf '%s' "$INPUT" | jq -r '.trigger' 2>/dev/null)
case "$TRIGGER" in
manual | auto) ;;
*) _loom_hook_block "$CLIENT" "$INVALID_REASON" ;;
esac

# --- session_id: required, loom-coord identifier grammar, bounded length ---
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id' 2>/dev/null)
if ! _loom_valid_session_id "$SESSION"; then
    _loom_hook_block "$CLIENT" "$INVALID_REASON"
fi

# --- cwd (soft; falls back to the hook's inherited cwd) ---
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -n "$HOOK_CWD" ] && [ -d "$HOOK_CWD" ]; then
    cd "$HOOK_CWD" 2>/dev/null || true
fi

# --- resolve repo root and git dir ---
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    # Not a git repo or git unavailable — nothing to guard, fail-open
    _loom_hook_allow
fi

GITDIR=$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null) ||
    GITDIR=$(git -C "$REPO_ROOT" rev-parse --git-dir 2>/dev/null)
if [ -z "$GITDIR" ]; then
    _loom_hook_allow
fi
case "$GITDIR" in
/*) ;;
*) GITDIR="$REPO_ROOT/$GITDIR" ;;
esac

STATE_DIR="$GITDIR/loom/precompact/$SESSION"
MARKER="$STATE_DIR/marker"
LOG="$STATE_DIR/log"

# --- compute current progress anchor ---
# A session coordinated through loom-coord (--session <session_id> or
# LOOM_SESSION_ID) anchors on its own checkpoint file; otherwise the last
# .docs/-touching commit is the repository-wide anchor.
SESSION_COORD_DIR="$GITDIR/loom/session-$SESSION"
SESSION_CHECKPOINT="$SESSION_COORD_DIR/checkpoint"
COORDINATED=0
if [ -f "$SESSION_CHECKPOINT" ]; then
    COORDINATED=1
    CHK_SHA=$(git -C "$REPO_ROOT" hash-object -- "$SESSION_CHECKPOINT" 2>/dev/null) || CHK_SHA=""
    if [ -z "$CHK_SHA" ]; then
        _loom_hook_allow
    fi
    CUR="checkpoint:$CHK_SHA"
elif [ -d "$SESSION_COORD_DIR" ]; then
    COORDINATED=1
    CUR="checkpoint:none"
else
    CUR=$(git -C "$REPO_ROOT" log -1 --format=%H -- .docs 2>/dev/null)
    if [ -z "$CUR" ]; then
        # No .docs/ history — nothing to guard, fail-open
        _loom_hook_allow
    fi
fi

# --- first run for this session: marker absent/unreadable → record and allow ---
if [ ! -f "$MARKER" ] || ! PREV=$(cat "$MARKER" 2>/dev/null); then
    _loom_atomic_write "$MARKER" "$CUR"
    _loom_hook_allow
fi

# --- progress advanced → update marker and allow ---
if [ "$CUR" != "$PREV" ]; then
    _loom_atomic_write "$MARKER" "$CUR"
    _loom_hook_allow
fi

# --- no progress (CUR == PREV) ---
if [ "$TRIGGER" = "manual" ]; then
    if [ "$COORDINATED" -eq 1 ]; then
        _loom_hook_block "$CLIENT" "loom write-ahead backstop: session checkpoint has not advanced before manual compaction (ADR 0013); write an advanced checkpoint via loom-coord checkpoint-write --session ${SESSION}, then retry."
    fi
    _loom_hook_block "$CLIENT" "loom write-ahead backstop: .docs/ has not advanced before manual compaction (ADR 0013); commit a .docs/ checkpoint, then retry."
else
    # auto: append bounded observation log line, never block (never-wedge)
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u)
    _loom_append_bounded_log "$LOG" "$(printf '%s\t%s\t%s' "$TIMESTAMP" "$SESSION" "$CUR")"
    _loom_hook_allow
fi

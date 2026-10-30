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
#   <git-dir>/loom/precompact/<session-id>/marker  (last .docs/-touching commit SHA)
#   <git-dir>/loom/precompact/<session-id>/log     (bounded no-progress-auto log)
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

# _loom_hook_select_client — prints "codex" when the Codex-specific root
# validates, otherwise "claude" when the Claude-specific root validates.
# Codex intentionally sets both roots for compatibility; preferring its
# specific binding keeps the shared hook's Codex wire adapter selected.
_loom_hook_select_client() {
    if _loom_hook_validate_root "${PLUGIN_ROOT:-}" ".codex-plugin/plugin.json"; then
        printf 'codex'
        return 0
    elif _loom_hook_validate_root "${CLAUDE_PLUGIN_ROOT:-}" ".claude-plugin/plugin.json"; then
        printf 'claude'
        return 0
    fi
    return 1
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
    *)
        printf '%s\n' "$reason" >&2
        exit 2
        ;;
    esac
}

# _loom_atomic_write <path> <content> — write-to-temp then rename-into-place.
_loom_atomic_write() {
    local path="$1" content="$2" dir tmp
    dir=$(dirname -- "$path")
    mkdir -p "$dir" 2>/dev/null || return 1
    tmp="$dir/.tmp.$$.$RANDOM"
    printf '%s\n' "$content" >"$tmp" || return 1
    mv -f -- "$tmp" "$path"
}

# _loom_append_bounded_log <path> <line> — append, keep only the last
# LOOM_PRECOMPACT_LOG_CAP lines, written atomically (write-to-temp, rename).
_loom_append_bounded_log() {
    local path="$1" line="$2" dir tmp keep
    dir=$(dirname -- "$path")
    mkdir -p "$dir" 2>/dev/null || return 1
    tmp="$dir/.tmp.$$.$RANDOM"
    keep=$((LOOM_PRECOMPACT_LOG_CAP - 1))
    if [ -f "$path" ] && [ "$keep" -gt 0 ]; then
        tail -n "$keep" "$path" >"$tmp" 2>/dev/null || : >"$tmp"
    else
        : >"$tmp"
    fi
    printf '%s\n' "$line" >>"$tmp"
    mv -f -- "$tmp" "$path"
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

# --- trigger: only "manual" and "auto" are accepted current input ---
TRIGGER=$(printf '%s' "$INPUT" | jq -r '.trigger // empty' 2>/dev/null)
case "$TRIGGER" in
manual | auto) ;;
*) _loom_hook_block "$CLIENT" "$INVALID_REASON" ;;
esac

# --- session_id: required, strict allowlist charset, bounded length ---
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
case "$SESSION" in
'') _loom_hook_block "$CLIENT" "$INVALID_REASON" ;;
*[!A-Za-z0-9_-]*) _loom_hook_block "$CLIENT" "$INVALID_REASON" ;;
esac
if [ "${#SESSION}" -gt 128 ]; then
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

# --- compute current progress anchor (last .docs/-touching commit) ---
CUR=$(git -C "$REPO_ROOT" log -1 --format=%H -- .docs 2>/dev/null)
if [ -z "$CUR" ]; then
    # No .docs/ history — nothing to guard, fail-open
    _loom_hook_allow
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
    _loom_hook_block "$CLIENT" "loom write-ahead backstop: .docs/ has not advanced before manual compaction (ADR 0013); commit a .docs/ checkpoint, then retry."
else
    # auto: append bounded observation log line, never block (never-wedge)
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u)
    _loom_append_bounded_log "$LOG" "$(printf '%s\t%s' "$TIMESTAMP" "$CUR")"
    _loom_hook_allow
fi

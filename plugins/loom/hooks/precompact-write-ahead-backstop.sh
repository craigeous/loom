#!/usr/bin/env bash
# precompact-write-ahead-backstop.sh — PreCompact hook guard (ADR 0013 §Decision 5)
#
# Enforces the write-ahead invariant: before compacting, check whether .docs/
# has advanced (i.e. been committed to) since the last recorded compaction marker.
# Reads Claude Code hook stdin (JSON with compaction_trigger), exits 2 on a
# no-progress + manual compaction, exits 0 otherwise (fail-open).
#
# Marker: <git-dir>/loom/precompact-marker (last .docs/-touching commit SHA)
# Log:    <git-dir>/loom/precompact.log   (one line per no-progress auto event)
#
# Decision table (no-progress = .docs/ SHA == last marker):
#   progress advanced  → update marker, exit 0 (allow)
#   no-progress + manual → stderr remediation, exit 2 (block)
#   no-progress + auto   → append log line, exit 0 (never-wedge)
#   no-progress + empty/unknown → treat as auto, exit 0
#   first run (no marker) → record current SHA, exit 0
#   not a git repo / git unavailable / empty stdin → exit 0 (fail-open)
#   no .docs/ history → exit 0 (fail-open; nothing to guard)

# --- Read all stdin ---
INPUT=$(cat)

# --- Extract compaction_trigger ---
if command -v jq >/dev/null 2>&1; then
    TRIGGER=$(printf '%s' "$INPUT" | jq -r '.compaction_trigger // empty' 2>/dev/null)
else
    # grep/sed fallback — best-effort on well-formed single-line JSON
    TRIGGER=$(printf '%s' "$INPUT" | grep -o '"compaction_trigger"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"compaction_trigger"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Empty trigger → treat as auto (never-wedge default)
if [ -z "$TRIGGER" ]; then
    TRIGGER="auto"
fi

# --- Extract session_id for logging ---
if command -v jq >/dev/null 2>&1; then
    SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
else
    SESSION=$(printf '%s' "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"session_id"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi
if [ -z "$SESSION" ]; then
    SESSION="unknown"
fi

# --- Extract cwd from stdin and change into it (cwd-independence) ---
# Claude Code passes the working directory as "cwd" in the hook JSON.
# Changing into it ensures git rev-parse resolves the correct repo regardless
# of whatever directory the hook process inherited.
if command -v jq >/dev/null 2>&1; then
    HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
else
    HOOK_CWD=$(printf '%s' "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"cwd"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi
if [ -n "$HOOK_CWD" ] && [ -d "$HOOK_CWD" ]; then
    cd "$HOOK_CWD" 2>/dev/null || true
fi

# --- Resolve repo root and git dir ---
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_ROOT" ]; then
    # Not a git repo or git unavailable — fail-open
    exit 0
fi

GITDIR=$(git -C "$REPO_ROOT" rev-parse --git-dir 2>/dev/null)
if [ -z "$GITDIR" ]; then
    exit 0
fi
# git-dir may be relative; make it absolute
case "$GITDIR" in
/*) ;;
*) GITDIR="$REPO_ROOT/$GITDIR" ;;
esac

STATE_DIR="$GITDIR/loom"
MARKER="$STATE_DIR/precompact-marker"
LOG="$STATE_DIR/precompact.log"

# --- Compute current progress anchor (last .docs/-touching commit) ---
CUR=$(git -C "$REPO_ROOT" log -1 --format=%H -- .docs 2>/dev/null)
if [ -z "$CUR" ]; then
    # No .docs/ history — nothing to guard, fail-open
    exit 0
fi

# --- First run: marker absent or unreadable → record and allow ---
if [ ! -f "$MARKER" ] || ! PREV=$(cat "$MARKER" 2>/dev/null); then
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$CUR" >"$MARKER"
    exit 0
fi

# --- Progress advanced → update marker and allow ---
if [ "$CUR" != "$PREV" ]; then
    printf '%s\n' "$CUR" >"$MARKER"
    exit 0
fi

# --- No progress (CUR == PREV) ---
if [ "$TRIGGER" = "manual" ]; then
    printf 'loom write-ahead backstop: no-progress detected.\n' >&2
    printf '.docs/ has not advanced since the last compaction (marker SHA: %s).\n' "$CUR" >&2
    printf 'This is the ADR 0013 write-ahead invariant: a checkpoint must be committed\n' >&2
    printf 'to .docs/ (e.g. status/handoff.md) before compacting.\n' >&2
    printf '\nRemediation:\n' >&2
    printf '  1. Commit a real .docs/ checkpoint (update status/handoff.md) then re-compact, or\n' >&2
    printf '  2. Re-run /compact if this block was spurious (no .docs/ work was expected).\n' >&2
    # Do NOT advance the marker on a block
    exit 2
else
    # auto or unknown: append observation log line, never block
    mkdir -p "$STATE_DIR"
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u)
    printf '%s\t%s\t%s\n' "$TIMESTAMP" "$SESSION" "$CUR" >>"$LOG"
    exit 0
fi

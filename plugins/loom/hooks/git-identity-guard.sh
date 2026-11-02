#!/usr/bin/env bash
# git-identity-guard.sh — PreToolUse hook guard (ADR 0003 policy; spec 08 wire)
#
# POLICY: blocks recognized git identity-mutation tokens (ADR 0003). Reads
# tool_input.command; a recognized token BLOCKS, everything else ALLOWS. This is
# defense in depth, not a shell parser or hostile-code sandbox: dynamically
# constructed commands, aliases, scripts, expansions, encoded text, commands
# outside an active hook, and concurrent external mutations can evade it. The
# post-command check is loom-verify-identity, which the developer workflow must
# invoke explicitly (commit-convention.md); it is not an automatic guarantee.
#
# The raw command text is scanned. Quoted bodies are NOT stripped, so tokens
# inside sh -c, bash -c, env, and other wrappers are seen, and unbalanced
# quoting never discards a token. Accepted false positives: recognized tokens in
# commit messages or read filters (e.g. a log author filter) are blocked.
#
# Recognized tokens blocked (any ambiguous mutation form is blocked):
#   the commit author flag (bare or =value)
#   -c user.* / author.* / committer.*  (also --config-env=...)
#   -c GIT_AUTHOR* / -c GIT_COMMITTER*
#   GIT_AUTHOR_*= / GIT_COMMITTER_*= assignments
#   git config writes to user|author|committer . name|email in any scope
#     (--local/--global/--system/--file), including --unset, --replace-all,
#     --add, --edit. Bare reads (no value, --get*, --list) are allowed.
#
# WIRE (spec 08 -> Hook normalization and output adapters): this single physical
# hook, reached through the one shared plugins/loom/hooks/hooks.json manifest,
# selects its client wire adapter at runtime from whichever of PLUGIN_ROOT
# (Codex) or CLAUDE_PLUGIN_ROOT (Claude) resolves to a validated physical loom
# plugin root. An unresolved/ambiguous root, invalid input JSON, or a
# wrong-typed tool_input.command fails closed through the fixed reason "Loom
# hook input invalid for pre-tool-use." A missing tool_input.command (no Bash
# target to evaluate) allows, matching the original ADR 0003 behavior exactly.
#
# jq 1.6+ is a hard runtime floor (spec 10); there is deliberately no
# grep/sed fallback for JSON parsing here — root/type validation both require
# real JSON semantics that a text fallback cannot provide correctly.

EVENT="pre-tool-use"
INVALID_REASON="Loom hook input invalid for ${EVENT}."

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

# _loom_hook_select_client — prints "claude" or "codex" and returns 0 only
# when exactly one of PLUGIN_ROOT (Codex)/CLAUDE_PLUGIN_ROOT (Claude) validates.
# Both valid (ambiguous) or neither valid (missing/mismatched) returns 1.
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
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$reason_json"
        exit 0
        ;;
    claude | *)
        printf '%s\n' "$reason" >&2
        exit 2
        ;;
    esac
}

# --- resolve client (spec 10 root binding) ---
CLIENT=$(_loom_hook_select_client) || _loom_hook_block "claude" "$INVALID_REASON"

# --- read all stdin ---
INPUT=$(cat)

# --- validate JSON shape ---
if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
    _loom_hook_block "$CLIENT" "$INVALID_REASON"
fi

# tool_input.command must be absent (no target — allow) or a string.
CMD_TYPE=$(printf '%s' "$INPUT" | jq -r '(.tool_input.command // null) | type' 2>/dev/null)
case "$CMD_TYPE" in
string | null) ;;
*) _loom_hook_block "$CLIENT" "$INVALID_REASON" ;;
esac

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# --- empty command → allow (nothing to evaluate; allow) ---
if [ -z "$CMD" ]; then
    _loom_hook_allow
fi

# --- git-word / env-var gate: only proceed for git-bearing commands ---
IS_GIT=0
if printf '%s' "$CMD" | grep -qE '(^|[^[:alnum:]_./-])git([[:space:]]|$|["'"'"'])'; then
    IS_GIT=1
fi
if printf '%s' "$CMD" | grep -qE 'GIT_(AUTHOR|COMMITTER)_[A-Za-z_]*='; then
    IS_GIT=1
fi
if [ "$IS_GIT" -eq 0 ]; then
    _loom_hook_allow
fi

# --- Override detection (all on the raw $CMD; quoted bodies are not stripped) ---

if printf '%s' "$CMD" | grep -qE -- '--author([[:space:]]|=|$|["'"'"'])'; then
    _loom_hook_block "$CLIENT" "loom identity guard: blocked --author override (ADR 0003 requires the uniform commit identity)."
fi

if printf '%s' "$CMD" | grep -qiE -- '(-c[[:space:]]+|--config-env=)["'"'"']?(user|author|committer)\.'; then
    _loom_hook_block "$CLIENT" "loom identity guard: blocked -c user.*/author.*/committer.* override (ADR 0003 requires the uniform commit identity)."
fi

if printf '%s' "$CMD" | grep -qE -- '-c[[:space:]]+["'"'"']?GIT_(AUTHOR|COMMITTER)'; then
    _loom_hook_block "$CLIENT" "loom identity guard: blocked -c GIT_AUTHOR*/GIT_COMMITTER* override (ADR 0003 requires the uniform commit identity)."
fi

if printf '%s' "$CMD" | grep -qE 'GIT_(AUTHOR|COMMITTER)_[A-Za-z_]*='; then
    _loom_hook_block "$CLIENT" "loom identity guard: blocked GIT_AUTHOR_*/GIT_COMMITTER_* env override (ADR 0003 requires the uniform commit identity)."
fi

# _loom_hook_config_write_line <line> — returns 0 when the line writes (or is an
# ambiguous mutation of) a recognized identity key via git config.
_loom_hook_config_write_line() {
    local line="$1" key='(user|author|committer)\.(name|email)'
    printf '%s' "$line" | grep -qE '(^|[^[:alnum:]_.-])config([[:space:]]|$|[;&|)"'"'"'])' || return 1
    printf '%s' "$line" | grep -qiE "(^|[^[:alnum:]_])${key}([^[:alnum:]_]|\$)" || return 1
    if printf '%s' "$line" | grep -qE -- '--(unset|unset-all|replace-all|add|edit)([[:space:]]|$)|(^|[[:space:]])-e([[:space:]]|$)'; then
        return 0
    fi
    if printf '%s' "$line" | grep -qE -- '--(get|get-all|get-regexp|list)([[:space:]]|$)|(^|[[:space:]])-l([[:space:]]|$)'; then
        return 1
    fi
    printf '%s' "$line" | grep -qiE "(^|[^[:alnum:]_])${key}(=|[[:space:]]+[^-[:space:];&|)])"
}

# Classify each statement separately (split on newline and ; & |) so a read in
# one statement never suppresses a recognized write in another.
while IFS= read -r LINE || [ -n "$LINE" ]; do
    if _loom_hook_config_write_line "$LINE"; then
        _loom_hook_block "$CLIENT" "loom identity guard: blocked git config write of an identity key (ADR 0003 requires the uniform commit identity)."
    fi
done < <(printf '%s' "$CMD" | tr ';&|' '\n')

# --- No recognized token detected → allow ---
_loom_hook_allow

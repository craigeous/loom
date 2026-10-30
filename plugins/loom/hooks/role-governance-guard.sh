#!/usr/bin/env bash
# role-governance-guard.sh — PreToolUse role anti-drift guard (slice role-governance-guard)
#
# POLICY: when LOOM_ROLE is set, blocks role-boundary drift in Bash commands:
#   orchestrator            -> test runners (scripts/check, bats, cargo test,
#                              npm test, pytest) unless LOOM_ALLOW_ORCHESTRATOR_GATE=1
#                              (which permits scripts/check only)
#   plan-/code-evaluator    -> git history/checkout mutation
# LOOM_ROLE unset or empty fails open. Defense in depth against agent drift, not
# a security boundary. Command words are inspected after the same Stage A/B/C
# de-quote transform as git-identity-guard.sh, so arguments never match.
#
# WIRE: identical root validation and client envelopes to git-identity-guard.sh
# (spec 08, spec 10). Invalid root/JSON/command type fails closed.

EVENT="pre-tool-use"
INVALID_REASON="Loom hook input invalid for ${EVENT}."
ORCH_REASON="Loom policy: Orchestrators cannot run test suites directly; delegate to an external worker."
EVAL_REASON="Loom policy: Evaluators are read-only and cannot mutate git history or checkout."

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

_loom_hook_select_client() {
    local codex_ok=1 claude_ok=1
    _loom_hook_validate_root "${PLUGIN_ROOT:-}" ".codex-plugin/plugin.json" && codex_ok=0
    _loom_hook_validate_root "${CLAUDE_PLUGIN_ROOT:-}" ".claude-plugin/plugin.json" && claude_ok=0
    if [ "$codex_ok" -eq 0 ] && [ "$claude_ok" -eq 0 ]; then
        return 1
    elif [ "$codex_ok" -eq 0 ]; then
        printf 'codex'
    elif [ "$claude_ok" -eq 0 ]; then
        printf 'claude'
    else
        return 1
    fi
}

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

_loom_hook_allow() {
    exit 0
}

_loom_hook_block() {
    local client="$1" reason reason_json
    reason=$(_loom_hook_sanitize_reason "$2")
    case "$client" in
    codex)
        reason_json=$(jq -Rn --arg r "$reason" '$r')
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$reason_json"
        exit 0
        ;;
    *)
        printf '%s\n' "$reason" >&2
        exit 2
        ;;
    esac
}

CLIENT=$(_loom_hook_select_client) || _loom_hook_block "claude" "$INVALID_REASON"

INPUT=$(cat)

if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
    _loom_hook_block "$CLIENT" "$INVALID_REASON"
fi

CMD_TYPE=$(printf '%s' "$INPUT" | jq -r '(.tool_input.command // null) | type' 2>/dev/null)
case "$CMD_TYPE" in
string | null) ;;
*) _loom_hook_block "$CLIENT" "$INVALID_REASON" ;;
esac

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || _loom_hook_allow

# Unset/empty role: fail open.
[ -n "${LOOM_ROLE:-}" ] || _loom_hook_allow

# Stage A/B/C de-quote (as git-identity-guard.sh)
DEESC=$(printf '%s' "$CMD" | sed -e 's/\\"//g' -e "s/\\\\'//g")
# Quoted words with no whitespace/separators are de-quoted (so 'bats' and "commit"
# still count as command words); other quoted segments are deleted (arguments).
STRIPPED=$(printf '%s' "$DEESC" | sed \
    -e "s/'\([^' [:space:];&|()]*\)'/\1/g" -e 's/"\([^" [:space:];&|()]*\)"/\1/g' \
    -e "s/'[^']*'//g" -e 's/"[^"]*"//g')
DQ=$(printf '%s' "$STRIPPED" | tr -cd '"' | wc -c | tr -d ' ')
SQ=$(printf '%s' "$STRIPPED" | tr -cd "'" | wc -c | tr -d ' ')
if [ $((DQ % 2)) -ne 0 ] || [ $((SQ % 2)) -ne 0 ]; then
    _loom_hook_allow
fi

# Command-start anchor: line start or after ; & | ( and optional env assignments.
START='(^|[;&|(])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
PATHPFX='([^[:space:]]*/)?'
# git global options, including value-taking ones (-C <p>, -c <k=v>, --git-dir <p>, ...)
GITOPT='((-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]+|--(git-dir|work-tree|namespace|super-prefix|config-env)([[:space:]]+|=)[^[:space:]]+[[:space:]]+|-[^[:space:]]+[[:space:]]+)'

case "$LOOM_ROLE" in
orchestrator)
    if printf '%s' "$STRIPPED" | grep -qE "${START}(bash[[:space:]]+|sh[[:space:]]+)?${PATHPFX}scripts/check([[:space:]]|\$)"; then
        [ "${LOOM_ALLOW_ORCHESTRATOR_GATE:-}" = "1" ] || _loom_hook_block "$CLIENT" "$ORCH_REASON"
    fi
    # Independent of the landing-gate exception: other runners are always blocked.
    if printf '%s' "$STRIPPED" | grep -qE "${START}(${PATHPFX}bats|${PATHPFX}pytest|cargo[[:space:]]+test|npm[[:space:]]+test)([[:space:]]|\$)"; then
        _loom_hook_block "$CLIENT" "$ORCH_REASON"
    fi
    ;;
plan-evaluator | code-evaluator)
    if printf '%s' "$STRIPPED" | grep -qE "${START}git[[:space:]]+${GITOPT}*(commit|push|merge|rebase|cherry-pick|apply|reset[[:space:]]+(.*[[:space:]])?--hard)([[:space:]]|\$)"; then
        _loom_hook_block "$CLIENT" "$EVAL_REASON"
    fi
    ;;
esac

_loom_hook_allow

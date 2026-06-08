#!/bin/sh
# git-identity-guard.sh — PreToolUse hook guard (ADR 0003)
#
# Blocks git commands that override the uniform commit identity.
# Reads Claude Code hook stdin (JSON with tool_input.command), exits 2 on
# a detected identity override, exits 0 otherwise (fail-open).
#
# Override paths blocked (only on commit-creating subcommands):
#   --author= / --author <value>
#   -c user.name= / -c user.email= / any -c user.*=
#   -c GIT_AUTHOR*= / -c GIT_COMMITTER*=
#   GIT_AUTHOR_NAME= / GIT_AUTHOR_EMAIL= / GIT_COMMITTER_NAME= / GIT_COMMITTER_EMAIL=
#
# Override-detection is scoped to commit-creating subcommands only:
#   commit, commit-tree, am, cherry-pick, revert, rebase, merge
# Read-only subcommands (log, shortlog, blame, show, diff, config, …) are
# always allowed, even if --author or identity env vars are present (on reads,
# --author is a filter and identity vars change nothing recorded).
# If the subcommand cannot be determined cleanly (unrecognized global option,
# no subcommand token found), the hook fails OPEN (allow, exit 0) per the
# defense-in-depth posture of ADR 0003 — the binding rule is commit-convention.md.
#
# De-quote transform (flag-vs-text discrimination):
#   Stage A: remove backslash-escaped quote chars (\" and \')
#   Stage B: strip contents of 'single' and "double" quoted segments
#   Stage C: fail-open if odd quote count remains (unparseable quoting)
# All override checks run on $STRIPPED, never on the raw command.

# --- Read all stdin ---
INPUT=$(cat)

# --- Extract tool_input.command ---
if command -v jq >/dev/null 2>&1; then
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
    # grep/sed fallback — best-effort on well-formed single-line JSON
    CMD=$(printf '%s' "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# --- Empty command → allow (fail open) ---
if [ -z "$CMD" ]; then
    exit 0
fi

# --- Stage A: remove backslash-escaped quote characters ---
DEESC=$(printf '%s' "$CMD" | sed -e 's/\\"//g' -e "s/\\\\'//g")

# --- Stage B: strip contents (and delimiters) of quoted segments ---
STRIPPED=$(printf '%s' "$DEESC" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')

# --- Stage C: fail-open backstop on unresolvable (odd) quote count ---
DQ=$(printf '%s' "$STRIPPED" | tr -cd '"' | wc -c | tr -d ' ')
SQ=$(printf '%s' "$STRIPPED" | tr -cd "'" | wc -c | tr -d ' ')
if [ $((DQ % 2)) -ne 0 ] || [ $((SQ % 2)) -ne 0 ]; then
    exit 0
fi

# --- git-word / env-var gate: only proceed for git-bearing commands ---
# Match 'git' as a whole word (not a substring of another identifier)
# or an identity env var assignment (which only appears alongside git anyway)
IS_GIT=0
if printf '%s' "$STRIPPED" | grep -qE '(^|[^[:alnum:]_./-])git([[:space:]]|$)'; then
    IS_GIT=1
fi
if printf '%s' "$STRIPPED" | grep -qE '(GIT_AUTHOR_(NAME|EMAIL)|GIT_COMMITTER_(NAME|EMAIL))='; then
    IS_GIT=1
fi
if [ "$IS_GIT" -eq 0 ]; then
    exit 0
fi

# --- Determine git subcommand (override-detection is commit-scoped) ---
# Walk tokens with a state machine: skip leading VAR=value env assignments
# before 'git', skip global options and their consumed values after 'git',
# and take the first bare non-option token as the subcommand.
# Fail-open (SUBCMD="") if parsing is ambiguous.
SUBCMD=""
SEEN_GIT=0
SKIP_NEXT=0
for tok in $STRIPPED; do
    if [ "$SEEN_GIT" -eq 0 ]; then
        case "$tok" in
            [A-Za-z_]*=*) continue ;;     # leading VAR=value env assignment
            git) SEEN_GIT=1; continue ;;
            *) SUBCMD=""; break ;;         # not a clean `git ...` invocation
        esac
    fi
    if [ "$SKIP_NEXT" -eq 1 ]; then SKIP_NEXT=0; continue; fi
    case "$tok" in
        -c)  SKIP_NEXT=1; continue ;;
        -C)  SKIP_NEXT=1; continue ;;
        --git-dir|--work-tree|--namespace|--exec-path|--config-env)
             SKIP_NEXT=1; continue ;;
        -c*|-C*|--git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--config-env=*)
             continue ;;
        -p|--paginate|-P|--no-pager|--bare|--no-replace-objects|--literal-pathspecs|--no-optional-locks|--html-path|--man-path|--info-path|--version|--help)
             continue ;;
        -*)  SUBCMD=""; break ;;           # unrecognized global option → fail open
        *)   SUBCMD="$tok"; break ;;        # first bare token = subcommand
    esac
done

# --- Override detection — runs ONLY for commit-creating subcommands ---
case "$SUBCMD" in
    commit|commit-tree|am|cherry-pick|revert|rebase|merge)

        # --author= or --author <space> (flag form)
        if printf '%s' "$STRIPPED" | grep -qE -- '--author([[:space:]]|=)'; then
            printf 'loom identity guard: blocked --author flag (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
            exit 2
        fi

        # -c user.*= (user identity config override)
        if printf '%s' "$STRIPPED" | grep -qE -- '-c[[:space:]]+user\.[A-Za-z]+='; then
            printf 'loom identity guard: blocked -c user.*= config override (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
            exit 2
        fi

        # -c GIT_AUTHOR*= or -c GIT_COMMITTER*= (identity env override via -c)
        if printf '%s' "$STRIPPED" | grep -qE -- '-c[[:space:]]+(GIT_AUTHOR|GIT_COMMITTER)[A-Z_]*='; then
            printf 'loom identity guard: blocked -c GIT_AUTHOR*/GIT_COMMITTER* config override (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
            exit 2
        fi

        # Inline or exported GIT_AUTHOR_NAME/EMAIL or GIT_COMMITTER_NAME/EMAIL
        if printf '%s' "$STRIPPED" | grep -qE '(GIT_AUTHOR_(NAME|EMAIL)|GIT_COMMITTER_(NAME|EMAIL))='; then
            printf 'loom identity guard: blocked GIT_AUTHOR_*/GIT_COMMITTER_* env var override (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
            exit 2
        fi

        ;;
esac

# --- No override detected (or non-commit subcommand) → allow ---
exit 0

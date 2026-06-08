# PreToolUse Hook for Git Author Identity Guard

Status: Approved
Date: 2026-06-08

## Research Questions Answered

### 1. Plugin Hook Mechanism

**Where hooks live in a plugin:**
- **Primary location:** `hooks/hooks.json` in plugin root ([Plugins reference, code.claude.com](https://code.claude.com/docs/en/plugins-reference))
- **Alternative:** Inline in `.claude-plugin/plugin.json` under a `hooks` key (not recommended; separate file is standard)

**File structure for plugin hooks:**
```json
{
  "description": "Brief explanation (optional)",
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...],
    "Stop": [...]
  }
}
```

The `description` field is optional; the `hooks` wrapper is required. This is distinct from user `~/.claude/settings.json` hooks, which omit the wrapper and place event keys directly at the top level ([Plugins reference, code.claude.com](https://code.claude.com/docs/en/plugins-reference)).

**Local loom status:** Confirmed — `/Users/craig/git/loom/plugins/loom/.claude-plugin/plugin.json` does not declare any hooks, and no `hooks/` directory currently exists in the plugin.

### 2. PreToolUse Event Specifics

**Event name:** `PreToolUse`

**Matcher syntax for Bash tool:** Use the literal string `"Bash"` as the matcher value. Optionally add an "if" field for command filtering (e.g., `"Bash(git *)"` to match only git subcommands).

**Example matcher:**
```json
{
  "matcher": "Bash",
  "hooks": [...]
}
```

**JSON input shape on stdin (for PreToolUse):**
```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/dir",
  "permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
  "hook_event_name": "PreToolUse",
  "effort": {
    "level": "low|medium|high|xhigh|max"
  },
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit ..."
  }
}
```

The **command string is always in `tool_input.command`** ([Hooks reference, code.claude.com](https://code.claude.com/docs/en/hooks)).

### 3. Blocking Semantics: Exit Codes and JSON Response

**Two methods to block a tool call in PreToolUse:**

#### Method A: Exit Code 2 with stderr (simplest)
- **Exit code:** `2` (any other non-zero code = non-blocking error)
- **Behavior:** Tool call is blocked; stderr text is fed back to Claude as an error message
- **No JSON parsing:** Any stdout JSON is ignored when exiting 2
- **Quote:** "Exit code 2 is a blocking error. The tool call is blocked and prevented from executing. stderr text is fed back to Claude as an error message." ([Hooks reference, code.claude.com](https://code.claude.com/docs/en/hooks))

#### Method B: Exit Code 0 with JSON `permissionDecision` (structured)
- **Exit code:** `0`
- **JSON output schema:**
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Explanation of why blocked"
    }
  }
  ```
- **permissionDecision values:** `"deny"`, `"allow"`, `"ask"`, or `"defer"`
- **Requirement:** When using `"deny"`, the `permissionDecisionReason` field is required ([Hooks reference, code.claude.com](https://code.claude.com/docs/en/hooks))

**Recommendation for this use case:** Method A (exit 2 + stderr) is simpler and sufficient for a deny-only guard.

### 4. Hook Command Execution

**Execution model:**
- Hook commands are spawned as **shell commands** (shell determined by the system; typically `/bin/sh` on POSIX, `PowerShell.exe` on Windows)
- **Shebang line honored:** If the command is a script file (e.g., `/path/to/script.sh`), the shebang (`#!/bin/sh`) determines the interpreter
- **Environment variable substitution:** `${CLAUDE_PLUGIN_ROOT}` is expanded before execution

**`${CLAUDE_PLUGIN_ROOT}` availability:**
- **Defined:** Yes, as both a path placeholder in the JSON config and as an exported environment variable (`$CLAUDE_PLUGIN_ROOT`) in the hook process
- **Reliability:** Generally reliable for command hooks in PreToolUse/PostToolUse, but known issues exist for SessionStart and some other events (see Gotchas)
- **Quote:** "Both export them as environment variables `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, and `CLAUDE_PLUGIN_DATA` on the spawned process, so a script can read `process.env.CLAUDE_PLUGIN_ROOT` regardless of how it was launched." ([Hooks reference, code.claude.com](https://code.claude.com/docs/en/hooks))

**Portability constraints:**
- **Use POSIX sh, not bash:** For maximum portability across managed projects (which may lack bash), write hook scripts in POSIX sh (`#!/bin/sh`)
- **Avoid bash-isms:** Conditional expression syntax (`[[ ]]`, process substitution, etc.) breaks on systems with only `/bin/sh`
- **Precedent:** loom's own config sets identity as `Craig Pfeiffer <craigeous@gmail.com>`; this single uniform identity across roles is the enforcement target (ADR 0003)

### 5. Gotchas

1. **`${CLAUDE_PLUGIN_ROOT}` not set for some hook events:** SessionStart hooks and UserPromptSubmit hooks have reported issues where the environment variable is not injected, though PreToolUse appears reliable ([Issue #27145 and #36585, github.com/anthropics/claude-code](https://github.com/anthropics/claude-code/issues/27145))

2. **Exit code 1 is not a blocking error:** Conventional Unix return code 1 for failure does **not** block; only exit code 2 blocks PreToolUse. Exit 1 = non-blocking error that lets the tool proceed ([Hooks reference, code.claude.com](https://code.claude.com/docs/en/hooks))

3. **Hook output shown to user/model:** Anything written to stderr (when exit 2) is fed back as Claude's error message, which Claude then receives and can act on. Avoid sensitive information in stderr ([Hooks reference guide, code.claude.com](https://code.claude.com/docs/en/hooks-guide))

4. **Known issue: Plugin command hooks silently dropped for some events:** There is a reported bug where command hooks in `hooks/hooks.json` for PreToolUse are silently dropped during plugin loading, while prompt hooks on the same event load correctly ([Issue #34573, github.com/anthropics/claude-code](https://github.com/anthropics/claude-code/issues/34573)). **Workaround:** Use `type: "prompt"` with an LLM-based hook instead, or inline the hook in `.claude-plugin/plugin.json` as an alternative structure.

5. **Performance:** Hooks block the agentic loop (synchronous), so slow scripts will delay Claude. Keep guard scripts fast (parse, match, exit).

6. **Matcher edge cases:** The "if" field for further filtering (e.g., `"Bash(git *)"`) uses permission rule syntax; ensure command patterns are correctly escaped in JSON.

## Git Identity Override Methods (Attack Surface)

Based on git internals, the following flags/environment variables override author identity and must be blocked:

**Command-line flags:**
- `--author=<name> <email>` (exact format: `--author="Name <email@domain.com>"` or pattern search)
- `-c user.name=<value>` (config override flag)
- `-c user.email=<value>` (config override flag)
- `-c GIT_AUTHOR_NAME=<value>` (setting env vars via -c, rarely used)

**Environment variables:**
- `GIT_AUTHOR_NAME` (overrides `user.name` config)
- `GIT_AUTHOR_EMAIL` (overrides `user.email` config)
- `GIT_COMMITTER_NAME` (overrides `user.name` for committer field)
- `GIT_COMMITTER_EMAIL` (overrides `user.email` for committer field)
- `GIT_AUTHOR_DATE` (overrides timestamp; blocks identity but included for completeness)
- `GIT_COMMITTER_DATE` (same; included for completeness)

**Precedence (high to low):**
1. `--author=` flag
2. `-c user.name=` / `-c user.email=` flags
3. Environment variables (`GIT_AUTHOR_*`)
4. Git config (`user.name`, `user.email`)

([Git Environment Variables, git-scm.com](https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables); [git-commit docs, git-scm.com](https://git-scm.com/docs/git-commit))

## Recommended Implementation

### File Structure
```
plugins/loom/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   └── guard-git-author.sh
```

### `hooks/hooks.json`
```json
{
  "description": "Guard against overridden git author identity",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git *)",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/guard-git-author.sh"
          }
        ]
      }
    ]
  }
}
```

### `hooks/guard-git-author.sh` (POSIX portable outline)

```sh
#!/bin/sh
# Guard against git author identity override via flags or environment variables.
# Blocks: --author=, -c user.name=, -c user.email=, GIT_AUTHOR_*, GIT_COMMITTER_*

# Read hook input from stdin
INPUT=$(cat)

# Extract the bash command string (tool_input.command field)
COMMAND=$(printf '%s\n' "$INPUT" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)

# Reject if command is empty
if [ -z "$COMMAND" ]; then
  echo "Error: could not parse git command from hook input" >&2
  exit 2
fi

# Check for author override flags in the command
if printf '%s\n' "$COMMAND" | grep -qE '(--author=|--author[[:space:]]+|git[[:space:]]+-c[[:space:]]+(user\.(name|email)|GIT_AUTHOR|GIT_COMMITTER)=)'; then
  cat >&2 <<'ERRBLOCK'
Blocked: git command attempts to override author identity via:
  --author= flag
  -c user.name= or -c user.email= flag
  -c GIT_AUTHOR_* or -c GIT_COMMITTER_* variable

loom commits must use the uniform configured identity (Craig Pfeiffer <craigeous@gmail.com>).
See .docs/ADR/0003-cold-handoffs-commit-per-handoff.md for rationale.
ERRBLOCK
  exit 2
fi

# Check for author override environment variables in the command
# (e.g., GIT_AUTHOR_NAME=... git commit)
if printf '%s\n' "$COMMAND" | grep -qE '(GIT_AUTHOR_NAME|GIT_AUTHOR_EMAIL|GIT_COMMITTER_NAME|GIT_COMMITTER_EMAIL|GIT_AUTHOR_DATE|GIT_COMMITTER_DATE)='; then
  cat >&2 <<'ERRBLOCK'
Blocked: git command attempts to override author identity via environment variables:
  GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL
  GIT_COMMITTER_NAME, GIT_COMMITTER_EMAIL
  GIT_AUTHOR_DATE, GIT_COMMITTER_DATE

loom commits must use the uniform configured identity (Craig Pfeiffer <craigeous@gmail.com>).
See .docs/ADR/0003-cold-handoffs-commit-per-handoff.md for rationale.
ERRBLOCK
  exit 2
fi

# No override detected; allow the command
exit 0
```

## Open Questions

1. **Session persistence:** Will `${CLAUDE_PLUGIN_ROOT}` reliably resolve at hook execution time for PreToolUse in all tested Claude Code versions? (Recommend manual testing post-implementation.)

2. **Command hook bug status:** Is Issue #34573 (command hooks silently dropped) still present in the current Claude Code release? If so, should the guard be implemented as a prompt-based hook instead?

3. **JSON parsing robustness:** The outlined guard script uses `grep` to extract the command from JSON stdin. For production, consider using `jq` (if available) or a more robust JSON parser to handle escaped characters in commands. The current approach assumes command strings don't contain literal `\"` sequences.

## Sources

- [Plugins reference - Claude Code Docs](https://code.claude.com/docs/en/plugins-reference)
- [Hooks reference - Claude Code Docs](https://code.claude.com/docs/en/hooks)
- [Automate actions with hooks - Claude Code Docs](https://code.claude.com/docs/en/hooks-guide)
- [Git Environment Variables - git-scm.com](https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables)
- [git-commit Documentation - git-scm.com](https://git-scm.com/docs/git-commit)
- [Hook executor doesn't set CLAUDE_PLUGIN_ROOT - Issue #24529 - github.com/anthropics/claude-code](https://github.com/anthropics/claude-code/issues/24529)
- [CLAUDE_PLUGIN_ROOT environment variable not set for SessionStart hooks - Issue #27145 - github.com/anthropics/claude-code](https://github.com/anthropics/claude-code/issues/27145)
- [CLAUDE_PLUGIN_ROOT not passed to UserPromptSubmit hooks - Issue #36585 - github.com/anthropics/claude-code](https://github.com/anthropics/claude-code/issues/36585)
- [Plugin hooks.json: command hooks silently dropped for PreToolUse/PostToolUse events - Issue #34573 - github.com/anthropics/claude-code](https://github.com/anthropics/claude-code/issues/34573)
- [Portable Shell - Autoconf Manual](https://www.gnu.org/software/autoconf/manual/autoconf-2.64/html_node/Portable-Shell.html)

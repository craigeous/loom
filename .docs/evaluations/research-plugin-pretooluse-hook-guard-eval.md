# Evaluation: 2026-06-08-plugin-pretooluse-hook-guard

Verdict: PASS
Round: 1
Reviewed against: the note's cited sources — Claude Code docs (hooks reference,
plugins reference, hooks-guide), git-scm (git-commit, environment-variables), and
GitHub issues anthropics/claude-code #34573, #27145, #36585, #24529.

## Findings

All five load-bearing claims are cited and confirmed against authoritative sources
(official Claude Code docs and git-scm), with one minor over-statement noted.

- [MINOR] "permissionDecisionReason field is required" for `deny` (line 87) is an
  over-statement. The PreToolUse decision-control table in the hooks reference says
  the reason for `"deny"` is "shown to Claude" but does not state it is strictly
  required. Not load-bearing — the chosen approach is Method A (exit 2 + stderr),
  which does not use this field.
- [MINOR] The stdin-shape example (lines 44-60) embellishes the documented schema
  with an `effort.level` object and a `permission_mode` enum that includes values
  ("auto", "dontAsk") not enumerated on the cited page. The load-bearing field
  (`tool_input.command`) is correct and confirmed; the surrounding extras are
  decorative and could mislead an implementer into depending on unverified fields.
- [MINOR] Gotchas 1 and 4 and Open Question 2 cite GitHub issues (#34573, #27145,
  #36585, #24529) that are all **closed**. The cited titles and #34573's body match
  exactly, so the citations are accurate; but the note frames them as live
  reliability risks without flagging closed status. The note's own Open Question 2
  ("is #34573 still present in the current release?") correctly defers this to
  post-implementation testing, which is the right disposition.

## Verified claims (no findings)

1. **Hook file location** — CONFIRMED. Plugins reference states verbatim:
   "Location: `hooks/hooks.json` in plugin root, or inline in plugin.json." Matches
   note lines 11-12. Local-tree claim (no hooks declared in plugin.json, no
   `hooks/` dir) independently verified.
2. **Block mechanism — exit 2 (not 1)** — CONFIRMED. Hooks reference: "PreToolUse |
   Yes | Blocks the tool call" on exit 2; "Claude Code treats exit code 1 as a
   non-blocking error and proceeds." The `permissionDecision: "deny"` JSON schema
   (`hookSpecificOutput.hookEventName/permissionDecision/permissionDecisionReason`)
   and the allow/deny/ask/defer value set are confirmed.
3. **stdin shape — `tool_input.command`** — CONFIRMED. Doc shows
   `COMMAND=$(jq -r '.tool_input.command')` and the matching JSON example.
4. **`${CLAUDE_PLUGIN_ROOT}` availability** — CONFIRMED. Doc: both command and HTTP
   forms "export them as the environment variables CLAUDE_PROJECT_DIR,
   CLAUDE_PLUGIN_ROOT, and CLAUDE_PLUGIN_DATA on the spawned process." The note's
   verbatim quote (line 101) matches.
5. **Dropped-command-hook caveat** — SOURCED and material. Issue #34573 exists with
   the exact cited title and a body describing command hooks silently dropped for
   PreToolUse/PostToolUse while prompt hooks load. It materially affects the
   approach (the note's prompt-hook fallback is a reasonable hedge).
6. **Attack surface (git overrides)** — CONFIRMED. git-commit docs show
   `--author=<author>`; the environment-variables page documents `GIT_AUTHOR_NAME/
   EMAIL/DATE`, `GIT_COMMITTER_*`, and that env vars apply over config "only if
   these aren't present," supporting the precedence ordering.

## Required changes (for FAIL)

None — no blockers and no unaddressed majors.

## Notes

Every load-bearing claim is sourced to the authoritative origin (official Claude
Code docs for hook mechanics, git-scm for git internals, the anthropics/claude-code
tracker for the caveat) and each was spot-checked to actually support the summary.
All nine cited URLs resolve (HTTP 200).

Optional polish for a future revision (none blocking): trim the stdin example to
the documented fields, soften "required" to "shown to Claude" for the deny reason,
and annotate the cited issues as closed-pending-reverify. These are hygiene, not
correctness, and do not gate approval under the research light-gate.

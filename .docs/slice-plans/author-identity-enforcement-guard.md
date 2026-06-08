# Author-identity enforcement guard (PreToolUse hook + doc hardening)

Status: Plan Review
Target specs: (none — playbook/plugin hardening; aligns with ADR 0003)

## Context

ADR 0003 requires that **all loom roles commit under one uniform git
author/committer identity**, so the blind code evaluator cannot infer the
producing role from commit metadata. Today this is enforced only by prose: the
playbook reference `plugins/loom/skills/loom-playbook/references/commit-convention.md`
tells roles not to set or override git identity. There is no mechanical guard, and
the prose only forbids two of the override paths (`git -c user.*=...` and
`git config user.*`) — it does **not** mention the `--author=` flag or the
`GIT_AUTHOR_*` / `GIT_COMMITTER_*` environment variables, which also override
identity (precedence per git-scm: `--author=` > `-c user.*` > `GIT_*` env >
config).

This slice adds **two layers** for one purpose — *enforce uniform commit
identity*:

1. **Defense-in-depth hook (best-effort):** a Claude Code plugin PreToolUse hook
   that runs a POSIX-sh guard script before any `Bash` tool call, and blocks
   (exit 2) any `git`-bearing command that overrides author/committer identity.
2. **Doc hardening (the reliable layer):** extend `commit-convention.md` to forbid
   all override paths explicitly and to note that the hook enforces it.

**Why the doc is the reliable layer, not the hook.** The approved research
(`.docs/research/2026-06-08-plugin-pretooluse-hook-guard.md`, Gotcha 4 / Open
Question 2) documents a known Claude Code issue
([anthropics/claude-code #34573](https://github.com/anthropics/claude-code/issues/34573))
in which **plugin command hooks in `hooks/hooks.json` can be silently dropped for
PreToolUse**, while prompt hooks load. Whether the bug is live in a given Claude
Code version cannot be verified from this repo, and end-to-end hook *firing*
inside Claude Code cannot be guaranteed here. Therefore this plan treats the hook
as **best-effort defense-in-depth** and the doc rule as the authoritative,
always-present layer. The slice's *acceptance basis* is direct, script-level
testing of the guard (which is fully deterministic), not in-session firing.

What exists today (verified against the tree):
- `plugins/loom/.claude-plugin/plugin.json` declares **no** `hooks` key, and
  `plugins/loom/hooks/` does **not** exist.
- `commit-convention.md` has a "One uniform git identity" bullet covering
  `git -c user.*=...` and `git config user.*` only.
- ADR 0003 (lines 30–39) is the rationale; it is immutable and **not** edited here.

Out of scope:
- Editing ADR 0003 or any `.docs/spec/` (immutable / frozen authority).
- Detecting non-identity attacks (e.g. `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` are
  date overrides, not identity; **not** blocked here to keep the guard's single
  purpose tight and avoid false positives on legitimate replay/import flows).
- Any change to orchestrator/role command prompts beyond the playbook reference.
- Converting the hook to a `type: "prompt"` hook (the research's fallback for
  #34573); deferred — recorded as a Note if script-level acceptance is fine and
  the doc layer covers the gap.

## Steps

### Hook-location decision (verified)

Per the research (lines 11–12, eval claim 1, both confirmed against the Plugins
reference): plugin hooks live in **`hooks/hooks.json` in the plugin root** and are
auto-discovered there; the `.claude-plugin/plugin.json` `hooks` key is only an
*alternative* inline form. **Therefore do NOT add a `hooks` pointer to
`plugin.json`** — `hooks/hooks.json` is the standard auto-discovered location and a
pointer would be redundant. Step 3 is intentionally a no-op verification, not an
edit.

### Matcher decision (verified)

The research's example uses matcher `"Bash(git *)"` (permission-rule syntax with an
implicit "if" filter). The plan instead uses the **plain documented tool-name
matcher `"Bash"`** and gates on `git` **inside the script**. Rationale: (a) `"Bash"`
is the literal, documented matcher value (research line 34, eval claim 1); (b) the
research itself flags matcher "if"-field escaping as an edge case (Gotcha 6); (c)
the script must inspect the full command anyway (to catch `VAR=... git ...` and
`export`), so the script is the single, testable place that decides. This keeps the
guard's correctness fully verifiable by the script-level tests in Verification.

1. **Create `plugins/loom/hooks/hooks.json`** (new file). Declare a PreToolUse hook
   matching the `Bash` tool that runs the shipped guard via `${CLAUDE_PLUGIN_ROOT}`.
   Exact content:

   ```json
   {
     "description": "Block git commands that override the uniform commit identity (ADR 0003).",
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/git-identity-guard.sh\""
             }
           ]
         }
       ]
     }
   }
   ```

   Notes: the `hooks` wrapper object is required for plugin hook files (research
   line 26). `${CLAUDE_PLUGIN_ROOT}` is exported to the spawned process and expanded
   in the JSON `command` (research line 99–101, eval claim 4). The path is quoted to
   tolerate spaces in the plugin root.

2. **Create `plugins/loom/hooks/git-identity-guard.sh`** (new file, `#!/bin/sh`,
   **executable** — `chmod +x`). POSIX sh only (no `[[ ]]`, no bash-isms; research
   lines 103–105). Behavior:

   - Read all of stdin into `INPUT`.
   - Extract `tool_input.command`. **Use `jq` if available, with a grep fallback**
     (jq may be absent in managed projects): if `command -v jq` succeeds, use
     `jq -r '.tool_input.command // empty'`; else fall back to a `grep`/`sed`
     extraction of the `"command"` value. (The grep fallback is best-effort on
     heavily-escaped JSON, acknowledged in research Open Question 3; this is
     acceptable because the hook is defense-in-depth and the doc is authoritative.)
   - **If the extracted command is empty → allow (exit 0).** Rationale: an empty or
     unparseable command is not a detected identity override; failing *open* here
     keeps the best-effort hook from blocking unrelated/odd `Bash` calls. (This
     deliberately differs from the research sketch, which exited 2 on empty — that
     would block legitimate non-git or parse-miss commands and cause false
     positives. The doc layer, not a fail-closed hook, is the reliable guarantee.)
   - **Only act on `git`-bearing commands** to avoid false positives: proceed to the
     override checks only if the command matches `git` as a word — i.e. matches the
     ERE `(^|[^[:alnum:]_./-])git([[:space:]]|$)` OR contains a `GIT_AUTHOR_*` /
     `GIT_COMMITTER_*` env-var assignment (an inline `VAR=... git ...` always has
     `git`, so the word-match covers it; the env check is the trigger that also
     catches the assignment itself). If neither, **exit 0** (e.g. `ls`,
     `digit=...`, `legitimate=1` won't match the `git` *word*).
   - **Detection — block (exit 2) if the git command contains ANY of:**
     - `--author=` **or** `--author ` (flag form with `=` or a following space).
       ERE: `--author([[:space:]]|=)`.
     - `-c user.name=` / `-c user.email=` / any `-c user.*=` config override.
       ERE: `-c[[:space:]]+user\.[A-Za-z]+=`.
     - `-c GIT_AUTHOR...=` / `-c GIT_COMMITTER...=` (setting identity env via `-c`).
       ERE: `-c[[:space:]]+(GIT_AUTHOR|GIT_COMMITTER)[A-Z_]*=`.
     - Inline or `export`ed identity env vars:
       `GIT_AUTHOR_NAME=` / `GIT_AUTHOR_EMAIL=` / `GIT_COMMITTER_NAME=` /
       `GIT_COMMITTER_EMAIL=`. ERE:
       `(GIT_AUTHOR_(NAME|EMAIL)|GIT_COMMITTER_(NAME|EMAIL))=`. This matches both
       `GIT_AUTHOR_NAME=x git commit ...` and `export GIT_AUTHOR_NAME=x; git ...`.
   - On any match: write a **clear stderr message** naming the specific violation
     class and the rule, then **exit 2**. Per the eval's MINORs, the exit-2 method
     needs **only** exit code + stderr — do **not** emit `permissionDecision` /
     `permissionDecisionReason` JSON (that belongs to the unused Method B), and do
     **not** depend on any stdin field other than `tool_input.command`. The stderr
     message must state: which override class was detected; that loom requires one
     uniform identity per **ADR 0003**; and that the fix is a plain `git commit`
     under the repo's configured identity (do not print a specific name/email — keep
     it generic). Keep it concise (research Gotcha 3: stderr is fed back to Claude).
   - If `git`-bearing but no override matched → **exit 0** (allow), e.g.
     `git commit -m "msg"`, `git -c core.pager=cat log` (note: `-c core.*` is a
     non-identity config and must **not** be blocked — the `-c user.*` /
     `-c GIT_AUTHOR/COMMITTER` patterns are scoped to identity keys only).

   The script must be ordered: parse → empty-check (allow) → git-word/env gate
   (else allow) → override checks (block) → final allow. Keep it fast (research
   Gotcha 5).

3. **`plugins/loom/.claude-plugin/plugin.json` — NO edit (verification only).**
   Confirm `hooks/hooks.json` is the auto-discovered location and that no `hooks`
   pointer is required in `plugin.json` (see Hook-location decision above). Leave
   `plugin.json` byte-for-byte unchanged. The developer must confirm `git diff`
   shows **no** change to this file.

4. **Harden `plugins/loom/skills/loom-playbook/references/commit-convention.md`.**
   In the "One uniform git identity" bullet (currently lines 16–20), extend the
   forbidden-override list so it covers **all** identity-override paths, not just
   `git config` / `-c user.*`. The revised bullet must explicitly forbid:
   - `git commit --author=...` (the `--author` flag),
   - `git -c user.name=...` / `git -c user.email=...` (and any `-c user.*`),
   - the environment variables `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`,
     `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` (inline `VAR=... git ...` or
     `export`), in addition to the existing `git config user.*` prohibition.

   Add one sentence stating that a **plugin PreToolUse hook**
   (`plugins/loom/hooks/git-identity-guard.sh`) enforces this by blocking such
   commands, **and** that the hook is best-effort defense-in-depth (it may not fire
   in every Claude Code version per a known issue) so **this rule is binding
   regardless of whether the hook fires**. Keep the existing "stop and ask if no
   identity is configured / never commit as `loom <loom@localhost>`" guidance and
   the rest of the file (other Rules bullets, Message shape, Examples) unchanged.
   Keep wording consistent with ADR 0003 (uniform identity rationale).

5. **Update the slice-plans index** `.docs/slice-plans/README.md`: add this plan to
   the **Active plans** section (replacing the `(none)` placeholder) with a one-line
   description: author-identity enforcement guard — PreToolUse hook
   (`plugins/loom/hooks/`) + `commit-convention.md` hardening; enforces ADR 0003's
   uniform commit identity.

## Verification

This is a markdown/prompt repo with no compiled gate (CLAUDE.md), **but this slice
ships an executable script and a JSON config that are directly testable**, so
script-level testing is **required** and is the acceptance basis. The developer
must run each check below and **record the actual observed exit codes / output as
evidence** in this plan's Notes (dated).

Run each from the repo root.

**A. Hook config is valid JSON.**
```
jq . plugins/loom/hooks/hooks.json
```
Must succeed (exit 0) and echo the parsed object. Confirm `matcher` is `"Bash"`,
`type` is `"command"`, and `command` references `${CLAUDE_PLUGIN_ROOT}/hooks/git-identity-guard.sh`.

**B. Script is executable POSIX sh.** `ls -l plugins/loom/hooks/git-identity-guard.sh`
shows the executable bit; first line is `#!/bin/sh`. Optionally
`sh -n plugins/loom/hooks/git-identity-guard.sh` (syntax check) exits 0.

**C. BLOCKED cases — each must print `2`.** Pipe crafted stdin and echo `$?`:
```
echo '{"tool_input":{"command":"git commit --author=\"x <x@y>\" -m z"}}' | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git -c user.email=x@y commit -m z"}}'    | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git -c user.name=Foo commit -m z"}}'     | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"GIT_AUTHOR_NAME=Foo git commit -m z"}}'  | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"export GIT_COMMITTER_EMAIL=x@y; git commit -m z"}}' | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit --author bar -m z"}}'         | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
```
Every one must print `2` and write a clear stderr message naming the violation and
ADR 0003.

**D. ALLOWED cases — each must print `0`.**
```
echo '{"tool_input":{"command":"git commit -m \"msg\""}}'          | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git -c core.pager=cat log"}}'      | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"ls -la"}}'                         | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"echo legitimate=1"}}'              | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
```
Every one must print `0` (no false positive on `-c core.*`, on non-git commands,
or on the substring `git` inside another word).

**E. jq-absent fallback (best-effort).** Re-run at least one BLOCKED case (C) and
one ALLOWED case (D) with `jq` made unavailable, e.g. by running the script with a
`PATH` that excludes jq:
```
echo '{"tool_input":{"command":"git commit --author=x -m z"}}' | PATH=/usr/bin sh plugins/loom/hooks/git-identity-guard.sh; echo $?   # expect 2
echo '{"tool_input":{"command":"git commit -m z"}}'            | PATH=/usr/bin sh plugins/loom/hooks/git-identity-guard.sh; echo $?   # expect 0
```
(Choose a PATH on the test machine that lacks `jq` but has `sh`/`grep`/`sed`.)
Confirms the grep fallback path preserves the block/allow decision.

**F. Doc + scope checks.**
- `commit-convention.md` now names `--author=`, `-c user.*`, and
  `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env vars, and states the hook enforces this as
  best-effort defense-in-depth (rule binding regardless).
- `git diff --name-only` lists exactly: `plugins/loom/hooks/hooks.json`,
  `plugins/loom/hooks/git-identity-guard.sh`, `commit-convention.md`,
  `.docs/slice-plans/README.md`, and this plan — and **not** `plugin.json`
  (Step 3 is a no-op) nor any `.docs/spec/` or ADR file.

**End-to-end caveat (not a gate).** In-session firing of the hook inside Claude
Code cannot be guaranteed in this repo (known issue #34573; research Gotcha 4 /
Open Question 2). Script-level checks A–F are the acceptance basis; the
`commit-convention.md` rule is the reliable layer that covers the gap. The
developer **should** additionally attempt a live sanity check if a Claude Code
session is available (run a blocked command and observe the deny) and record the
result, but a non-firing live check does **not** fail this slice.

## Notes

- **Filename (planner, 2026-06-08):** the task fixes the script name as
  `git-identity-guard.sh`; the research sketch used `guard-git-author.sh`. The
  task name is authoritative and used throughout.
- **Two deliberate divergences from the research sketch (planner, 2026-06-08):**
  (1) matcher is `"Bash"` (plain documented tool name) with the `git` gate in the
  script, not `"Bash(git *)"`, per the Matcher decision above; (2) the script
  **allows** (exit 0) on empty/unparseable command rather than exit 2 — failing
  open avoids false-positive blocks of unrelated `Bash` calls, and the doc layer
  (not a fail-closed hook) is the reliable guarantee per the defense-in-depth
  framing.
- **Eval MINORs honored (planner, 2026-06-08):** the script uses only exit
  code 2 + stderr (no `permissionDecision`/`permissionDecisionReason`), and
  depends only on the documented `tool_input.command` stdin field.
- **Prompt-hook fallback deferred (planner, 2026-06-08):** if a future Claude Code
  version is confirmed to drop the command hook (#34573), converting to a
  `type: "prompt"` hook is the research's recommended hedge; out of scope for this
  slice because acceptance is script-level and the doc layer is authoritative.

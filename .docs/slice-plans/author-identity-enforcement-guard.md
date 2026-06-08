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

This plan is informed by the approved research note
`.docs/research/2026-06-08-plugin-pretooluse-hook-guard.md` and its evaluation at
`.docs/evaluations/research-plugin-pretooluse-hook-guard-eval.md` (both verified
to resolve against the tree).

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
     override checks only if `$STRIPPED` (the de-quoted command, defined below)
     matches `git` as a word — i.e. matches the
     ERE `(^|[^[:alnum:]_./-])git([[:space:]]|$)` OR contains a `GIT_AUTHOR_*` /
     `GIT_COMMITTER_*` env-var assignment (an inline `VAR=... git ...` always has
     `git`, so the word-match covers it; the env check is the trigger that also
     catches the assignment itself). If neither, **exit 0** (e.g. `ls`,
     `digit=...`, `legitimate=1` won't match the `git` *word*). Gating on
     `$STRIPPED` also means `git commit -m "set GIT_AUTHOR_NAME=foo"` is evaluated
     by the override checks (it is a real `git` command) but, because the env
     assignment was inside the stripped message body, no override token remains →
     it falls through to the final allow.
   - **Strip quoted substrings BEFORE override detection (flag-vs-text
     discrimination).** Override syntax (`--author=`, `GIT_AUTHOR_NAME=`,
     `-c user.*=`) is legitimate when it appears inside the *value* of a message-
     bearing option (`-m "..."`, `-F`, `--message=...`) or a `--grep`/path
     argument — that text is not a real flag/assignment token and must NOT block.
     A real override token always lives **outside** any quoted region (a flag like
     `--author=` or an inline `VAR=` assignment cannot be inside the message
     string and still take effect). So: build a **de-quoted copy** of the command
     by removing the *contents* of every single-quoted and double-quoted segment,
     then run all override patterns on that de-quoted copy (not the raw command).

     De-quoting is a **three-stage, ordered** transform (belt-and-suspenders).
     Stage order matters — earlier stages must run before later ones:

     **Stage A — remove backslash-escaped quote characters FIRST.** Delete every
     `\"` and `\'` from the working copy *before* stripping any quoted body. This
     is what defeats the escaped-inner-quote false-positive: an escaped quote inside
     a message (`-m "use \"--author=\" flag"`) is not a real quote delimiter, so
     removing it first lets the surrounding *real* `"..."` body strip cleanly as one
     span (carrying the in-message `--author=` away with it) instead of the body-strip
     `sed` mis-pairing across the `\"` and leaving the token exposed. Critically,
     Stage A is a **no-op on real overrides**, because a genuine `--author="x"` /
     `-c user.email=x` / inline `VAR=` token contains no backslash-escaped quotes —
     so removing `\"`/`\'` cannot erase a real override token (verified below).

     **Stage B — strip the contents (and delimiters) of every quoted segment.**
     After Stage A, delete each `'...'` and `"..."` span. A real flag/assignment
     token sits *before* the opening quote of its value (or is wholly unquoted), so
     it survives Stage B; only message/argument text is removed.

     ```
     DEESC=$(printf '%s' "$CMD" | sed -e 's/\\"//g' -e "s/\\\\'//g")
     STRIPPED=$(printf '%s' "$DEESC" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')
     ```

     - Stage A: `s/\\"//g` deletes `\"`; `s/\\'//g` deletes `\'` (POSIX sed; the
       backslash is doubled in the shell single-/double-quoted literals above).
     - Stage B: `s/'[^']*'//g` deletes each `'...'` segment; `s/"[^"]*"//g` deletes
       each `"..."` segment.

     **Stage C — fail-open backstop on ambiguous quoting.** After Stages A+B, if
     `$STRIPPED` **still** contains an unbalanced (odd) count of `"` or `'`
     characters, the command's quoting could not be cleanly resolved — so
     **exit 0 (allow)** without running any override check. This is a *deliberate*
     fail-open: the guard never blocks a command whose quoting it cannot parse
     (consistent with defense-in-depth — the doc layer is the authoritative
     guarantee). It does not create a false-negative for clean overrides, because a
     cleanly-parsed real override (`--author=evil`, `-c user.email=x`,
     `VAR= git ...`) leaves an *even* (typically zero) quote count in `$STRIPPED`
     and so passes the backstop into the override checks. Concretely:

     ```
     DQ=$(printf '%s' "$STRIPPED" | tr -cd '"' | wc -c | tr -d ' ')
     SQ=$(printf '%s' "$STRIPPED" | tr -cd "'" | wc -c | tr -d ' ')
     if [ $((DQ % 2)) -ne 0 ] || [ $((SQ % 2)) -ne 0 ]; then exit 0; fi
     ```

     Run BOTH the `git`-word gate's existence checks **and** all override EREs
     below against `$STRIPPED` (the Stage A+B output that passed the Stage C
     backstop). (Run the env-var trigger of the git gate against `$STRIPPED` too, so
     `git commit -m "set GIT_AUTHOR_NAME=foo"` does not even trip the gate.)
     Detection is entirely on `$STRIPPED`, never on the raw `$CMD`.

     Worked discrimination (prototyped — all confirmed):
     - `git commit -m "fix --author= parsing"` → body stripped → no `--author=`
       outside quotes → **ALLOW**.
     - `git commit -m "set GIT_AUTHOR_NAME=foo"` → assignment is inside the quoted
       body → stripped → **ALLOW**.
     - `git log --grep="--author="` → `--grep` is not an identity flag and its
       quoted value is stripped → **ALLOW**.
     - `git commit --author="x <x@y>"` → the **value** is stripped but the
       `--author=` flag token sits *before* the opening quote and survives →
       **BLOCK** (this is exactly why quoting a real override does not hide it).
     - `git commit --author=foo` (unquoted) → survives stripping → **BLOCK**.
     - `GIT_AUTHOR_NAME=foo git commit -m "msg"` → the inline assignment is
       outside quotes → survives → **BLOCK**; only the `"msg"` value is stripped.
     - `git -c user.email=x@y commit -m z` → `-c user.email=` is unquoted →
       survives → **BLOCK**.
     - `git commit -m "use \"--author=\" flag carefully"` → Stage A removes the two
       `\"` → `... -m "use --author= flag carefully"` → Stage B strips the now-clean
       `"..."` body (carrying `--author=` with it) → `git commit -m ` → no token →
       **ALLOW**. (Under the old ordering this wrongly BLOCKED.)
     - `git commit -m "mention \"GIT_AUTHOR_NAME=x\" here"` → Stage A removes `\"` →
       Stage B strips the body → no token → **ALLOW**.
     - `git commit -m "note \"-c user.email=\" thing"` → same path → **ALLOW**.
     - `git commit -m "wip` (genuinely unbalanced quoting) → Stages A/B cannot
       resolve the lone `"`; Stage C sees an odd quote count → **ALLOW** (fail open,
       never block on unparseable quoting).

     **Documented limitation — fail-open on unparseable quoting (corrected).**
     The earlier draft of this plan claimed escaped inner quotes could *only* fail
     open; that was wrong. With a naïve single body-strip, deleting the contents and
     boundaries of a *mis-paired* quote span can **expose** an override token that was
     genuinely inside the message, so the guard would **false-positive (fail
     **closed**)** and block a legitimate commit such as
     `git commit -m "use \"--author=\" flag carefully"`. That is exactly the
     "blocks legitimate commits" failure mode. The Stage A escaped-quote pre-removal
     above **eliminates** that subclass (verified: all three escaped-inner-quote
     messages now ALLOW). For any *remaining* quoting the transform still cannot
     resolve cleanly (e.g. a truly unbalanced quote), the **Stage C backstop fails
     open (exit 0)** — the guard never blocks a command whose quoting it could not
     parse. Net residual: the guard may, at worst, **fail open** (not block) on a
     pathological hand-crafted quoting payload — consistent with defense-in-depth,
     where the `commit-convention.md` doc rule is the authoritative guarantee. It
     does **not** fail closed on any case in the Verification matrix. A
     cleanly-parsed real override is never allowed by Stage C, because its
     `$STRIPPED` quote count is even (the override token is unquoted), so it always
     reaches — and is caught by — the override checks (verified by D3).

   - **Detection — block (exit 2) if `$STRIPPED` (the de-quoted command) contains
     ANY of:**
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

   The script must be ordered: parse `$CMD` → empty-check (allow) →
   **Stage A** (remove `\"`/`\'` → `$DEESC`) → **Stage B** (strip `'...'`/`"..."`
   bodies → `$STRIPPED`) → **Stage C** (odd quote count in `$STRIPPED` → allow,
   fail-open backstop) → git-word/env gate on `$STRIPPED` (else allow) → override
   checks on `$STRIPPED` (block) → final allow. All pattern matching (gate and
   overrides) runs on `$STRIPPED`, never on the raw `$CMD`. Keep it fast (research
   Gotcha 5; de-quoting is two short `sed` passes plus a `tr`/`wc` quote count).

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

**D2. ALLOWED — override syntax appearing only inside message/argument TEXT —
each must print `0`.** These are the false-positive cases the quote-stripping in
Step 2 must defeat; a regression here means detection is scanning the raw command
again. (Note: this very slice's own commit message — "guard against `--author`
flag" — is the second case, so a guard that fails this would block its own commit.)
```
echo '{"tool_input":{"command":"git commit -m \"fix --author= parsing\""}}'        | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit -m \"guard against --author flag\""}}'  | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit -m \"set GIT_AUTHOR_NAME=foo in script\""}}' | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit -m \"add -c user.email= override\""}}'  | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git log --grep=\"--author=\""}}'                   | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
```
Every one must print `0`.

**D3. Adversarial — a real override whose VALUE is quoted must still BLOCK
(print `2`).** Confirms quote-stripping does not create a new false-negative: the
flag/assignment token lives outside the quotes and survives stripping. The third
case proves Stage A (escaped-quote removal) is a **no-op on real overrides** — it
combines a real `--author=` with an escaped quote elsewhere and must still block.
```
echo '{"tool_input":{"command":"git commit --author=\"evil <e@e>\" -m \"ok\""}}'   | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit --author \"evil <e@e>\""}}'             | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit --author=evil -m \"say \\\"hi\\\"\""}}' | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
```
All three must print `2`.

**D4. ALLOWED — override syntax inside ESCAPED inner quotes within a message —
each must print `0`.** These are the Round-2 MAJOR cases: a legitimate commit whose
message contains an override token between backslash-escaped inner double-quotes.
Stage A removes the `\"` pair before Stage B strips the (now-clean) outer `"..."`
body, so the in-message token is carried away and no override survives. (In the JSON
stdin below, each in-message `\"` is encoded as `\\\"`.)
```
echo '{"tool_input":{"command":"git commit -m \"use \\\"--author=\\\" flag carefully\""}}'   | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit -m \"mention \\\"GIT_AUTHOR_NAME=x\\\" here\""}}'  | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
echo '{"tool_input":{"command":"git commit -m \"note \\\"-c user.email=\\\" thing\""}}'       | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
```
Every one must print `0`. (Sanity-check the decoded command with
`jq -r '.tool_input.command'` first if unsure of the encoding — the decoded form is
`git commit -m "use \"--author=\" flag carefully"`, etc.)

**D5. ALLOWED — genuinely unparseable (unbalanced) quoting fails OPEN — must print
`0`.** Proves the Stage C backstop never blocks a command whose quoting it cannot
resolve cleanly.
```
echo '{"tool_input":{"command":"git commit -m \"wip"}}'   | sh plugins/loom/hooks/git-identity-guard.sh; echo $?
```
Must print `0`.

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
- **Round-1 FAIL revision (planner, 2026-06-08):** the eval
  (`.docs/evaluations/author-identity-enforcement-guard-eval.md`) found a BLOCKER —
  override EREs ran against the raw command, so a commit whose *message* mentioned
  `--author=` / `GIT_AUTHOR_NAME=` was wrongly blocked. Fix: Step 2 now strips the
  contents of all single- and double-quoted segments
  (`sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g'`) into `$STRIPPED` and runs the
  git-word gate **and** all override patterns on `$STRIPPED`, never on the raw
  command. A real flag/assignment token sits outside the quotes and survives, so
  quoting an override's value does not hide it (verified). Verification gained
  Section D2 (five message-text ALLOW cases, each must print `0`) and D3 (adversarial
  quoted-value overrides, each must print `2`). MINOR path-drift fixed: Context
  now cites the research eval at its real path. All eval-confirmed items
  (detection completeness, exit-2, POSIX sh, jq+fallback, `${CLAUDE_PLUGIN_ROOT}`,
  hooks.json location, fail-open, doc hardening, defense-in-depth framing) are
  unchanged. (NOTE: the Round-1 claim that quote-stripping "only removes text, so
  it cannot manufacture a false positive" was **incorrect for escaped inner
  quotes** and is superseded by the Round-3 revision below.)
- **Round-2 FAIL revision (planner, 2026-06-08):** Round 2 PASSED the 14/14 matrix
  but found a MAJOR — the escaped-quote limitation was described with the wrong
  failure direction. A single body-strip `sed` mis-pairs across a backslash-escaped
  inner quote (`-m "use \"--author=\" flag"`), **exposing** the in-message
  `--author=` token and thereby **false-positiving (failing CLOSED)** — blocking a
  legitimate commit, not failing open as the plan claimed. Fix (Step 2): the
  de-quote transform is now **three ordered stages** — **Stage A** removes
  backslash-escaped quote characters (`\"`, `\'`) *before* any body strip (this
  collapses the escaped-inner-quote case so the real outer `"..."` body strips
  cleanly and carries the in-message token away; it is a no-op on real overrides,
  which contain no escaped quotes); **Stage B** strips `'...'`/`"..."` bodies;
  **Stage C** is a fail-open backstop — if `$STRIPPED` still has an odd count of
  `"` or `'`, exit 0 (never block on quoting the guard can't parse). The limitation
  paragraph is corrected to state the residual accurately (Stage A eliminates the
  escaped-inner-quote false-positive; Stage C fails OPEN on any remaining
  unparseable quoting; clean overrides have an even quote count and always reach the
  override checks). Verification gained **D4** (three escaped-inner-quote ALLOW
  cases, each `0`), **D5** (one unbalanced-quote ALLOW case, `0`), and a third **D3**
  adversarial BLOCK (`--author=evil` alongside an escaped quote → `2`, proving
  Stage A is a no-op on real overrides). The full Round-2 14-case matrix, the three
  escaped-quote ALLOW cases, and the adversarial BLOCK were re-prototyped under the
  new ordering before commit — all pass. All other eval-confirmed items unchanged.
- **Prompt-hook fallback deferred (planner, 2026-06-08):** if a future Claude Code
  version is confirmed to drop the command hook (#34573), converting to a
  `type: "prompt"` hook is the research's recommended hedge; out of scope for this
  slice because acceptance is script-level and the doc layer is authoritative.

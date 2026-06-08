# Evaluation: author-identity-enforcement-guard

Verdict: FAIL
Round: 1
Reviewed against: the Approved research note
`.docs/research/2026-06-08-plugin-pretooluse-hook-guard.md` and its eval
(`.docs/evaluations/research-plugin-pretooluse-hook-guard-eval.md`),
ADR 0003 (uniform identity / author-neutral commits), and the current
`plugins/loom/skills/loom-playbook/references/commit-convention.md`. Detection and
mechanical claims were prototyped against the exact patterns the plan specifies.

## Findings

The plan is well-structured, well-sourced, and mechanically correct on almost
every axis. It fails on one axis that the task flags as decisive: the detection
logic produces systematic false positives that would block legitimate commits.

- [BLOCKER] **Detection matches override syntax inside commit-message / argument
  text, blocking legitimate commands.** Step 2 specifies that every detection ERE
  (`--author([[:space:]]|=)`, `-c[[:space:]]+user\.[A-Za-z]+=`, the `-c GIT_*` ERE,
  and the env-var ERE) is run against the *whole* extracted command string. There
  is no logic to distinguish a real flag/assignment **token** from the literal text
  of a quoted `-m` message, a `--grep` argument, or a file path. I prototyped the
  plan's exact patterns; the following legitimate commands are all wrongly BLOCKED
  (exit 2):
  - `git commit -m "fix --author= parsing"`
  - `git commit -m "guard against --author flag"`  ← note: this is the kind of
    message *this very slice* would use to describe itself.
  - `git commit -m "set GIT_AUTHOR_NAME=foo in script"`
  - `git commit -m "add -c user.email= override"`
  - `git log --grep="--author="`

  The plan's "False positives" mitigation only addresses the *git-word* gate
  (non-git commands; substrings like `legitimate`/`digit`) and the `-c core.*`
  vs `-c user.*` distinction — both of which I confirmed work correctly. It never
  addresses override syntax appearing as message/argument *content*, which is
  highly plausible for a commit-hygiene feature whose own changes mention these
  tokens. The task instruction rates a plausible false positive as at least MAJOR;
  this one is systematic, self-referential, and unmitigated, and the guard cannot
  be bypassed mid-session except by removing the plugin — i.e. the "a guard with
  bugs is worse than none" case. Rated BLOCKER. The plan must specify how a real
  flag is distinguished from message/path text (e.g. strip the `-m`/`-F`/`--grep`
  argument values, or anchor the flag patterns to a token boundary that excludes
  quoted regions) — and acknowledge any residual ambiguity it cannot resolve.

- [MAJOR] **Verification has no ALLOW coverage for the false-positive cases.** The
  task requires the acceptance checks to include the message-text ALLOW cases.
  Section D's ALLOW set is `git commit -m "msg"`, `git -c core.pager=cat log`,
  `ls -la`, `echo legitimate=1` — none exercise a commit whose message contains
  `--author=`, `GIT_AUTHOR_NAME`, or `-c user.*`. As written, the acceptance basis
  would pass while the BLOCKER above is live. Add explicit ALLOW cases for the
  five commands listed above (or whichever survive the fix) so the guard's
  correctness is actually proven by the stated checks.

- [MINOR] **Authority path drift in references.** The plan cites the research eval
  as informing its design but the eval lives at
  `.docs/evaluations/research-plugin-pretooluse-hook-guard-eval.md`, not a
  date-prefixed name; not load-bearing for the plan, but a reader following the
  trail should be pointed at the real file. (The research note path the plan cites
  is correct and resolves.)

- [MINOR] **Bare `git commit --author` (no value, no trailing space/=) is not
  caught** by `--author([[:space:]]|=)`. This is an incomplete invocation git
  itself rejects, so it is not a real identity-override hole; noting for
  completeness only.

## Verified correct (no findings)

- **Detection completeness for real tokens:** prototyping confirms all four env
  vars (`GIT_AUTHOR_NAME/EMAIL`, `GIT_COMMITTER_NAME/EMAIL`) inline or `export`ed,
  `-c user.*=`, `-c GIT_AUTHOR/COMMITTER*=`, and `--author=` / `--author ` are all
  caught. No identity-override *vector* is missed.
- **Block mechanism:** exit 2 (not 1), POSIX `#!/bin/sh`, no bash-isms, jq-with-
  grep-fallback specified concretely, exit-code-+-stderr only (no
  `permissionDecision` JSON), depends only on `tool_input.command`. Matches the
  research and its eval's MINORs.
- **hooks.json:** validated as well-formed JSON; `matcher: "Bash"`, `type:
  "command"`, `${CLAUDE_PLUGIN_ROOT}/hooks/git-identity-guard.sh` quoted. Located
  at the auto-discovered `hooks/hooks.json` with the required `hooks` wrapper, and
  correctly adds **no** redundant `plugins/loom/.claude-plugin/plugin.json`
  pointer (Step 3 verified as a no-op; plugin.json today declares no hooks and
  `plugins/loom/hooks/` does not exist — both confirmed against the tree).
- **Fail-open on empty/unparseable command:** sound and well-justified given the
  defense-in-depth framing; an empty command is not a detected override.
- **Scope / honesty:** correctly framed as best-effort defense-in-depth (per the
  research's #34573 caveat) with `commit-convention.md` as the reliable,
  always-present layer; the acceptance basis is script-level testing, not in-
  session firing. Not over-claimed.
- **Doc hardening:** Step 4 extends the existing "One uniform git identity" bullet
  to cover all override paths (`--author=`, `-c user.*`, `GIT_AUTHOR_*` /
  `GIT_COMMITTER_*`) and states the hook is best-effort, rule binding regardless —
  consistent with ADR 0003 and the current file (lines 14–20).
- **jq extraction** on the verification stdin (escaped quotes in message) returns
  the correct command string for both BLOCK and ALLOW cases.

## Required changes (for FAIL)

1. Eliminate the message/argument-text false positive (the BLOCKER). Specify, in
   Step 2, how the guard distinguishes a genuine flag/env token from override
   syntax that appears inside a quoted `-m`/`-F`/`--grep` value or a file path —
   e.g. remove the value of message-bearing options before scanning, or restrict
   the flag patterns to positions that cannot be inside a quoted message. State
   any ambiguity that cannot be fully resolved and confirm it fails *open*
   (allow), consistent with the defense-in-depth framing.
2. Add ALLOW verification cases (Section D) covering at minimum:
   `git commit -m "fix --author= parsing"`,
   `git commit -m "guard against --author flag"`,
   `git commit -m "set GIT_AUTHOR_NAME=foo in script"`,
   `git commit -m "add -c user.email= override"` — each must print `0`.
3. (MINOR, optional) Point the research-eval reference at the real path
   `.docs/evaluations/research-plugin-pretooluse-hook-guard-eval.md`.

## Notes

Detection of real override tokens and all mechanical/JSON/scope items are correct
and ready; the single load-bearing defect is that the patterns are applied to the
raw command without flag-vs-text discrimination, which the task explicitly warns is
the "worse than none" failure mode. Resolving change 1 (with the change-2 tests
proving it) should clear the verdict — the rest of the plan does not need rework.
The fix is testable at the script level exactly as the plan already frames its
acceptance basis.

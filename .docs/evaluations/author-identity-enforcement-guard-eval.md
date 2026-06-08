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

---

# Evaluation: author-identity-enforcement-guard (Round 2)

Verdict: FAIL
Round: 2
Reviewed against: the same authority as Round 1 (Approved research note
`.docs/research/2026-06-08-plugin-pretooluse-hook-guard.md` + its eval, ADR 0003,
and `commit-convention.md`). The revised detection logic (commit `934d232`) was
**independently prototyped** — the plan's exact `sed` stripping plus the four
override EREs were implemented as a `#!/bin/sh` script and exercised against the
full ALLOW/BLOCK matrix and adversarial edge cases. Findings below cite observed
exit codes, not the plan's assertions.

## Round-1 findings — resolution check (diff `934d232`)

- **[BLOCKER] message-text false positive — RESOLVED (for the common cases).**
  The revision adds `STRIPPED=$(printf '%s' "$CMD" | sed -e "s/'[^']*'//g" -e
  's/"[^"]*"//g')` and runs the git-word gate **and** every override ERE against
  `$STRIPPED`, never the raw command (Step 2, lines 142-165, 221-225). Prototyped
  against the full matrix — all 14 task cases pass:

  | Case | Expect | Got |
  |---|---|---|
  | `git commit -m "fix --author= parsing"` | 0 | 0 |
  | `git commit -m "guard against --author flag"` | 0 | 0 |
  | `git commit -m "set GIT_AUTHOR_NAME=foo in script"` | 0 | 0 |
  | `git commit -m "add -c user.email= override"` | 0 | 0 |
  | `git log --grep="--author="` | 0 | 0 |
  | `git commit -m "msg"` | 0 | 0 |
  | `git -c core.pager=delta commit -m "x"` | 0 | 0 |
  | `ls -la` | 0 | 0 |
  | `git commit --author="evil <e@e>" -m "ok"` | 2 | 2 |
  | `git commit --author "evil <e@e>"` | 2 | 2 |
  | `git commit --author=evil` | 2 | 2 |
  | `git -c user.email=x@y commit -m "x"` | 2 | 2 |
  | `GIT_AUTHOR_NAME=foo git commit -m "x"` | 2 | 2 |
  | `GIT_COMMITTER_EMAIL=z@z git commit -m "x"` | 2 | 2 |

  Verification questions answered: (1) quote-stripping turns every ALLOW case into a
  string with no surviving override token — confirmed. (2) every BLOCK case retains
  the flag/assignment token outside the quotes after stripping (the token sits
  *before* the opening quote for `--author="..."`, or is wholly unquoted for inline
  env / `-c user.*`) — confirmed. (3) no new false-negative in the well-formed cases
  — additional adversarial probes (`-m "a" --author=evil -m "b"`, `-m "msg"
  --author="evil"`, odd-quote `... -m 'wip`) all still BLOCK. (4) no remaining
  false-positive **in well-formed (non-escaped-quote) commands** — confirmed.

- **[MAJOR] no ALLOW coverage for message-text cases — RESOLVED.** Verification now
  has Section D2 (five message-text ALLOW cases, each must print `0`) and D3 (two
  adversarial quoted-value overrides, each must print `2`) (lines 301-322). These
  cover the exact set the Round-1 finding required, plus the adversarial direction.

- **[MINOR] research-eval path drift — RESOLVED.** Context (lines 29-31) now cites
  `.docs/evaluations/research-plugin-pretooluse-hook-guard-eval.md`.

## New finding

- [MAJOR] **The documented escaped-quote limitation is described with the wrong
  failure direction; it actually fails *closed*, false-positiving legitimate
  commits.** Step 2 (lines 183-192) accepts the escaped-quote edge case on the
  explicit premise that "the residual effect is at worst that a real override ... is
  **not** blocked — i.e. the guard **fails open**" and "It will **not** newly
  false-*positive* a legitimate commit, because over-stripping only removes text (it
  cannot manufacture an override token)." **Both halves are false.** I prototyped the
  plan's exact `sed` against a legitimate commit whose message contains an override
  token between escaped inner double-quotes:

  - `git commit -m "use \"--author=\" flag carefully"` → STRIPPED becomes
    `git commit -m --author=\ flag carefully` (the sed re-pairs `"..\"` and `\".."`,
    leaving `--author=` exposed) → **exit 2 (BLOCKED)**. Expected: allow.
  - `git commit -m "the \"GIT_AUTHOR_NAME=x\" trick"` → **exit 2**. Expected: allow.
  - `git commit -m "describe \"-c user.email=\" usage"` → **exit 2**. Expected: allow.

  The reasoning error: over-stripping does not merely "remove text" — by deleting the
  contents *and the boundaries* of mis-paired quote spans it can **expose** a token
  that was genuinely inside the message, manufacturing a surviving override token.
  So the residual fails **closed** (blocks a legitimate commit), which is precisely
  the "blocks legitimate commits / worse than none" failure mode that made the
  Round-1 finding a BLOCKER. This subclass is narrower than Round 1 (it requires
  escaped inner double-quotes flanking the token, an uncommon message shape) and the
  limitation is at least acknowledged — hence MAJOR, not BLOCKER. But the plan's
  stated safety justification for *accepting* the limitation rests on a claim that is
  the opposite of the real behavior, so a developer implementing to the plan would
  ship a guard believing escaped quotes can only fail open. Required: correct the
  limitation paragraph to state the residual can false-positive (fail closed) on
  escaped-inner-quote messages, and specify the mitigation — e.g. detect an
  odd/unbalanced quote count in `$CMD` after stripping and **fail open (exit 0)** in
  that case, so the guard never blocks a command whose quoting it could not parse
  cleanly. Add one D-series ALLOW case with an escaped inner quote to prove it.

## Verified still-correct (unchanged by the revision)

The revision (111 insertions / 6 deletions) touched only the stripping logic, D2/D3,
and the path fix. All Round-1 "verified correct" items remain intact and were
re-confirmed where prototyped: detection completeness for real tokens (all four env
vars inline/`export`ed, `-c user.*=`, `-c GIT_AUTHOR/COMMITTER*=`, `--author=` /
`--author `); exit-2-not-1 with stderr only (no `permissionDecision` JSON); POSIX
`#!/bin/sh`; jq-primary with grep fallback (jq path prototyped correct; fallback
remains explicitly best-effort/fail-open per research Open Question 3 — unchanged
and not regressed); `hooks.json` well-formed with `matcher:"Bash"`, `type:"command"`,
quoted `${CLAUDE_PLUGIN_ROOT}` path at the auto-discovered location; no `plugin.json`
pointer (Step 3 no-op); fail-open on empty/unparseable; doc hardening (Step 4) and
defense-in-depth framing consistent with ADR 0003.

## Required changes (for FAIL)

1. Correct Step 2's escaped-quote limitation paragraph: state that over-stripping
   mis-paired quote spans can **expose** an in-message token and thereby
   **false-positive (fail closed)** a legitimate commit — not only fail open.
2. Specify a mitigation that keeps the guard fail-open under quoting it cannot parse:
   e.g. count quote characters in `$CMD`; if unbalanced (odd number of `"` or `'`
   after accounting for the matched spans), **exit 0** rather than running override
   checks. Add a D-series ALLOW case such as
   `git commit -m "use \"--author=\" flag carefully"` that must print `0`.

## Notes

This is close. The load-bearing Round-1 BLOCKER is genuinely fixed for the realistic
command space (14/14 matrix cases correct, independently prototyped), and the
verification now proves it with D2/D3. The remaining MAJOR is not the detection logic
itself but a factual error in how the plan characterizes its own residual: it claims
fail-open where the prototype shows fail-closed on escaped-inner-quote messages.
Correcting the claim and adding a balanced-quote fail-open guard (change 2) should
clear the verdict; no other rework is needed.

---

# Evaluation: author-identity-enforcement-guard (Round 3)

Verdict: PASS
Round: 3
Reviewed against: the same authority as Rounds 1–2 (Approved research note
`.docs/research/2026-06-08-plugin-pretooluse-hook-guard.md` + its eval, ADR 0003,
and `commit-convention.md`). The revised three-stage de-quote transform (commit
`bf6cff0`) was **independently re-implemented from the plan text alone** as a
`#!/bin/sh` script and exercised against the full ALLOW/BLOCK matrix plus the
critical Stage-A/Stage-C trace checks. Findings cite observed exit codes and the
traced intermediate values (`$DEESC`, `$STRIPPED`, quote counts), not the plan's
assertions. Pre-state of every file the plan touches was re-confirmed against the
tree.

## Round-2 finding — resolution check (diff `bf6cff0`)

- **[MAJOR] escaped-quote limitation described with wrong failure direction
  (false-positive / fail-closed) — RESOLVED.** Step 2 now specifies an ordered
  three-stage de-quote: Stage A (`s/\\"//g`, `s/\\'//g`) removes backslash-escaped
  quote characters first; Stage B strips `'...'`/`"..."` bodies; Stage C exits 0 if
  an odd `"` or `'` count remains in `$STRIPPED`. I prototyped the exact transform
  and traced intermediates for the Round-2 failing cases:
  - `git commit -m "use \"--author=\" flag carefully"` → DEESC
    `... -m "use --author= flag carefully"` → STRIPPED `git commit -m ` (dq=0,sq=0)
    → no token → **exit 0 (ALLOW).** The Round-2 false-positive is gone.
  - `git commit -m "mention \"GIT_AUTHOR_NAME=x\" here"` → **exit 0.**
  - `git commit -m "note \"-c user.email=\" thing"` → **exit 0.**
  The limitation paragraph (lines 231-249) is now factually correct: it states the
  prior draft's claim was wrong, that a naïve single body-strip fails **closed**
  (exposes an in-message token), that Stage A eliminates that subclass, and that
  Stage C fails **open** on any residual unparseable quoting. Accurate against the
  prototype.

## Independent full-matrix prototype (built from plan text, not trusted)

| Case | Expect | Got |
|---|---|---|
| `git commit -m "fix --author= parsing"` | 0 | 0 |
| `git commit -m "use \"--author=\" flag carefully"` (D4) | 0 | 0 |
| `git commit -m "mention \"GIT_AUTHOR_NAME=x\" here"` (D4) | 0 | 0 |
| `git commit -m "note \"-c user.email=\" thing"` (D4) | 0 | 0 |
| `git log --grep="--author="` | 0 | 0 |
| `git commit -m "msg"` | 0 | 0 |
| `git -c core.pager=delta commit -m "x"` | 0 | 0 |
| `git commit -m "wip` (unbalanced → fail-open, D5) | 0 | 0 |
| `ls -la` | 0 | 0 |
| `git commit --author="evil <e@e>" -m "ok"` | 2 | 2 |
| `git commit --author "evil <e@e>"` | 2 | 2 |
| `git commit --author=evil` | 2 | 2 |
| `git commit --author=evil -m "say \"hi\""` (D3 #3) | 2 | 2 |
| `git -c user.email=x@y commit -m "x"` | 2 | 2 |
| `GIT_AUTHOR_NAME=foo git commit -m "x"` | 2 | 2 |
| `GIT_COMMITTER_EMAIL=z@z git commit -m "x"` | 2 | 2 |

16/16 match (9 ALLOW → 0, 7 BLOCK → 2).

Critical questions answered (each traced, not assumed):
1. **Stage A never destroys a real override token.** D3 case 3
   (`--author=evil -m "say \"hi\""`): Stage A removes only the in-message `\"`
   pair; DEESC retains `--author=evil`, STRIPPED retains `--author=evil` → BLOCK.
   Real tokens carry no backslash-escaped quotes, so Stage A is provably a no-op on
   them.
2. **Stage C never lets a clean real override slip (no false-negative).** Every
   BLOCK case yields an **even** (zero) quote count in `$STRIPPED` — the override
   token is unquoted, so its surrounding quotes (if any) strip in balanced pairs.
   None of the seven BLOCK cases hit the odd-count backstop; all reach the override
   checks and exit 2. Confirmed by trace (e.g. `--author="evil <e@e>" -m "ok"` →
   STRIPPED `git commit --author= -m `, dq=0).
3. **No remaining false-positive.** All nine ALLOW cases exit 0, including the three
   escaped-inner-quote messages and the `-c core.pager` non-identity config.
4. **Limitation paragraph accurate.** The guard fails **open** (never closed) on
   unparseable quoting; clean overrides (even quote count) always reach detection.
   Verified directly: a hand-crafted odd-quote payload alongside a real override
   (`git commit --author=evil -m "wip` with a lone trailing quote) exits 0 —
   exactly the documented Stage-C fail-open residual, covered by the doc layer.
5. **Verification matrix complete with recorded-exit-code instructions.** Section C
   (6 BLOCK), D (4 ALLOW), D2 (5 message-text ALLOW), D3 (3 adversarial BLOCK incl.
   the new escaped-quote-no-op case), D4 (3 escaped-inner-quote ALLOW), D5
   (unbalanced-quote fail-open ALLOW), plus E (jq-absent fallback) and F
   (doc + scope). Each requires `echo $?` evidence recorded in Notes.
6. **Previously-confirmed items intact.** Re-confirmed against the tree:
   `plugin.json` declares no `hooks` key and `plugins/loom/hooks/` does not exist
   (Step 3 no-op correct); `commit-convention.md` lines 14-20 cover only `-c user.*`
   / `git config user.*` (Step 4's extension to `--author=` and the four env vars is
   correctly scoped); detection completeness, exit-2-with-stderr-only, POSIX sh,
   jq-with-grep-fallback (fallback extraction prototyped correct), quoted
   `${CLAUDE_PLUGIN_ROOT}` path, auto-discovered `hooks/hooks.json`, and the
   defense-in-depth framing are unchanged.

## Findings

- [MINOR] **Residual hyper-adversarial fail-open is real but correctly documented.**
  A deliberately hand-crafted command that appends a lone unbalanced quote to a real
  override is allowed (exit 0) via the Stage-C backstop, as the prototype confirms.
  This is an intentional, documented design choice (fail-open over fail-closed) with
  the `commit-convention.md` doc rule as the authoritative layer — not a guard
  defect. A self-inflicted bypass by an actor who is already declining to follow the
  binding doc rule is outside what a best-effort defense-in-depth hook must close.
  Non-blocking.

- [MINOR] **Bare `git commit --author` (no `=`, no trailing space) still uncaught**
  (carried from Round 1). `--author([[:space:]]|=)` does not match a flag at
  end-of-string with no delimiter; git itself rejects that incomplete invocation, so
  it is not an identity-override hole. Noted for completeness only. Non-blocking.

## Verdict rationale

The Round-2 MAJOR is genuinely fixed: the three-stage transform was independently
re-derived from the plan and passes 16/16, the Stage-A no-op and Stage-C
no-false-negative properties hold under trace, and the limitation paragraph now
states the residual in the correct (fail-open) direction. Verification covers D4,
D5, the new adversarial D3, and the prior matrix with recorded exit codes. No
BLOCKER or MAJOR remains; the two residuals are documented MINORs consistent with
the defense-in-depth framing. PASS.

## Required changes

None (the two MINORs are optional polish, not required for PASS).

---

# Evaluation: author-identity-enforcement-guard (Round 4 — code)

Verdict: PASS
Round: 4
Reviewed against: the slice-plan `author-identity-enforcement-guard.md` (scope +
acceptance authority, incl. the C/D/D2/D3/D4/D5 + E + F matrix), the Approved
research note `.docs/research/2026-06-08-plugin-pretooluse-hook-guard.md`, ADR 0003,
and Rounds 1–3. This round reviews the **shipped artifact** (commit `a47bf95`) — the
actual `plugins/loom/hooks/git-identity-guard.sh` was executed, not a prototype
re-derived from the plan. Every exit code below is observed from the committed
script.

## Gate (re-run, not trusted)

- `jq . plugins/loom/hooks/hooks.json` → exit 0; valid JSON. PreToolUse event,
  `matcher:"Bash"`, `type:"command"`, `command:"\"${CLAUDE_PLUGIN_ROOT}/hooks/git-identity-guard.sh\""`,
  `hooks` wrapper present. Confirmed.
- Script: `#!/bin/sh`, mode `-rwxr-xr-x` (executable), `sh -n` exit 0.
- Block mechanism is exit **2** with explanatory stderr naming the violation class +
  ADR 0003 + "use plain git commit" remediation (no specific name/email). Confirmed
  by direct run.

## Independently-run acceptance matrix (committed script, observed exit codes)

| Case | Command (decoded) | Expect | Got |
|---|---|---|---|
| C1 | `git commit --author="x <x@y>" -m z` | 2 | 2 |
| C2 | `git -c user.email=x@y commit -m z` | 2 | 2 |
| C3 | `git -c user.name=Foo commit -m z` | 2 | 2 |
| C4 | `GIT_AUTHOR_NAME=Foo git commit -m z` | 2 | 2 |
| C5 | `export GIT_COMMITTER_EMAIL=x@y; git commit -m z` | 2 | 2 |
| C6 | `git commit --author bar -m z` | 2 | 2 |
| D1 | `git commit -m "msg"` | 0 | 0 |
| D2 | `git -c core.pager=cat log` | 0 | 0 |
| D3 | `ls -la` | 0 | 0 |
| D4 | `echo legitimate=1` | 0 | 0 |
| D2-1 | `git commit -m "fix --author= parsing"` | 0 | 0 |
| D2-2 | `git commit -m "guard against --author flag"` | 0 | 0 |
| D2-3 | `git commit -m "set GIT_AUTHOR_NAME=foo in script"` | 0 | 0 |
| D2-4 | `git commit -m "add -c user.email= override"` | 0 | 0 |
| D2-5 | `git log --grep="--author="` | 0 | 0 |
| D3-1 | `git commit --author="evil <e@e>" -m "ok"` | 2 | 2 |
| D3-2 | `git commit --author "evil <e@e>"` | 2 | 2 |
| D3-3 | `git commit --author=evil -m "say \"hi\""` | 2 | 2 |
| D4-1 | `git commit -m "use \"--author=\" flag carefully"` | 0 | 0 |
| D4-2 | `git commit -m "mention \"GIT_AUTHOR_NAME=x\" here"` | 0 | 0 |
| D4-3 | `git commit -m "note \"-c user.email=\" thing"` | 0 | 0 |
| D5-1 | `git commit -m "wip` (unbalanced) | 0 | 0 |

25/25 match (the Notes table's 26-count includes the two E cases below).

### E — jq-absent fallback (genuinely exercised)

The Notes' Section-E run used `PATH=/usr/bin:/bin`, which on this machine **still
contains `/usr/bin/jq`** — so it did not actually test the fallback. I re-ran with a
curated bin dir (symlinks to `sh cat grep sed tr wc head` only; `command -v jq`
fails) so the grep/sed branch is truly taken:

| Case | Expect | Got |
|---|---|---|
| E1 `git commit --author=x -m z` | 2 | 2 |
| E2 `git commit -m z` | 0 | 0 |
| `git -c user.email=x@y commit -m z` | 2 | 2 |
| `GIT_AUTHOR_NAME=Foo git commit -m z` | 2 | 2 |
| `export GIT_COMMITTER_EMAIL=x@y; git commit -m z` | 2 | 2 |
| `git commit -m "fix --author= parsing"` | 0 | 0 |
| `ls -la` | 0 | 0 |

The grep/sed extraction (`grep -o '"command"...' | head -1 | sed ...`) correctly
recovers the command on well-formed single-line JSON and preserves every block/allow
decision. (Caveat, noted not blocking: if even `grep` is absent the script fails
open — the intended defense-in-depth posture; the doc layer is authoritative.)

## Adversarial probing (my own cases)

False-negative hunt — every real override caught (all → 2): `--author=evil` (no
`-m`); `GIT_AUTHOR_NAME='Evil Person' git commit` (single-quoted value, VAR outside
quotes); `git -c user.email="e@e"`; `git -c core.pager=cat -c user.name=Evil commit`
(identity `-c` buried after a benign `-c`); `git commit -m z --author=evil` (flag
after message); `-c GIT_AUTHOR_NAME=`/`-c GIT_COMMITTER_EMAIL=`; all four inline env
vars; double `--author`. **No false-negative found** — no identity override on a
commit slips through.

False-positive hunt on commits — all correctly allowed (→ 0): `git commit --amend
--no-edit`; `git commit -m "see GIT_COMMITTER_NAME docs"`; `git commit -m "refactor:
drop -c user.email handling"`; `git grep GIT_AUTHOR_NAME`; `git show HEAD:script.sh`.
**No legitimate commit is blocked.**

## Findings

- [MINOR] **`--author` is blocked on non-commit git subcommands too (`git log
  --author=`, `git shortlog --author=`, `git blame --author`).** Observed: `git log
  --author=alice` → exit 2; `git log --author="Craig" --oneline` → exit 2. `--author`
  is a legitimate read-only *filter* on `log`/`shortlog`/`blame`, unrelated to commit
  identity, so the guard would refuse those while the plugin is active. **This is a
  faithful realization of the approved plan, not an implementation deviation:** the
  plan specifies exactly `ERE: --author([[:space:]]|=)` run on `$STRIPPED` with no
  subcommand scoping, and its entire Verification matrix targets only `git commit
  --author=`; this ERE was reviewed and PASSED in Rounds 1–3. The plan also frames
  the hook as best-effort defense-in-depth with the doc as the authoritative layer,
  and the affected commands are non-mutating. Recorded as a **planning-refinement**
  MINOR (scope the `--author` block to `commit`/`am`/`rebase`/`cherry-pick`, or
  require a preceding `commit`) — not a defect in this slice satisfying its plan.
  Likewise `git add src/--author=file.txt` and `git branch feature/--author=x` block
  (override token as an unquoted-argument substring); these are contrived and share
  the same root (no token-boundary anchoring in the approved ERE).
- [MINOR] **Bare `git commit --author` (no `=`, no trailing delimiter) uncaught**
  (carried from Rounds 1/3). `--author([[:space:]]|=)` does not match a flag at
  end-of-string with no delimiter; git itself rejects that incomplete invocation, so
  it is not an identity-override hole. Non-blocking.
- [MINOR] **Fail-open when `grep` itself is unavailable.** In a jq-absent *and*
  grep-absent environment the extraction yields empty → exit 0. Consistent with the
  documented fail-open posture; the doc layer is the guarantee. Non-blocking.

## Scope

`git show --name-only` lists six files. The four plan-named files
(`hooks/hooks.json`, `git-identity-guard.sh`, `commit-convention.md`, the slice-plan)
are exactly Steps 1/2/4 + the status flip. The two extra files are acceptable
in-scope maintenance, not drift:
- **`CLAUDE.md`** — adds `hooks/` to the Repo-layout description, documenting the new
  directory this slice introduces; mandated by the repo's own "Update this file
  before committing" rule.
- **`.docs/slice-plans/README.md`** — the plan index; updates this plan's lifecycle
  entry (`Plan Review` → `In Progress`), which is the index's job (plan Step 5).

Confirmed **no** change to `plugins/loom/.claude-plugin/plugin.json` (Step 3 no-op
verified; `jq 'has("hooks")'` → false, so no redundant pointer) and **no** edit to
any `.docs/spec/` or ADR file. Commit is author-neutral; single-slice; no co-author
trailer; commit subject ends `(Implemented)`.

## Doc hardening

`commit-convention.md` now forbids all override paths — `git commit --author=...`,
`git -c user.*=...`, `git config user.*`, and the four `GIT_AUTHOR_*`/`GIT_COMMITTER_*`
env vars (inline or `export`) — frames the hook as best-effort defense-in-depth that
"may not fire in every Claude Code version (#34573)" with the rule "**binding
regardless of whether the hook fires**," cites ADR 0003, and keeps the existing
stop-and-ask / never-`loom <loom@localhost>` guidance. Consistent with ADR 0003.

## Verdict rationale

The shipped guard passes the full plan acceptance matrix 25/25 when I run it, the
jq-absent fallback (genuinely exercised, unlike the recorded run) preserves every
decision, and independent adversarial probing found **no false-negative** (no commit
identity override slips through) and **no legitimate commit blocked**. JSON wiring,
POSIX-sh/executable/syntax, exit-2-with-stderr, plugin.json no-op, doc hardening, and
author-neutral single-slice hygiene all hold. The remaining items are MINORs — the
most notable (`git log --author=` blocked) is a faithful consequence of the
thrice-approved detection ERE and a planning-refinement candidate, not a failure of
this implementation to satisfy its plan. No BLOCKER, no unaddressed MAJOR. PASS.

## Required changes

None for PASS. Recommended planning follow-up (not blocking): scope the `--author`
block to commit-producing subcommands so legitimate `git log/shortlog/blame
--author=` filters are not refused.

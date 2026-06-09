# Evaluation: shell-gate-plan.md

Verdict: FAIL
Round: 1
Reviewed against: `.docs/spec/06-init-modes.md` (Gate establishment),
`.docs/spec/08-playbook.md` (gates), `references/gate-learning.md` (Step 5),
`gates/rust.md` (shape template), `plugins/loom/hooks/git-identity-guard.sh`
(behavior under test), the plan-eval rubric + severity.md. Mechanical checks run
read-only against the real hook and tooling.

## Findings

- [BLOCKER] The jq-absent fallback recipe (Step 1, item 4, lines 153–164) is
  wrong as written and the plan asserts it verified. The recipe builds a stub
  dir symlinking `cat grep sed tr wc head` (no `sh`) and then runs
  `env PATH="$stub" sh "$GUARD"`. Because `env` re-resolves the `sh` interpreter
  against the *replaced* PATH (which contains no `sh`), the verbatim recipe
  exits **127** ("sh not found"), not the F-row expected exit codes. Verified by
  running the plan's exact recipe against the real hook: F1 → status 127 (plan
  expects 2). The plan's Notes (lines 460–465) claim this recipe was "Verified to
  yield NO_JQ and correct BLOCK/ALLOW while authoring this plan" — that claim is
  false for the recipe as printed. A developer copying it verbatim gets three
  erroring fallback tests and a red `bats` gate, which under spec 06 means the
  gate stays UNVERIFIED and `shell.md` must not be recorded Verified. The fix is
  one token: add `sh` to the binary loop (`for t in cat grep sed tr wc head sh`),
  or invoke the interpreter by absolute path (`PATH="$stub" /bin/sh "$GUARD"`).
  With `sh` resolvable the F-rows produce the asserted 2/2/0 and `command -v jq`
  correctly reports NO_JQ — confirmed read-only.

## Required changes (for FAIL)

1. Fix the `guard_no_jq` recipe so the `sh` interpreter is resolvable under the
   stubbed PATH (add `sh` to the symlinked binary list, or invoke `/bin/sh`
   absolutely). Re-state the verification claim to match the corrected recipe.
   The expected F-row exit codes (F1=2, F2=2, F3=0) and the NO_JQ requirement are
   correct and stay.

## Notes

Everything else in the plan checked out against the authority and the real tree;
this is a single mechanical defect in an otherwise rigorous plan.

Verified PASSING, recorded so they are not re-litigated on re-review:

- **Tooling / starting state.** `shfmt -i 4 -d <hook>` → exit 0 (clean);
  `shfmt -d <hook>` (tab default) → exit 1 (would diff); `shellcheck <hook>` →
  exit 0. shfmt 3.13.1, bats 1.13.0, shellcheck 0.11.0. The `-i 4` choice is
  internally consistent: it keeps the format step green with zero hook churn, so
  Step 2 touches no `.sh` — matches the out-of-scope/Verification V5 claims.
- **Full BLOCK/ALLOW matrix replayed with proper JSON stdin.** All 11 BLOCK rows
  (B01–B11) exit 2 and all 14 ALLOW rows (A01–A14) exit 0 against the shipped
  hook — every asserted exit code is correct, including A09
  (`git log --grep="--author="` → 0, quoted value stripped) and A13 (unbalanced
  quote → Stage C fail-open → 0).
- **The central correctness claim holds.** B10 (`git -c user.email=x@y log`) and
  B11 (`git log --author=alice`) both exit **2** on the shipped hook. The plan is
  correct to encode these as BLOCK (exit 2) and to refuse the orchestrator's
  "ALLOW" framing; this is the accepted fail-closed read over-block documented in
  `commit-convention.md` (lines 38–39: "`git log --author=alice` … are also
  blocked. This is an accepted fail-closed …"). A plan asserting ALLOW here would
  have been the defect; this plan correctly asserts the real behavior.
- **Spec 06 run-green-once honored.** `shell.md` is recorded `Status: Verified`
  only after Step 3's green run on the real hook, and Step 3 explicitly stops and
  keeps the gate UNVERIFIED if any step is non-green (matches spec 06 3rd bullet
  and gate-learning Step 4→5).
- **gate-learning Step 5 / rust.md shape.** Planned `shell.md` mirrors rust.md's
  required fields (title, `Status: Verified`, `Detected by:`, run-in-order intro,
  format/lint/test table, Notes) and carries the required "the code evaluator
  re-runs this gate" note (Step 2; V3 mechanical checks named). `Detected by:`
  adds a sound no-`Cargo.toml` clause so it will not mis-fire on a Rust repo that
  merely contains helper shell scripts.
- **CLAUDE.md reconciliation accurate, not overstated.** Root CLAUDE.md still
  says "no compiled code yet" (line 88, verified); Step 4 replaces only that
  sentence, keeps the markdown-first framing and the Rust-gate / gate-learning
  pointers, and adds the three concrete commands. Does not overstate.
- **Scope / hygiene.** Standard template, `Status: Plan Review`, target specs
  06/08 named, mechanically-followable Verification section. Touches only the
  new `.bats`, new `shell.md`, root CLAUDE.md, and this plan/index; edits no
  spec/ADR. The slice-plans README Active entry (Step 5) is already in place and
  correct. gates/ currently holds only `rust.md`; no `.bats` exists yet — tree
  state matches the plan's claims.

# Evaluation: shell-gate-plan.md (Round 2)

Verdict: PASS
Round: 2
Reviewed against: the Round-1 BLOCKER and the diff `91c11c6..fea83d4` on
`.docs/slice-plans/shell-gate-plan.md`; `plugins/loom/hooks/git-identity-guard.sh`
(fallback branch under test); `.docs/spec/06-init-modes.md` (run-green-once);
plan-eval rubric + severity.md. The corrected jq-absent recipe was run read-only
against the real hook.

## Findings

- The Round-1 BLOCKER is **resolved**. The fix touches exactly two places, both
  confirmed in the diff:
  - **Step 1.4 recipe (now lines 154–168):** the interpreter is now invoked by
    absolute path — `run env PATH="$stub" /bin/sh "$GUARD"` — and a NOTE explains
    that a bare `sh` would re-resolve against the jq-free PATH and exit 127. The
    coreutils-symlink loop and the deliberate jq exclusion are unchanged.
  - **Notes claim corrected (lines 470–493):** the false "Verified to yield
    NO_JQ and correct BLOCK/ALLOW while authoring this plan" is gone. The fallback
    bullet is now labelled "corrected Round 2", explains the earlier 127 defect,
    and states the F-row codes are **expected** and exercised at run-green-once
    (Step 3 / V1), "not pre-verified here." The closing "Verified read-only"
    bullet likewise scopes its pre-verification claim to the B/A rows
    (default PATH, jq present) and states F1–F3 are "stated as expected, not
    pre-verified via the recipe."
- Mechanical confirmation (read-only, real hook
  `plugins/loom/hooks/git-identity-guard.sh`): built the stub dir per the
  corrected recipe and ran `env PATH="$stub" /bin/sh "$GUARD"`:
  - F1 (`git commit --author=evil -m z`) → exit **2** (was 127 with the old
    bare-`sh` recipe).
  - F2 (`GIT_AUTHOR_NAME=Foo git commit -m z`) → exit **2**.
  - F3 (`git commit -m z`) → exit **0**.
  - Under `PATH="$stub"`, `command -v jq` reports **NO_JQ**, so the hook's
    grep/sed `else` branch is genuinely exercised (the stub contains only
    cat/grep/sed/tr/wc/head; no jq). The asserted 2/2/0 hold via the fallback.

## Required changes (for FAIL)

None.

## Notes

The revision is surgical: only Step 1.4 and the two affected Notes bullets
changed; the 28-row matrix, all V-sections, the `shell.md`/CLAUDE.md/index steps,
and every other Round-1-PASSing element are byte-unchanged in the diff and were
not re-litigated. The single Round-1 mechanical defect is fixed and the
verification language now matches reality (expected-at-run-green rather than
falsely pre-verified). No BLOCKER, no MAJOR ⇒ PASS.

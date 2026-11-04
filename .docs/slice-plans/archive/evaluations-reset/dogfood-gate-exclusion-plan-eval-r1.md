# Evaluation: dogfood-gate-exclusion (slice-plan)

Verdict: FAIL
Round: 1
Artifact: .docs/slice-plans/dogfood-gate-exclusion.md @ 6356a98
Evaluator: plan-evaluator (blind)

## Required changes (top)

1. [BLOCKER] Resolve the conflict with the Approved `dogfood-retirement` plan. Its removal
   handoff cannot work as written (finding B1).
2. [MAJOR] Make acceptance criteria a–c into exact runnable commands with stated expected
   output (finding M1).

## Findings

### [BLOCKER] B1 — Carve-out removal handed to a slice whose approved acceptance criteria forbid it
- This plan, lines 37-38: "the variable and filter then become dead and must be removed in
  that slice's `scripts/check` edit". Line 33: "No change to ... any ADR, or any spec". It
  does not mention amending the retirement plan.
- `dogfood-retirement.md` @ 6356a98 (Status: Approved):
  - Step 7 (lines ~111-114): "Gate and CI changes: none required ... Expected edits to those
    three files: 0 lines."
  - Verification #4 (lines 152-153):
    `test -z "$(git diff --stat "$BASE" HEAD -- scripts/check .github/workflows/check.yml scripts/check-toolchain.json)"`
    and `! rg -n 'dogfood' scripts/check ...`.
  - Context (lines 22-26) says `scripts/check` has no dogfood entry and that "Deleting the files
    therefore shrinks the gate with no gate edit".
- Once this slice lands, `scripts/check` contains `dogfood` three times (the comment, the
  `BATS_EXCLUDED_FILE` value and the printf). The retirement `BASE` comes after this slice.
  So retirement must either:
  - leave the carve-out, which fails check 153 (`rg 'dogfood'` hits); or
  - remove it, which fails check 152 (non-empty `git diff --stat` on `scripts/check`) and
    breaks Step 7's "0 lines".
  - Either way the Approved plan's acceptance is unsatisfiable. Both plans are named
    upstream authority, and they now contradict each other.
- Check: `git show 6356a98:.docs/slice-plans/dogfood-retirement.md | sed -n 108,154p`.
- Simplest fix (pick one and state it in the plan):
  - (a) Add a required follow-on: before `dogfood-retirement` is developed, the planner
    revises it with a cold re-eval. The revision changes Step 7 to "remove the
    dogfood-gate-exclusion carve-out (≈6 lines)" and replaces Verification #4's
    `scripts/check` diff assertion with a check that the diff is exactly the carve-out
    removal. Keep `! rg -n 'dogfood' scripts/check`.
  - (b) Explicitly sequence that revision as part of this slice's handoff in `## Notes`, and
    list it in Out of Scope as a separate planner task.

### [MAJOR] M1 — Acceptance criteria not all runnable commands with stated results
- Line 81, (a): "`bats --count` over the discovered list never includes the file". No command
  is given, and "never includes" cannot be tested as written.
- Line 82-83, (b): "the final Bats summary's ok count equals `T0 - B`". No command extracts or
  counts the ok lines, and skipped tests (`ok ... # skip`) make "ok count" ambiguous.
  "run files are 17" has no command.
- Line 86, (c): `scripts/check ... | rg -c '^Excluding '`. The `...` is elided, and as written
  it implies a second full gate run.
- Lines 71-73: `T0` comes from running the old gate in full on the baseline. That is costly
  and avoidable.
- Fix: capture the single candidate gate run once, for example
  `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check 2>&1 | tee /private/tmp/gate.log; test ${PIPESTATUS[0]} -eq 0`.
  Then assert:
  - `rg -c '^Excluding scripts/tests/macos-dual-client-dogfood\.bats from Bats stage \(\.docs/slice-plans/dogfood-gate-exclusion\.md\)$' /private/tmp/gate.log` gives 1.
  - `rg '^Discovered 931 Bats tests$' /private/tmp/gate.log`.
  - `! rg 'macos-dual-client-dogfood' /private/tmp/gate.log` except the Excluding line, or
    use an equivalent filter.
  - Compute T0 without a gate run:
    `git ls-files -z '*.bats' | xargs -0 bats --count` (expected 972).
    Then T1 = `git ls-files -z '*.bats' | grep -zv '^scripts/tests/macos-dual-client-dogfood.bats$' | xargs -0 bats --count`
    (expected 931).

### [MINOR] m1 — ADR 0024 §8 not addressed
- ADR 0024 §8 (line ~357) says "The existing release gate remains until a later formal
  decision changes it." That clause concerns the M0–M7 release gate, not `scripts/check`
  stage contents. ADR 0033 §3 and its Consequences ("tooling and tests leave the gate") plus
  the owner decision cover this carve-out.
- The plan should still cite 0024 §8 and 0033 in one line, to show that no accepted
  requirement is violated.

### [MINOR] m2 — LOC arithmetic
- Line 66 says "about 4 added, 1 replaced by 3: net about +7". 4 + (3 − 1) = +6. State the
  exact net. It is within the ≤15 target either way.

## Mechanical checks performed (all at 6356a98)

| Check | Result | Command / evidence |
|---|---|---|
| Single exclusion point | PASS | One variable plus one filter, both in `scripts/check` Bats stage (plan Steps 1-2) |
| Cited lines exist | PASS | `git show 6356a98:scripts/check \| cat -n \| sed -n 523,533p`: 523 `stage "Bats tests"`, 524 `test_files=()`, 525 the ls-files loop, 526-530 required loop, 532 Discovered printf, 533 run-bats-under |
| Required-file loop cannot re-add | PASS | Lines 526 names only shell-runtime.bats and repository-validation.bats |
| Test count | PASS | `grep -c '^@test'` on dogfood file gives 41; the sum over all 18 tracked `*.bats` at 6356a98 is 972, so 931 other, matching plan lines 71-73 |
| File counts | PASS | `git ls-tree -r --name-only 6356a98 \| grep '\.bats$' \| wc -l` gives 18 |
| Printed line specified | PASS | Lines 49 and 85, exact text |
| Nothing else in gate changes | PASS | Steps confined to lines 523-525. Other stages are untouched |
| CI consistent | PASS | `.github/workflows/check.yml:129` runs `scripts/check` and holds no separate Bats list |
| Validator consistent | PASS | `validate-repository.mjs` has no `bats` reference. Line 170 is a general `git ls-files` walk, and the file stays tracked. `git grep macos-dual-client-dogfood.bats 6356a98 -- scripts .github plugins` finds no other consumer |
| Tests reading check output | PASS | `repository-validation.bats` runs copied `scripts/check` only under CONTRACT_ONLY, BASH_ONLY, PROVISION_ONLY or shim modes. No assertion on "Discovered" |
| `set -e` safety | PASS | `scripts/check:2` sets `set -euo pipefail`. `[ ] \|\| append` in the loop body returns 0 |
| No test deleted or weakened | PASS | Lines 31-32 |
| Gate exact | PASS | Line 75: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` |
| LOC stated, plan size, status | PASS | ≤15 LOC target. `wc -l` gives 101 lines (≤250). Status: Plan Review |
| Consistency with Approved dogfood-retirement | **FAIL** | See B1 |
| Runnable acceptance criteria | **FAIL** | See M1 |

## Prior Rounds Summary

None (first review).

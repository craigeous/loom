# Evaluation: <artifact name>

Verdict: PASS | FAIL
Round: <n>
Reviewed against: <the spec/ADR/plan/sources the judgment used>

## Findings

- [BLOCKER] <must fix before approval> — <where / why>
- [MAJOR]   <significant concern> — <where / why>
- [MINOR]   <nit / improvement> — <where / why>

## Required changes (for FAIL)

1. <concrete, actionable change>
2. <...>

## Notes

<Optional reasoning the author may read when revising. No author identity is
referenced — this verdict is blind.>

<!--
Rules (full definitions in references/severity.md):
- Any unresolved [BLOCKER], or any unaddressed [MAJOR] ⇒ Verdict: FAIL.
- PASS means no blockers and no unaddressed majors; [MINOR]s don't block.
- Use the literal Verdict: PASS / FAIL regardless of how the request was phrased.
- On a re-review, confirm each prior BLOCKER/MAJOR was resolved (cite the diff).

Round: <n> — counting rule (see spec 03 ## Round limits / references/status-machine.md):
- <n> is the count of FAIL→revise cycles for this artifact.
- Increment only on a FAIL. The first clean review of a fresh artifact is round 0.
- A PASS that resolves a prior FAIL repeats that FAIL's round number (it does not advance).
-->

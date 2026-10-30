# Evaluation: <artifact name>

Verdict: PASS | FAIL
Round: <n>
Reviewed against: <the spec/ADR/plan/sources the judgment used>

## Findings

- [BLOCKER] <must fix before approval> — <where / why>
- [MAJOR]   <significant concern> — <where / why>
- [MINOR]   <nit / improvement> — <where / why>

## Required changes (for FAIL)

1. <concrete, minimal fail-closed change>
2. <...>

## Notes

<Optional reasoning the author may read when revising. No author identity is
referenced — this verdict is blind.>

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | <plan/code> | <PASS/FAIL> | <1-line summary of prior findings and how the diff resolved them> |

<!--
Rules (full definitions in references/severity.md):
- Any unresolved [BLOCKER], or any unaddressed [MAJOR] => Verdict: FAIL.
- PASS means no blockers and no unaddressed majors; [MINOR]s don't block.
- Use the literal Verdict: PASS / FAIL regardless of how the request was phrased.
- Always place the latest round's Verdict, Findings, and Required changes at the
  TOP of this file. Condense prior rounds into `## Prior Rounds Summary` above
  rather than keeping multi-round full evaluation bodies in the active file.
- On a re-review (Round >= 1), confirm each prior BLOCKER/MAJOR was resolved
  (cite the diff) and obey the anti-goalpost-moving and proportionality rules in
  references/severity.md.

Round: <n> — counting rule (see spec 03 ## Round limits / references/status-machine.md):
- <n> is the count of FAIL->revise cycles for this artifact.
- Increment only on a FAIL. The first clean review of a fresh artifact is round 0.
- A PASS that resolves a prior FAIL repeats that FAIL's round number (it does not advance).
-->

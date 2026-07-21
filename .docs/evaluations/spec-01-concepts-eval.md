# Evaluation: 01 — Concepts & `.docs/` Layout

Verdict: FAIL
Round: 1
Reviewed against: accepted ADRs 0018, 0020–0022 and retained prior ADR authority; repository improvement plan M2/M4/M5; sibling frozen specs; current tree; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] Publication receipts are assigned to the wrong persistence boundary —
  `Isolation workspaces are not project artifacts` says validated receipts enter
  tracked `.docs/`, but ADR 0020 and improvement-plan M2 require the receipt to be
  recorded only after remote verification in coordinator/recovery state. A receipt
  proving publication cannot be part of the single candidate update whose publication
  it proves; writing it to tracked `.docs/` afterward would require an unreviewed
  second target update and contradict specs 03–04's atomic remote-first flow.
- [MAJOR] The Authority section omits ADR 0021 even though this spec normatively
  defines the local-review companion, exact review revisions, review-run workspace,
  and deterministic assembly introduced by that ADR.

## Required changes (for FAIL)

1. Distinguish the pre-publication candidate manifest from the post-verification
   publication receipt, and place the receipt in declared coordinator/recovery state
   consistent with ADR 0020 and specs 03–04; do not claim it enters tracked `.docs/`.
2. Add ADR 0021 to the Authority section for the local-review artifact and workspace
   contracts.

## Notes

All relative links resolve. Evaluation/findings naming and the canonical instruction
digest layout otherwise agree with the amended spec set.

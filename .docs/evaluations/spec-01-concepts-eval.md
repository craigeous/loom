# Evaluation: 01 — Concepts & `.docs/` Layout

Verdict: FAIL
Round: 2
Reviewed against: accepted ADRs 0018–0022; approved research; already-approved amended sibling specs; prior verdict; exact revision diff `a1f7995..009bb79`; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] The revised receipt boundary now matches ADR 0020, but the frozen amended
  spec 02 still says “publication-receipt changes” are prepared in the disposable
  integration candidate. A post-verification receipt cannot be candidate content, so
  the approved spec set remains materially contradictory about persistence and timing.

## Required changes (for FAIL)

1. Amend spec 02 so finalization prepares only candidate-authorized tracked content;
   record or reconstruct the publication receipt after fresh remote verification in
   the untracked common-Git-dir recovery state defined here.

## Notes

The prior receipt-location blocker and omitted-ADR-0021 authority finding are fully
resolved in this revision. No other blocker was found.

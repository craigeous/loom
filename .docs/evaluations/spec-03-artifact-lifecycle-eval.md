# Evaluation: 03 — Artifact Lifecycle & Status State Machine

Verdict: FAIL
Round: 2
Reviewed against: accepted ADRs 0018–0022; approved research; already-approved amended sibling specs; prior verdict; exact revision diff `a1f7995..009bb79`; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] The revised lifecycle correctly records the receipt only after remote
  verification, but frozen amended spec 02 still places “publication-receipt changes”
  in the disposable integration candidate. Those contracts cannot both implement the
  ADR-0020 publication boundary, leaving landing and cleanup ordering ambiguous.

## Required changes (for FAIL)

1. Amend spec 02 to remove the publication receipt from candidate preparation and
   align it with this spec's post-verification, untracked receipt/recovery flow.

## Notes

The prior legal-status-vocabulary and archive-ordering blockers are fully resolved in
this revision. No other blocker was found.

# Evaluation: 03 — Artifact Lifecycle & Status State Machine

Verdict: FAIL
Round: 1
Reviewed against: accepted ADRs 0020–0022 and retained ADRs 0003, 0005, 0013, and 0017; repository improvement plan M2/M4/M5/M6; sibling frozen specs; current tree; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] The claimed exhaustive legal-status set excludes `Accepted`, although
  governing ADRs 0018–0022 and thirteen retained accepted ADRs mechanically carry
  `Status: Accepted`. Spec 08 requires CI to validate allowed statuses, so implementing
  this table literally would reject the authority used to build the state machine.
- [BLOCKER] Archive ordering contradicts the remote-first candidate contract. The
  lifecycle diagram places `Archived` after verified `Landed` and local cleanup, while
  the same spec requires the archived plan/index state and prospective `Archived` text
  inside the one pre-publication candidate. ADR 0020 requires those finalization
  artifacts to publish atomically and makes post-verification cleanup local/idempotent;
  the diagram permits an incorrect second tracked finalization step.

## Required changes (for FAIL)

1. Reconcile the legal status vocabulary with immutable/current ADR files—either add
   and define `Accepted` or define a mechanically enforceable compatibility rule that
   does not reject accepted authority.
2. Make the diagram and prose show archived plan/index state as prospective candidate
   content that becomes authoritative with verified publication; keep post-publication
   cleanup outside the tracked lifecycle transition.

## Notes

Review-run validity, evaluation-run validity, Ready-to-Publish recovery, remote-derived
Landed authority, and merits-only round counting otherwise match the governing ADRs.

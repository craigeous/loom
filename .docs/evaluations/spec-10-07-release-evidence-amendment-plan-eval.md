# Plan Evaluation: spec-10-07-release-evidence-amendment

Artifact: [spec-10-07-release-evidence-amendment](../slice-plans/spec-10-07-release-evidence-amendment.md)
Commit: 999f03a
Round: 1
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [ADR 0005](../ADR/0005-specs-frozen-after-approval.md), [spec 10](../spec/10-packaging.md), [spec 07](../spec/07-command-surface.md), and [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

F1 is resolved: the revision restores manifest and catalog loading, the specified offline checks, per-run fields, and a clean candidate install. F2 and F3 remain open in part. The status table and deferred-host labels improve the draft, and correction naming and separation of git checks are now specified, but the support rule still excludes future admissions and the executable verification does not establish all required archive and checklist properties. D-b through D-e remain reasonable subject to F3; D-a's v0.2.0 schema restriction does not fix the general support rule (F2).

## Findings

- [BLOCKER] **F2 — Admission-based support remains contradictory.** The revised Release conformance evidence states that a pair is supported only when ADR 0032 §1, as amended by ADR 0033 §1, lists it as REQUIRED. Neither ADR lists a later admitted pair as REQUIRED; ADR 0033 instead delegates admission to a future per-harness ADR. Thus the rule excludes the very pairs the new table allows. State that a pair is required by the applicable release row including an accepted admission ADR, and preserve ADR 0033's applicable admission and atomic release conditions.
- [MAJOR] **F3 — Verification remains incomplete.** The new archive command accepts any entry under `logs/`, without checking the specified log path pattern or file types; it therefore does not establish the stated archive-only contract. It also does not provide the previously requested mechanical retirement and deferral invariant checks. Add executable checks for the archive's allowed paths and types and for the checklist's retirement and deferral assertions. Correction naming and release-time git versus offline validation separation are addressed.

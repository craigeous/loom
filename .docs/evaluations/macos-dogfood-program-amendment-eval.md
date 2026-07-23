# Evaluation: macOS-first dual-client dogfood program amendment

Verdict: FAIL
Round: 0
Reviewed against: accepted ADR 0024, ADRs 0018/0019/0023, target specs 00/02/03/04/06/07/08/10, the spec index, improvement plan, and plan-evaluation rubric

Evidence mode: `loom-repository-bootstrap/v1`
Conformance: degraded bootstrap; not `loom-local-review/v1`
Isolation: not established under ADR 0022
Release conformance: not established

## Findings

- [BLOCKER] `R0-F001` — The plan deferred planner-owned frozen-spec amendments until
  after slice-plan approval, which would route illegal spec edits to a developer.
- [BLOCKER] `R0-F002` — The path boundary used open-ended evaluator/finalization
  classes instead of the literal exhaustive allowlist ADR 0024 requires.
- [BLOCKER] `R0-F003` — The eight-spec step did not map exact normative changes to
  each file/section, including the added bootstrap eligibility exceptions.
- [BLOCKER] `R0-F004` — Digest verification incorrectly described hashing a body and
  semantic comparison; spec 08 requires whole-file normalized bytes and byte-exact
  deterministic rendered blocks.
- [BLOCKER] `R0-F005` — Publication checks omitted full protected transition history,
  bound tip, component availability, no-conflicting-intent, and settled-result
  containment.
- [MAJOR] `R0-F006` — Several invariants had unspecified searches rather than bounded
  commands, exact values/counts, parsers, and exit expectations.

## Required changes

1. Keep the complete planning set Draft while the planner authors all amendments,
   then submit that exact set once for cold plan evaluation.
2. Enumerate every writable and immutable prerequisite path literally.
3. Add a per-file/per-section amendment matrix.
4. Use spec 08's exact whole-file digest and deterministic byte-comparison contract.
5. Add every ADR-0023/0024 pre-run and pre-publication state check.
6. Replace vague searches with executable bounded assertions and expected results.

## Notes

The sealed package and accepted-authority bindings validated. Evaluator raw verdict
SHA-256: `98583cbf24027b0708c38086f21a0073aca17813e85572a25f873417b91909dc`.

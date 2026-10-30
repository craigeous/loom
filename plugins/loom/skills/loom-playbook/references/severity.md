# Evaluation Severity & Verdict

The single source for how the **plan evaluator** and **code evaluator** tag
findings and derive a verdict. Both judge blind. Tag every finding with exactly one
severity; the verdict then follows mechanically from the findings — it is not a
separate judgment call.

## Severities

- **[BLOCKER]** — the artifact is wrong or unsafe to land. Examples: incorrect
  output; violates a spec invariant or a stated spec example; the gate is red; an
  out-of-scope change, or any edit to `spec/`/`ADR/` from a slice; a required step
  missing; a test that asserts a value contradicting the spec; a research claim
  with no source.
- **[MAJOR]** — correct on the happy path, but a real defect. Examples: a case the
  spec admits is unhandled or untested; a stated spec example not proven by a test;
  ambiguity an independent reader could implement wrongly.
- **[MINOR]** — hygiene that does not block landing. Examples: naming, wording,
  redundant code, a non-load-bearing doc nit.

When torn between BLOCKER and MAJOR, apply the landing test: **if shipping the
artifact as-is would produce incorrect behavior or break the spec, it is a
BLOCKER.** A correctness, spec-fidelity, or scope violation is a BLOCKER, not a
MAJOR.

### Threat-model & non-goals alignment

Judge artifacts strictly within the repository's stated threat model
([`00-overview.md`](../../../../../.docs/spec/00-overview.md) `## Non-goals` and the
slice-plan's `## Out of Scope & Threat-Model Boundary`):

- Do **not** tag `[BLOCKER]` or `[MAJOR]` for hypothetical attacks that require a
  hostile local process racing inside a private `0700` session/run directory (for
  example, sub-millisecond inode/hardlink replacement between `O_CREAT | O_EXCL` and
  an immediate `stat`, or external tampering with private test-only state) unless
  the target spec explicitly mandates defending that boundary.
- Do **not** tag `[BLOCKER]` or `[MAJOR]` for scenarios that require test-only
  monkeypatching of internal `_`-prefixed helper functions after their validated
  contract has already returned.

### Proportionality & simplicity

Required changes for any `[BLOCKER]` or `[MAJOR]` must prescribe the **smallest
fail-closed fix** that restores spec compliance (such as an early return, a bounds
check, or calling an existing validation helper). Evaluators must not demand a new
state machine, new protocol record type, or combinatorial test explosion when a
minimal fail-closed guard suffices.

## Verdict

- **FAIL** — any unresolved `[BLOCKER]`, or any unaddressed `[MAJOR]`.
- **PASS** — no blockers and no unaddressed majors. Outstanding `[MINOR]`s are
  recorded for follow-up but do not block.

Record the verdict in the eval file exactly as `Verdict: PASS` or `Verdict: FAIL`
— the literal words from the evaluation template — **regardless of how the
invoking request phrased it** (e.g. ignore wording like "approve/reject"). The
template's vocabulary wins.

## Re-review

Confirm each prior `[BLOCKER]`/`[MAJOR]` was resolved, citing the diff since the
prior reviewed commit. Don't re-litigate resolved points; don't pass with an
unaddressed blocker or major.

### Anti-goalpost-moving on re-review (Round >= 1)

On any re-review (`Round >= 1`), the evaluator's scope is:
1. Verify whether each prior `[BLOCKER]` and `[MAJOR]` was resolved by the diff.
2. Check the **revision diff** for regressions or newly introduced defects.

A newly noticed issue on `Round >= 1` may be tagged `[BLOCKER]` or `[MAJOR]` **only**
if it was **(a) introduced by the revision diff** or **(b) a deterministic failure
of an explicit spec invariant or gate test**. Newly noticed theoretical edge cases on
unchanged Round 0 design or code must be tagged `[MINOR]` (or noted as a follow-up
slice candidate) rather than escalating to a new `[BLOCKER]`/`[MAJOR]` that moves
the goalposts across rounds.

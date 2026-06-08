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

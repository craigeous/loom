# Evaluation: Local Review Helper slice plan

Verdict: FAIL
Round: 1
Reviewed against: ADR 0021, ADR 0022, repository improvement plan M4, plan-evaluation rubric and severity guidance; revision diff 6935a15..ff76975.

## Findings

- [MAJOR] The revised status derivation gives conflicting answers after `validate` runs with no results. Step 5 writes an `invalid` verdict for missing finders, but step 7 defines `prepared` as having no result files and says `invalid` is reported when the validation digest matches. Both conditions hold for this case, with no precedence specified; an implementation can report `prepared` and exit 3 instead of the recorded invalid verdict and exit 2. The revision also says any result change resets to `collecting`, but does not explicitly override the stale valid aggregate for the exit code. Specify precedence and test validation with zero results and a result change after a valid verdict.

## Required changes

1. Define phase and exit-code precedence for an unchanged validated empty result set and for a changed result set, so the current state cannot report a stale valid verdict. Add focused status tests for both cases.

## Notes

The revision diff resolves the seven Round 0 findings: object-based export includes per-entry verification and attribute tests; the clean-tree check narrowly excludes supplied gate evidence; validation requires Git objects and rederives the tree, diff, inventory, inputs, and export; the schema and validation define deleted and binary locations; provenance has defined sources and matching checks; assembly records its state and status derives transitions; and the requested validation cases are in the test matrix. The state-transition resolution has the remaining ambiguity identified above. The plan is 250 lines, within the limit.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | Revision 6935a15..ff76975 addresses export, gate evidence, Git-object binding, location schemas, provenance, transitions, and missing tests; the revised transition rules retain the ambiguity identified in Round 1. |

# Evaluation: Local Review Helper slice plan

Verdict: FAIL
Round: 0
Reviewed against: ADR 0021, ADR 0022, repository improvement plan M4, plan-evaluation rubric and severity guidance.

## Findings

- [BLOCKER] The export is not necessarily the source tree at `head_sha`: the plan uses `git archive` with `core.attributesFile=/dev/null` (lines 117–120), but tracked `.gitattributes` can still apply `export-ignore` and `export-subst`. A self-consistent export hash cannot detect an omitted or substituted tracked file. ADR 0021 requires the source tree at the exact head; ADR 0022 requires exact reviewed source. Export directly from the commit tree or otherwise verify every exported path, mode and content against it, and test tracked export attributes.
- [BLOCKER] The clean-tree rule and gate-evidence input conflict (lines 100–108): `--untracked-files=all` rejects untracked evidence inside the repo, while evidence outside it is also rejected. This rules out the expressly supported untracked scratch evidence. Define a narrow exclusion for the supplied evidence, or accept a safely validated external evidence path, while retaining rejection of unrelated dirty state; test both.
- [BLOCKER] Validation does not establish that the manifest's SHAs, tree, inventory and export actually correspond to the reviewed commits (lines 127–137). It only checks self-recorded hashes and makes diff re-derivation optional when objects are absent; a manifest and source from a different tree can be internally consistent and accepted. Define verifiable binding to the exact commit objects and tree, including a fail-closed policy or independently verifiable object evidence when objects are unavailable, and exercise mismatched head/tree/export and unavailable-object cases. ADR 0021 requires recalculation of every object/hash; ADR 0022 depends on the exact source and diff.
- [BLOCKER] The declared manifest schema excludes its own deleted-file representation: `ranges[]` permits only `{start,end}` with `additionalProperties: false` (lines 48–56), while preparation adds `side: old` (lines 114–115). Also findings require `line` or `line_end` (lines 67–69), but validation requires binary findings to omit `line` (lines 148–150) without defining a valid location shape. Specify consistent conditional schemas and location rules for deleted and binary changes, and test valid and invalid examples.
- [MAJOR] The plan does not define how `prepare` obtains several required manifest fields, including Loom/helper versions, adapter and model profile (lines 50–59, 92–94, 122). Nor does validation compare result provenance adapter/model profile with the manifest (lines 141–145). Specify inputs or deterministic sources and matching checks, with a provenance-mismatch test, so the required provenance is reliable.
- [MAJOR] State transitions are under-specified: `validate` writes state but `assemble` never specifies recording `assembled`, and `status` reports pending or last-recorded state without specifying how newly written results change `prepared` to `collecting` (lines 124–126, 153–174). Specify deterministic transitions or derive status from current files, and test status before and after results, validation and assembly.
- [MAJOR] The test matrix omits explicit nonzero exit-status rejection, exact base/head/diff result mismatch, and deleted/binary location acceptance and rejection (lines 210–219). These are distinct protocol validation rules; add focused cases proving each fails closed or succeeds as appropriate.

## Required changes

1. Bind the exported snapshot and validated review inputs to the exact reviewed Git objects, including attribute and missing-object cases.
2. Resolve gate-evidence cleanliness, schema/location, provenance, and state-transition ambiguities as described above.
3. Add focused tests for those fixes and the missing validation cases.

## Notes

The plan is 250 lines, within its stated budget. Its registration inventory covers the resolver, root bindings, fixtures, binding schema, validator and tests; the prompt-hash split can be implemented as an interim input, provided the later release pins prompt assets as ADR 0021 requires. The plan's workspace-construction exclusion is consistent with ADR 0022's separate implementation slices, but the helper's exported review evidence must still be correct.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | Initial review; changes required as listed above. |

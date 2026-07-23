# Evaluation: 05 — Controlled-Input Independent Evaluation

Verdict: PASS
Round: 1
Reviewed artifact commit: `c14034fc9d5b2066858f1660dbfa48ad064b15fa`
Reviewed artifact blob: `01bfc9838f15e941cb469d1b7b231f2b88a32d33`
Reviewed against: accepted ADR 0023; retained production authority in accepted ADRs
0020–0022; sibling specs 03 and 04; exact amendment diff `80499f1^..80499f1`;
resolving revision diff `213b909..c14034f`; plan-evaluation rubric and severity
rules.

## Findings

No blocking or major findings.

## Notes

The `213b909..c14034f` revision resolves the Round-1 blocker. Lines 105–172 now
define a planning-artifact path separate from the code-bearing path. The manifest
binds the normalized artifact path, type/status, full reviewed commit and blob,
artifact bytes, typed authority/rubric/severity inputs, optional current-tree evidence,
and the prior verdict plus exact artifact revision diff on re-review. Only those
read-only inputs reach one fresh cold, non-delegating plan evaluator distinct from the
author/producer and root.

The evaluator can write only one verdict in confined output plus private scratch and
cannot write `.docs/`, commit, or transition status. The root verifies confinement,
eligibility, state, schema, uniqueness, completeness, and all hashes before copying the
verdict without merits changes and applying only spec 03's legal transition. Required
degraded provenance is explicit, including ADR 0023's ratification label. Invalid or
unrecordable runs are infrastructure-blocked, never merits PASS/FAIL, consume no round,
and cannot advance status; the protected transition state and production-component
retirements make fallback and full-sunset revival impossible.

Lines 174 onward retain the code-bearing requirements: exact base/head package,
developer gate evidence, three cold correctness/test/security finders, independent
code evaluator adjudication, and fresh gate rerun. The spec therefore preserves the
code guarantees while excluding every code-only participant from planning evaluation,
consistent with ADR 0023 and Approved specs 03 and 04.

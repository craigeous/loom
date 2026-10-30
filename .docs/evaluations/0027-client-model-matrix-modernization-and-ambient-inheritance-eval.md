# Evaluation — ADR 0027 Ambient Model Inheritance, Model Matrix Modernization, and Dogfood Antigravity Adapter

Artifact: `.docs/ADR/0027-client-model-matrix-modernization-and-ambient-inheritance.md`
Authority: spec 00-overview, spec 02-roles, spec 10-packaging, ADR 0002, ADR 0018, ADR 0024, plan-eval-rubric.md, severity.md
Round: 1
Verdict: PASS

Revision diff inspected: `git diff 9485f53..d3e722f` (ADR 0027 only).

## Round 0 finding resolution

1. **[BLOCKER] Silent supersession — RESOLVED.** §1 explicitly partially supersedes ADR 0002 and ADR 0018 §3 and states what remains in force.
2. **[BLOCKER] Spec 02/10 contradiction without a path — RESOLVED.** §5.1 schedules a formal planner spec amendment for specs 02 and 10 (inheritance, precedence, matrix v0.3.0); Follow-On Work lists it. Specs stay frozen until that amendment passes cold plan evaluation; the ADR is Draft and does not claim the specs are already amended.
3. **[BLOCKER] Antigravity vs spec 00 / ADR 0024 — RESOLVED.** §4 recasts Antigravity as a private dogfood adapter under ADR 0024 and states it leaves the public dual-client obligations (spec 00, ADR 0019) unchanged. "First-class" language is removed.
4. **[MAJOR] Traceability — RESOLVED (adequately).** Context now states the concrete problems (the Codex retirement error, the quota error, commit `0dd3db9`) and references ADRs/specs by link. No research note is cited, but the rubric accepts "research/problem".
5. **[MAJOR] Exact model IDs in the Decision — RESOLVED.** The Decision names no model IDs. They remain only as Context examples, and defaults are delegated to the matrix.
6. **[MAJOR] Undefined mechanisms — RESOLVED to ADR altitude.** The four-tier precedence is defined (CLI > `.docs/loom-models.json` > ambient > matrix). The cache path and TTL are specified, and Claude effort is explicitly omitted on the wire. The `.docs/loom-models.json` schema and the "conforming to supported provider families" test are left to the scheduled spec amendment and schema work.
7. **[MAJOR] Consequences — RESOLVED.** The ADR now names trade-offs (machine-to-machine variation, mitigated by logging the effective model), the test-matrix burden, and follow-on work (spec amendments, matrix v0.3.0, schemas, launcher).
8. **[MINOR] Vague "baseline floors" — RESOLVED** (matrix v0.3.0 floors).

## Residual notes (non-blocking, not goalpost shifts)

- The spec amendment MUST define the `.docs/loom-models.json` schema, the ambient-validity test, and the cache invalidation rule. It must also address blind-review comparability under ambient drift, since the effective-model logging is only a mitigation.
- The ADR has no `Supersedes`/`Amends` header line, though §1 states it in the body. Consider adding one at acceptance.
- The rotation `claude -> codex -> antigravity -> claude` should be explicitly scoped to private dogfood runs in the spec amendment.

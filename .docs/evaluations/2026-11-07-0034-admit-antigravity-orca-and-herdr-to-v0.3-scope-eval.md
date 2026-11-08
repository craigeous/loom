# Plan Evaluation: 0034-admit-antigravity-orca-and-herdr-to-v0.3-scope

Artifact: [0034-admit-antigravity-orca-and-herdr-to-v0.3-scope](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md)
Commit: 77dac53
Round: 1
Verdict: FAIL
Reviewed against: [ADR 0031](../ADR/0031-herdr-as-an-hc-driven-client.md), [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [hc runtime reference](../research/2026-11-01-hc-agent-runtime-reference.md), [Orca and Antigravity runtime reference](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

The revision cites new Orca and Antigravity runtime research, identifies floors and bindings, and replaces client-token rotation with provider-family rules. It preserves the hc evaluator prohibition and live-probe gate, describes controlled-input and process separation without claiming shared-UID kernel containment, and correctly identifies the ADR 0033 §1 deferrals as superseded. However, three major findings remain: (1) omission of material ADR 0032 §6 work lists and truncation of E1–E5 evidence requirements, (2) an unresolved contradiction between requiring all five roles for Herdr supported status and continuing the prohibition of hc evaluators, and (3) failure to require deterministic resolution of the evaluator model family and fail closed when unknown.

## Findings

- [MAJOR] Admission work lists and E1–E5 evidence remain incomplete: The revised dispositions omit material ADR 0032 §6 work: Antigravity role isolation and governance testing, stubbed launch and rotation tests, the evidence-gated default rotation, and spec amendments; and Herdr retirement and the role-governance hc deny. The E1–E5 plan also substitutes different criteria for ADR 0032 §3: E3 omits required parity, guard and refusal coverage; E4 lists limited activities rather than all five roles, a complete blind loop and the gate for each pair at its floor; and E5 omits owner acknowledgement and the post-tag, commit-bound evidence record. The proposed full proof does not specify these required results.
- [MAJOR] Herdr release evidence has no path past the evaluator prohibition: ADR 0032 §§3 and 5 require all five roles through each required host and explicitly say Herdr cannot become supported while hc evaluators remain prohibited. This ADR preserves that prohibition but requires all five pairs for v0.3.0 and schedules a complete proof without resolving or expressly superseding the conflicting Herdr evidence requirement. Direct evaluator processes preserve the hc prohibition but do not satisfy the existing requirement to launch every role through hc.
- [MAJOR] Unresolved evaluator model family does not explicitly fail closed: The revision requires different underlying author and evaluator families and fails closed when the author family is unresolved, but does not require deterministic resolution of the evaluator family or fail closed when it is unknown. Antigravity can select multiple families, so author resolution alone cannot establish the comparison required by the prior finding.

## Required changes

1. Complete the ADR 0032 §6 dispositions and give each required pair an E1–E5 plan that preserves the actual offline, live, owner sign-off and commit-bound evidence requirements.
2. Resolve the conflict between the required Herdr five-role evidence and the preserved hc evaluator prohibition, either through an authorized follow-up decision or an explicit, justified supersession of the applicable evidence requirement.
3. Require deterministic resolution of both author and evaluator model families, including hosted and Antigravity sessions, and fail closed if either cannot be established.

## Notes

- The revision cites new Orca and Antigravity runtime research, identifies floors and bindings, and replaces client-token rotation with provider-family rules.
- It preserves the hc evaluator prohibition and live-probe gate, describes controlled-input and process separation without claiming shared-UID kernel containment, and correctly identifies the ADR 0033 §1 deferrals as superseded.

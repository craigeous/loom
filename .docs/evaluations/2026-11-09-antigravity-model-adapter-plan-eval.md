# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/archive/antigravity-model-adapter.md)
Verdict: FAIL
Round: 4
Commit: b200179b0a642a8c087953ae29eaf829104f8f9f
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 4; BLOCKER: 0, MAJOR: 3, MINOR: 0). The revision specifies who captures and stores the author model, how it is passed to evaluator launches, and an explicit handoff test alongside same-family rejection. The launch-descriptor contract remains incomplete, and the handoff test does not exercise the newly specified orchestrator flow. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [MAJOR] The descriptor contract names the common required fields but does not specify their types or constraints, including `schema`, `client`, `role`, `profile`, `coldId`, `cold`, `delegation`, and `permissions`. It also leaves the `environment` object's unknown-field behavior unspecified. Therefore, the plan does not define complete permitted shapes for all three variants.
- [MAJOR] The stated compatibility claim does not establish how existing consumers with closed schemas accept the new top-level fields, or how existing launcher invocations behave when `--author-model` is omitted. The prior verdict explicitly required compatibility with existing signatures and consumers.
- [MAJOR] The handoff test manually extracts the author model and passes it to the evaluator. It would not detect a failure in `loom-run` to capture, persist, or forward that value, which is the flow the revision assigns to the orchestrator.

## Required Changes

1. Define the types and constraints of every common descriptor field and the complete nested object shapes, including unknown-field behavior.
2. Specify compatibility behavior for existing launcher calls and descriptor consumers, including any schema or consumer updates needed for the additive fields.
3. Add a test that exercises the orchestrator's author-launch capture, routing-file persistence, and evaluator-launch handoff, while retaining the same-family rejection test.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 3 | plan | FAIL | Author model handoff data flow and handoff test unspecified; launch descriptor schema lacked complete 3-variant contract and consumer compatibility definition. Resolved in Round 4 by specifying orchestrator descriptor capture, persistence, and `--author-model` handoff; defining the complete 3-variant `loom-role-launch-v1` schema with closed constraints, required/optional fields, and additive consumer compatibility; and adding an explicit author-to-evaluator handoff test. |
| 2 | plan | FAIL | Author model propagation lacked concrete evidence capture definition; launch schema lacked complete 3-variant contract and consumer compatibility; threat-model overstated cognitive independence; baseline paths not fully specified. Resolved in Round 3 by specifying author descriptor capture and mandatory concrete `--author-model`, rejecting aliases in family extraction, detailing the complete 3-variant `loom-role-launch-v1` schema with additive compatibility, enumerating the exact 6-file v0.2.0 repository paths for git show validation, and narrowing the threat-model claim to provider-family classification separation. |
| 1 | plan | FAIL | Step 3 mapped aliases to Google without establishing concrete model; `--author-family` permitted unverified claims; launch schema shape not detailed for all variants; v0.2.0 baseline and fixture comparisons inconsistent; threat-model overstated cognitive independence. Resolved in Round 2 by requiring concrete model resolution before family extraction, eliminating unverified `--author-family` in favor of mandatory concrete `--author-model`, defining exact launch schema additions across all three variants, specifying the 6-file v0.2.0 baseline verified against `git show v0.2.0:<path>`, and narrowing the threat-model claim strictly to provider-family separation. |
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Notes

The Round 3 request for an explicit handoff example and same-family rejection is present; the remaining test gap concerns verification of the actual orchestrator path. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

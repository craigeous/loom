# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/archive/antigravity-model-adapter.md)
Verdict: FAIL
Round: 6
Commit: 33afb0b5b30df65a1aa18cc4e5b2719c834943bb
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 6; BLOCKER: 0, MAJOR: 2, MINOR: 0). The revision adds launcher persistence, the orchestrator workflow step, production-path handoff test, and strict schema checks. The Round 5 consumer-compatibility finding remains unresolved: the plan asserts that every consumer shares the revised schema, but does not establish that fact or specify how existing consumers are updated. The persistence step also leaves researcher routing ambiguous. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [MAJOR] Step 1 declares the schema to be the sole canonical asset and says all consumers resolve it directly, but identifies no consumer paths or migration work to establish that assertion. The Ajv checks validate descriptors against the revised schema; they do not exercise an identified consumer’s validation path or show how a consumer with an existing closed schema obtains the revision. Keeping the `v1` identifier alone does not make an old closed schema accept the new fields.
- [MAJOR] Step 3 includes `researcher` among author launches that update the routing file, but specifies only planner and developer keys. An implementer cannot tell whether a researcher launch should write separate keys, leave the file unchanged, or overwrite planner/developer provenance.

## Required Changes

1. Identify the launch-descriptor consumers and how each obtains the canonical schema; specify updates or version handling for any consumer that does not already use it. Test the relevant consumer validation path with legacy and v0.3.0 descriptors and unknown-property rejection.
2. Define researcher routing-file behavior explicitly, including its keys if persistence is required, and ensure it cannot overwrite planner or developer provenance.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 5 | plan | FAIL | Test still performed orchestrator capture manually instead of invoking production path; closed-schema consumer sharing and versioning behavior not established. Resolved in Round 6 by adding Step 4 for `loom-run/SKILL.md` orchestrator workflow, implementing `--routing-file` author-launch capture and persistence in `loom-launch-role`, asserting that all consumers share the canonical schema asset under compatible minor extension `v1`, and adding tests invoking the production author-persistence -> evaluator-handoff path and strict Ajv legacy/v0.3.0 consumer validation. |
| 4 | plan | FAIL | Descriptor types & constraints incomplete across 3 variants and environment object; consumer and CLI compatibility unspecified for omitted --author-model and closed schemas; handoff test bypassed orchestrator routing-file flow. Resolved in Round 5 by defining complete types, enums, patterns, and constraints for all common and variant fields with additionalProperties: false; specifying single-family backward compatibility defaults and schema property updates for closed-schema consumers; and replacing manual extraction test with full orchestrator launch capture, routing-file persistence, and evaluator handoff test. |
| 3 | plan | FAIL | Author model handoff data flow and handoff test unspecified; launch descriptor schema lacked complete 3-variant contract and consumer compatibility definition. Resolved in Round 4 by specifying orchestrator descriptor capture, persistence, and `--author-model` handoff; defining the complete 3-variant `loom-role-launch-v1` schema with closed constraints, required/optional fields, and additive consumer compatibility; and adding an explicit author-to-evaluator handoff test. |
| 2 | plan | FAIL | Author model propagation lacked concrete evidence capture definition; launch schema lacked complete 3-variant contract and consumer compatibility; threat-model overstated cognitive independence; baseline paths not fully specified. Resolved in Round 3 by specifying author descriptor capture and mandatory concrete `--author-model`, rejecting aliases in family extraction, detailing the complete 3-variant `loom-role-launch-v1` schema with additive compatibility, enumerating the exact 6-file v0.2.0 repository paths for git show validation, and narrowing the threat-model claim to provider-family classification separation. |
| 1 | plan | FAIL | Step 3 mapped aliases to Google without establishing concrete model; `--author-family` permitted unverified claims; launch schema shape not detailed for all variants; v0.2.0 baseline and fixture comparisons inconsistent; threat-model overstated cognitive independence. Resolved in Round 2 by requiring concrete model resolution before family extraction, eliminating unverified `--author-family` in favor of mandatory concrete `--author-model`, defining exact launch schema additions across all three variants, specifying the 6-file v0.2.0 baseline verified against `git show v0.2.0:<path>`, and narrowing the threat-model claim strictly to provider-family separation. |
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Notes

The plan is 189 lines, within the 250-line target. Step 4 is file-scoped, and Step 6 invokes the specified launcher persistence and evaluator handoff sequence while retaining same-family rejection. The stated v0.3.0 floor, binding, profile mappings, deferred live proof, and threat-model boundary align with the cited authority. The plan names the repository gate and a targeted Bash command. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

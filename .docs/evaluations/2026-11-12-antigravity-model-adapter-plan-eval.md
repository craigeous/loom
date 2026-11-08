# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/archive/antigravity-model-adapter.md)
Verdict: FAIL
Round: 7
Commit: c43d500f95be870182dc2f7e2bd6b8ff73cde41e
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 7; BLOCKER: 0, MAJOR: 2, MINOR: 0). The revision defines separate researcher routing keys and specifies the three strict Ajv compatibility cases. The Round 6 consumer finding remains unresolved: the plan lists four consumers but does not establish how each handles schema resolution and versioning, and its claim that all four resolve the schema directly conflicts with the listed behavior. The researcher isolation test also omits the planner and developer model keys. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [MAJOR] Step 1 says all internal consumers resolve the canonical schema directly, but its own descriptions say the orchestrator consumes stdout JSON, the launcher checks a file, and the integrity validator checks schema integrity. It does not establish how the orchestrator handles descriptor fields or versions, or substantiate the absence of separate closed schemas and out-of-tree copies. Retaining the `v1` identifier alone does not establish compatibility for a consumer using an older closed schema.
- [MAJOR] The researcher isolation test asserts that `.routes["planner"]` and `.routes["developer"]` remain unchanged, but does not assert the same for `.routes["planner-model"]` and `.routes["developer-model"]`. It therefore does not fully verify the stated isolation of planner and developer provenance.

## Required Changes

1. For each identified consumer, state accurately whether and how it resolves or validates against the canonical schema, how it handles descriptor versions and added fields, and what update is needed if it has a separate closed schema. Provide a mechanically verifiable basis for the no-duplicate claim, with an explicit boundary for out-of-tree consumers.
2. Seed and assert all four planner and developer provenance keys unchanged in the researcher isolation test, while asserting both researcher keys update.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 6 | plan | FAIL | Consumer resolution paths not identified to substantiate single canonical schema claim; researcher routing-file persistence behavior ambiguous. Resolved in Round 7 by explicitly enumerating all 4 launch-descriptor consumers and their file resolution paths, establishing why version v1 is backward-compatible with no duplicate schemas, defining isolated researcher routing persistence (.routes["researcher"] and ["researcher-model"]) that cannot overwrite planner/developer keys, and adding an explicit test for researcher routing isolation. |
| 5 | plan | FAIL | Test still performed orchestrator capture manually instead of invoking production path; closed-schema consumer sharing and versioning behavior not established. Resolved in Round 6 by adding Step 4 for `loom-run/SKILL.md` orchestrator workflow, implementing `--routing-file` author-launch capture and persistence in `loom-launch-role`, asserting that all consumers share the canonical schema asset under compatible minor extension `v1`, and adding tests invoking the production author-persistence -> evaluator-handoff path and strict Ajv legacy/v0.3.0 consumer validation. |
| 4 | plan | FAIL | Descriptor types & constraints incomplete across 3 variants and environment object; consumer and CLI compatibility unspecified for omitted --author-model and closed schemas; handoff test bypassed orchestrator routing-file flow. Resolved in Round 5 by defining complete types, enums, patterns, and constraints for all common and variant fields with additionalProperties: false; specifying single-family backward compatibility defaults and schema property updates for closed-schema consumers; and replacing manual extraction test with full orchestrator launch capture, routing-file persistence, and evaluator handoff test. |
| 3 | plan | FAIL | Author model handoff data flow and handoff test unspecified; launch descriptor schema lacked complete 3-variant contract and consumer compatibility definition. Resolved in Round 4 by specifying orchestrator descriptor capture, persistence, and `--author-model` handoff; defining the complete 3-variant `loom-role-launch-v1` schema with closed constraints, required/optional fields, and additive consumer compatibility; and adding an explicit author-to-evaluator handoff test. |
| 2 | plan | FAIL | Author model propagation lacked concrete evidence capture definition; launch schema lacked complete 3-variant contract and consumer compatibility; threat-model overstated cognitive independence; baseline paths not fully specified. Resolved in Round 3 by specifying author descriptor capture and mandatory concrete `--author-model`, rejecting aliases in family extraction, detailing the complete 3-variant `loom-role-launch-v1` schema with additive compatibility, enumerating the exact 6-file v0.2.0 repository paths for git show validation, and narrowing the threat-model claim to provider-family classification separation. |
| 1 | plan | FAIL | Step 3 mapped aliases to Google without establishing concrete model; `--author-family` permitted unverified claims; launch schema shape not detailed for all variants; v0.2.0 baseline and fixture comparisons inconsistent; threat-model overstated cognitive independence. Resolved in Round 2 by requiring concrete model resolution before family extraction, eliminating unverified `--author-family` in favor of mandatory concrete `--author-model`, defining exact launch schema additions across all three variants, specifying the 6-file v0.2.0 baseline verified against `git show v0.2.0:<path>`, and narrowing the threat-model claim strictly to provider-family separation. |
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Notes

The plan is 200 lines, within the 250-line target. Its numbered steps are file-scoped; the out-of-scope and threat-model boundary are explicit; and it names the repository gate and a targeted verification command. The specified floor, release registration, deferred live proof, and provider-family boundary align with the cited authority. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

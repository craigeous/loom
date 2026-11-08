# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/antigravity-model-adapter.md)
Verdict: FAIL
Round: 5
Commit: d43a16a4b21974af19b52ea96dcf603b0e501c2a
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 5; BLOCKER: 0, MAJOR: 2, MINOR: 0). The revision defines the descriptor fields and closed environment object, specifies omitted-model behavior for single-family authors, and retains same-family rejection. It does not yet test the orchestrator’s actual capture and handoff path, and its closed-schema compatibility claim remains incomplete. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [MAJOR] The proposed handoff test still performs the orchestrator’s work in the test: it captures the launcher output, parses it, and writes the routing file itself. It would pass if `loom-run` failed to capture or persist the model. The steps also describe orchestrator changes in context but do not identify a file-scoped implementation step for them.
- [MAJOR] Adding optional properties to the updated launcher schema does not make an **existing consumer’s own closed schema** accept descriptors containing those properties. The plan does not identify affected closed-schema consumers, specify their updates or versioning behavior, or establish that all such consumers use the updated shared schema.

## Required Changes

1. Add a numbered, file-scoped step for the actual `loom-run` capture, routing-file persistence, and evaluator handoff. Specify a test that invokes that production path and observes the persisted model and evaluator result; retain the routing-file same-family rejection case.
2. Identify how existing closed-schema consumers obtain the revised schema and specify any required consumer updates or compatible versioning. Add a compatibility check that exercises the relevant consumer validation path.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 4 | plan | FAIL | Descriptor types & constraints incomplete across 3 variants and environment object; consumer and CLI compatibility unspecified for omitted --author-model and closed schemas; handoff test bypassed orchestrator routing-file flow. Resolved in Round 5 by defining complete types, enums, patterns, and constraints for all common and variant fields with additionalProperties: false; specifying single-family backward compatibility defaults and schema property updates for closed-schema consumers; and replacing manual extraction test with full orchestrator launch capture, routing-file persistence, and evaluator handoff test. |
| 3 | plan | FAIL | Author model handoff data flow and handoff test unspecified; launch descriptor schema lacked complete 3-variant contract and consumer compatibility definition. Resolved in Round 4 by specifying orchestrator descriptor capture, persistence, and `--author-model` handoff; defining the complete 3-variant `loom-role-launch-v1` schema with closed constraints, required/optional fields, and additive consumer compatibility; and adding an explicit author-to-evaluator handoff test. |
| 2 | plan | FAIL | Author model propagation lacked concrete evidence capture definition; launch schema lacked complete 3-variant contract and consumer compatibility; threat-model overstated cognitive independence; baseline paths not fully specified. Resolved in Round 3 by specifying author descriptor capture and mandatory concrete `--author-model`, rejecting aliases in family extraction, detailing the complete 3-variant `loom-role-launch-v1` schema with additive compatibility, enumerating the exact 6-file v0.2.0 repository paths for git show validation, and narrowing the threat-model claim to provider-family classification separation. |
| 1 | plan | FAIL | Step 3 mapped aliases to Google without establishing concrete model; `--author-family` permitted unverified claims; launch schema shape not detailed for all variants; v0.2.0 baseline and fixture comparisons inconsistent; threat-model overstated cognitive independence. Resolved in Round 2 by requiring concrete model resolution before family extraction, eliminating unverified `--author-family` in favor of mandatory concrete `--author-model`, defining exact launch schema additions across all three variants, specifying the 6-file v0.2.0 baseline verified against `git show v0.2.0:<path>`, and narrowing the threat-model claim strictly to provider-family separation. |
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Notes

The plan is 180 lines, within the 250-line target. It states its scope and threat-model boundary and provides a repository gate and targeted Bash command. The stated v0.3.0 floor, binding, and profile mappings match ADR 0034; E4 live proof is explicitly deferred to Slice 5. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

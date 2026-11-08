# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/archive/antigravity-model-adapter.md)
Verdict: FAIL
Round: 3
Commit: b1aa49641496384f9160a80b5d16ca78928e96ae
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 3; BLOCKER: 0, MAJOR: 2, MINOR: 0). The revision resolves the exact baseline paths and narrows the threat-model claim. It also requires concrete Antigravity author models, rejects aliases and adds the requested same-family test. However, it still leaves the author-model handoff and complete launch-descriptor contract insufficiently specified for independent implementation. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [MAJOR] The plan says the author descriptor records the concrete model and evaluator launches receive `--author-model`, but does not specify which component reads the descriptor, how it carries the value to each evaluator launch, or how the value is tied to the actual model used. The requested same-family test is listed, but no handoff test verifies that evidence flows from the author launch to the evaluator.
- [MAJOR] The launch-schema contract remains incomplete. The plan lists common required field names and two optional family fields, but does not define the client-specific object shapes, types, constraints, or all permitted optional fields for the three variants. It also says `authorClient` and `crossFamilyVerified` are emitted without specifying their schema definitions, and asserts consumer compatibility without explaining existing launcher-signature and consumer behavior.

## Required Changes

1. Specify the component and data flow that capture the actual resolved author model from the launch descriptor and pass it as `--author-model` to every evaluator launch. Add a test covering that handoff as well as same-family rejection.
2. Define the complete permitted descriptor and schema shapes for `claude`, `codex`, and `antigravity`, including required and optional fields, types, constraints, and unknown-field behavior. Specify how the additive fields remain compatible with existing launcher signatures and consumers.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 2 | plan | FAIL | Author model propagation lacked concrete evidence capture definition; launch schema lacked complete 3-variant contract and consumer compatibility; threat-model overstated cognitive independence; baseline paths not fully specified. Resolved in Round 3 by specifying author descriptor capture and mandatory concrete `--author-model`, rejecting aliases in family extraction, detailing the complete 3-variant `loom-role-launch-v1` schema with additive compatibility, enumerating the exact 6-file v0.2.0 repository paths for git show validation, and narrowing the threat-model claim to provider-family classification separation. |
| 1 | plan | FAIL | Step 3 mapped aliases to Google without establishing concrete model; `--author-family` permitted unverified claims; launch schema shape not detailed for all variants; v0.2.0 baseline and fixture comparisons inconsistent; threat-model overstated cognitive independence. Resolved in Round 2 by requiring concrete model resolution before family extraction, eliminating unverified `--author-family` in favor of mandatory concrete `--author-model`, defining exact launch schema additions across all three variants, specifying the 6-file v0.2.0 baseline verified against `git show v0.2.0:<path>`, and narrowing the threat-model claim strictly to provider-family separation. |
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Notes

All six baseline files now have exact repository paths and a `git show v0.2.0:<path>` comparison. The threat-model boundary is limited to provider-family classification separation. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

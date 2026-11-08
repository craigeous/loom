# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/antigravity-model-adapter.md)
Verdict: FAIL
Round: 1
Commit: 0d7dde4e17e9e3f379d1cbc25cf3c385071e6fa8
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 1; BLOCKER: 1, MAJOR: 2, MINOR: 2). The revision adds the required dual-Bash repository gate, cache and version-refusal tests, and substantially more descriptor detail. The central family-resolution issue remains: the plan still assigns Google family to aliases without establishing the model actually used. The v0.2.0 baseline and provider-separation claims also remain inconsistent. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [BLOCKER] Step 3 maps `flash`, `inherit`, and `pro` directly to Google matrix models for family resolution. The cited authority does not establish that those aliases select those concrete models. If an alias inherits or selects a Claude model, the launcher could incorrectly permit same-family evaluation. This leaves the Round 0 family-resolution finding unresolved.
- [MAJOR] The plan permits `--author-family` as an alternative to `--author-model`, but does not specify how that value is validated or established as the actual author model's family. It also does not specify the requested unknown-author-model test or how the new argument reaches every evaluator launch.
- [MAJOR] The descriptor revision lists root properties, helper values, and two new launch-schema fields, but does not define the complete permitted `loom-role-launch-v1` shape or resolve how the schema and emitted descriptor fit the existing contract. The requested exact shape and signature check therefore remains incomplete.
- [MINOR] The stated v0.2.0 baseline is `git show v0.2.0:<path>`, while Step 4 directs comparison against the fixture directory. The latter does not establish that either the matrix or fixtures match the release tag. The relevant file set and comparison are not specified consistently.
- [MINOR] The threat-model section still says the invariant enforces "cognitive and model weights/training provenance separation." Provider-family separation alone does not establish those properties.

## Required Changes

1. Resolve aliases to the concrete model actually selected before determining its family, or fail closed when that model cannot be established. Add tests for unknown author models and alias resolution, including a same-family case.
2. Specify how author model or family evidence reaches every evaluator launch, validate any accepted `--author-family` value, and make its relationship to the actual author model explicit.
3. Specify the complete launch-descriptor and schema changes, including required versus optional fields and their compatibility with existing launcher signatures and consumers.
4. Define the exact v0.2.0 file set and a mechanical comparison against the tagged release baseline; make the validator instruction consistent with it.
5. Limit the threat-model claim to provider-family separation.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Notes

The plan now explicitly calls for `scripts/check` under Bash 3.2.57 and Bash 5.3+, and tests for cache hit, expiration, atomic rewrite, and below-floor or unknown version refusal. It also specifies the Antigravity root fields, `allowedHelpers`, and the v0.3.0 floor and profile additions. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

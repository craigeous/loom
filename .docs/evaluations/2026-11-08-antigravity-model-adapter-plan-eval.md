# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/antigravity-model-adapter.md)
Verdict: FAIL
Round: 2
Commit: 5442fce3c823a32eb410ad7db884887086faa3f6
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 2; BLOCKER: 0, MAJOR: 2, MINOR: 1). The revision removes direct alias-to-family mapping and the unvalidated `--author-family` option. It also specifies the dual-Bash gate, cache and version-refusal tests, root descriptor fields, helper list, and v0.3.0 matrix additions. However, several requirements remain unresolved: the plan does not fully specify how concrete author-model evidence reaches evaluator launches, the complete launch-descriptor contract, or an accurate provider-family threat-model claim. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [MAJOR] The plan requires a concrete `--author-model` "via flag or routing file," but does not specify how that evidence is captured from the actual author launch and propagated to every evaluator launch. Step 3 also sends aliases through `_agy_pick` inside family extraction without defining how that establishes the model actually used by an author. The requested alias-resolution test does not include a resolved alias selecting the author's family and being rejected.
- [MAJOR] The launch-schema change specifies only two optional additions. It does not define the complete permitted `loom-role-launch-v1` shape, including required fields for all three variants, or explain compatibility with existing launcher signatures and consumers. The emitted descriptor includes fields beyond the two schema additions without resolving their contract.
- [MINOR] The threat-model boundary still claims provider-family separation ensures distinct model weights and API endpoints. Family classification alone does not establish either property. The six-file baseline is now directed against `git show v0.2.0:<path>`, though four entries are given as bare filenames rather than unambiguous repository paths.

## Required Changes

1. Specify how the actual concrete author model is recorded and carried to every evaluator launch; reject aliases or resolve them to evidence of the model actually used. Add a test in which an alias resolves to the author's family and evaluation is rejected.
2. Specify the complete launch-descriptor and schema contract for all three variants, including required and optional fields and compatibility with existing signatures and consumers.
3. Limit the threat-model claim to provider-family separation, and give all six baseline files as exact repository paths for the tag comparison.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 1 | plan | FAIL | Step 3 mapped aliases to Google without establishing concrete model; `--author-family` permitted unverified claims; launch schema shape not detailed for all variants; v0.2.0 baseline and fixture comparisons inconsistent; threat-model overstated cognitive independence. Resolved in Round 2 by requiring concrete model resolution before family extraction, eliminating unverified `--author-family` in favor of mandatory concrete `--author-model`, defining exact launch schema additions across all three variants, specifying the 6-file v0.2.0 baseline verified against `git show v0.2.0:<path>`, and narrowing the threat-model claim strictly to provider-family separation. |
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Notes

The plan explicitly calls for `scripts/check` under Bash 3.2.57 and Bash 5.3+, and includes cache hit, expiration, atomic rewrite, and below-floor or unknown-version refusal tests. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

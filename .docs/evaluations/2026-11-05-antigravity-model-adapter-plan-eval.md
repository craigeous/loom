# Evaluation: antigravity-model-adapter

Artifact: [antigravity-model-adapter](../slice-plans/archive/antigravity-model-adapter.md)
Verdict: FAIL
Round: 0
Commit: e0985349ac2932df4bad3e4ccb6fa3bf8c410516
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), [runtime research](../research/2026-11-08-orca-and-antigravity-runtime-reference.md), and [plan evaluation rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

FAIL (round 0; BLOCKER: 1, MAJOR: 3, MINOR: 2). The v0.3.0 floor and profile mappings match ADR 0034, and the plan is within its stated size budget. However, the family-enforcement flow can skip or incorrectly infer the author's family, and the verification plan omits the required repository gate and discovery-cache coverage. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

## Findings

- [BLOCKER] Step 3 enforces author-family resolution only "when `author_client` is supplied or routed." It also substitutes the profile floor when `--author-model` is absent. For a multi-family Antigravity author, that floor does not establish which model actually authored the artifact; it can therefore permit same-family evaluation. ADR 0034 §3 requires both families to be deterministically resolved and failure when either cannot be resolved.
- [MAJOR] The plan calls `node scripts/validate-repository.mjs --all` the full repository check, but ADR 0034 §4 and Spec 10 name `scripts/check` as the repository gate. The plan does not specify running that gate under both required Bash versions.
- [MAJOR] ADR 0034 §5 explicitly includes verification of dynamic discovery caching in the Antigravity conformance slice. The plan contains no discovery-cache test or command. It also omits explicit unknown-version and below-floor refusal coverage called for by ADR 0034 §1.
- [MAJOR] The descriptor work is incomplete: the plan adds family fields and requires schema conformance, but names no launch-descriptor schema update or exact permitted shape. The root descriptor also leaves `allowedHelpers` unspecified. An implementer cannot reliably produce the asserted validated artifacts from the plan alone.
- [MINOR] The claim that the family invariant "guarantees cognitive independence" exceeds what provider-family separation establishes. The mapping also treats aliases such as `inherit` as Google without establishing the actual selected model's family.
- [MINOR] The plan requires a validator to assert that v0.2.0 files are unchanged but does not define a stable baseline or mechanical comparison. "Against HEAD" is ambiguous once the implementation is committed.

## Required Changes

1. Define how every evaluator launch obtains the author's actual model family; fail closed when it cannot be established. Specify how aliases resolve to an actual family, and cover missing, unknown, same-family, and different-family cases.
2. Specify the exact descriptor and schema changes, including `allowedHelpers`, after checking them against the implementation tree. Resolve any signature or shape mismatches.
3. Add `scripts/check` and the required Bash 3.2 and Bash 5.3+ gate runs, plus targeted tests for discovery caching and unknown/below-floor refusal.
4. Define a mechanical baseline for the v0.2.0 unchanged assertion and narrow the cognitive-independence claim to provider-family separation.

## Notes

Antigravity's admission to v0.3.0 at floor `1.4.12` and the three stated profile mappings align with ADR 0034. Spec 10 still contains older deferral text; ADR 0034 supersedes that deferral for scope admission, while supported status remains contingent on release evidence. The explicit threat-model boundary appropriately acknowledges the same-UID limitation. Evaluated blind via OpenAI Codex (`gpt-6.1-terra`).

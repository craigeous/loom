# Evaluation: identity-guard-contract (slice-plan)

Verdict: FAIL
Round: 2
Reviewed against: plan-eval-rubric.md, severity.md (anti-goalpost-moving, Round >= 1), repository-improvement-plan.md (M3 `identity-guard-contract`), ADR 0003, spec 00, spec 08, spec 10, `loom-resolve-helper`, `adapters/roots/*.json`, `schemas/loom-installed-root-binding-v1.schema.json`, `scripts/validate-repository.mjs`, templates/evaluation.md; revision diff `ddccc8f..3f2554f`

## Findings

- [MAJOR] Allowlist mirror enumeration is still incomplete (remainder of Round 1 MAJOR) — The revision now lists the two `adapters/roots/*.json` bindings, the two `adapters/fixtures/v0.2.0/metadata/*-root.json` fixtures, and `expectedRoots` in `scripts/validate-repository.mjs`. It omits `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`, which pins the same allowlist as `"$defs": {"allowedHelpers": {"type": "array", "const": ["loom-coord"]}}` (lines 5-8), referenced by both root-binding variants (lines 36, 72). A developer who follows Step 2 literally will add `loom-verify-identity` to the JSON bindings, and schema validation in `scripts/check` / `validate-repository.mjs --all` will then reject them against `const: ["loom-coord"]`. `scripts/tests/repository-validation.bats` (around lines 433-456) also exercises `allowedHelpers` mutations and may need review. Round 1 required that the plan list every file carrying the allowlist; this one is still missing, so the required change is not fully met.

## Required changes (for FAIL)

1. Add `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json` (`$defs.allowedHelpers.const`) to the Step 2 mirrored-file list, updated to `["loom-coord", "loom-verify-identity"]`.
2. Say whether `scripts/tests/repository-validation.bats` needs a matching update. Its `allowedHelpers` mutation cases at ~433-456 should be checked, and the plan should name it if it changes.

## Notes

Round 1 MAJOR (mirrored allowlist files): partly resolved. Four of the five mirrored artifacts are now named, along with the validator, and a consistency check is added. The schema `const` remains.

No regressions or new defects were found in the revision diff beyond the above. The plan is 107 lines, within the 250-line limit. Nothing else is raised, per the anti-goalpost rule. This is the same mechanical class of gap as Round 1 and should pass once the schema file is listed.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | 2 MAJOR: (1) verifier unnamed/no CLI/no resolver registration; (2) workflow files unnamed. Both resolved by the Round 1 revision. |
| 1 | plan | FAIL | 1 MAJOR: the helper allowlist is mirrored in adapter JSON, fixtures and the validator, which the plan omitted. The Round 2 revision listed the adapter JSON, fixtures and validator. |
| 2 | plan | FAIL | 1 MAJOR: the JSON schema `loom-installed-root-binding-v1.schema.json` still pins `const: ["loom-coord"]` and is not listed. |

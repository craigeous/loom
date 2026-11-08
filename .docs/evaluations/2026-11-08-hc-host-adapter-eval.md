# Code Evaluation: hc-host-adapter

Artifact: [hc-host-adapter](../slice-plans/hc-host-adapter.md)
Commit: 78d011e
Round: 3
Verdict: FAIL
Reviewed against: [ADR 0031](../ADR/0031-herdr-as-an-hc-driven-client.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [hc-host-adapter slice plan](../slice-plans/hc-host-adapter.md), [spec 10](../spec/10-packaging.md), and [code-eval rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md).

## Summary

The implementation in commit `78d011e` introduces `loom-host-hc` and associated metadata, schema, and repository validator checks. However, gate verification failed in the evaluation sandbox due to temporary directory permissions, input validation in `loom-host-hc` permitted embedded newlines in terminal names and integer overflow on numeric options, and compatibility matrix changes exceeded the approved slice scope by modifying the `workflows` array.

## Findings

- [BLOCKER] Gate verification did not pass: Gate execution failed with `mktemp: mkdtemp failed ... Operation not permitted` due to sandbox temporary directory restrictions.
- [MAJOR] Name validation accepts embedded newlines: In `loom-host-hc`, `grep -E` validated line-by-line rather than the entire input string, permitting terminal names containing newlines to pass when the first line matched the regex.
- [MAJOR] Oversized numeric arguments bypass bounds checks: In `loom-host-hc`, integer comparison on oversized numeric arguments (exceeding Bash 64-bit integer limits) failed with integer overflow, bypassing bounds checks.
- [MINOR] Matrix schema change exceeds approved scope: `plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json` and `plugins/loom/adapters/compatibility/v0.3.0.json` were modified to add `"doctor"` to `workflows`, which was not part of the approved `hc-host-adapter` slice plan.

## Required Changes

1. Ensure the gate command runs in an environment with a writable temporary directory (`TMPDIR`).
2. Reject embedded newlines and carriage returns in `_validate_name` before regex validation, and enforce maximum length check.
3. Guard `$timeout` and `$lines` against integer overflow by verifying digit count before numeric comparison.
4. Revert `workflows` modifications in the compatibility matrix schema and `v0.3.0.json`, and re-pin sha256 in `check-toolchain.json`.

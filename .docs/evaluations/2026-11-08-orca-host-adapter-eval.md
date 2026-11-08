# Code Evaluation: orca-host-adapter

Artifact: [orca-host-adapter](../slice-plans/orca-host-adapter.md)
Commit: c84cdae
Round: 1
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [orca-host-adapter slice plan](../slice-plans/orca-host-adapter.md), [spec 07](../spec/07-command-surface.md), [spec 10](../spec/10-packaging.md), and [code-eval rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md).

## Summary

The adapter implements the planned launch refusal, bounded wait and read operations, and close/show cleanup verification. The v0.3.0 host descriptor, fixture, schema and matrix registration are present; the specified v0.2.0 files and installed-root surfaces have no diff, and the toolchain change only repins the matrix schema. The local review reports `ran-clean` and contains no individual findings to adjudicate. Independent evaluation found the status JSON validation defect below.

The requested gate rerun passed: shfmt, ShellCheck, bash syntax, repository validation, and the specified Bash 3.2 Bats command all exited zero. The Bats command's `-f "host binding:"` filter selected six repository-validation tests; it did not run the adapter tests. An additional unfiltered Bash 3.2 run of shell-runtime and adapter tests passed all 22 tests, including the eight adapter tests. The existing malformed-JSON test does not cover an empty successful response.

## Findings

1. **[BLOCKER] Empty status response succeeds without JSON.** In `plugins/loom/bin/loom-host-orca` lines 61–68, `jq -c` exits zero when its input contains no JSON values. If `orca terminal show` exits 0 with empty or whitespace-only stdout, `status` emits nothing and exits 0 instead of failing closed with exit 2 as the plan requires for JSON parsing failure. Reproduced with `LOOM_ORCA_BIN=/usr/bin/true plugins/loom/bin/loom-host-orca status term_1`, which exits 0. Require an actual JSON value before accepting the response, and add an empty-response regression test.

## Prior Rounds Summary

Rounds 0 and 1 plan evaluations refined Orca CLI behavior, close/show exit validation, and fixture deep-equality. This is Round 1 of the artifact evaluation sequence (first code evaluation round).

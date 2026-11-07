# Code Evaluation: release-conformance-and-evidence-schema

Artifact: [release-conformance-and-evidence-schema](../slice-plans/archive/release-conformance-and-evidence-schema.md)
Commit: c55ac98
Round: 3
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [spec-10-07-release-evidence-amendment](../slice-plans/spec-10-07-release-evidence-amendment.md), [spec 10](../spec/10-packaging.md), [spec 07](../spec/07-command-surface.md), and [code-eval rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md).

## Summary

Round 2's size blocker remains unresolved. The CI files were restored, but the complete base-to-implementation diff is 933 additions and 52 deletions, net +881 lines; the implementation paths alone are net +739. The plan requires at most 300 net lines and permits only the CI sibling split. Repository `--all` passed before recording this evaluation, but rejects the requested Round 3 record under eval-sequence: it expects Round 2 after the plan evaluation. Both requested gate commands selected Bash 5.3.9 and completed 947 tests with failures; their concurrent execution collided in shared temporary worktree paths, and the evaluation was edited during the runs, so these results are not clean HEAD verification. An explicit `BASH_BIN=/bin/bash` floor run failed before Bats on Bash 3.2.57.

## Findings

- [BLOCKER] The Bash 3.2.57 platform gate fails before running Bats: `scripts/run-bats-under:123` expands an empty `bats_jobs_args` array under `set -u` when GNU parallel is unavailable. Make the launcher handle the empty argument list on Bash 3.2, then rerun the floor gate.
- [BLOCKER] The plan's <= 300 net LOC limit remains exceeded. The diff from d877660 to c55ac98 is net +881, and even limiting the count to README, schema, tests, fixture and validator gives +739. Restoring the CI files does not resolve this finding. Return to the planner for an approved scope/size resolution before landing.
- [MINOR] COR-1 confirmed: correction numbers are converted to Number before the purported leading-zero check, so `corr01` alone is accepted. The spec describes N as an integer and does not explicitly forbid that spelling; align the diagnostic or reject the spelling as a follow-up.
- [MINOR] TST-1 confirmed: broad schema-path assertions do not isolate the cardinality constraints. TST-4 confirmed: matrix drift tests exercise Claude only. TST-3 confirmed: original-with-supersedes and missing-original branches lack focused negative tests.
- TST-2 is rejected as a defect: schema validation already enforces the entry/client relationship before the semantic check; the redundant check is harmless.

## Prior Rounds Summary

Round 2 failed on correction records, the net LOC limit / CI split, fixture exit status, and the Bash 5 run record. The revision adds predecessor/hash/candidate and chain checks, restores the CI files, asserts valid-fixture success, records Bash 5.3.9, and adds matrix and correction-chain negative cases. The net LOC finding remains open as stated above.

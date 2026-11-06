# Plan Evaluation: launcher-matrix-and-rotation-fix

Artifact: [launcher-matrix-and-rotation-fix](../slice-plans/archive/launcher-matrix-and-rotation-fix.md)
Commit: 3315134
Round: 0
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [spec 10](../spec/10-packaging.md), and [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

The default matrix and two-client rotation address the identified gaps, but the proposed selector permits a v0.2.0 build to launch with another release's profile mapping. The plan also leaves a rotation invariant without a mechanical verification command.

## Findings

- [BLOCKER] D1, steps 2–4 and B2 deliberately allow `--release 0.3.0` in a v0.2.0 build, yielding the v0.3.0 Codex mapping. Spec 10's versioned compatibility section specifies the exact v0.2.0 effective map, and ADR 0032 §3 E1 requires the release's own matrix to carry the mappings used by launchers. A caller-selected future matrix defeats that release binding. Bind selection to the current product release; defer a different release's mapping to that release's reviewed change, and replace B2 with a rejection test for a mismatched release.
- [MAJOR] V3 asks the developer to inspect `_next_client_in_cycle` but gives no executable assertion. The rubric requires asserted invariants to be mechanically verified. Specify a command that fails if the function maps Codex to Antigravity, or make the behavioral tests exhaust both evaluator roles and all author clients and assert the resulting client for each.

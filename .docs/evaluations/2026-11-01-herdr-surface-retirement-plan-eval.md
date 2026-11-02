# Evaluation: herdr-surface-retirement

Verdict: FAIL
Round: 2
Commit: b52467b
Reviewed against: ADR 0031, specs 07/08/10, split plans, named research and playbook rubric.

## Summary

FAIL (round 2; BLOCKER: 2, MAJOR: 0, MINOR: 0). The no-matrix-key design conflicted with spec 10, and unsupported Codex roles were not stated. The remaining sections are the original record, unchanged.

## Required changes

1. Resolve the matrix registration contract against frozen spec 10 through the appropriate authority before implementing the no-matrix-key design.
2. Explicitly retain the unsupported Codex role status in final status instructions alongside the evaluator restriction.

## Findings

- [BLOCKER] The revision directs slice 2 to add no matrix key and removes the previous hc floor verification (.docs/slice-plans/herdr-surface-retirement.md:18-20, :51-53, :99). Frozen .docs/spec/10-packaging.md:145 requires the matrix to record hc as a host with floor 0.1.16. The dependent plan instead puts the floor only in a standalone binding (.docs/slice-plans/hc-host-adapter.md:50-54). This revision cannot satisfy that explicit invariant without an authority change or a conforming matrix design. Command: `rg -n 'matrix records|no matrix|matrix key|hostFloors|floor' .docs/spec/10-packaging.md .docs/slice-plans/{herdr-surface-retirement,hc-host-adapter}.md`.
- [BLOCKER] The second round 1 finding is only partly resolved: the revised final status instruction explicitly blocks evaluators but does not state Codex roles on hc remain unsupported (.docs/slice-plans/herdr-surface-retirement.md:83-87); ADR 0031:197-200 explicitly prohibits those roles pending their contract and Q2. Retain that explicit status as the prior verdict required. Command: `rg -n 'blind|evaluator|Codex|unsupported' .docs/slice-plans/herdr-surface-retirement.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md`.

## Mechanical checks

- `wc -l .docs/slice-plans/herdr-surface-retirement.md` reports 112 lines; line 6 sets <= 120 added LOC for Bats edits and re-pin. The exact full gate is `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
- `git diff 3e04b23 -- .docs/slice-plans/herdr-surface-retirement.md` shows the schema exclusion and blind-review additions. The schema search conflict is resolved; the retained host binding location and separate schema match the host plan. The other split plans retain the blind-review open item. The guard plan specifies wrapper tests, including shell wrappers, substitutions, timeout, xargs and paths. The v0.2.0 fixtures are retained; no Herdr UI is required.
- `jq '.rootBindings' plugins/loom/adapters/compatibility/v0.3.0.json` confirms the revised jq criterion operates on the current array shape. Acceptance criteria are mechanically testable; commands comparing to HEAD must be run against the pre-change baseline as intended. The plan's existing named paths and the host plan's explicitly new artifacts were checked against the tree and dependent plan. No hc, Orca or agy program was started.

## Prior Rounds Summary

Round 1 FAIL: the host schema search conflict was resolved by excluding the retained schema; the blind-review blocker was added, but explicit unsupported Codex status remains missing.

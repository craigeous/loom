# Evaluation: hc-live-probe

Verdict: FAIL
Round: 1
Commit: 3e04b23
Reviewed against: ADR 0031, specs 07, 08 and 10, the split slice plans, the named research notes, and the plan-evaluation rubric.

## Summary

FAIL (round 1; BLOCKER: 1, MAJOR: 1, MINOR: 0). The probe criterion used terminal state instead of status.state, and the unresolved blind-review constraint was missing. The remaining sections are the original record, unchanged.

## Required changes

1. Specify the actual `status.state` field for P4/P6 and test the real `hc get` JSON shape.
2. Explicitly retain the unresolved blind-review constraint and the prohibition on evaluator roles on hc pending the follow-up ADR.

## Findings

- [BLOCKER] `.docs/slice-plans/hc-live-probe.md:93` requires `state` to be `done` or `idle`, and line 97 repeats it. The named research distinguishes terminal `state` from `status.state`: an interactive terminal is live while `status.state` is `done`. Implementing the stated criterion against terminal state rejects a valid live probe. Command: `rg -n 'state|reported|status' .docs/slice-plans/hc-live-probe.md .docs/research/2026-11-01-hc-agent-runtime-reference.md`.
- [MAJOR] `.docs/slice-plans/hc-live-probe.md:25` lists open gates but omits the blind-review constraint and evaluator exclusion; line 35 only says hc does not enforce blind review. ADR 0031:179-185 and 245-248 leave the owner decision open and prohibit evaluator roles on hc pending a follow-up ADR. State this explicitly. Command: `rg -n -i 'blind|evaluator|open' .docs/slice-plans/hc-live-probe.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md .docs/spec/07-command-surface.md`.

## Mechanical checks and scope

`wc -l .docs/slice-plans/hc-live-probe.md` reports 123 lines; line 6 names a 260 LOC added budget for script and Bats. `git log -1 --format='%h %s' -- .docs/slice-plans/hc-live-probe.md` identifies 3e04b23. `test -e` confirms progress, index and CLAUDE.md exist; the script and Bats paths are explicitly marked new. `rg -n 'gate|scripts/check|probe|slice|GUI|role|model|reported|state' .docs/slice-plans/hc-live-probe.md .docs/slice-plans/hc-guard-deny-policy.md .docs/slice-plans/hc-host-adapter.md .docs/slice-plans/herdr-surface-retirement.md` checks the named gate, dependencies, no UI, and testable criteria; P4/P6 have the field defect above. `jq -e . plugins/loom/adapters/compatibility/v0.3.0.json` succeeds. The other plans place registration under v0.3.0, preserve v0.2.0 fixtures, and prescribe deny tests for wrappers; this generic probe adds no role support, UI, Orca, or Antigravity integration. No live commands or gate were run.

## Prior Rounds Summary

The predecessor plan evaluation `.docs/evaluations/herdr-hc-client-plan-eval.md` identified guard, premature role launch, retirement search, model and Q1 findings. `git show --stat --oneline 3e04b23 -- .docs/slice-plans/hc-live-probe.md` shows this split is a new artifact; its generic probe specifies the model and does not claim Q1. Guard and retirement belong to the separate plans and are outside this verdict.

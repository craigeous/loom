# Evaluation: herdr-surface-retirement

Verdict: FAIL
Round: 1
Reviewed against: ADR 0031, specs 07, 08 and 10, the split slice plans, the named research notes, and the plan-evaluation rubric.
Commit: 3e04b23

## Summary

FAIL (round 1; BLOCKER: 2, MAJOR: 0, MINOR: 0). The no-herdr schema search contradicted the retained host binding, and the final status instructions omitted the open blind-review blocker. The remaining sections are the original record, unchanged.

## Required changes

1. Scope acceptance search to exclude the retained host-binding schema and any required host validation content, while still detecting retired plugin surfaces.
2. Explicitly retain the unresolved blind-review requirement and unsupported evaluator and Codex roles in the final status instructions.

## Findings

- [BLOCKER] `.docs/slice-plans/herdr-surface-retirement.md:90` requires no `herdr` in all schemas, but the dependent host plan requires a new schema validating a binding whose `host` is `herdr` (`.docs/slice-plans/hc-host-adapter.md:73` and :79). Its strict const schema necessarily contains that value, making the acceptance criterion incompatible with the required retained host binding. Exact command: `rg -n 'herdr|schema|const' .docs/slice-plans/hc-host-adapter.md .docs/slice-plans/herdr-surface-retirement.md`.
- [BLOCKER] `.docs/slice-plans/herdr-surface-retirement.md:78` directs final status updates without retaining the explicit open blind-review blocker. ADR 0031:178-182 and :245-248 explicitly leave it unresolved pending a follow-up ADR; its generic “designed, unverified” instruction does not preserve that open item or explicitly state evaluator and Codex roles remain unsupported. Exact command: `rg -n 'blind|open|evaluator|Codex' .docs/slice-plans/herdr-surface-retirement.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md`.

## Mechanical checks

- `wc -l .docs/slice-plans/herdr-surface-retirement.md` reports 106 lines; line 6 states a 120 LOC added budget scoped to Bats edits and re-pin.
- `git log -1 --oneline` identifies 3e04b23; `git show --stat --oneline 3e04b23` confirms the split. The retirement plan lands last and preserves slice 2's v0.3.0 host artifacts; wrapper-specific tests are specified in slice 1. The v0.2.0 fixtures remain untouched; no Herdr UI is required. The full gate is `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
- Checked explicitly named existing paths with `test -e` and hook test paths with `rg --files plugins/loom/hooks scripts/tests | rg '(guard|backstop|loom-launch-role|loom-resolve-helper).*bats$'`; the host binding and fixture are new in slice 2. Acceptance criteria are mechanically testable, but criterion 1 contradicts the dependency as above. `jq -e '.hostFloors, .hostBindings' plugins/loom/adapters/compatibility/v0.3.0.json` currently reports null before slice 2, as expected.
- Read the named research and relevant frozen spec references. No live probe, program launch, gate, or repository modification was performed.

## Prior Rounds Summary

The predecessor plan evaluation `.docs/evaluations/herdr-hc-client-plan-eval.md` found a guard wrapper gap, premature role launches, a retained-link search conflict, and probe evidence gaps. The split plans specify raw-command wrapper coverage, prohibit host role launch, exclude the retained link, and assign the probe to slice 3. The current retirement search introduces the separate schema conflict above.

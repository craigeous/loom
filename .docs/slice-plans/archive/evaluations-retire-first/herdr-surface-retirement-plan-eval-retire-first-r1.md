# Evaluation: herdr-surface-retirement

Verdict: FAIL
Round: 1
Reviewed commit: 170cc95

## Required changes

1. Make finalize instructions reflect that slices 2 and 3 and their probe evidence remain future work when this slice lands first.
2. Extend the matrix jq criterion to check all three profile objects have no `herdr` key.

## Findings

- [BLOCKER] `.docs/slice-plans/herdr-surface-retirement.md:17` and `:84-87`: the revised order lands retirement before slice 2, yet finalization says ADR 0031 items landed and directs recording the probe result. Slice 2 is unimplemented and the probe is slice 3; this would record nonexistent completion/evidence. Change finalization to record actual retirement and outstanding work. Commands: `git show 170cc95 -- .docs/slice-plans/herdr-surface-retirement.md`; `rg -n 'lands first|items landed|probe result' .docs/slice-plans/herdr-surface-retirement.md`; `rg -n 'probe script is slice 3|No role launch' .docs/slice-plans/hc-host-adapter.md`.
- [MAJOR] `.docs/slice-plans/herdr-surface-retirement.md:20-21,52-54,100`: the revised jq check does not test the three per-profile Herdr keys, despite the stated no-Herdr-keys post-state. Include `(.profiles | all(has("herdr") | not))` in the criterion. Command: `jq -e '(.clientFloors | has("herdr") | not) and (has("hostFloors") | not) and (.rootBindings | map(.id) | index("herdr-plugin-root/v1") | not)' plugins/loom/adapters/compatibility/v0.3.0.json`; inspection of `jq '.profiles' plugins/loom/adapters/compatibility/v0.3.0.json` establishes those are independent keys.

## Mechanical checks

- `git show 170cc95 -- .docs/slice-plans/herdr-surface-retirement.md` verifies the specified revision. `git show 170cc95:.docs/slice-plans/herdr-surface-retirement.md | rg -n 'validateHostBinding|hostFloors\.hc|slice 2 owns'` finds line 35's ownership statement and line 113's historical revision entry, not operative dependencies. The literal requested absence is therefore not satisfied; the operative plan requires no slice 2 code.
- Matrix compatibility check: `jq '{clientFloors,rootBindings,profiles,hostFloors}' plugins/loom/adapters/compatibility/v0.3.0.json` shows existing Herdr fields and no hostFloors; retirement removes the former and slice 2 adds the optional `hostFloors.hc` object specified by `rg -n 'hostFloors|Matrix registration' .docs/slice-plans/hc-host-adapter.md`. These are distinct keys, so the intended data changes compose after rebase; the older slice 2 prose still assumes the opposite order and must be rebased accordingly.
- `rg -n 'Codex|evaluator|blind|12 cases|48 files|scripts/check|Target size|Status:' .docs/slice-plans/herdr-surface-retirement.md` confirms the listed role restrictions, blind-review item, counts, gate and Plan Review status. `wc -l .docs/slice-plans/{herdr-surface-retirement,hc-host-adapter,hc-live-probe}.md` yields 115, 155, 130; archived guard plan is at `.docs/slice-plans/archive/hc-guard-deny-policy.md`. Per-slice LOC budgets are 120, 380, 260 and 140 respectively; 250 is the plan-document line target, not a universal LOC cap.
- Explicit repository paths in the plan refer to existing files or directories; abbreviated hook and Bats names resolve under their stated directories. No new paths are required. The requested active path `.docs/slice-plans/hc-guard-deny-policy.md` is absent; its landed plan is archived.
- The jq command on the current pre-retirement matrix returns false as expected; it has not been run on a hypothetical edited file. Full gate was not run in this read-only plan review.

## Prior Rounds Summary

Prior round 1 blockers concerned searching a retained host schema and preserving the blind-review blocker. The first is resolved for the newly selected order because the host schema does not yet exist; the second is retained explicitly at lines 36-37 and 85-88. Revision diff checked with `git show 170cc95 -- .docs/slice-plans/herdr-surface-retirement.md`.

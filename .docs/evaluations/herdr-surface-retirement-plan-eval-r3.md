# Evaluation: herdr-surface-retirement

Verdict: PASS
Round: 3

## Required changes

None.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

## Mechanical checks

- Round 2 findings are resolved: slice 2 owns the optional v0.3.0 `hostFloors.hc` registration with floor `0.1.16`, retained and checked by retirement; final status explicitly preserves unsupported Codex and evaluator roles. Round 1's schema exclusion and blind-review open item remain in place. Command: `git diff 3e04b23 -- .docs/slice-plans/herdr-surface-retirement.md`.
- Cross-plan registration, host binding, floor, unsupported roles, and unresolved blind review are consistent; the host plan specifies the optional matrix schema change. Guard wrapper tests are specified. Command: `rg -n 'hostFloors|0.1.16|unsupported|blind|wrapper|sh -c|bash -c|timeout|xargs' .docs/slice-plans/{herdr-surface-retirement,hc-guard-deny-policy,hc-host-adapter,hc-live-probe}.md`.
- `wc -l .docs/slice-plans/herdr-surface-retirement.md` yields 113; line 6 states <= 120 added LOC for Bats edits and re-pin, excluding deletions. The named full gate is `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`. Acceptance criteria are testable against repository contents and candidate baseline. `jq -e '.rootBindings | type == "array"' plugins/loom/adapters/compatibility/v0.3.0.json` succeeds.
- Named existing paths were checked with `test -e` and `rg --files plugins/loom/hooks scripts/tests | rg '(guard|backstop|loom-launch-role|loom-resolve-helper).*bats$'`; host artifacts are explicitly new in slice 2. The v0.2.0 fixtures remain untouched; no Herdr UI is required. No live programs or gate were run.

## Prior Rounds Summary

Round 1 FAIL: retained host schema conflicted with the search and final status omitted the blind-review restriction. Round 2 FAIL: matrix floor registration conflicted with spec 10 and final status omitted unsupported Codex roles. Both rounds' findings are resolved.

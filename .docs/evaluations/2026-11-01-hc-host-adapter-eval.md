# Evaluation: hc-host-adapter

Verdict: PASS
Round: 3
Commit: 1c7b0ef
Reviewed against: ADR 0031, specs 07, 08 and 10, the split slice plans, the named research notes, and the plan-evaluation rubric.

## Summary

PASS (round 3; BLOCKER: 0, MAJOR: 0, MINOR: 0). Registration through an optional hostFloors property is specified and the v0.2.0 fixtures stay protected. The remaining sections are the original record, unchanged.

## Required changes

None.

## Findings

None.

## Prior Rounds Summary

Round 1: the closed matrix schema conflict is addressed by an optional `hostFloors` property and schema digest re-pin; blind review remains explicitly unresolved. Round 2: the host adapter again owns registration in the v0.3.0 matrix, and retirement retains it. The v0.2.0 fixtures remain protected.

## Mechanical review notes

- `git diff b52467b HEAD -- .docs/slice-plans/hc-host-adapter.md` identifies the round 2 revision; `jq -e '.additionalProperties == false and (.properties|has("hostFloors")|not)' plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json` confirms the existing schema needs the planned amendment.
- `wc -l .docs/slice-plans/hc-host-adapter.md` reports 155 lines. Line 6 scopes the 380 added LOC target to helper, Bats and registration; line 145 names `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` as the gate.
- `for p in plugins/loom/adapters/compatibility/v0.3.0.json plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json scripts/check-toolchain.json scripts/validate-repository.mjs scripts/tests/repository-validation.bats CLAUDE.md .docs/slice-plans/README.md; do test -e "$p" || printf 'missing: %s\n' "$p"; done` reports no missing existing touched paths; new helper, binding, schema, fixture and Bats paths are marked new. Acceptance criteria specify stub output, validator results and repository comparisons.
- `rg -n 'hostFloors|0.1.16|Codex|evaluator|blind|wrapper|timeout|xargs|backtick|absolute' .docs/slice-plans/{hc-host-adapter,hc-guard-deny-policy,hc-live-probe,herdr-surface-retirement}.md` confirms registration ownership, floor, retirement preservation, unsupported roles and blind-review open item. The guard specifies wrapper cases and tests; no Herdr UI is required. The slices are consistent on binding location and order, with guard and adapter independent and retirement last. Orca and Antigravity are outside scope.

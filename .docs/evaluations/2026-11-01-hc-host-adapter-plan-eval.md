# Evaluation: hc-host-adapter

Verdict: FAIL
Round: 2
Commit: b52467b
Reviewed against: ADR 0031, specs 07, 08 and 10, the split slice plans, the named research notes, and the plan-evaluation rubric.

## Summary

FAIL (round 2; BLOCKER: 1, MAJOR: 0, MINOR: 0). The revision removed all v0.3.0 matrix registration, against the owner decision and spec 10. The remaining sections are the original record, unchanged.

## Required changes

Register the helper and hc host floor in the v0.3.0 matrix through a compatible schema change, preserving the frozen v0.2.0 fixtures. Align the retirement plan with the chosen matrix and schema design.

## Findings

- [BLOCKER] The revision removes all matrix registration: the plan explicitly forbids editing v0.3.0.json and substitutes a standalone binding (.docs/slice-plans/hc-host-adapter.md:50, :90). This violates the binding owner decision to register under the v0.3.0 matrix and the explicit frozen spec requirement that the matrix record hc as a host with floor 0.1.16 (.docs/spec/10-packaging.md:145). It also leaves the retirement plan without the required matrix host entry. The prior schema incompatibility is avoided, but the required behavior is now missing. Exact commands: `rg -n -i 'matrix|host binding|floor' .docs/slice-plans/hc-host-adapter.md .docs/spec/10-packaging.md .docs/slice-plans/herdr-surface-retirement.md` and `jq -e '.additionalProperties == false and (.properties|has("hostBindings")|not)' plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json`.

## Prior Rounds Summary

Round 1 FAIL: the proposed matrix keys violated the closed schema; the revision removes those keys and the matrix edit, creating the blocker above. The prior minor finding is resolved: blind review remains an explicit open blocker at plan line 49.

## Mechanical review notes

- `wc -l .docs/slice-plans/hc-host-adapter.md` reports 145 lines; line 6 scopes the 380 added LOC target to helper, Bats and registration. Line 136 names `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` as the full gate.
- `for p in scripts/validate-repository.mjs scripts/tests/repository-validation.bats CLAUDE.md .docs/slice-plans/README.md scripts/check-toolchain.json; do test -e "$p" || printf 'missing %s\n' "$p"; done` reports no missing existing touched paths; the helper, host binding, schema, fixture and Bats file are marked new. Acceptance checks use stub output, validator results and git comparisons.
- `rg -n -i 'schema|binding|blind|host.adapter|depend|wrapper|timeout|xargs|backtick|absolute' .docs/slice-plans/{hc-host-adapter,hc-guard-deny-policy,hc-live-probe,herdr-surface-retirement}.md` confirms the common standalone host binding and open blind-review item, guard wrapper tests and the split ordering; the matrix omission above is inconsistent with authority. No Herdr UI is required; Codex and evaluator roles remain unsupported; Orca and Antigravity are not included. v0.2.0 fixtures are protected.
- `git diff 3e04b23 HEAD -- .docs/slice-plans/hc-host-adapter.md` identifies the revision; no other new blocker or major was found under the round 2 rule.

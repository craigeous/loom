# Evaluation: hc-host-adapter

Verdict: FAIL
Round: 1
Reviewed against: ADR 0031, specs 07, 08, 10, the three split plans, both named research notes, and the playbook rubric and template.

## Findings

- [BLOCKER] The matrix additions cannot pass the existing schema: the plan adds `hostFloors` and `hostBindings` while explicitly forbidding modification of the matrix schema (.docs/slice-plans/hc-host-adapter.md:82, :84). That schema rejects additional properties and defines neither key. The full gate validates the matrix, so this implementation fails its gate. Exact command: `jq -e '(.additionalProperties == false) and (.properties | has("hostFloors") | not) and (.properties | has("hostBindings") | not)' plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json` (true). Specify a compatible schema/versioning change and its fixture consequences while preserving the owner's frozen v0.2.0 decision.
- [MINOR] The plan says evaluator roles are unsupported (.docs/slice-plans/hc-host-adapter.md:42) but does not explicitly retain the unresolved blind-review requirement as an open item, as ADR 0031 requires. Exact command: `rg -n -i 'blind|evaluator' .docs/slice-plans/hc-host-adapter.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md`.

## Required changes

1. Resolve the closed matrix schema conflict with a concrete, compatible registration and verification approach that preserves frozen v0.2.0 evidence.
2. Explicitly record the unresolved blind-review requirement and its follow-up decision.

## Mechanical review notes

- `wc -l .docs/slice-plans/hc-host-adapter.md` reports 140 lines; line 6 states a 380 LOC added budget scoped to helper, tests, and registration. The gate is named at line 132. Acceptance checks are testable through the named stub, validator, and git comparisons.
- Existing touched paths were checked with `for p in plugins/loom/adapters/compatibility/v0.3.0.json scripts/validate-repository.mjs scripts/tests/repository-validation.bats CLAUDE.md .docs/slice-plans/README.md scripts/check-toolchain.json; do test -e "$p" || printf 'missing: %s\n' "$p"; done`; new files are labeled new at lines 54, 73, 79, 88 and 99.
- `rg -n 'host-adapter|guard|blind|hc-host|depends|Depends' .docs/slice-plans/{hc-live-probe,herdr-surface-retirement,hc-guard-deny-policy}.md` and review of the plan establish the guard first, probe third and retirement last; no Herdr UI is required. The guard plan lists the requested wrappers and tests per form. Codex and evaluator launch remain unsupported; Orca and Antigravity are outside this slice. v0.3.0 registration is specified and v0.2.0 fixtures are protected.
- `git log -1 --oneline -- .docs/slice-plans/hc-host-adapter.md` identifies 3e04b23; no prior evaluation file exists for this split artifact. `git diff 3e04b23 HEAD -- .docs/slice-plans/hc-host-adapter.md` is empty. Round 1 records this first FAIL.

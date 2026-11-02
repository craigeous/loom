# Herdr `hc` Client: Superseded by Four Slice Plans

Status: Abandoned
Target specs: 07-command-surface.md, 08-playbook.md, 10-packaging.md
Authority: ADR 0031 (Accepted)
Target size: n/a (superseded; the budgets live in the four plans below)

## Context

This single plan (plan-eval PASS at commit `8c4299d`, then a developer pass that stopped
at Needs Clarification on branch `herdr-hc-client`, commit `556cd52`) is replaced by four
separately evaluated slice plans, per the owner decisions of 2026-11-01. Its full text is
kept in git history (`git show 8c4299d:.docs/slice-plans/herdr-hc-client.md`); the
evaluation records `herdr-hc-client-plan-eval.md` and
`2026-11-01-herdr-hc-client-plan-eval.md` are unchanged history, and no approval carries
over to the new plans.

| # | Plan | Target size | Depends on |
|---|---|---|---|
| 1 | [hc-guard-deny-policy.md](hc-guard-deny-policy.md) | <= 140 LOC | none |
| 2 | [hc-host-adapter.md](hc-host-adapter.md) | <= 380 LOC | none |
| 3 | [hc-live-probe.md](hc-live-probe.md) | <= 260 LOC | none |
| 4 | [herdr-surface-retirement.md](herdr-surface-retirement.md) | <= 120 LOC | lands after 1 and 2 |

Program ceiling: 900 LOC added across the four (the earlier single-plan target of 450 was
measured infeasible by the developer pass at about 860 added lines including tests).

## Out of Scope & Threat-Model Boundary

Nothing is implemented from this file. Scope and boundaries are in the four plans.

## Steps

None. The developer pass on branch `herdr-hc-client` (commit `556cd52`) is not carried
forward as an approved implementation; its Notes are resolved as: Step 3 conflict, v0.3.0
registration only (plan 2); all wrapper forms denied (plan 1); per-slice size (above);
name grammar, `exit_code`, and not_found cleanup (plan 2); probe evidence path (plan 3).

## Verification

None. See each plan's own gate.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Plan-eval R0: `hc` guard regex covers assignments/options after `env` (+tests); no role launch in scope (`launch` refuses, probes generic and first); AC4 excludes `*.bats` and the retained allowlist link; probe model `claude-haiku-5-5`; Q1 claim removed |
| 2 | Owner decisions: v0.3.0-only registration, deny-by-default for all `hc` wrapper forms, per-slice size; split into four plans and set `Abandoned` |

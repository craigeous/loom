# loom

**loom** weaves a development loop out of five specialist roles —
*researcher, planner, plan evaluator, developer, code evaluator* — and drives
them through a file-based, spec-driven process so that work survives context
resets and is reviewed with blind, impartial rigor.

loom is a Claude Code **skill**. You invoke it inside any repository; it detects
how aligned that repo is with loom's conventions and either bootstraps,
migrates, or resumes work. A thin orchestrator spawns each role as a **cold
agent** on the model best suited to its job, hands off work through files in
`.docs/`, and stops at the scope boundary or human checkpoint you declared.

## Why

- **Context drift** — long sessions lose the thread. loom keeps durable memory in
  `.docs/` so any cold agent can resume from files alone.
- **Blind rigor** — evaluators judge work without knowing who produced it, so
  review stays critical and free of self-approval.
- **Token-smart automation** — each role runs on the cheapest model that can do
  its job well; only judgment-heavy roles use the strongest model.

## Status

Design phase. The authoritative design lives in [`.docs/spec/`](.docs/spec/README.md).
Start with [`00-overview.md`](.docs/spec/00-overview.md).

loom **dogfoods its own structure**: this repository is managed by the very
process loom implements. Its specs, ADRs, slice-plans, and evaluations live in
`.docs/`.

# 0007 — Namespaced Command Surface

Status: Accepted
Date: 2026-06-08

## Context

ADR 0001 established loom as a Claude Code plugin with an orchestrator command and
per-role one-off commands, but it referred to the orchestrator as the bare `/loom`
command. Claude Code plugins **namespace their components by plugin name**: a
command file surfaces as `/<plugin>:<filename>` and an agent as `<plugin>:<name>`.
There is no bare `/<plugin>` entry point. This was confirmed empirically at M1
install when resolving OQ-D (see
[09 — Open Questions](../spec/09-open-questions.md), OQ-D resolved). The shipped
plugin under `plugins/loom/` reflects this: `commands/` and `agents/` produce only
namespaced surfaces.

The resolved surface is already authoritative in the Approved specs
[07 — Command Surface](../spec/07-command-surface.md) and
[10 — Packaging](../spec/10-packaging.md). ADR 0001 is Accepted and immutable, so
its stale bare-`/loom` references cannot be rewritten; this ADR records the
decision of record.

In scope: the naming/namespacing of loom's command and agent surface. Out of
scope: the plugin/orchestrator architecture itself (ADR 0001 stands), model tiers
(ADR 0002), and packaging layout details (spec 10).

## Decision

- loom's command surface is **namespaced** as `/loom:<name>`. **There is no bare
  `/loom` command.** The orchestrator is invoked as **`/loom:run`**, not `/loom`.
- The full command surface is one file per command under
  `plugins/loom/commands/` (each surfaces as `/loom:<filename>`):
  `/loom:run` (the orchestrator) plus the one-off commands `/loom:research`,
  `/loom:plan`, `/loom:eval-plan`, `/loom:develop`, `/loom:eval-code`,
  `/loom:status`, and `/loom:init`.
- The five role agents under `plugins/loom/agents/` are namespaced `loom:<role>`:
  `loom:researcher`, `loom:planner`, `loom:plan-evaluator`, `loom:developer`,
  `loom:code-evaluator`.
- The authoritative description of this surface lives in the Approved specs
  [07 — Command Surface](../spec/07-command-surface.md) and
  [10 — Packaging](../spec/10-packaging.md); this ADR is the decision of record
  behind them.

## Consequences

- **Supersedes (in part) ADR 0001.** This ADR supersedes only the bare-`/loom`
  command-naming in ADR 0001 (e.g. "the `/loom` orchestrator", "runs the `/loom`
  command"). Read those references as `/loom:run`. ADR 0001's plugin architecture
  and orchestrator-spawns-roles decision otherwise stands unchanged.
- All loom documentation, commands, agents, and onboarding text must use the
  namespaced form (`/loom:<name>`, `loom:<role>`) and must not introduce a bare
  `/loom`.
- The namespace prefix is derived from the plugin `name` in
  `plugins/loom/.claude-plugin/plugin.json` (spec 10). Renaming the plugin would
  change every command and agent surface — a breaking change to be handled by a
  new planning cycle, not silently.
- No new behavior is introduced; this ADR aligns the immutable ADR record with the
  empirically resolved, already-Approved spec surface.

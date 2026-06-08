# 07 — Command Surface

Status: Draft

loom is a Claude Code **plugin**. Plugin components are **namespaced by plugin
name** — there is no bare `/loom`; commands are `/loom:<name>` and agents are
`loom:<role>` (confirmed empirically at M1 install). See
[10 — Packaging](10-packaging.md).

## Commands (`plugins/loom/commands/`)

One file per command (each surfaces as `/loom:<filename>`):

| Command | File | What it does |
|---|---|---|
| `/loom:run [scope]` | `run.md` | The **orchestrator** — detect init mode, take scope + claimed gates, drive the driver loop. |
| `/loom:research <topic>` | `research.md` | One-off researcher pass → cited `.docs/research/` note. |
| `/loom:plan` | `plan.md` | One-off planner pass → ADR / spec / slice-plan. |
| `/loom:eval-plan [artifact]` | `eval-plan.md` | One-off **blind** plan/research review → verdict. |
| `/loom:develop [slice]` | `develop.md` | One-off developer pass → implement + gate. |
| `/loom:eval-code [slice]` | `eval-code.md` | One-off **blind** code review → verdict. |
| `/loom:status` | `status.md` | Print `.docs/` state; no agents, no writes. |
| `/loom:init` | `init.md` | Initialize / align this repo to loom. |

## Agents (`plugins/loom/agents/`)

The five roles the commands spawn via the Task tool, namespaced `loom:<role>`:
`loom:researcher` (haiku), `loom:planner` (opus), `loom:plan-evaluator` (opus),
`loom:developer` (sonnet), `loom:code-evaluator` (opus).

## Orchestrated vs one-off

`/loom:run` chains roles automatically within the declared scope, pausing at
claimed gates and stopping at the scope boundary. The one-off commands each run a
single cold-agent pass and stop — for targeted manual work ("just re-evaluate this
plan"). Both spawn the same agents against the same files; only the chaining
differs.

## Shared logic

The orchestrator rules common to all commands live in the playbook at
`skills/loom-playbook/references/orchestration.md` (+ `status-machine.md`); each
command file is thin and references them, so behavior stays consistent.

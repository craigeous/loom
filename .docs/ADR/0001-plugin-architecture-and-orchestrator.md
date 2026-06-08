# 0001 — Plugin Architecture & Orchestrator Model

Status: Accepted
Date: 2026-06-08

> Note: the bare `/loom` command references below are superseded by ADR 0007
> (namespaced command surface — the orchestrator is `/loom:run`); 0001's
> plugin/orchestrator architecture decision otherwise stands.

## Context

loom needs to run five role agents on different models and coordinate handoffs.
Claude Code sub-agents **cannot spawn other sub-agents**, so peer-to-peer role
calls are impossible. We needed a packaging primitive and a coordination model.
Anthropic's own `feature-dev` plugin demonstrates the pattern: an orchestrating
command launches specialized agents.

## Decision

- loom is a **Claude Code plugin** comprising `commands/` (the `/loom`
  orchestrator + per-role one-off commands), `agents/` (the five role agents), and
  `skills/loom-playbook/` (the bundled playbook).
- The **orchestrator is the main interactive session** that runs the `/loom`
  command. It is the only actor that spawns role sub-agents (via the Task tool).
  It is not a sixth role.
- Every handoff is mediated: "role A calls role B" means "role A finishes and
  commits; the orchestrator observes the status and spawns role B."

## Consequences

- The "agents can't call agents" constraint is irrelevant to the design — only the
  orchestrator spawns, which is exactly what we want for coherent routing and
  blind evaluation.
- Parallelism is achieved by the orchestrator launching multiple background
  sub-agents in separate worktrees, not by nested spawning (see ADR 0003 and spec
  04). `claude -p` via `Bash(claude:*)` remains a reserve mechanism for deep
  nesting.
- loom is distributable through the plugin/marketplace system (ADR 0006).

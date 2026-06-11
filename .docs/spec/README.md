# loom Specs

Status: Living

These docs are loom's durable design memory. Read this file first, then the spec
for the area you are working on.

## Reading Order

1. [Overview & Goals](00-overview.md)
2. [Concepts & `.docs/` Layout](01-concepts.md)
3. [Roles](02-roles.md)
4. [Artifact Lifecycle & Status State Machine](03-artifact-lifecycle.md)
5. [Orchestrator](04-orchestrator.md)
6. [Blind Evaluation](05-blind-evaluation.md)
7. [Init Modes](06-init-modes.md)
8. [Command Surface](07-command-surface.md)
9. [Playbook](08-playbook.md)
10. [Packaging & Distribution](10-packaging.md)
11. [Open Questions](09-open-questions.md)

## Durable vs Transient Memory

- **`.docs/spec/`** — authoritative "what loom is." A spec is **frozen once
  approved**; it changes only through a new planning cycle (planner → plan
  evaluator → approved), never by a developer. On conflict, the spec wins.
- **`.docs/ADR/`** — numbered architecture decision records, immutable after
  acceptance. If a decision becomes wrong, mark it superseded and add a new
  record; never rewrite history.
- **`.docs/slice-plans/`** — transient "how we intend to build the next thing."
  Proposals under discussion, not authority. When a slice lands, the plan is
  archived and the living docs are updated — **the spec is not edited** (see ADR
  0005).

## Non-Negotiable Decisions

- The product/skill name is **loom**.
- loom is a **Claude Code plugin** (commands + agents + a bundled playbook skill),
  distributed as its own single-plugin **marketplace** (ADR 0001, 0006).
- The **orchestrator is the main interactive session** running the `/loom`
  command — not a sixth role. It is the only actor that spawns role sub-agents
  (sub-agents cannot spawn sub-agents). "Role A calls role B" = "role A finishes
  and commits; the orchestrator spawns role B" (ADR 0001).
- Five roles: researcher, planner, plan evaluator, developer, code evaluator.
- Roles are **cold agents** that hand off through files in `.docs/`; they never
  share live context. **Every handoff ends in a commit**, so evaluators always
  have a clean diff and any interrupted loop resumes from git + files (ADR 0003).
- Evaluation is **blind**: an evaluator is never told who authored what it
  reviews and never sees the author's reasoning. Role separation means no role
  approves its own work (ADR 0004).
- The human starts each loop and declares its **scope** and which **approval
  gates** they claim (all, or a named list). If a gate is not claimed, evaluator
  approval is sufficient to advance.
- Models are pinned **by tier** — `haiku` (researcher), `sonnet` (developer),
  `opus` (planner + both evaluators), and the **orchestrator** `sonnet` (ADR 0012).
  Exact versions are **not** pinnable and track the user's environment (ADR 0002).
- loom is **opinionated and general-purpose**: it carries a **playbook** and
  imposes it on managed projects, detecting the toolchain to fill in concrete
  gate commands. **Rust is the only verified gate**; for other stacks, init
  *identifies and creates* the gate, then records it for reuse.
- loom **dogfoods** its own structure: this repo is managed by loom's process.
- Living docs (roadmap, progress, handoff) are kept **separate**.
- **Parallelism** (multiple slices in flight at once, via worktree-per-slice) is
  designed-for from day one but built **after** the sequential single-slice loop.

## Decision Records

Accepted ADRs live in [`../ADR/`](../ADR/):

- 0001 — Plugin architecture & orchestrator model
- 0002 — Model selection by tier
- 0003 — File-based cold handoffs with a commit per handoff
- 0004 — Blind evaluation by controlled inputs + role separation
- 0005 — Specs frozen after approval; change only via planning
- 0006 — Distribution as a single-plugin self-marketplace

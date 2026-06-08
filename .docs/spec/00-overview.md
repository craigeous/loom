# 00 — Overview & Goals

Status: Draft

## What loom is

loom is a Claude Code skill that runs a **spec-driven development loop** staffed
by five specialist roles and driven by a thin orchestrator. The roles hand off
work through files in a project's `.docs/` directory, so any role can be spawned
as a fresh "cold" agent and pick up exactly where the last one left off — the
files are the memory.

The loop:

```
                ┌─────────────┐
   owner ──────▶│ researcher  │──▶ research notes
                └─────────────┘
                       │
                       ▼
   owner ◀────▶┌─────────────┐──▶ ADRs ─▶ specs ─▶ slice-plans (draft)
               │   planner   │
               └─────────────┘
                       │ (status: ready for review)
                       ▼
                ┌──────────────┐   reject (notes) ─┐
                │plan evaluator│◀──────────────────┘
                └──────────────┘
                       │ approve
                       ▼
                ┌─────────────┐   reject (notes) ─┐
                │  developer  │◀──────────────────┘
                └─────────────┘
                       │ (status: implemented)
                       ▼
                ┌──────────────┐
                │code evaluator│── approve ─▶ land + archive
                └──────────────┘── reject ──▶ back to developer
```

## The three problems loom solves

1. **Context drift.** Long agent sessions lose the thread, re-derive decisions,
   and contradict earlier work. loom keeps durable, authoritative memory in
   `.docs/spec/` and `.docs/ADR/`, and transient working memory in
   `.docs/slice-plans/`. A cold agent reconstructs full context from files.

2. **Lack of impartial review.** A single agent that writes and then "reviews"
   its own work rubber-stamps it. loom separates authoring from evaluating into
   distinct roles, and gives evaluators **blind** inputs — no author identity, no
   author reasoning — so review stays critical.

3. **Token cost.** Running everything on the strongest model is wasteful. loom
   assigns each role the cheapest model that does its job well, reserving the
   strongest model for judgment-heavy roles (planning and both evaluators).

## Goals (v1)

- A working `/loom` orchestrated loop plus per-role one-off commands.
- The full `.docs/` artifact structure with a status-driven state machine.
- Blind evaluation enforced by construction (controlled prompt inputs).
- Three init modes: greenfield, unaligned-project alignment, resume.
- A playbook of conventions that loom imposes on managed projects.
- loom managing its own development (dogfooding).

## Non-goals (v1)

- Parallel slices in flight at once. The architecture is *designed for* it
  (worktree-per-slice, orchestrator-as-hub), but it is built **after** the
  sequential single-slice loop works (see roadmap).
- True peer-to-peer agent calls. Not needed: the orchestrator (main session)
  spawns every role. `claude -p` is a reserve mechanism if deep nesting is ever
  required.
- Replacing human judgment on product direction — the owner still drives intent
  and claims approval gates.

## Glossary

- **Owner** — the human running loop. Starts each loop and sets its scope.
- **Role** — one of the five specialist cold agents.
- **Orchestrator** — the main interactive session running the `/loom` command; it
  spawns every role agent and routes work. Not a sixth role.
- **Artifact** — a file the loop produces: research note, ADR, spec, slice-plan,
  or evaluation.
- **Cold agent** — a freshly spawned agent with no prior context; it reads only
  the files (and prompt) handed to it.
- **Playbook** — loom's bundled, evolving set of conventions/templates it imposes
  on managed projects.
- **Gate** — the format → lint → test sequence a slice must pass before review.

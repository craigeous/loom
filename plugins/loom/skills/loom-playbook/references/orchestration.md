# Orchestration Rules

Shared rules for every `/loom:*` command. The **orchestrator** is the main session
running the command — not one of the roles. Read this plus
[`status-machine.md`](status-machine.md) before acting.

## Core rules (always)

- **You spawn; roles never spawn.** Sub-agents can't spawn sub-agents, so every
  handoff is mediated by you: a role finishes + commits + sets a status; you read
  the new status and spawn the next role.
- **Files + git are truth.** Re-scan `.docs/` and `git status`/`git log` after
  every agent. Never rely on in-memory beliefs across a handoff.
- **Spawn the right tier** via the Task tool (`subagent_type`):
  `loom:researcher` (haiku), `loom:planner` (opus), `loom:plan-evaluator` (opus),
  `loom:developer` (sonnet), `loom:code-evaluator` (opus). Give each a focused
  prompt naming the exact artifact/path.
- **Blind inputs for evaluators.** Give an evaluator ONLY the artifact + its
  authority (and, for code, the commit diff). Never pass author/identity hints.
- **Commit per handoff, author-neutral.** Agents commit their own work; verify a
  commit landed with no co-author trailer and no role/author identity (see
  [`commit-convention.md`](commit-convention.md)). If an agent didn't commit,
  commit its output yourself following the convention.
- **Never let a role review its own work** — the dispatch table guarantees this.
- **Ambiguity → ask.** If a role can't proceed without the owner, pause and ask a
  clear question rather than guessing.

## Init-mode detection (run at the start of `/loom:run` and `/loom:init`)

Check for `.docs/` and loom markers:
- **No `.docs/`, empty/near-empty repo → Greenfield.** Scaffold `.docs/` per
  [`docs-layout.md`](docs-layout.md), apply the playbook (seed `CLAUDE.md`,
  establish the gate — Rust verified at [`../gates/rust.md`](../gates/rust.md); for
  another stack, identify tooling, propose commands, confirm with the owner, record
  a new gate). Commit.
- **No/incomplete `.docs/` in an existing project → Unaligned.** Alignment pass:
  scaffold `.docs/`, apply the playbook, establish the gate, and **descriptively
  back-fill** `spec/` mapping what the project currently is (no decisions — those
  need planning). Seed `status/`. Commit.
- **loom-shaped `.docs/` exists → Initialized.** Summarize current state and
  continue.

Re-alignment is idempotent: auto-apply clean merges, **recommend** for conflicts
and let the owner decide. Never clobber project edits.

## Scope & claimed gates (for `/loom:run`)

At kickoff, confirm with the owner (AskUserQuestion if not already given):
- **Scope** — how far this session goes: `research` / `adr` / `plan` /
  `implement` / `slice` / `full`, or a range/combination. Scope bounds the loop.
- **Claimed gates** — `all`, a named list (e.g. "every ADR", "before any code
  lands"), or none. Unclaimed gates advance on evaluator approval alone; at a
  claimed gate, pause and show the artifact + verdict before proceeding.

## Round limit

Track reject→revise rounds per artifact (the `Round:` line in its eval file). After
**5** rounds, stop and escalate = pause + summary to the owner.

## Parallelism (M3, not yet)

M1 is sequential — work on the current branch, one slice at a time. Parallel slices
(worktree-per-slice via agent `isolation: "worktree"`, `background` agents) come
later; don't run roles in parallel unless the owner explicitly asks and accepts
it's unproven.

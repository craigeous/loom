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
- **Never edit code yourself; route every code change through a role.** You plan,
  dispatch, verify, and manage `.docs/`/status/branches — you do **not** write or
  fix source. A bug fix, revert, or repair — even a one-liner, even cleaning up an
  out-of-scope change an evaluator flagged — is a **developer** slice, re-verified by
  the **evaluator**. Committing an agent's *already-produced* output (above) is fine;
  authoring or modifying code is not.
- **One slice in flight by default; parallel independent/disjoint slices are
  allowed** per [`parallelism.md`](parallelism.md) (each on its own branch +
  worktree, owner opts in). Don't stack unrelated in-flight slices on **one
  branch** — a re-review's diff-against-prior-commit will conflate them and flag
  the wrong thing. Parallel slices on separate branches are fine when they are
  independent (disjoint file sets — see `parallelism.md`).
- **Ambiguity → ask.** If a role can't proceed without the owner, pause and ask a
  clear question rather than guessing.

## Init-mode detection (run at the start of `/loom:run` and `/loom:init`)

Run the classifier in [`init-detection.md`](init-detection.md) first; it returns
Greenfield / Unaligned / Initialized. Then act per that mode:

- **Greenfield** → [`greenfield.md`](greenfield.md) — scaffold `.docs/`, apply
  playbook, establish gate, hand back.
- **Unaligned** → [`unaligned.md`](unaligned.md) — alignment pass: study the
  repo, scaffold + gate (per `greenfield.md`), descriptive `spec/` back-fill,
  resume as Initialized.
- **Initialized** → [`initialized.md`](initialized.md) — resume: derive the
  menu from `.docs/` + git state (mapped to the dispatch table), then declare
  scope + gates and run the driver loop; re-apply the current playbook
  idempotently.

Re-running init re-applies the current playbook idempotently — see
[`initialized.md`](initialized.md) for the merge strategy (auto-apply clean,
recommend for conflicts, never clobber).

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

## Parallelism

Worktree-per-slice parallelism is **active** — orchestrator-spawned background
agents, each in its own worktree on its own branch, governed by
[ADR 0008](../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md).
The owner opts in. See [`parallelism.md`](parallelism.md) for the complete
operational body: create→work→land→cleanup workflow, the `.docs/` coordination
model (living docs + slice-plans index orchestrator-owned/main-only/serialized;
slice branches carry only disjoint uniquely-named plan/eval/code), concurrency
safety (`index.lock` backoff, crash cleanup, one-branch-per-slice), and the
slicer-independence rule.

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

## Automated review before a slice lands

Authority: spec [04](../../../../../.docs/spec/04-orchestrator.md) § "Automated
review before a slice lands" (the run step) and
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
§1.

- **When.** When a slice reaches `Implemented`, and before the slice can land,
  run Claude Code's built-in `/review` and `/security-review` on the slice's
  commit diff — before (or while) dispatching the code-evaluator.
- **Who runs it.** Only the orchestrator may spawn, and a sub-agent cannot safely
  run a command that may spawn; therefore the orchestrator runs these commands —
  never the code-evaluator
  ([ADR 0001](../../../../../.docs/ADR/0001-plugin-architecture-and-orchestrator.md)).
  This is consistent with the "You spawn; roles never spawn" rule above.
- **Local diff mode only.** Run the commands on the slice's commit diff in local
  diff mode only — never PR / `--comment` / `--fix` mode (no GitHub round-trip,
  no PR metadata, no posting, no working-tree mutation), keeping the input
  identity-neutral and network-silent so the blind contract holds (ADR 0010 §1/§3).
- **Capture and hand off.** Capture output into the committed, identity-neutral,
  per-slice findings artifact per [`review-findings.md`](review-findings.md) — see
  that file for path, format, and the four status tokens. Commit the artifact
  author-neutral per [`commit-convention.md`](commit-convention.md) and hand it to
  the blind code-evaluator as an **additional input** alongside the commit diff,
  slice-plan, specs, and gate evidence.
- **Applicability.** Run the review only when the slice's diff touches at least
  one code (non-docs) file. A pure-docs slice skips with a note, recording the
  `skipped: docs-only` status in the artifact — never "ran clean" (ADR 0010 §5).
- **Degradation.** If a command is unavailable in the environment, skip it and
  record `skipped: command-unavailable` in the artifact — never silently claim a
  clean review (ADR 0010 §7).
- **Not the gate.** This is a new, separate review dimension — **not** part of
  the `format → lint → test` gate, which is unchanged (ADR 0010 §8).

## Scope & claimed gates (for `/loom:run`)

At kickoff, confirm with the owner (AskUserQuestion if not already given):
- **Scope** — how far this session goes: `research` / `adr` / `plan` /
  `implement` / `slice` / `full`, or a range/combination. Scope bounds the loop.
- **Claimed gates** — `all`, a named list (e.g. "every ADR", "before any code
  lands"), or none. Unclaimed gates advance on evaluator approval alone; at a
  claimed gate, pause and show the artifact + verdict before proceeding.

## Round limit

Count **FAIL cycles** per artifact via the `Round:` line in its single eval file — a
PASS does not advance the count; a resolving PASS shares the FAIL's round number; a
fresh artifact's first review is round 0. **One** counter per artifact across **both**
review phases (plan-review FAILs + code-review FAILs accumulate toward the same 5).
At **5** FAILs the orchestrator **stops and escalates = pause + summary** to the owner.

See [spec 03 `## Round limits`](../../../../../.docs/spec/03-artifact-lifecycle.md)
— especially the **Escalation contract (pause + summary)** subsection — for what the
summary must contain and the owner-driven reset rule.

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

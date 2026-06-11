# 04 — Orchestrator

Status: Plan Review

## What the orchestrator is

The orchestrator is **the main, interactive Claude Code session that runs when you
invoke `/loom:run`.** The `commands/run.md` body is its operating instructions. It is
not a sixth role and not a sub-agent — it is the session you are talking to, and it
is the only actor that holds the Task tool and can **spawn role sub-agents**.

This resolves the "agents can't call agents" constraint: that limit only applies to
*sub-agents*. The orchestrator (main session) spawns every role. So:

> "Role A calls role B" ≡ "Role A finishes, sets a status, and commits; the
> orchestrator observes that status and spawns role B."

The orchestrator is the switchboard for every handoff. This is exactly how
Anthropic's own `feature-dev` plugin is built.

## The driver loop

```
start(scope, claimed_gates)
  ├─ determine init mode (see 06) and act
  ├─ if greenfield/owner-directed: gather intent, optionally run researcher/planner
  └─ loop:
       state = scan(.docs/ statuses + git)          # files + commits are truth
       action = next_action(state, scope)           # dispatch table (see 03)
       if action == none or out_of_scope: break
       if transition is an owner-claimed gate:
            pause → show artifact + verdict → await owner decision
       agent = spawn_cold(role, tier, inputs, worktree?)   # via Task tool
       wait(agent)                                   # agent works, commits, sets status
       # (the agent committed; orchestrator need not write files itself)
  └─ on break: summarize to owner; ensure status/handoff.md reflects the next step
```

Key properties:

- **Cold every time.** Each role is a fresh agent given only the files/prompt it
  needs. Between calls, the only state is `.docs/` + the repo + git history.
- **Files and commits are truth.** The orchestrator re-scans after every agent, so
  an interrupted loop resumes from the last commit.
- **Right tier per role** (see [02](02-roles.md)).

## Automated review before a slice lands

When a slice reaches **`Implemented`**, before (or while) dispatching the
code-evaluator and **before the slice can land**, the orchestrator runs Claude
Code's built-in **`/code-review`** and **`/security-review`** on the slice's commit
**diff** ([ADR 0010](../ADR/0010-orchestrator-run-automated-review-in-code-eval.md),
[ADR 0011](../ADR/0011-correct-automated-review-command-to-code-review.md)).
The orchestrator runs them — never the code-evaluator — because only the
orchestrator may spawn and a sub-agent cannot safely run a command that may spawn
([ADR 0001](../ADR/0001-plugin-architecture-and-orchestrator.md)).

- **Local diff mode only.** Never PR / `--comment` / `--fix` mode — no GitHub
  round-trip, no PR metadata, no working-tree mutation — so the input stays
  identity-neutral and network-silent and the blind contract holds
  ([ADR 0004](../ADR/0004-blind-evaluation-role-separation.md)).
- **Target the slice's commit range.** At `Implemented` the slice is already
  committed, so the working tree is empty; the orchestrator targets the slice's
  **commit range / branch** when running `/code-review` (e.g. `git diff
  <base>...<slice-HEAD>` or passing the slice branch/range as the command's
  target), never the empty working tree
  ([ADR 0011](../ADR/0011-correct-automated-review-command-to-code-review.md) §2).
- **Findings artifact.** The orchestrator captures the output into a committed,
  author-neutral, identity-scrubbed, per-slice file
  `.docs/evaluations/<slice-name>-review-findings.md` (companion to the slice's
  `-eval.md`) and hands it to the blind code-evaluator as an additional input.
- **Applicability.** Run only when the slice's diff touches at least one code
  (non-docs) file; a pure-docs slice **skips with a note**.
- **Explicit status.** The artifact records a distinguishable status —
  ran-with-findings / ran-clean / skipped: docs-only / skipped: command
  unavailable. A skip is never confusable with a clean review; if a command is
  unavailable the orchestrator skips and records it, never silently claiming clean.
- **Not the gate.** This is a new, separate review dimension — **not** part of the
  `format → lint → test` gate, which is unchanged.

## Scope (declared by the owner at kickoff)

Scope bounds the driver loop — how far this session goes. Examples:

- `research` — only the researcher (+ its review) on a topic.
- `adr` — through an accepted ADR.
- `plan` — through approved spec + slice-plan(s), no implementation.
- `implement` — take an approved slice-plan through landed code.
- `slice` — a full single-slice pass: plan → evaluate → implement → evaluate →
  land.
- `full` — keep running slices toward the roadmap target until a checkpoint.
- **ranges / combinations** — e.g. "plan and implement one slice but stop before
  landing." When scope spans roles, the orchestrator chains them automatically;
  this is what "agents calling agents" means in practice.

## Approval gates (declared by the owner at kickoff)

By default **evaluator approval is sufficient** to advance. At kickoff the owner
claims gates: either **`all`** (pause before every advance) or a **named list**
(e.g. "every ADR" and "before any code lands"). At a claimed gate the orchestrator
pauses, shows the artifact + the evaluator's verdict, and waits for the owner.

## Parallelism (designed-for; built after the sequential loop)

The orchestrator can launch **multiple role sub-agents at once**, each in the
**background** and each in its own **git worktree** — without any agent-to-agent
calls. This gives parallel slices safely:

- Each in-flight slice gets its **own branch + worktree** → no file clobbering.
- The orchestrator runs e.g. `developer` on slice A and `developer` on slice B
  concurrently, each isolated; as each reaches `Implemented`, it fires a
  `code-evaluator` for each.
- The orchestrator remains the single hub, keeping the status machine and blind
  routing coherent.
- **`.docs/` coordination across branches** follows the hybrid model decided in
  [ADR 0008](../ADR/0008-parallel-docs-coordination-worktree-per-slice.md) (the
  authority for detail):
  - The three living docs (`roadmap.md`, `progress.md`, `handoff.md`) **and the
    slice-plans index `slice-plans/README.md`** are **orchestrator-owned,
    main-only, and serialized** — a slice branch never edits them.
  - Each slice branch carries only its **uniquely-named** plan file
    (`<slice>-plan.md`), eval file (`<slice>-eval.md`), and its code. These path
    sets are disjoint across slices by construction, so `.docs/` merge conflicts
    cannot arise.
  - Landing is a **serial merge + finalize on main**: the orchestrator merges one
    slice (bringing only its disjoint files), runs the finalize pass on main to
    update the living docs and move the slice's index entry Active → Archived,
    then merges the next.
  - **Concurrency safety:** `index.lock` collisions retried with exponential
    backoff; crashed worktrees reclaimed via `git worktree remove -f` / `git
    worktree prune`; one checkout per branch (each in-flight slice = one unique
    branch in one worktree).
  - **Slicer-independence rule:** only slices that touch **disjoint source files**
    run in parallel; overlapping or mutually dependent slices are **sequenced**.

**`claude -p` fallback:** a sub-agent with `Bash(claude:*)` can shell out to a
headless `claude -p` to spawn a peer agent. Kept in reserve for deep nesting;
the worktree approach is primary because it is more observable and controllable.

## Human checkpoints

The loop pauses and returns to the owner when: the scope boundary is reached; an
owner-claimed gate is reached; an artifact exceeds the round limit (escalation =
pause + summary, see [03](03-artifact-lifecycle.md)); or a role reports it cannot
proceed without owner input. On every pause the orchestrator ensures
`status/handoff.md` reflects the next step.

## One-off invocation

Each role is also runnable directly ([07](07-command-surface.md)). A one-off is a
single cold-agent pass: read files, do the job, write/commit, set status, return —
without the orchestrator chaining the next role.

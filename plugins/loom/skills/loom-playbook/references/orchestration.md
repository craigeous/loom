# Orchestration Rules

Shared rules for every `/loom:*` command. The **orchestrator** is the main session
running the command — not one of the roles. Read this plus
[`status-machine.md`](status-machine.md) before acting.

## Core rules (always)

- **You spawn; roles never spawn.** Sub-agents can't spawn sub-agents, so every
  handoff is mediated by you: a role finishes + commits + sets a status; you read
  the new status and spawn the next role.
- **Files + git are truth.** Re-scan `.docs/` `Status:` lines + `git
  status`/`git log` after every agent — the `/loom:status` digest, **not artifact
  bodies**. Never rely on in-memory beliefs across a handoff.
- **Stay thin (ADR 0012).** You default to the `sonnet` tier. Your context must
  scale with the number of in-flight artifacts, not the size of the work product.
  See *Context discipline* below — it is not optional.
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

## Context discipline (thin orchestrator — ADR 0012)

You run on the `sonnet` tier; a correctly-thin orchestrator stays roughly flat in
context across loop iterations regardless of tier, because the heavy material lives
in sub-agents and in `.docs/`. If your context grows with the *size of the work*
rather than the *number of in-flight artifacts*, that is the bug — not the model.
Four rules:

- **Pass references, never bodies.** Hand each role `.docs/` **paths**; the cold
  role reads the artifact in its own isolated window. Never inline a plan, diff,
  research note, or eval **body** into your own context. This is the single biggest
  lever.
- **Demand the bounded return contract.** Instruct every spawned role to reply with
  only `{Status:, artifact path(s), a ≤~150-token summary, the one branch-relevant
  signal (verdict / gate result / blocker / clarification)}` — and to **not echo its
  body** (no pasted diffs, eval prose, research bodies, file dumps). The body is in
  `.docs/` for the next cold role; you route from the pointer + the signal.
- **Route on the signal, not the prose.** Branch off the `Status:` line + the
  returned signal — never by reading the critique or diff body. On a FAIL, the
  *developer* reads the eval; you do not. (The owner-claimed-gate pause is the one
  place you surface an artifact, and only to the owner.)
- **Compaction = cold self-restart.** Because `.docs/` + git are truth, when your
  window grows large, checkpoint to `status/handoff.md` and **re-bootstrap from the
  status digest** with a fresh window — a perfect reset, since the durable state was
  never in the window. Prefer this to letting context degrade. Raising your window
  (or running on `opus`) is an owner lever, not the primary answer.

The one unavoidable exception is the automated-review run step (below): it *must*
execute in your window because sub-agents can't spawn. Treat it as
**write-and-forget** — capture → write the `-review-findings.md` artifact → drop it;
do not reason over or branch on the findings.

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
review before a slice lands" (the run step),
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
§1, and
[ADR 0011](../../../../../.docs/ADR/0011-correct-automated-review-command-to-code-review.md).

- **When.** When a slice reaches `Implemented`, and before the slice can land,
  run Claude Code's built-in `/code-review` and `/security-review` on the slice's
  commit diff — before (or while) dispatching the code-evaluator.
- **Who runs it.** Only the orchestrator may spawn, and a sub-agent cannot safely
  run a command that may spawn; therefore the orchestrator runs these commands —
  never the code-evaluator
  ([ADR 0001](../../../../../.docs/ADR/0001-plugin-architecture-and-orchestrator.md)).
  This is consistent with the "You spawn; roles never spawn" rule above.
- **Actually invoke the command — never simulate it.** "Run `/code-review`" means
  issue a **real tool call** that executes the actual command: invoke the
  `code-review` and `security-review` skills via the **Skill tool** (equivalently,
  the `/code-review` and `/security-review` slash commands), and transcribe **their
  emitted output** into the findings artifact. It is a **hard violation** to author
  the findings yourself by reading the diff and writing what you *think* the command
  would say — the entire value of this step is the independent reviewer's analysis,
  which you must not impersonate. Concretely: before you write the findings
  artifact, your transcript MUST contain a Skill-tool (or slash-command) invocation
  of `code-review` and one of `security-review`; if it does not, you have not run
  the step. If you ever find yourself analysing the code to produce findings, stop —
  that is the failure mode. If the command genuinely cannot be invoked, record
  `skipped: command-unavailable` (below) — never substitute your own review and
  never claim `ran-clean`.
- **Local diff mode only.** Run the commands on the slice's commit diff in local
  diff mode only — never PR / `--comment` / `--fix` mode (no GitHub round-trip,
  no PR metadata, no posting, no working-tree mutation), keeping the input
  identity-neutral and network-silent so the blind contract holds (ADR 0010 §1/§3).
- **Target the slice's commit range.** At `Implemented` the slice is already
  committed, so the working tree is empty. The orchestrator targets the slice's
  commit range or branch when running `/code-review` — e.g. `git diff
  <base>...<slice-HEAD>` or passing the slice branch/range as the command's target
  argument — never the empty working tree
  ([ADR 0011](../../../../../.docs/ADR/0011-correct-automated-review-command-to-code-review.md)
  §2).
- **Capture and hand off.** Capture output into the committed, identity-neutral,
  per-slice findings artifact per [`review-findings.md`](review-findings.md) — see
  that file for path, format, and the four status tokens. Commit the artifact
  author-neutral per [`commit-convention.md`](commit-convention.md) and hand it to
  the blind code-evaluator as an **additional input** alongside the commit diff,
  slice-plan, specs, and gate evidence. **Write-and-forget** (ADR 0012): once the
  artifact is written, drop the review output — do not reason over or branch on the
  findings; the blind code-evaluator adjudicates them from the file.
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

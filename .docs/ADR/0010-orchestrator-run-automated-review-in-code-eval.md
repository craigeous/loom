# 0010 — Orchestrator-Run Automated Review Feeds the Blind Code-Evaluator

Status: Plan Review
Date: 2026-06-10

## Context

loom ships code only after its blind **code-evaluator** reviews an `Implemented`
slice against the slice-plan and specs (spec [03](../spec/03-artifact-lifecycle.md)
— `Implemented → (code review) → Landed`; spec [02](../spec/02-roles.md) — the
code-evaluator reads *only* the commit diff, slice-plan, specs, and gate evidence).
The owner's concern is that this review is a single model pass with no dedicated
vulnerability scan, so loom can land code that is more vulnerable, or buggier, than
a project with an automated review step would accept.

Claude Code ships two built-in slash commands that address exactly this: **`/review`**
(code review on a local diff or a GitHub PR) and **`/security-review`** (scans for
SQL injection, XSS, auth flaws, insecure data handling, dependency issues). Both run
locally on a diff and **do not require a GitHub PR**. The approved research note
[`.docs/research/2026-06-10-review-security-review-in-code-eval.md`](../research/2026-06-10-review-security-review-in-code-eval.md)
(Status: Approved) establishes the feasibility facts this ADR relies on and must not
contradict.

Two constraints shape how loom can use them:

1. **Only the orchestrator spawns** ([ADR 0001](0001-plugin-architecture-and-orchestrator.md)):
   "sub-agents cannot spawn other sub-agents." The marketplace `code-review` plugin
   demonstrably fans out to multiple parallel agents; the **built-in** `/review` /
   `/security-review` internal spawn behavior is **UNVERIFIED** (research note §"Do
   these commands spawn sub-agents?" and Open questions). A command *designed* to
   spawn cannot run *as designed* from a sub-agent — so the code-evaluator (a
   sub-agent, frontmatter `tools: Read, Grep, Glob, Bash, Write, Edit` — no `Agent`
   tool) cannot safely be the actor that runs these commands.
2. **Blind evaluation** ([ADR 0004](0004-blind-evaluation-role-separation.md)): the
   evaluator receives only controlled, identity-scrubbed inputs and performs no
   identity-revealing network operation. `/review` in **PR/`--comment` mode** pulls
   in PR metadata and posts to GitHub — which would violate the blind contract (research
   note §"Blind-evaluation contract implications"). Local diff mode does not.

**The owner has chosen** to add automated review to the code-review phase, gated
before merge, with the **code-evaluator owning the verdict** — but to relocate the
*command execution* to the orchestrator, because a sub-agent cannot run a spawning
command. This ADR records that decision and the design calls it requires.

**In scope:** the decision that automated review enters the code-review phase, who
runs it and when, how the findings reach the blind evaluator, how blindness is
preserved, that findings are advisory (not auto-FAIL), the applicability/skip
condition, cost and degradation, and the relationship to the gate. **Out of scope
(deferred to follow-on planning per [ADR 0005](0005-specs-frozen-after-approval.md)):**
the amended spec 04/02 text, the playbook bodies (`orchestration.md`,
`agents/code-evaluator.md`, `references/code-eval-rubric.md`, `status-machine.md`),
and the exact findings-artifact format. This ADR **builds on** ADR 0001 (only the
orchestrator spawns), ADR 0004 (the blind contract), and
[ADR 0002](0002-model-selection-by-tier.md) (tiers/cost); it **supersedes no
existing ADR** and changes no spec.

## Decision

### 1. Automated review runs in the code-review phase, executed by the orchestrator

When a slice reaches **`Implemented`**, the **orchestrator** — the only actor
permitted to spawn ([ADR 0001](0001-plugin-architecture-and-orchestrator.md)) — runs
Claude Code's built-in **`/review`** and **`/security-review`** on the slice's commit
**diff**, *before or while* dispatching the code-evaluator, and **before the slice can
land**. The orchestrator runs them, never the code-evaluator, precisely because a
sub-agent cannot safely run a command that may spawn (Context constraint 1). This holds
regardless of whether the built-ins actually spawn: orchestrator-mediation is safe
either way (research note §"The nested-spawn blocker"), so the decision does not hinge
on the UNVERIFIED spawn question.

These commands run in **local diff mode only** — operating on the slice's commit
diff, **never** in PR/`--comment`/`--fix` mode. No GitHub round-trip, no PR metadata,
no posting, no working-tree mutation.

Running before land is the point: the review is a pre-merge check, so any finding the
evaluator confirms as a BLOCKER blocks the merge — which is the owner's objective
(loom must stop shipping un-reviewed, more-vulnerable code).

### 2. Findings reach the evaluator as a committed, identity-neutral input artifact

The orchestrator captures the `/review` and `/security-review` output into a single
**author-neutral, identity-scrubbed findings artifact** and hands it to the blind
code-evaluator as an **additional input**, alongside the existing inputs (the commit
diff, the slice-plan, the specs, and the gate evidence — spec
[02](../spec/02-roles.md)).

- **Location/convention.** The artifact lives under the evaluations area as a
  review-findings companion to the slice's eval file — proposed path
  `.docs/evaluations/<slice-name>-review-findings.md` (the eval file is already
  `.docs/evaluations/<slice-name>-eval.md`). It is a per-slice input the evaluator
  reads, distinct from the evaluator's own verdict file. The exact filename
  convention and internal format are playbook detail fixed by the follow-on slice;
  this ADR fixes only that the findings live in a committed, evaluator-readable,
  identity-neutral file consistent with loom's files-and-git handoff model
  ([ADR 0003](0003-cold-handoffs-commit-per-handoff.md)) and the `.docs/` layout.
- **Committed author-neutral.** Like every loom handoff, the orchestrator commits
  the findings artifact under the uniform git identity, with an author-neutral
  message, per [`references/commit-convention.md`](../../plugins/loom/skills/loom-playbook/references/commit-convention.md).
  This is a parallel-coordination detail to keep consistent with
  [ADR 0008](0008-parallel-docs-coordination-worktree-per-slice.md): under
  worktree-per-slice the findings file is per-slice and uniquely named (like the eval
  file), so it does not collide across branches.

### 3. Blindness is preserved — an invariant, not a hope

The mechanism must not leak author identity into the blind evaluator (ADR 0004). This
is guaranteed by construction:

- **Local diff mode only** — no GitHub PR reference, no PR number/owner/SHA metadata,
  no `--comment` posting (Decision §1).
- **loom commits are already author-neutral** — the diff the review runs on carries no
  AI co-author trailers and a single uniform identity
  ([ADR 0003](0003-cold-handoffs-commit-per-handoff.md) /
  [ADR 0004](0004-blind-evaluation-role-separation.md)), so nothing identity-revealing
  is present to surface.
- **The findings artifact names no author** — it records *findings* (location,
  description, the command's confidence), never who wrote the code or any author
  reasoning. The orchestrator scrubs any incidental identity before handing it over.
- **No GitHub round-trip** at any point.

State this as an invariant: **the automated-review input is identity-neutral and
network-silent, so it adds a review dimension without weakening the ADR 0004 blind
contract.**

### 4. Findings are advisory; the code-evaluator adjudicates and owns the verdict

The review findings are **advisory input the code-evaluator must consider and
adjudicate** — they are **not an oracle and not an auto-FAIL**. loom's
[`references/severity.md`](../../plugins/loom/skills/loom-playbook/references/severity.md)
remains the **single source of verdict authority**: the verdict follows mechanically
from the evaluator's own severity-tagged findings, exactly as today.

The evaluator processes the artifact as follows:

- It **confirms or rejects** each reported finding against the diff, plan, and specs.
- For each finding it **confirms**, it maps it to severity per `severity.md`: a
  confirmed exploitable vulnerability → **BLOCKER**; a real correctness bug →
  **BLOCKER/MAJOR** by the landing test; hygiene → **MINOR**. A confirmed BLOCKER
  yields **FAIL**, which — because the review runs before land (§1) — blocks the
  merge.
- It **discards false positives** with a one-line reason, recorded in the eval file.

This advisory framing is required, not optional softness: `/review` itself **scores
confidence and explicitly expects false positives**, so treating its output as an
auto-FAIL would let an unreviewed third-party heuristic, not loom's rubric, decide
landings. The evaluator — not the command — owns the verdict.

### 5. Applicability — run on code diffs, skip-with-a-note for pure-docs slices

loom slices are frequently **doc-only** (markdown specs, playbook, references), where
a security/code scan has no value and only burns tokens. The automated review
therefore runs **only when the slice's diff contains code**:

- **Trigger.** Run `/review` and `/security-review` when the slice's commit diff
  touches at least one **non-docs file** — i.e. a file that is not pure documentation
  (markdown/text under `.docs/`, READMEs, and other prose). The precise file-class
  predicate (extensions / path globs that count as "code" vs "docs") is playbook
  detail fixed by the follow-on slice; this ADR fixes that the trigger is
  **presence of a code change in the diff**.
- **Skip-with-a-note.** For a pure-docs slice, the orchestrator **skips** the review
  and still writes the findings artifact, recording explicitly that the review was
  **skipped because the diff is docs-only** (not that it ran clean). The evaluator
  thus always receives an explicit, truthful record of whether the review ran.

### 6. Cost is acknowledged and deliberately accepted

Per the research note, the marketplace `code-review` evidence shows `/review` fans out
to multiple Sonnet/Haiku agents; the built-ins may do likewise. This is a **real
per-code-review-phase token cost**, incurred **once per slice's code review** (and
skipped entirely for docs-only slices, §5). Consistent with
[ADR 0002](0002-model-selection-by-tier.md) (cost is a first-class design input),
this cost is **accepted deliberately** as the price of pre-merge automated review on
code-bearing slices; it is not free and is not hidden.

### 7. Availability and graceful degradation

`/review` and `/security-review` are Claude Code **built-ins**, available wherever
loom runs. If a command is **unavailable** in a given environment, the mechanism
**degrades gracefully**: the orchestrator **skips it and records in the findings
artifact that it was skipped because unavailable** — it must **never silently claim a
clean review**. The evaluator distinguishes "ran, no findings" from "skipped
(unavailable / docs-only)" because the artifact says which. For managed projects,
loom **imposes this review the same way it imposes the gate** — it is part of the
code-review phase loom runs on the projects it manages, not loom-repo-only.

### 8. Relationship to the gate — a new, separate review dimension

This is a **new review dimension in the code-review phase**. It is **not** part of the
`format → lint → test` gate, which is **unchanged**. The gate still runs (developer,
before `Implemented`) exactly as specified; the automated review is an *additional*
pre-merge check feeding the evaluator, orthogonal to and not a replacement for the
gate.

## Alternatives considered

The research note enumerates three paths (Feasibility Verdict §"Viable paths
forward"):

- **(1) Orchestrator-run review — CHOSEN.** The orchestrator (not a sub-agent) runs
  the commands and feeds identity-scrubbed findings to the blind evaluator. **Why it
  wins:** it is the lowest-architectural-risk path — it respects the one-spawner
  invariant (ADR 0001) without amending it, preserves the blind contract (ADR 0004)
  via local-diff-only mode and an identity-neutral artifact, and keeps verdict
  authority with the evaluator and `severity.md`. It works **whether or not** the
  built-ins spawn internally, so it does not depend on the UNVERIFIED spawn question.

- **(2) loom-native non-spawning review — NOT CHOSEN.** Build a loom-internal,
  non-spawning review the code-evaluator invokes itself. Rejected: it gives a
  narrower review than the built-ins (fewer perspectives), and it forces loom to
  build and maintain new review content that duplicates capability Claude Code
  already ships. Path (1) reuses the built-ins for breadth at lower maintenance cost.

- **(3) Amend ADR 0001 to allow nested spawn — REJECTED.** Permitting a sub-agent
  (the code-evaluator) to spawn review agents would **erode the "only the orchestrator
  spawns" invariant** that makes loom's routing and blind evaluation coherent. The
  research note marks this "Not recommended"; it adds architectural complexity to
  solve a problem path (1) solves without touching ADR 0001.

**Honest note on the open question:** whether the built-in `/review` /
`/security-review` commands spawn sub-agents internally is **UNVERIFIED** (research
note Open questions). The chosen decision is **safe regardless** — orchestrator
mediation works whether or not the built-ins spawn — so approval of this ADR does
**not** hinge on resolving that gap.

## Consequences

- **Spec 04 (orchestrator) must be amended in a follow-on planning cycle** to add the
  orchestrator's "run `/review` + `/security-review` on the `Implemented` diff,
  capture identity-neutral findings, hand to the code-evaluator" step to the driver
  loop. **Spec 02 (roles)** must be amended to add the review-findings artifact to the
  code-evaluator's **Reads** list and the "adjudicate advisory findings, own the
  verdict" behavior. Both specs are **Approved and frozen** (ADR 0005), so these are
  deliberate planner-authored, blind-evaluated passes — **not** a side effect of this
  ADR or any landing. This ADR is the decision input to that cycle.
- **Playbook follow-up slices** (each its own planning/build unit, sequenced after the
  spec amendments land so the playbook matches the frozen spec) will need to amend, at
  least: [`references/orchestration.md`](../../plugins/loom/skills/loom-playbook/references/orchestration.md)
  (the run/dispatch step that executes the commands and writes the findings artifact);
  [`agents/code-evaluator.md`](../../plugins/loom/agents/code-evaluator.md) (add the
  findings artifact to its inputs);
  [`references/code-eval-rubric.md`](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md)
  (the advisory-adjudication procedure and severity mapping); and possibly
  [`references/status-machine.md`](../../plugins/loom/skills/loom-playbook/references/status-machine.md)
  (where the review step sits relative to `Implemented → code review`). These are named
  as consequences and are **not implemented here**.
- **Builds on, does not supersede.** This relies on ADR 0001 (orchestrator-only
  spawning — which is *why* the orchestrator, not the evaluator, runs the commands),
  ADR 0004 (the blind contract — preserved via local-diff-only + identity-neutral
  artifact), ADR 0003 (committed author-neutral handoffs), ADR 0008 (per-slice,
  uniquely-named coordination files), and ADR 0002 (cost acknowledged). It changes no
  existing ADR.
- **Easier:** loom stops shipping un-reviewed code — every code-bearing slice gets a
  dedicated automated code + security review before it can merge, with confirmed
  BLOCKERs gating the land.
- **Harder / new obligations:** the orchestrator gains a new per-slice step (run
  commands, scrub identity, write/commit a findings artifact, apply the
  docs-only/availability skip-with-a-note); the code-evaluator gains an adjudication
  responsibility (confirm/reject each finding, map to `severity.md`, record discards);
  and a real, deliberately-accepted token cost is incurred once per code-bearing
  slice's review.
- **No gate change and no status-machine status change.** The `format → lint → test`
  gate is untouched (Decision §8); no new `Status:` value is introduced — the review
  runs within the existing `Implemented → (code review) → Landed` phase.

## Notes

- **Open question (does not block approval):** empirically confirm whether the
  built-in `/review` / `/security-review` commands spawn sub-agents internally
  (research note Open questions). The decision is safe either way, but confirming it
  would let the follow-on playbook slices document the actual behavior precisely.
- **Open question (does not block approval):** whether `/review`'s confidence-scoring
  threshold should be tuned for loom (e.g. a minimum confidence the orchestrator
  records, or that the evaluator weights) is left to the follow-on rubric slice; this
  ADR fixes only that findings are advisory and the evaluator adjudicates, not any
  numeric threshold.

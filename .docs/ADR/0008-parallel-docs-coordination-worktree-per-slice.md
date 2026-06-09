# 0008 — Parallel `.docs/` Coordination for Worktree-per-Slice

Status: Plan Review
Date: 2026-06-09

## Context

M3 introduces parallelism: the orchestrator launches multiple role agents at once,
each in its own git worktree on its own branch, and lands each slice by merging
back to main (spec [04](../spec/04-orchestrator.md) — Parallelism; ADR 0001 —
only the orchestrator spawns). This resolves **OQ-A**
([09](../spec/09-open-questions.md)): with worktree-per-slice, *where does `.docs/`
status live, and how is it reconciled at landing?*

The research note `.docs/research/2026-06-08-git-worktree-parallel-slices.md`
(Status: Research Review) documents the mechanics and frames the trade-offs:

- Worktrees share one object store and global refs, but each has its **own working
  directory, `HEAD`, and index**. `.docs/` is a normal tracked directory, so each
  worktree sees its branch's snapshot of `.docs/`, not a live view of main.
- **Agent-input freshness:** if status lives only on main and a slice is on a
  branch, an agent in that worktree reads a *stale* `.docs/` unless it pulls
  (research §"Mapping to loom", risk on scenario 1).
- **Merge conflicts:** if two slices write the **same** `.docs/` file, landing both
  conflicts (research §"Mapping to loom", merge-conflict bullet; OQ in research
  note).
- **Orchestrator responsibility:** something must decide when main's living docs
  are written so concurrent slices don't race them.
- Concurrency gotchas: transient `index.lock` collisions on the shared `.git/`
  (research gotcha 1), no auto-cleanup on agent crash (gotcha 6), hooks run
  per-worktree (gotcha 4), one-checkout-per-branch (research §"Branch checkout
  constraint").

**Foundation.** ADR 0003 already makes every handoff an author-neutral commit and
mandates a single uniform git identity — that is what lets independent worktrees
commit safely without leaking author/role into the blind-eval diff. This ADR builds
the `.docs/` coordination layer on top of it.

**In scope:** the `.docs/` file-placement model across branches; who writes which
file when; reconciliation/cleanup at landing; the concurrency-safety rules the
orchestrator and hooks must honor; and the serial boundaries that remain.
**Out of scope:** the agent-isolation/`background`-spawn wiring itself (a playbook
build item), and any change to the status state machine in
[03](../spec/03-artifact-lifecycle.md) (unchanged — this ADR only constrains *where*
those status writes happen).

## Decision

Adopt the **hybrid (research scenario 1, hardened): living docs on main, owned by
the orchestrator; per-slice plan/eval/code on the slice branch.**

### 1. The `.docs/` coordination model — which files live where, written by whom

| Path | Lives / is authoritative on | Written by | When |
|------|------|------|------|
| `.docs/status/roadmap.md`, `progress.md`, `handoff.md` (the three **living docs**) | **main only** | **orchestrator** (and the finalize pass it spawns onto main) | between handoffs; never edited on a slice branch |
| `.docs/slice-plans/<slice>-plan.md` | the **slice branch** (created there at plan time) | planner, in the slice worktree | during plan/eval rounds for that slice |
| `.docs/evaluations/<slice>-eval.md` | the **slice branch** | plan-evaluator and code-evaluator, in the slice worktree | during eval rounds for that slice |
| source/code for the slice | the **slice branch** | developer, in the slice worktree | implement rounds |
| `.docs/spec/`, `.docs/ADR/`, `.docs/research/` | **main only** | planner/researcher, on main via a non-parallel planning pass | only in a planning cycle (specs frozen — ADR 0005; ADRs immutable) |

Rules that make this safe:

- **The orchestrator is the sole writer of the three living docs, and it writes
  them only on the main worktree.** A slice worktree never edits `roadmap.md`,
  `progress.md`, or `handoff.md`. This is the single most important rule: living
  docs are the one set of files multiple slices would otherwise contend for, so no
  slice ever touches them. This extends spec 04's "orchestrator is the single hub"
  to file authorship under parallelism, and refines the Q7/spec-03 finalize pass:
  the finalize pass that updates living docs runs **on main**, not in the slice
  worktree.
- **Per-slice artifacts are branch-local and uniquely named.** Each slice's plan
  and eval files are keyed by the slice name (`<slice>-plan.md`,
  `<slice>-eval.md`), exactly as the existing tree already does
  (`.docs/evaluations/<artifact-name>-eval.md`,
  `.docs/slice-plans/<name>-plan.md`). Two concurrent slices therefore write
  **disjoint** path sets and cannot collide.
- **Agent-input freshness is handled at spawn, not by polling.** The orchestrator
  creates each worktree from a **fresh `origin/main`**
  (`git worktree add -b <slice-branch> <path> origin/main`, per the research Create
  phase). The agent's `.docs/` snapshot is therefore current as of spawn time.
  Because agents are **cold** (spec 04) and the orchestrator passes each agent only
  the focused inputs it needs, an in-flight slice agent does **not** depend on
  reading main's living docs mid-flight; the orchestrator, which holds the live
  picture, is the one that consults and updates them. This eliminates the
  "stale read on a slice branch" risk of research scenario 1 without replicating
  status onto every branch.

**Why not the alternatives.** Research scenario 2 ("all `.docs/` on main; slice
branches carry only code; agents pull before each commit") was rejected: it forces
plan/eval artifacts to be authored on main while code is on a branch, splitting one
slice's record across two refs, and it makes the developer responsible for
pull-before-commit on a shared directory — reintroducing the very living-doc
contention this ADR removes. Keeping each slice's plan+eval+code together on its
branch means the blind code evaluator reviews a single coherent diff (ADR 0003) and
the slice's full history lands atomically.

### 2. Reconciliation at landing

Landing is performed by the orchestrator from the **main worktree** (research Land
phase):

```
# from the main worktree, orchestrator's control:
git merge <slice-branch>          # brings the slice's code + <slice>-plan.md + <slice>-eval.md onto main
git worktree remove <worktree-path>   # cleanup; -f if the worktree is unclean
```

- **`.docs/` merge conflicts are avoided by construction, not resolved after the
  fact.** Because (a) each slice owns distinct plan/eval filenames and (b) no slice
  ever edits the three living docs, a slice merge touches only files no other slice
  touches. The living docs are updated **only on main by the orchestrator**, which
  **serializes** those writes: the orchestrator merges one slice, runs that slice's
  finalize pass to update `progress.md`/`handoff.md` (and `roadmap.md` if a
  milestone closed) on main, commits, then merges the next slice. Two slices are
  never landed in a way that has both editing a living doc concurrently.
- **If a genuine code conflict arises** (two slices touched the same source file —
  a slicing/planning defect, not a `.docs/` issue), the orchestrator does not
  hand-edit code: per the orchestration rules it routes the conflict resolution
  through a **developer** slice, re-verified by the evaluator. The orchestrator's
  own merge/finalize writes are limited to the living docs it owns.
- **Cleanup is mandatory after every landing.** Remove the worktree
  (`git worktree remove`) once merged; stale worktrees consume disk and leave stale
  `index.lock` files (research Cleanup).

### 3. Concurrency safety

- **`index.lock` collisions → exponential-backoff retry.** Concurrent commits in N
  worktrees can collide on the shared `.git/` (research gotcha 1). When a git write
  (commit/merge) fails with an `index.lock` error, **retry with exponential backoff
  (3–5 attempts at ~200ms, 400ms, 800ms, …)** before surfacing the failure. This
  applies to agents committing in their worktrees and to the orchestrator's merge
  writes on main.
- **Crash / stale-lock cleanup.** A killed agent leaves its worktree and possibly a
  stale `index.lock`; the main worktree cannot auto-detect this (research gotcha 6).
  The orchestrator reclaims it with `git worktree remove -f <path>` and periodically
  `git worktree prune` (e.g. before launching a new wave of slices) to clear
  orphaned/missing worktrees.
- **One checkout per branch.** A branch can be checked out in only one worktree
  (research §"Branch checkout constraint"). Therefore **each in-flight slice = one
  unique branch in one worktree**; the orchestrator never reuses a branch across
  concurrent slices and never uses `--force` to double-check-out.
- **The per-worktree git-identity-guard hook is parallel-safe — confirmed.** The
  PreToolUse guard `plugins/loom/hooks/git-identity-guard.sh` is **stateless**: it
  reads only the hook stdin (`tool_input.command`), inspects that one string, and
  exits 0/2. It writes no shared file, lock, or database, so the per-worktree
  hook-execution gotcha (research gotcha 4) does not affect it — concurrent
  invocations in multiple worktrees cannot race. It therefore continues to enforce
  ADR 0003's uniform identity correctly in every worktree, which is precisely what
  keeps parallel author-neutral commits blind-eval-safe.

### 4. What stays serial (concurrency-model boundaries)

- **The orchestrator is still the only spawner** (ADR 0001) and the **only writer
  of main's living docs**. These are not parallelized.
- **Living-doc updates are serialized on main** as described in §2 — one
  merge+finalize at a time.
- **Planning/eval handoffs that must see each other's status remain coordinated
  through main.** Planning passes that write `spec/`, `ADR/`, or `research/`, and
  any decision that depends on the cross-slice picture, run as **non-parallel**
  passes on main (specs frozen — ADR 0005; ADRs immutable). Parallelism is for
  building **independent, already-approved** slices, not for concurrent planning of
  the shared design memory.
- **The M1 "one slice in flight at a time" rule is relaxed only along defined
  lines:** parallelism is permitted across **independent** slices (disjoint source
  files and disjoint per-slice `.docs/` filenames), each on its own branch+worktree.
  Slices that would touch the same source file, or that depend on each other's
  output, are **not** run concurrently — they remain sequential so the
  diff-against-prior-commit blind review (ADR 0003) stays unambiguous.

## Consequences

- **OQ-A is settled** and `09-open-questions.md` should move OQ-A to *Resolved*
  (→ this ADR) at finalize.
- **Spec 04's Parallelism section becomes implementable**: its open
  "`.docs/` coordination across branches" pointer is now answered here. On approval,
  a planning cycle should fold this model into spec 04 (and spec 08 playbook
  guidance); the spec is frozen, so that is a deliberate planning pass, not a
  landing side effect (ADR 0005).
- **Builds on, does not supersede, ADR 0003 and ADR 0001.** Uniform author-neutral
  identity (0003) and orchestrator-only spawning (0001) are prerequisites this ADR
  relies on; nothing here changes them.
- **Easier:** parallel DEVELOP across independent slices with no `.docs/` merge
  conflicts by construction; coherent per-slice diffs for blind review; deterministic
  living-doc history (single serial writer).
- **Harder / new obligations on the orchestrator:** it must create worktrees from
  fresh `origin/main`, serialize merge+finalize, implement `index.lock` backoff
  retry, and run crash cleanup (`git worktree remove -f` / `prune`). These are
  playbook build items for M3 (`orchestration.md` Parallelism section, currently
  "M3, not yet").
- **Constraint on the slicer/planner:** slices intended to run in parallel must be
  carved to be independent (disjoint files). Overlapping slices must be sequenced.
  This is a planning-time responsibility, surfaced here so the slice-plan author
  honors it.
- **No new status tokens.** The state machine in spec 03 is unchanged; this ADR only
  fixes *where* each status-bearing write happens under parallelism.

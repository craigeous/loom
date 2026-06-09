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
| `.docs/status/roadmap.md`, `progress.md`, `handoff.md` (the three **living docs**) **and `.docs/slice-plans/README.md`** (the slice-plans **index**) | **main only** | **orchestrator** (and the finalize pass it spawns onto main) | between handoffs; never edited on a slice branch |
| `.docs/slice-plans/<slice>-plan.md` (the per-slice plan **file**, uniquely named) | the **slice branch** (created there at plan time) | planner, in the slice worktree | during plan/eval rounds for that slice |
| `.docs/evaluations/<slice>-eval.md` | the **slice branch** | plan-evaluator and code-evaluator, in the slice worktree | during eval rounds for that slice |
| source/code for the slice | the **slice branch** | developer, in the slice worktree | implement rounds |
| `.docs/spec/`, `.docs/ADR/`, `.docs/research/` (and their indexes — `ADR/README.md`, the `spec/` indexes) | **main only** | planner/researcher, on main via a non-parallel planning pass | only in a planning cycle (specs frozen — ADR 0005; ADRs immutable) |

Rules that make this safe:

- **The orchestrator is the sole writer of the three living docs *and the
  slice-plans index*, and it writes them only on the main worktree.** A slice
  worktree never edits `roadmap.md`, `progress.md`, `handoff.md`, **or
  `.docs/slice-plans/README.md`**. This is the single most important rule: these
  are the **shared, single-instance** files multiple slices would otherwise contend
  for, so no slice ever touches them. `slice-plans/README.md` is a shared **index**,
  not a per-slice artifact: it carries one **Active plans** section and one
  **Archived plans** section that the live git history shows is edited on *every*
  plan-authoring commit and *every* finalize commit (e.g. plan commits `caea545`,
  `9e567ab`, `377225f` add an Active-plans line; finalize commit `3c9c25b` moves an
  entry from Active to Archived). Two concurrent slices each adding a line to that
  one Active-plans region — on their own branches — would conflict on merge. So the
  index is reclassified into the **same bucket as the living docs**: orchestrator-
  owned, main-only, serialized. This extends spec 04's "orchestrator is the single
  hub" to file authorship under parallelism, and refines the Q7/spec-03 finalize
  pass: the finalize pass that updates living docs runs **on main**, not in the
  slice worktree.
- **This is a change from the M1-sequential habit.** Until now (one slice in flight
  at a time) the planner edited `slice-plans/README.md`'s Active-plans entry in the
  *same plan commit* as the plan file, and the developer/finalize touched it again
  when archiving — all on one branch, so it never conflicted. Under parallelism that
  index edit **moves off the slice branch onto the orchestrator-on-main path**: the
  planner authoring a slice-plan on its branch writes **only** the uniquely-named
  plan file (`.docs/slice-plans/<slice>-plan.md`), *not* the index; the orchestrator
  updates the `slice-plans/README.md` Active/Archived sections on main — serialized
  with the other living-doc writes — when it creates a slice (add to Active) and
  when it lands one (move Active → Archived).
- **Per-slice artifacts are branch-local and uniquely named.** Each slice's plan
  *file* and eval file are keyed by the slice name (`<slice>-plan.md`,
  `<slice>-eval.md`), exactly as the existing tree already does
  (`.docs/evaluations/<artifact-name>-eval.md`,
  `.docs/slice-plans/<name>-plan.md`). These uniquely-named files — the plan file,
  the eval file, and the slice's code — are the **only** `.docs/`/source files a
  slice branch carries; every shared single-instance file (the three living docs and
  the slice-plans index) lives main-only. Two concurrent slices therefore write
  **disjoint** path sets and cannot collide on any `.docs/` file.
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
git merge <slice-branch>          # brings ONLY the slice's disjoint files onto main: code + <slice>-plan.md + <slice>-eval.md
                                  # (the slice-plans/README.md index is NOT on the branch; the orchestrator updates it on main)
git worktree remove <worktree-path>   # cleanup; -f if the worktree is unclean
```

- **`.docs/` merge conflicts are avoided by construction, not resolved after the
  fact.** The invariant: a concurrent slice **branch** carries *only* disjoint,
  uniquely-named files — its plan file (`<slice>-plan.md`), its eval file
  (`<slice>-eval.md`), and its code; **every** shared single-instance file (the
  three living docs `roadmap.md`/`progress.md`/`handoff.md` **and the slice-plans
  index `slice-plans/README.md`**) is written **only on main by the orchestrator**
  and **serialized**. Because (a) each slice owns distinct plan/eval filenames, (b)
  no slice ever edits a living doc, and (c) no slice ever edits the slice-plans
  index, a slice merge touches only files no other slice touches. The orchestrator
  serializes the shared-file writes: it merges one slice, spawns that slice's
  finalize pass on main to update `progress.md`/`handoff.md` (and `roadmap.md` if a
  milestone closed) and moves the slice's entry from Active to Archived in
  `slice-plans/README.md`, commits, then merges the next slice. (It also adds a
  slice's Active-plans entry on main when it first creates the slice.) Two slices
  are never landed in a way that has both editing a shared file concurrently.
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
  of main's living docs *and the slice-plans index***. These are not parallelized.
- **Living-doc and slice-plans-index updates are serialized on main** as described
  in §2 — one merge+finalize at a time.
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
- **Shared *content/source* files vs. shared *index/living-doc* files — two
  different mechanisms.** The main-only-orchestrator rule above is for the shared
  **coordination** files (the three living docs + the slice-plans index): single
  instances that *every* slice's lifecycle would otherwise touch, so they are pulled
  off the branch entirely. It is **not** for ordinary shared **content** files. In
  loom's own dogfooding the project source is markdown, so a slice's developer pass
  legitimately edits content files such as the root `CLAUDE.md` or the playbook
  `SKILL.md` on the branch (git history confirms slice/implement commits do this —
  e.g. `a47bf95`, `db39d44`, `b2463c4`). Those are governed by the
  **slicer-independence rule** (the bullet above): two parallel slices must not
  carve overlapping content/source files; if they would both edit `CLAUDE.md` /
  `SKILL.md` / a managed project's source file, that is the "same source file"
  case and the slices are sequenced, not run concurrently. They are *not* moved to
  the orchestrator (the orchestrator never authors content — only status). Verified
  against the live tree: the only shared single-instance coordination files a slice
  lifecycle touches are the three living docs and `slice-plans/README.md`;
  `evaluations/README.md` is static (one file per artifact, untouched since
  scaffold), and `ADR/README.md` + the `spec/` indexes are written only on the
  serial planning path. No other shared `.docs/` file remains in the slice-branch
  write set.

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
  living-doc *and slice-plans-index* history (single serial writer).
- **Harder / new obligations on the orchestrator:** it must create worktrees from
  fresh `origin/main`, serialize merge+finalize, **maintain the
  `slice-plans/README.md` Active/Archived index on main** (add an entry when it
  creates a slice, move it to Archived when it lands one — work the planner/developer
  used to do in-branch under M1 sequential), implement `index.lock` backoff retry,
  and run crash cleanup (`git worktree remove -f` / `prune`). These are playbook
  build items for M3 (`orchestration.md` Parallelism section, currently "M3, not
  yet").
- **Change from the M1 habit (call out at the spec-04 fold):** the slice-plans index
  edit moves *off* the slice branch. The planner's plan commit now writes only the
  uniquely-named plan file; the index Active/Archived update is an orchestrator-on-
  main action. Spec 08 / `orchestration.md` guidance must reflect that the planner
  and developer no longer touch `slice-plans/README.md` once parallelism is on.
- **Constraint on the slicer/planner:** slices intended to run in parallel must be
  carved to be independent (disjoint files). Overlapping slices must be sequenced.
  This is a planning-time responsibility, surfaced here so the slice-plan author
  honors it.
- **No new status tokens.** The state machine in spec 03 is unchanged; this ADR only
  fixes *where* each status-bearing write happens under parallelism.

# Worktree-per-slice parallelism

Parallelism is **available; the owner opts in.** The orchestrator (the only spawner
— ADR 0001) may launch multiple developer agents concurrently, each in its own git
worktree on its own branch, each processing an independent, already-approved slice.
The governing decision is
[ADR 0008](../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md).
This document is the single authoritative operational body: when the owner opts in
to the parallel model, follow every rule here precisely. The isolation wiring
(`background` agent spawn) is a separate build item; the coordination model and
safety rules documented here are in effect regardless.

See also: [`orchestration.md`](orchestration.md) (Core rules, Round limit,
Scope & gates), [`status-machine.md`](status-machine.md) (status dispatch).

---

## When to parallelize — the slicer-independence rule

**Only parallelize slices whose file sets are fully disjoint.**

Two slices are independent (safe to run in parallel) when both conditions hold:

1. **Disjoint source/content files.** No source or content file is edited by both
   slices (e.g. if two slices would both edit `CLAUDE.md` or `SKILL.md`, they are
   *not* independent — sequence them instead).
2. **Disjoint per-slice `.docs/` filenames.** Each slice carries a uniquely named
   plan file and eval file (`<slice>-plan.md`, `<slice>-eval.md`); no overlap on
   these names.

**Two distinct mechanisms — do not confuse them:**

- **Shared *coordination/index* files** (the three living docs + `slice-plans/README.md`)
  are pulled off the branch entirely — the orchestrator owns them on main. This is
  a structural placement rule, not a slicer-independence question. A slice branch
  never edits these files at all (see next section).
- **Shared *content/source* files** (e.g. root `CLAUDE.md`, the playbook `SKILL.md`,
  a managed project's source file) are the slicer-independence case: if two slices
  would both edit the same content file, those slices are **sequenced, not
  parallelized**. The orchestrator never authors content — only status; so these
  shared-content files cannot be moved to the orchestrator. Sequence the slices
  instead.

**Dependent slices** (one slice needs another's output to proceed) are always
sequenced — parallelism is only for slices that are truly independent.

This is a **planning/slicing-time responsibility.** The orchestrator must verify
both conditions before spawning two slices concurrently.

---

## The `.docs/` coordination model — who writes what where

*Traces ADR 0008 §1.*

### Orchestrator-owned, main-only, serialized (never on a slice branch)

The following four files are written **only by the orchestrator, only on the main
worktree, and only one at a time** (serialized):

| File | Why it is main-only |
|------|---------------------|
| `.docs/status/roadmap.md` | Living doc — shared single instance |
| `.docs/status/progress.md` | Living doc — shared single instance |
| `.docs/status/handoff.md` | Living doc — shared single instance |
| `.docs/slice-plans/README.md` | **The slice-plans index** — carries one Active-plans region and one Archived-plans region; every plan-authoring commit and every finalize commit edits this one file. Two concurrent slices each appending to that one Active-plans region would conflict on merge. Therefore the index is reclassified into the same bucket as the three living docs: orchestrator-owned, main-only, serialized. |

**A slice worktree never edits any of these four files.**

### Slice-branch-local (written on the slice branch, uniquely named)

Each slice carries exactly three categories of files on its branch — no more:

| File | Written by |
|------|------------|
| `.docs/slice-plans/<slice>-plan.md` | planner, in the slice worktree |
| `.docs/evaluations/<slice>-eval.md` | plan-evaluator and code-evaluator, in the slice worktree |
| Source/code for the slice | developer, in the slice worktree |

### Change from the M1 sequential habit

Under M1 (one slice in flight at a time) the planner edited `slice-plans/README.md`
in the *same commit* as the plan file, and the developer's finalize pass archived it
— all on one branch, so it never conflicted. **Under parallelism that index edit
moves off the slice branch:**

- The planner authoring a slice-plan on its branch writes **only** the
  uniquely-named plan file (`.docs/slice-plans/<slice>-plan.md`) — **not** the
  `slice-plans/README.md` index.
- The orchestrator maintains the index's Active/Archived sections on main:
  - **When it creates a slice** → add an entry to Active plans on main.
  - **When it lands a slice** → move that entry from Active to Archived on main.
- Developer/finalize passes no longer touch the index on the branch.

### The disjoint-file invariant

Because each slice owns distinct plan/eval filenames, no slice edits a living doc,
and no slice edits the slice-plans index, **two concurrent slices write disjoint
path sets and cannot collide on any `.docs/` file.** Conflicts are avoided by
construction, not resolved after the fact.

### Agent-input freshness

Worktrees are created from a **fresh `origin/main`** (see the `git worktree add`
command below), so each agent's `.docs/` snapshot is current as of spawn. Cold
agents (spec 04) receive focused inputs and do not read main's living docs
mid-flight; the orchestrator holds the live picture and consults/updates the living
docs between handoffs. No polling, no per-branch status replication.

---

## Workflow: create → work → land → cleanup

*Traces ADR 0008 §2.*

### Create (orchestrator, per in-flight slice)

```
git worktree add -b <slice-branch> <worktree-path> origin/main
```

- Always branch from **`origin/main`** (fresh snapshot — not a local branch that
  may lag).
- Pass `<worktree-path>` to the developer agent as its working directory.
- Update the slice-plans index (Active plans entry) on main immediately after
  creating the worktree.

### Work (developer agent, in the slice worktree)

The developer (and the slice's planner/evaluator) run **inside `<worktree-path>`**
on `<slice-branch>`. They commit author-neutral per ADR 0003 and hand back to the
orchestrator. They write only the three categories of slice-branch files listed
above — they do not touch the living docs or the index.

### Land (orchestrator, from the main worktree — serialized, one slice at a time)

```
# From the main worktree:
git merge <slice-branch>
# Brings only the slice's disjoint files onto main:
#   code + <slice>-plan.md + <slice>-eval.md
#   (slice-plans/README.md index is NOT on the branch; orchestrator updates it here)
```

After the merge, the orchestrator runs the **finalize pass on main**:

1. Update `.docs/status/progress.md` and `handoff.md`.
2. Update `.docs/status/roadmap.md` if a milestone closed.
3. Move the slice's index entry from Active to Archived in `slice-plans/README.md`.
4. `git mv` the slice-plan into `.docs/slice-plans/archive/`.
5. Commit.

Then merge the next slice. Living-doc and index updates are strictly serialized
(one merge+finalize at a time). **Never** run two merge+finalize sequences
concurrently.

**Genuine code conflict** (two slices touched the same source file — a slicing
defect, not a `.docs/` issue): the orchestrator does **not** hand-edit code. Route
the resolution through a **developer** slice, re-verified by the evaluator, per the
never-edit-code Core rule (`orchestration.md`).

### Cleanup (mandatory after every landing)

```
git worktree remove <worktree-path>    # add -f if the worktree is unclean
git worktree prune                     # run periodically (e.g. before a new wave)
                                       # to clear orphaned/missing worktrees
```

Stale worktrees consume disk and may leave stale `index.lock` files. Remove every
worktree immediately after its slice is merged.

---

## Concurrency safety

*Traces ADR 0008 §3.*

### `index.lock` collisions → exponential-backoff retry

Concurrent commits across N worktrees share one `.git/` object store; git write
operations (commit, merge) can collide on `index.lock`. When a git write fails with
an `index.lock` error, **retry with exponential backoff** — 3–5 attempts at
approximately 200 ms, 400 ms, 800 ms, … — before surfacing the failure. Applies to:

- Agents committing in their slice worktrees.
- The orchestrator's merge and finalize commits on main.

### Crash / stale-lock cleanup

A killed or crashed agent leaves its worktree and possibly a stale `index.lock`.
The orchestrator reclaims it with:

```
git worktree remove -f <worktree-path>
git worktree prune
```

Run `git worktree prune` periodically (e.g. before launching a new wave of slices)
to clear any orphaned worktrees that no longer have a working directory on disk.

### One checkout per branch

A branch can be checked out in only one worktree at a time (git constraint). Each
in-flight slice = one unique branch in one worktree. The orchestrator never:

- Reuses a branch across concurrent slices.
- Uses `--force` to double-checkout a branch.

Name slice branches distinctly (e.g. `slice/<slice-name>`).

### The git-identity-guard hook is parallel-safe

`plugins/loom/hooks/git-identity-guard.sh` is **stateless**: it reads only the hook
`stdin` (`tool_input.command`), inspects that one string, and exits 0 or 2. It
writes no shared file, lock, or database. Concurrent invocations across multiple
worktrees therefore cannot race. The hook continues to enforce ADR 0003's uniform
author-neutral identity in every worktree, which is what keeps parallel commits
blind-eval-safe.

---

## What stays serial

*Traces ADR 0008 §4.*

- **The orchestrator is the only spawner** (ADR 0001) and the **only writer of
  main's living docs and the slice-plans index.** These are not parallelized.
- **Living-doc and slice-plans-index updates are serialized on main** — one
  merge+finalize at a time (see Land above).
- **Planning passes that write `spec/`, `ADR/`, or `research/`**, and any
  cross-slice decision, run as **non-parallel** passes on main. Specs are frozen
  (ADR 0005); ADRs are immutable. Parallelism is for building **independent,
  already-approved** slices — not for concurrent planning of shared design memory.
- **Slices that share a source/content file are sequenced.** If two candidate
  parallel slices would both edit `CLAUDE.md`, `SKILL.md`, or any managed-project
  source file, they are not run concurrently — the diff-against-prior-commit blind
  review (ADR 0003) must remain unambiguous, and shared-content files are a
  slicer-independence violation (see above).

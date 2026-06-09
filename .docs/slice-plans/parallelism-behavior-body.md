# M3 Parallelism behavior body — worktree-per-slice operational guidance

Status: Approved
Target specs: ADR 0008 (`.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md`, Accepted) — operationalized into the playbook. (Spec 04's Parallelism fold is the deferred planning-cycle item per ADR 0008 Consequences; this slice does **not** touch frozen `spec/`.)

## Context

ADR 0008 is **Accepted**: it decides the `.docs/` coordination model for
worktree-per-slice parallelism (living docs + `slice-plans/README.md` index are
orchestrator-owned and main-only/serialized; each slice branch carries only its
uniquely-named plan/eval/code; concurrent slices write disjoint files), the
reconciliation/landing flow (serial merge + finalize on main from the main
worktree, then worktree cleanup), the concurrency-safety rules (`index.lock`
exponential backoff, crash cleanup, one-branch-per-slice, the stateless
identity-guard hook), and the boundaries (orchestrator-only spawning; shared
design memory stays serial; the M1 "one slice in flight" rule relaxes only for
independent/disjoint slices).

The playbook does **not** yet carry this. Today
`plugins/loom/skills/loom-playbook/references/orchestration.md` says
"Parallelism (M3, not yet)" and "don't run roles in parallel," and its Core rules
state "One slice in flight at a time (M1)" as an absolute. ADR 0008 is now the
decision those guards block; this slice turns the ADR into operational guidance.

This slice **mirrors the M2 init-body pattern**: the operational detail is
single-sourced into a new `references/` body and the call sites are repointed at
it — exactly how `greenfield.md` / `unaligned.md` / `initialized.md` /
`gate-learning.md` / `tooling.md` were single-sourced and cross-linked.

**In scope:** create `references/parallelism.md` (the authoritative operational
body, faithful to ADR 0008); repoint/relax the guards in `orchestration.md` and
`commands/run.md`; add `parallelism.md` to the `SKILL.md` References list; update
root `CLAUDE.md` layout/roadmap-status line to reflect M3 in progress.

**Out of scope:** editing `.docs/spec/` or `.docs/ADR/` (frozen specs — ADR 0005;
ADRs immutable — the spec-04 fold is a separate deferred planning cycle); building
the agent-isolation/`background`-spawn wiring itself (ADR 0008 §scope marks that a
later build item); changing the status state machine (spec 03 unchanged — ADR 0008
only constrains *where* status writes happen); resolving OQ-A in
`09-open-questions.md` (a finalize action on the ADR, not this slice).

## Steps

### 1. Create `plugins/loom/skills/loom-playbook/references/parallelism.md` (new file)

The single authoritative worktree-per-slice operational body. Author it from
scratch (no template — it is a reference body like `greenfield.md`). It must
faithfully implement ADR 0008. Structure it with these sections, each tracing to
the ADR section named:

- **Heading + framing.** `# Worktree-per-slice parallelism`. One-paragraph frame:
  parallelism is **available, owner opts in** (not "unproven / not yet");
  the orchestrator remains the **only spawner** (ADR 0001) and may use background
  agents + per-worktree isolation; cite ADR 0008 as the governing decision and
  link to it (`../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md`
  — **verify this relative depth resolves** from
  `plugins/loom/skills/loom-playbook/references/` to repo-root `.docs/` before
  finalizing; adjust the `../` count to match the real tree).

- **When to parallelize (slicer-independence rule)** — traces ADR 0008 §4 last two
  bullets. Only parallelize slices whose file sets are **disjoint**: disjoint
  source/content files **and** disjoint per-slice `.docs/` filenames. State the ADR
  0008 distinction explicitly: shared **coordination/index** files (the three
  living docs + `slice-plans/README.md`) are pulled off the branch entirely
  (orchestrator-owned, see next section) — that is a *different mechanism* from
  shared **content/source** files. Shared content/source files (e.g. root
  `CLAUDE.md`, the playbook `SKILL.md`, a managed project's source file) are the
  "same source file" case: slices that would both edit one of those are
  **sequenced, not parallelized** (the orchestrator never authors content — only
  status). Dependent slices (one needs another's output) are also sequenced. This
  is a planning/slicing-time responsibility.

- **The `.docs/` coordination model — who writes what where** — traces ADR 0008 §1.
  Reproduce the placement rules concretely:
  - The three **living docs** (`.docs/status/roadmap.md`, `progress.md`,
    `handoff.md`) **and** the slice-plans **index** (`.docs/slice-plans/README.md`)
    are written **only by the orchestrator, only on the main worktree, serialized**.
    A slice worktree never edits any of these four files. State *why* the index is
    in this bucket: it is a shared single-instance file with one Active-plans and
    one Archived-plans region that every plan/finalize commit edits, so concurrent
    branches would conflict on it — so it is reclassified into the living-docs
    bucket.
  - The per-slice **plan file** (`.docs/slice-plans/<slice>-plan.md`), **eval file**
    (`.docs/evaluations/<slice>-eval.md`), and the slice's **code/source** live on
    the **slice branch**, uniquely named by slice. These are the **only** files a
    slice branch carries.
  - **Change from the M1 habit (call out explicitly):** the planner authoring a
    slice-plan on its branch now writes **only** the uniquely-named plan file —
    **not** `slice-plans/README.md`. The orchestrator updates the index's
    Active/Archived sections on main (Active when it creates the slice; Active →
    Archived when it lands it). Developer/finalize no longer touch the index on the
    branch either.
  - **The disjoint-file invariant:** because each slice owns distinct plan/eval
    filenames, no slice edits a living doc, and no slice edits the index, two
    concurrent slices write **disjoint** path sets and cannot collide on any
    `.docs/` file — conflicts are avoided *by construction*.
  - **Agent-input freshness:** worktrees are created from a **fresh `origin/main`**,
    so the agent's `.docs/` snapshot is current as of spawn; cold agents get focused
    inputs and do not read main's living docs mid-flight — the orchestrator holds
    the live picture. No polling / no per-branch status replication.

- **Workflow: create → work → land → cleanup** — traces ADR 0008 §2 + research
  Create/Work/Land/Cleanup. Give the concrete git commands:
  - **Create** (per in-flight slice, from the orchestrator):
    `git worktree add -b <slice-branch> <worktree-path> origin/main`
    — the orchestrator passes `<worktree-path>` to the developer agent as its
    working directory.
  - **Work:** the developer (and the slice's planner/evaluator) run **in that
    worktree** on `<slice-branch>`, commit author-neutral (ADR 0003), and hand back
    to the orchestrator.
  - **Land** (orchestrator, from the **main worktree** — serialized, one slice at a
    time): `git merge <slice-branch>` (brings only the slice's disjoint files: code
    + `<slice>-plan.md` + `<slice>-eval.md`; the index is *not* on the branch), then
    the orchestrator updates the living docs + `slice-plans/README.md` on main
    (run/spawn the finalize pass on **main**: update `progress.md`/`handoff.md`,
    `roadmap.md` if a milestone closed, and move the slice's index entry Active →
    Archived), commits, **then** merges the next slice.
  - **Genuine code conflict** (two slices touched the same source file — a slicing
    defect): the orchestrator does **not** hand-edit code; route the resolution
    through a **developer** slice, re-verified by the evaluator (per the
    never-edit-code Core rule).
  - **Cleanup (mandatory after every landing):** `git worktree remove <worktree-path>`
    (`-f` if unclean); `git worktree prune` periodically (e.g. before a new wave) to
    clear orphaned worktrees.

- **Concurrency safety** — traces ADR 0008 §3:
  - **`index.lock` collisions → exponential-backoff retry.** On a git write
    (commit/merge) failing with an `index.lock` error, retry with exponential
    backoff (3–5 attempts at ~200ms / 400ms / 800ms / …) before surfacing the
    failure. Applies to agents committing in worktrees and to the orchestrator's
    merge writes on main.
  - **Crash / stale-lock cleanup.** A killed agent leaves its worktree and possibly
    a stale `index.lock`; reclaim with `git worktree remove -f <path>` and run
    `git worktree prune` periodically.
  - **One checkout per branch.** Each in-flight slice = one unique branch in one
    worktree; never reuse a branch across concurrent slices; never `--force`
    double-checkout.
  - **The per-worktree git-identity-guard hook is parallel-safe.** Note that
    `plugins/loom/hooks/git-identity-guard.sh` is **stateless** (reads only its hook
    stdin, writes no shared file/lock), so concurrent invocations across worktrees
    cannot race; it keeps enforcing ADR 0003's uniform identity in every worktree —
    which is what keeps parallel author-neutral commits blind-eval-safe.

- **What stays serial** — traces ADR 0008 §4:
  - Orchestrator is the only spawner (ADR 0001) and the only writer of main's living
    docs + the slice-plans index.
  - Living-doc and index updates are serialized on main (one merge+finalize at a
    time).
  - Planning passes that write `spec/`, `ADR/`, or `research/`, and any cross-slice
    decision, run as **non-parallel** passes on main (specs frozen — ADR 0005; ADRs
    immutable). Parallelism is for building **independent, already-approved** slices,
    not for concurrent planning of shared design memory.

Cross-link back to `orchestration.md` and `status-machine.md` so the body is
discoverable from the rules it backs.

### 2. Repoint + relax the guards in `orchestration.md`

File: `plugins/loom/skills/loom-playbook/references/orchestration.md`.

a. **Core rules — line 31–33** ("One slice in flight at a time (M1)."). Replace the
   absolute M1 phrasing with ADR 0008's relaxation. New bullet text (single
   bullet): one slice in flight **by default**; **parallel independent/disjoint
   slices are allowed** per [`parallelism.md`](parallelism.md) (each on its own
   branch + worktree, owner opts in). **Keep** the diff-against-prior-commit
   caution scoped to slices on the **same branch**: don't stack unrelated in-flight
   slices on **one branch**, or a re-review's diff-against-prior-commit will
   conflate them. (The caution survives; only the "one at a time, absolute" framing
   goes.)

b. **`## Parallelism (M3, not yet)` section — lines 70–75.** Replace the whole
   section. New section `## Parallelism` (drop "M3, not yet"): parallelism is
   **active** — worktree-per-slice, orchestrator-spawned background agents, governed
   by ADR 0008. Point to [`parallelism.md`](parallelism.md) as the authoritative
   operational body (create→work→land→cleanup, `.docs/` coordination, concurrency
   safety, the slicer-independence rule). Keep the **owner-opts-in** framing (owner
   asks for / accepts the parallel model); drop "not yet" / "unproven."

**Verify:** after the edit, `rg -n "M3, not yet"` and
`rg -n "one slice in flight at a time"` (the absolute phrasing) return nothing in
this file.

### 3. Repoint the guard framing in `commands/run.md`

File: `plugins/loom/commands/run.md`.

`run.md` currently has no explicit parallelism guard but lists the
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/*.md` bodies it acts from
(see the Procedure step 1 pattern that names `greenfield.md` / `unaligned.md` /
`initialized.md`). Add a `parallelism.md` reference so the orchestrator command
points at the now-active model and frames it as **available (owner opts in)**:

- Add `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/parallelism.md` to the
  "Read first (source of truth)" list (alongside `orchestration.md` and
  `status-machine.md`).
- In the Driver loop (step 3) add a short note: independent/disjoint slices may run
  in parallel (worktree-per-slice) when the **owner opts in** — see
  `parallelism.md` for the create→work→land→cleanup flow and the
  slicer-independence rule. Frame as available, **not** "not yet / unproven."

(Note: the task names "`commands/run.md` and the loom orchestrator command doc" —
these are the **same file**; `run.md` *is* the orchestrator command. Verified: no
separate orchestrator command doc exists under `plugins/loom/commands/`. Apply the
edits once, to `run.md`.)

**Verify:** `rg -ni "not yet|unproven|don't run roles in parallel" plugins/loom/commands/run.md`
returns nothing; `rg -n "parallelism.md" plugins/loom/commands/run.md` resolves.

### 4. Add `parallelism.md` to the `SKILL.md` References list

File: `plugins/loom/skills/loom-playbook/SKILL.md`, the `## References (references/)`
list (lines ~42–58). Add one bullet, matching the existing style:

`- `parallelism.md` — worktree-per-slice parallelism (ADR 0008): the create→work→land→cleanup workflow, the `.docs/` coordination model (living docs + slice-plans index orchestrator-owned/main-only/serialized; slice branches carry only disjoint uniquely-named plan/eval/code), concurrency safety (`index.lock` backoff, crash cleanup, one-branch-per-slice), and the slicer-independence rule.`

### 5. Update root `CLAUDE.md` layout + roadmap-status line

File: `/Users/craig/git/loom/CLAUDE.md`.

a. **Layout heading — line 24** (`## Repo layout (M2 complete; M3 next)`): change
   to `## Repo layout (M2 complete; M3 in progress)`.

b. Add a layout bullet for the new body, mirroring the M2-body bullets (e.g. the
   `tooling.md` / `gate-learning.md` bullets):
   `- **Parallelism behavior body** (M3): `plugins/loom/skills/loom-playbook/references/parallelism.md`
   is the single authoritative worktree-per-slice operational body (ADR 0008):
   create→work→land→cleanup, the `.docs/` coordination model (living docs +
   slice-plans index orchestrator-owned/main-only/serialized; slice branches carry
   only disjoint plan/eval/code), concurrency safety, and the slicer-independence
   rule.`

   Place it after the M2 body bullets, before the closing "When editing the
   playbook/agents…" bullet.

### 6. Update the slice-plans README active index (this slice's own entry)

File: `.docs/slice-plans/README.md`. **This is allowed**: under current state M3 is
not running in parallel yet, so the orchestrator-owned/main-only index rule the new
body *describes* is not yet operative for this slice. Replace the
`_(none — M2 complete; M3 not yet started)_` placeholder under `## Active plans`
with this slice's entry:

`- [parallelism-behavior-body.md](parallelism-behavior-body.md) — `Plan Review` —
M3 parallelism behavior body: new `references/parallelism.md` operationalizing
ADR 0008 (worktree-per-slice create→work→land→cleanup, `.docs/` coordination
model, concurrency safety, slicer-independence rule); repoints the
`orchestration.md` + `run.md` guards (drops "M3, not yet" / absolute
"one slice in flight"); adds it to `SKILL.md` + root `CLAUDE.md` (M3 in progress).`

## Verification

No compiled gate (loom is markdown — root `CLAUDE.md` "no gate to run"). Verification
is **review-against-ADR-0008, mechanical** (`rg`/`grep`, dogfood the rule):

1. **Every ADR 0008 element maps to concrete guidance in `parallelism.md`.** Check
   the body covers, each traceable to its ADR section: §1 coordination model (living
   docs + index main-only/serialized; disjoint per-slice plan/eval/code; the M1-habit
   change that moves the index edit off the branch; fresh-`origin/main` freshness);
   §2 landing (serial `git merge` + finalize on main + worktree cleanup; code-conflict
   → developer slice); §3 safety (`index.lock` backoff ~200/400/800ms; crash
   `git worktree remove -f`/`prune`; one-branch-per-slice; stateless identity-guard
   hook); §4 boundaries (orchestrator-only spawner; serial living-doc/index writes;
   serial planning of shared design memory; slicer-independence rule incl. shared
   SOURCE files like `SKILL.md`/`CLAUDE.md` → sequence). Spot-check with
   `rg -n "index.lock|worktree add|worktree remove|disjoint|origin/main|serial" plugins/loom/skills/loom-playbook/references/parallelism.md`.

2. **Coordination invariant stated correctly (matches ADR 0008, not the pre-fix
   version).** The body must say the slice-plans **index** (`slice-plans/README.md`)
   is in the **orchestrator-owned/main-only/serialized** bucket WITH the three living
   docs — not that slices edit the index on their branch. Confirm with
   `rg -n "slice-plans/README.md|index" plugins/loom/skills/loom-playbook/references/parallelism.md`
   and read for correctness.

3. **No stale phrasing remains in touched files.**
   - `rg -ni "M3, not yet" plugins/loom/` → nothing.
   - `rg -ni "one slice in flight at a time" plugins/loom/skills/loom-playbook/references/orchestration.md`
     → nothing (relaxed wording only).
   - `rg -ni "not yet|unproven" plugins/loom/commands/run.md` → nothing.

4. **Call sites point at `parallelism.md` and links resolve.**
   - `rg -rn "parallelism.md" plugins/loom/` → hits in `orchestration.md`,
     `run.md`, `SKILL.md`, and the new file's own cross-links; plus root `CLAUDE.md`.
   - Each relative link target exists: verify the
     `orchestration.md`/`SKILL.md` → `parallelism.md` links (same dir) and the
     `parallelism.md` → ADR 0008 relative path actually resolve against the tree
     (open the resolved path).

5. **No spec/ADR touched.** `git diff --name-only` shows **no** path under
   `.docs/spec/` or `.docs/ADR/`. Expected changed set: the new
   `references/parallelism.md`, `references/orchestration.md`,
   `commands/run.md`, `SKILL.md`, root `CLAUDE.md`, and
   `.docs/slice-plans/parallelism-behavior-body.md` + `.docs/slice-plans/README.md`.

6. **Init-body pattern mirrored.** Operational detail lives in `references/`
   (single source); call sites are short pointers — same shape as `greenfield.md` /
   `gate-learning.md` and their call sites. Confirm `orchestration.md`'s Parallelism
   section is a pointer, not a copy of the body.

## Notes

<none yet>
</content>
</invoke>

# Evaluation: parallelism-behavior-body

Verdict: PASS
Round: 1
Reviewed against: ADR 0008 (Accepted), research note 2026-06-08-git-worktree-parallel-slices.md (Approved), ADR 0001, orchestration.md, commands/run.md, SKILL.md, root CLAUDE.md, the real tree (rg/realpath checks).

## Findings

- [MINOR] Step 5a cites the CLAUDE.md layout heading as "line 24", but the heading
  `## Repo layout (M2 complete; M3 next)` is actually at **line 27** in the current
  tree. The quoted `old_string` text is exact, so the edit is still executable as
  written (text match, not line match) — but the stated line number is wrong and
  should be corrected to avoid misleading the implementer. (`grep -n "## Repo layout" CLAUDE.md` → 27.)

- [MINOR] CLAUDE.md line 25 reads "Design decisions are in `.docs/spec/` and
  `.docs/ADR/` (ADRs 0001–0006)." but ADRs 0007 and 0008 now exist (verified:
  `ls .docs/ADR/`). The plan edits CLAUDE.md for M3 and is governed by ADR 0008,
  yet leaves this stale ADR-range reference untouched. This is pre-existing drift
  and arguably outside the slice's single purpose, but it would be a cheap, in-scope
  correctness fix while CLAUDE.md is already open for this slice. Not a blocker;
  flagged so the author can decide.

- [MINOR] Step 4's `SKILL.md` line range is given as "~42–58" (the `~` is honest);
  the `## References` heading is at line 41 and the list runs 42–58. Fine as a
  guide; no change required.

## Required changes (for FAIL)

None — verdict is PASS. The MINOR items above are improvements, not blockers.

## Notes

Critical-invariant check (the Round-1 hole): **PASS.** The plan does NOT reintroduce
the defect of a planner writing the slice-plans index on a branch. Step 1's
"Change from the M1 habit" bullet and the "who writes what where" section state
exactly the fixed ADR-0008 rule: the slice-plans **index**
(`.docs/slice-plans/README.md`) is reclassified into the orchestrator-owned /
main-only / serialized bucket **with** the three living docs; a slice branch never
edits it; the planner authoring a plan on its branch writes **only** the
uniquely-named `<slice>-plan.md`; the orchestrator maintains Active/Archived on
main. The plan even reproduces the *why* (one Active/one Archived region edited on
every plan and finalize commit → concurrent branches would conflict).

ADR-0008 element coverage — every element maps to concrete guidance in the planned
`parallelism.md`:
- §1 coordination model: living docs + index main-only/serialized; per-slice
  plan/eval/code branch-local + uniquely named as the *only* branch files;
  disjoint-by-construction; fresh-`origin/main` freshness, cold agents, no polling. ✔
- §2 landing: serial `git merge` + finalize on main + mandatory worktree cleanup;
  genuine code conflict routed through a developer slice (never hand-edited). ✔
- §3 safety: `index.lock` exponential backoff (~200/400/800ms); crash cleanup
  (`git worktree remove -f` / `prune`); one-branch-per-slice; stateless
  identity-guard hook is parallel-safe. ✔
- §4 boundaries: orchestrator-only spawner (ADR 0001) and sole writer of living
  docs + index; serialized living-doc/index writes; serial planning of shared
  design memory; the slicer-independence rule **including** the shared-SOURCE-file
  (root `CLAUDE.md` / `SKILL.md` / managed-project source) → *sequence* distinction,
  kept explicitly separate from the index/living-doc *pull-off-branch* mechanism. ✔

Guard relaxation (Q4): correct. Step 2a replaces the absolute "one slice in flight
(M1)" with owner-opts-in "one by default; parallel independent/disjoint slices
allowed per parallelism.md" while **keeping** the diff-against-prior-commit caution
scoped to slices stacked on the *same* branch. Step 2b replaces "Parallelism (M3,
not yet)" with an active "Parallelism" pointer (owner-opts-in framing, drops "not
yet / unproven"). Step 3 adds the run.md reference + driver-loop note framed as
available, not "not yet".

Executable / single-purpose (Q1): six numbered, file-scoped steps, each naming the
exact file; one coherent goal (operationalize ADR 0008 into the playbook, mirroring
the M2 init-body single-source pattern). Out-of-scope is explicit and correct (no
`spec/`, no `ADR/`, no isolation/spawn wiring, no state-machine change, OQ-A
deferred).

No spec/ADR edits (Q5): the expected changed set (new `parallelism.md`,
`orchestration.md`, `run.md`, `SKILL.md`, root `CLAUDE.md`, the plan + README index)
touches nothing under `.docs/spec/` or `.docs/ADR/`. ✔

Paths real / link depth (Q5): verified mechanically. The planned
`parallelism.md` → ADR 0008 relative link
`../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md`
resolves from `plugins/loom/skills/loom-playbook/references/` to the real file
(`realpath` → REPO/.docs/ADR/0008-...md). The plan correctly instructs the author
to verify this depth; it is correct as written (five `../`). `parallelism.md` does
not yet exist (clean create). No separate orchestrator command doc exists — `run.md`
is the only one (`ls plugins/loom/commands/`), so the plan's "same file" note is
accurate.

Verification mechanical + checkable (Q6): the Verification section dogfoods the
rg/grep rule with concrete, checkable greps (stale-phrasing absence in each touched
file, link-target existence, no spec/ADR in the diff, ADR-element spot-check). Sound.

Self-consistency of Step 6: editing the README index directly for *this* slice does
not contradict the invariant the body asserts — ADR 0008 places the index-off-branch
rule under "once parallelism is on," and this slice is still landing sequentially.
Justification is correct.

---

# Round 2 (code)

Verdict: PASS
Round: 2
Reviewed against: commit `4cc9fa1`, slice-plan `parallelism-behavior-body.md`,
ADR 0008 (Accepted), ADR 0001, the git-identity-guard hook, and the real tree
(rg/realpath/cat mechanical checks). No compiled gate — markdown slice; acceptance
is review-against-ADR-0008 done mechanically.

## Findings

None at BLOCKER/MAJOR/MINOR. The slice faithfully operationalizes ADR 0008 into the
playbook and satisfies every plan step.

## Mechanical-check results

- **ADR-0008 fidelity (Q1).** Read `parallelism.md` and ADR 0008 in full and traced
  every element. §1 coordination model (four orchestrator-owned/main-only files incl.
  the index, with the *why*; slice-branch-local plan/eval/code uniquely named; the
  M1-habit change moving the index edit off-branch; disjoint-by-construction;
  fresh-`origin/main` + cold-agent freshness) — present, lines 52–108. §2 landing
  (`git worktree add … origin/main`; serial `git merge`+finalize on main updating
  progress/handoff/roadmap + Active→Archived + `git mv` archive; genuine code conflict
  → developer slice, never hand-edited; mandatory `git worktree remove`/`prune`
  cleanup) — present, lines 112–171. §3 safety (`index.lock` exponential backoff 3–5
  attempts ~200/400/800ms; crash cleanup `git worktree remove -f`/`prune`;
  one-checkout-per-branch, never reuse/`--force`; stateless identity-guard hook) —
  present, lines 175–219. §4 boundaries (orchestrator-only spawner + sole writer of
  living docs+index; serialized living-doc/index writes; serial planning of
  spec/ADR/research; slicer-independence incl. shared-SOURCE `CLAUDE.md`/`SKILL.md` →
  sequence, kept distinct from the index/living-doc pull-off-branch mechanism) —
  present, lines 223–239. Nothing weakened relative to the ADR.
- **CRITICAL invariant (Q2): PASS.** `parallelism.md` places `.docs/slice-plans/README.md`
  in the *orchestrator-owned, main-only, serialized* table (line 66) alongside the
  three living docs, with the conflict rationale; states "A slice worktree never edits
  any of these four files" (line 68); the "Change from the M1 sequential habit" section
  (lines 81–93) says the planner writes **only** the uniquely-named plan file and the
  orchestrator maintains Active/Archived on main; the Land section confirms the index
  is NOT on the branch (line 142). The pre-fix hole (a role writing the index on a
  slice branch) is NOT reintroduced anywhere.
- **Guards relaxed correctly (Q3): PASS.** `rg -ni "M3, not yet" plugins/loom/` → none.
  `rg -ni "one slice in flight at a time" orchestration.md` → none (the one remaining
  occurrence of that exact phrase is in `parallelism.md` line 82 as descriptive
  M1-history "Under M1 (one slice in flight at a time)…", not a guard). orchestration.md
  Core bullet now reads "One slice in flight by default; parallel independent/disjoint
  slices are allowed … owner opts in" (lines 31–36) and the diff-against-prior-commit
  caution is **preserved**, scoped to slices stacked on **one branch** (line 34). The
  `## Parallelism (M3, not yet)` section is replaced by an owner-opts-in pointer
  (lines 73–83). `rg -ni "not yet|unproven" run.md` → none; run.md adds the read-first
  reference (line 14) and a driver-loop owner-opts-in note (lines 38–40).
- **Links / scope (Q4): PASS.** `git show --name-only` = exactly
  parallelism.md (new) + orchestration.md + run.md + SKILL.md + CLAUDE.md +
  parallelism-behavior-body.md + slice-plans/README.md (the index, acceptable).
  No path under `.docs/spec/` or `.docs/ADR/`. The ADR-0008 relative link from
  `references/` (`../../../../../.docs/ADR/0008-…md`) resolves via `realpath` to the
  real file; same link in orchestration.md resolves; same-dir links
  (`orchestration.md`, `status-machine.md`) exist; parallelism.md cross-links back to
  both (lines 13–14, 160).
- **No contradiction (Q5): PASS.** parallelism.md reaffirms ADR 0001 orchestrator-only
  spawning (lines 3–5, 227) and ADR 0003 author-neutral commits. The git-identity-guard
  hook is genuinely stateless (verified by reading it: reads only stdin
  `tool_input.command`, exits 0/2, writes no shared file/lock), so the body's
  parallel-safe claim is accurate.
- **Init-body pattern mirrored.** Operational detail single-sourced in `references/`;
  call sites (orchestration.md Parallelism, run.md, SKILL.md, CLAUDE.md) are short
  pointers — same shape as the M2 bodies.

## Required changes

None — verdict is PASS.

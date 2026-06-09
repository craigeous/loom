# Evaluation: ADR 0008 — Parallel `.docs/` Coordination for Worktree-per-Slice

Verdict: FAIL
Round: 1
Reviewed against: `.docs/research/2026-06-08-git-worktree-parallel-slices.md` (authority/evidence base); ADR 0003, ADR 0001, ADR 0005; spec 04 (Parallelism), spec 03 (lifecycle / finalize), spec 09 (OQ-A); `orchestration.md`; `plugins/loom/hooks/git-identity-guard.sh`; current `.docs/` tree.

## Findings

- [MAJOR] **The "conflict-free by construction" claim misses a real shared list file: `.docs/slice-plans/README.md`.** §1 (table row for `slice-plans/<slice>-plan.md`) and §1 rule "Per-slice artifacts are branch-local and uniquely named ... write **disjoint** path sets and cannot collide" treat all `slice-plans/` writes as per-slice unique filenames. They are not. `slice-plans/README.md` is a single shared index with an **Active plans** and an **Archived plans** section, and the live tree + git history prove every plan and every finalize edits it: e.g. finalize commit `3c9c25b` moves an entry from "Active plans" to "Archived plans" in that one README; `50850d5`, `1afbc38`, `caea545`, `377225f`, `9e567ab` all touch it at plan/finalize time. Under parallelism, the plan-time "Active plans" entry is authored on the **slice branch** (per the §1 table), so two concurrent slices each add a line to the same "Active plans" region on their own branch; merging both lands a textual conflict in that region — exactly the `.docs/` merge conflict §2 says is "avoided by construction, not resolved after the fact." The ADR's foundational invariant therefore has a counterexample it does not address. (`rg -i 'readme|index|active plan|archived plan'` over the ADR returns only `git index`/`index.lock` hits — the slice-plans index is nowhere named.) The model needs an explicit rule for the slice-plans index, e.g. it is a living/orchestrator-owned, main-only, serialized file like the three status docs (not a slice-branch artifact), or the index is reconstructed on main at landing rather than carried per-branch.

- [MINOR] **Finalize-pass authorship phrasing is loose in one place.** §2 line "the orchestrator merges one slice, runs that slice's finalize pass" reads as the orchestrator authoring the finalize. Read together with §1 ("the finalize pass **it spawns** onto main") and the §1 rule that the finalize "refines the Q7/spec-03 finalize pass: ... runs **on main**," the intent is clearly orchestrator-*spawned* finalize on main — consistent with Q7/spec 03 (finalize is a re-spawned cold developer pass) and not foreclosing OQ-C. Recommend the §2 wording match §1 ("the orchestrator spawns that slice's finalize pass on main") so it cannot be read as the orchestrator authoring living-doc content directly, which would brush against `orchestration.md`'s "never edit … route through a role" for non-status content. Not blocking: the ADR's own §1/§4 keep the orchestrator as the writer of *status* living docs only, which Q7 already permits for the finalize.

## Correct / verified (not blocking — recorded for the re-review)

- **Hook statelessness claim is accurate.** Read `plugins/loom/hooks/git-identity-guard.sh`: it `cat`s stdin, extracts `tool_input.command`, runs string transforms, and `exit 0/2`. It writes no shared file, lock, or DB. §3's "stateless ⇒ gotcha 4 does not affect it ⇒ concurrent invocations cannot race" is faithful and correct.
- **Concurrency-safety items are faithful to the research.** index.lock exponential backoff (3–5 attempts, ~200/400/800ms) matches research gotcha 1 verbatim; crash cleanup via `git worktree remove -f` / `prune` matches gotcha 6; one-branch-per-worktree matches the "Branch checkout constraint"; create-from-`origin/main` matches the research Create phase. No overstatement of mechanics.
- **Other shared indexes are correctly covered.** `ADR/README.md` ("In Review"/"Accepted") and the `spec/` indexes are only touched in planning passes, which §1 (main-only, planning-cycle-only) and §4 (planning passes are non-parallel) explicitly serialize — so those index files are not a parallel-conflict path. `evaluations/README.md` is static ("one file per artifact"; git shows it untouched since scaffold) — not a hazard. The hole is specific to `slice-plans/README.md`.
- **Boundaries are coherent and contradict nothing accepted.** Orchestrator-only spawning (ADR 0001), serial shared-design-memory/planning passes, frozen specs (ADR 0005, ADRs immutable), and relaxing the M1 one-slice rule only for disjoint/independent slices are all consistent with spec 04, spec 03, `orchestration.md`, and ADR 0003's diff-against-prior-commit blind review.
- **ADR form is sound.** Template-conformant; `Status: Plan Review`; consequences honest (names the M3 orchestration build items, the slicer independence obligation, the deferred spec-04 fold); correctly states it *builds on, does not supersede* 0003/0001; correctly **defers** the spec-04 fold and the OQ-A→Resolved move to a finalize/planning pass instead of editing frozen specs/accepted ADRs from this ADR; README "In Review" entry added in the same commit.
- **Citations faithful.** Spot-checked gotcha numbers, scenario 1/2 framing, and Create/Land/Cleanup phases against the research note — accurately represented, not overstated.

## Required changes (for FAIL)

1. Address the `.docs/slice-plans/README.md` shared-index concurrency path. State explicitly how its **Active plans** / **Archived plans** sections are kept conflict-free under parallel slices — e.g. classify the slice-plans index as an orchestrator-owned, main-only, serialized file (like the three status living docs) rather than a slice-branch artifact, and/or have the orchestrator rebuild the index on main at plan/finalize time instead of carrying per-branch edits. Update the §1 table and the §1 "disjoint path sets" rule and the §2 "conflict-free by construction" claim so the central invariant actually holds for every `.docs/` file a parallel slice can touch. (Confirm the fix with `rg` over the proposed model + the live tree, not by eye.)

## Notes

The decision (hybrid: living docs on main + orchestrator-owned and serialized; per-slice plan/eval/code on the branch) is the right shape and most of the rigor is here — the freshness-at-spawn argument, the serial merge+finalize, the index.lock/crash/one-branch rules, and the hook-statelessness analysis are all sound and faithful to the research. The single gap is that the "no two slices touch the same file" foundation has one concrete counterexample (the slice-plans index) that the live repo already demonstrates is edited on every plan and every finalize. Close that and the conflict-free-by-construction claim becomes true rather than nearly-true.

---

# Round 2 re-review

Verdict: PASS
Round: 2
Reviewed against: same authority as Round 1 (research note `2026-06-08-git-worktree-parallel-slices.md`; ADR 0003/0001/0005; spec 04/03/09; `orchestration.md`; `git-identity-guard.sh`; live `.docs/` tree). Diff reviewed: commit `78e7ca1` since the Round-1 commit.

## Prior findings — resolution check

- **[MAJOR] slice-plans/README.md shared-index conflict path — RESOLVED.** `78e7ca1`
  reclassifies `.docs/slice-plans/README.md` into the living-doc bucket
  (orchestrator-owned, main-only, serialized) across every place the model states
  the invariant, and removes it from the slice-branch write set. Verified consistent
  end-to-end (`rg -ni 'readme|\bindex\b'` over the ADR):
  - §1 placement table row now lists `slice-plans/README.md` alongside the three
    living docs under "main only / orchestrator / never edited on a slice branch"
    (line 56). The `<slice>-plan.md` row is narrowed to "the per-slice plan **file**,
    uniquely named" (line 57).
  - §1 rules: the sole-writer rule names the index (lines 64–80); a new explicit
    **M1-habit-change** bullet (lines 81–90) states the planner writes **only** the
    uniquely-named plan file on its branch and the orchestrator updates the
    Active/Archived index on main at create (→Active) and land (Active→Archived).
  - §1 "disjoint path sets" rule (lines 91–99) now scopes the per-slice set to
    plan file + eval file + code and asserts disjointness "on any `.docs/` file."
  - §2 conflict-free-by-construction restatement (lines 132–146) and the merge
    snippet comment (line 128) both carry the index in the shared/main-only set.
  - §4 boundaries (lines 184–187) serialize "living-doc and slice-plans-index
    updates."
  No leftover text implies the index is written on a slice branch — line 56
  ("never edited on a slice branch") and line 85 ("moves off the slice branch onto
  the orchestrator-on-main path") agree. Cited evidence verified against the real
  tree: `slice-plans/README.md` exists with one **Active plans** and one **Archived
  plans** section (`grep -nE '^#|Active|Archived'`); plan commits `caea545`,
  `9e567ab`, `377225f` each edit it (`git show --stat`), and finalize `3c9c25b`
  edits it (Active→Archived move). The cited commits are accurate.

- **[MINOR] finalize-authorship wording — RESOLVED.** §2 now reads "spawns that
  slice's finalize pass on main" (line 142), matching §1's "the finalize pass **it
  spawns** onto main" — no longer readable as the orchestrator authoring living-doc
  content directly. Consistent with Q7/spec-03.

## Independent invariant check (rg + git history, not by eye)

Enumerated every `.docs/`/source file a slice lifecycle (plan→develop→eval→finalize)
touches and classified each:

- `.docs/slice-plans/<slice>-plan.md` — uniquely named, branch-local. Disjoint.
- `.docs/evaluations/<slice>-eval.md` — uniquely named, branch-local. Disjoint.
- slice source/code — branch-local; shared markdown content files (root `CLAUDE.md`,
  playbook `SKILL.md`) handled by the slicer-independence/sequencing rule (see below).
- `.docs/slice-plans/README.md` — **now main-only/orchestrator/serialized** (the fix).
- `.docs/status/{roadmap,progress,handoff}.md` — main-only/orchestrator/serialized.
- `.docs/evaluations/README.md` — static; `git log` shows it untouched since the
  scaffold commit `523cc01`. Not a hazard.
- `.docs/ADR/README.md`, `.docs/spec/` indexes, `.docs/research/` — main-only,
  non-parallel planning path (§1 + §4). Not a parallel-conflict path.

Result: every shared single-instance coordination file is in the
main-only/serialized set; everything a slice branch writes is uniquely-named (plan,
eval) or governed by sequencing (content/source). The conflict-free-by-construction
invariant now genuinely holds for every `.docs/` file a parallel slice can touch.
No reachable shared-conflict path remains.

## On the new content/source distinction (§4 last bullet) — sound

The ADR draws a clean two-mechanism split: shared **index/living-doc** files are
pulled off the branch to the orchestrator (it can author status); shared
**content/source** files (root `CLAUDE.md`, `SKILL.md`, a managed project's source)
cannot be moved to the orchestrator (it never authors content), so they fall under
the **slicer-independence rule** — two parallel slices must not carve overlapping
source files; overlap ⇒ sequence, don't parallelize. This is correct and complete
for the specific worry raised:

- Two slices editing `SKILL.md`'s References list concurrently *would* textually
  conflict — verified real: `b2463c4` appends to `SKILL.md` (References + Gates)
  and `db39d44` also edits `SKILL.md`; two such edits to the same list region merge-
  conflict. But this is a strict subset of "both slices edit `SKILL.md`," which the
  slicer-independence rule already forbids running concurrently (same source file ⇒
  sequence). So the References-list case is covered without a finer-grained rule.
- Cited content-edit commits verified: `a47bf95` edits `CLAUDE.md`; `db39d44` and
  `b2463c4` edit `CLAUDE.md` + `SKILL.md` (`git show --stat`). Accurate.

The distinction is decisive (it tells the slicer/planner exactly which remedy
applies to which file class) and matches accepted authority (ADR 0001 — orchestrator
never authors content; ADR 0003 — unambiguous diff-against-prior-commit review).

## Well-formedness / scope

- Template-conformant; findings traceable to the research/problem; consequences
  honest (names the new orchestrator obligation to maintain the index on main and
  the M1-habit change to fold at spec-04). `No silent supersession` — still
  explicitly builds on, does not supersede, 0003/0001.
- `78e7ca1` touched **only** the ADR file (`git show --name-only`) — no edits to
  `spec/` or any accepted ADR. ADR/README.md already carries the 0008 "In Review"
  entry from Round 1.
- Status line is the only content I changed: `Plan Review` → `Accepted`.

## Verdict rationale

The single Round-1 MAJOR and the Round-1 MINOR are both resolved; my independent
enumeration confirms the conflict-free-by-construction invariant now holds for
every `.docs/` file a parallel slice can touch, and the content/source-file
distinction soundly closes the only remaining shared-file path (SKILL.md/CLAUDE.md
via sequencing). No blockers, no unaddressed majors. PASS.

# Evaluation: claude-md-slim-down-plan

Verdict: FAIL
Round: 1
Reviewed against: `.docs/spec/08-playbook.md` § "CLAUDE.md auto-propagation" +
§ "Shape and Concision Discipline" + § "Slice-plans index ownership under
parallelism"; `.docs/research/2026-07-03-claude-md-digest-discipline.md`; the
current `/Users/craig/git/loom/CLAUDE.md` (197 lines); `references/code-eval-rubric.md`;
`agents/developer.md` (finalize step 2); `references/plan-eval-rubric.md`;
`references/severity.md`.

## Findings

- [MAJOR] Step 4 + the `slice-plans/README.md` row in **Files touched** are stale
  and conflict with the authority. Step 4 instructs the developer to "add this
  plan's entry to `## Active plans` (**replacing `(none)`**)" as part of the slice
  commit — but the README Active-plans entry for this slice **already exists**
  (`.docs/slice-plans/README.md` lines 20–26), and there is no `(none)` left to
  replace. Following step 4 literally would duplicate the entry. Independently,
  spec 08 § "Slice-plans index ownership under parallelism" assigns the Active/
  Archived index to the **orchestrator on main**, and states the in-slice author
  "writes **only** the uniquely-named plan file … **never** the index." Listing
  `slice-plans/README.md` in the slice's file-touch set therefore contradicts the
  approved spec's ownership rule (rubric: *Authority — consistent with them*;
  *Executable — steps an independent reader could follow*). This does not affect
  the `CLAUDE.md` deliverable's coverage, but it is a wrong instruction that an
  independent reader would implement incorrectly.

- [MINOR] Verification step 3 asserts ADR tags 0003, 0008–0013, 0017, 0014/0015/
  0016 each survive, but omits **ADR 0001** (current line 104) and **ADR 0002**
  (current line 123). Dropping these two bare cross-refs is acceptable point-don't-
  restate compression (the "only the orchestrator spawns" concept survives verbatim
  in the unchanged "What loom is" paragraph; the tier detail lives in
  `orchestration.md`/spec), but the plan's blanket claim "every currently-named …
  invariant must still be pointed to" is slightly overstated. State explicitly that
  0001/0002 are intentionally not re-tagged, so the acceptance is honest.

- [MINOR] The claim "16 pointers … correspond 1:1 to the 16 current Repo-layout
  bullets" (line 101–102) is a loose count. `CLAUDE.md` has 15 top-level Repo-layout
  bullets, one of which (line 35) explodes into three mapping rows (hooks / bin /
  rust-gate). The mapping is in fact **finer** than 1:1 (good for coverage), but the
  "16 = 16" framing is cosmetically inaccurate. Reword to "≥1:1, finer where a
  bullet bundled multiple components."

- [MINOR] Verification step 2's token list is strong for reference bodies but does
  not assert the structural pointers `plugins/loom/`, `.docs/`, or `hooks.json`
  survive. Low risk, but adding them would make the acceptance exhaustive.

## Required changes (for FAIL)

1. Resolve the `slice-plans/README.md` handling (the MAJOR). Either remove
   `slice-plans/README.md` from **Files touched** and delete step 4 entirely
   (the orchestrator owns the index per spec 08, and the Active entry is already
   present) — or, if an index touch is genuinely intended, correct step 4 to match
   the actual tree state (the entry exists; there is no `(none)` to replace) and
   reconcile it with spec 08 § "Slice-plans index ownership under parallelism".
   The slice's committed diff must not step on the orchestrator-owned index.

## Notes

The core of the plan — the rewrite and its acceptance — is sound and the primary
risk (lost coverage) is genuinely guarded:

- The compression mapping is 1:1-or-finer; the one current bullet that bundles
  three components (hooks / bin / rust-gate, line 35) is correctly split into three
  explicit rows, so nothing collapses invisibly.
- Verification step 2 `rg`-checks all 16 high-value reference tokens; all 16 named
  reference bodies / components / gates / hooks were confirmed to exist on the tree.
  A bad slim-down that dropped a reference file (e.g. `migration-recipe.md` or a
  gate) would be caught mechanically.
- The size bound (≤~100, target 80–100), read-first / Gate / Project-conventions /
  keep-consistent invariants, and link-resolution are all in the acceptance.
- Enforcement wiring is sound: the `code-eval-rubric.md` Hygiene bullet single-
  sources to spec 08 (does not restate the rule), flags restatement / over-bound /
  lost-coverage, references `severity.md`, and marks itself a separate dimension
  from the `format → lint → test` gate — matching spec 08's Enforcement paragraph.
  The `developer.md` addition is a genuine one-clause pointer.
- Scope discipline is correct: no `spec/`/`ADR/` edits, automated review
  `skipped: docs-only`, single coherent purpose.

Only the `slice-plans/README.md` step blocks approval; fix it and the plan is
approvable.

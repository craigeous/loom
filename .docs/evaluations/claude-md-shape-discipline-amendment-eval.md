# Evaluation: CLAUDE.md Shape and Concision Discipline amendment (spec 08 + spec 03 pointer)

Verdict: PASS
Round: 0
Reviewed against: `.docs/research/2026-07-03-claude-md-digest-discipline.md` (Approved);
existing spec 08 CLAUDE.md inclusion/exclusion rules; ADR 0012 and ADR 0013;
spec 03 finalize step 2; plan-eval rubric.

## Findings

- [MINOR] The two-zone shape (rule 3) drops the research note's optional third
  "project conventions" zone — spec 08 §*Shape* line 130–134. This is faithful to
  the note's *recommended amendment text* (which lists exactly two zones), not a
  defect; noted only so a future editor knows the omission was deliberate, not lost.
- [MINOR] "Bounded size" uses `under ~100 lines` where the research note wrote
  `< 100 lines` — spec 08 line 125–128. The tilde loosens a hard bound into a soft
  target; harmless and arguably more honest for a hand-maintained file, but a reader
  enforcing it should treat 80–100 as the operative target the note intended.

## Required changes (for FAIL)

None — PASS.

## Notes

Faithfulness (all five rules present and accurate to the Approved research note):
1. **Point, don't restate** — present, matches note rule 1 (single-clause pointer
   replaces restating paragraph; named file remains sole authority). ✓
2. **Bounded size** — `under ~100 lines (target 80–100)` for loom, `under ~200`
   for managed; over-bound detail moves to a reference file. Matches note rule 2. ✓
3. **Two zones** — stable top (read-first, what-is-loom, invariants, gate) +
   pointer index (name + one-clause purpose + link). Matches note rule 3. ✓
4. **Scope test** — "Would a reader need the detail here, or just know where to
   find it?" Matches note rule 4 verbatim in intent. ✓
5. **Enforcement** — developer finalize applies it; blind code-evaluator flags
   restatement / over-bound / paragraph-where-a-pointer-belongs on a finalize
   `CLAUDE.md` diff; rubric-body wiring explicitly DEFERRED to a follow-on slice
   ("not decided here — the normative rule lives in this spec"). Matches the note's
   "spec rule + developer discipline + evaluator check" recommendation and correctly
   scopes what is/isn't decided. ✓

Additive, not contradictory: the new subsection sits below the inclusion/exclusion
rules and opens by delimiting itself ("The inclusion/exclusion rules above decide
*what* may enter; this subsection governs its *shape and size*"). The four inclusion
categories and the per-slice-history exclusion (spec 08 lines 80–99) are unedited and
uncontradicted (verified by diff — the amendment commit adds only the new subsection
and the status flip). ✓

Citation correctness (top check — the research note failed a prior round on this):
The spec did **not** inherit the error. Spec 08 line 112–114 attributes
ADR 0012 → "context-budget discipline" and ADR 0013 → "the ~60% cold-restart
trigger." Verified mechanically: `rg "60%"` finds **no** literal `60%` in ADR 0012
(it establishes the context-budget / cold-restart-as-answer discipline, decision 4)
and **five** occurrences in ADR 0013, which explicitly operationalizes "loom's
intended 60% restart." Both attributions are correct; both link targets resolve
(`../ADR/0012-*.md`, `../ADR/0013-*.md` exist). ✓

Spec 03 pointer: finalize step 2 gained a single clause pointing to spec 08's
*Shape and Concision Discipline* (point-don't-restate, size bound, two-zone shape),
not a duplicate of the rule body. Cross-link anchor matches the real `#### Shape and
Concision Discipline` heading in spec 08 (line 107). ✓

No regression: the amendment commit (7d1b38d) touches only spec 08 and spec 03; no
immutable ADR or research note was edited. Both specs correctly flipped
`Approved → Plan Review` for the amendment cycle; playbook conformance intact.

Fresh artifact, no prior FAIL in this eval file → Round 0.

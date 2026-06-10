# Evaluation: spec 06 — Unaligned-migrate sub-mode amendment

Verdict: PASS
Round: 0
Reviewed against: ADR 0009 (Accepted, primary authority), ADR 0005 (freeze rule), the rest of `06-init-modes.md` for internal consistency; `plan-eval-rubric.md` + `severity.md`. Diff under review: commit `7b2808b` (Approved → Plan Review).

## Findings

No BLOCKER, MAJOR, or MINOR findings.

The amendment faithfully and completely encodes ADR 0009's decisions at the spec/design level, adds no policy beyond it, is internally consistent, and is lifecycle-correct. Verification was mechanical (`git show 7b2808b`, `--stat`, `rg`), not by eye.

### Faithfulness & completeness vs ADR 0009 (all decisions encoded)

- **Split (ADR §1)** → spec §2a/§2b. Unaligned-bare = descriptive back-fill, explicitly "unchanged"; Unaligned-migrate = map → move → rewrite cross-references → retain status, with the "nothing to describe that the existing tree does not already describe better" rationale preserved (spec lines 54-79).
- **Detection signal (ADR §2)** → Detection block + prose (spec lines 13-14, 18-32). Distinguishes pre-existing (undotted) docs spine → Unaligned-migrate, else Unaligned-bare; records the observation ("a non-loom docs spine exists at `<path>`") and steers; stays **read-only** ("mutates nothing, only observes and steers"); exact heuristics deferred to the follow-on `init-detection.md` slice.
- **Owner gate (ADR §3)** → spec lines 81-91. Named migrate / thin-pointer / abort, surfaced before any files move, not the generic "ambiguity → ask" fall-through, owner must answer. Each consequence matches the ADR: migrate → future Initialized; thin-pointer → re-detect Unaligned (loom does not yet honor the pointer); abort → re-detected Unaligned every run.
- **Status preservation (ADR §4)** → spec lines 92-100. Migrated specs keep prior status; not forced to Draft; not re-litigated through blind plan-eval; not a re-review trigger; the "new specs enter at Draft → review" rule is explicitly bare-only (also restated at the §2a bullet, lines 67-69); reconciled with ADR 0005 ("spec lifecycle is untouched").
- **Inline in `/loom:init` (ADR §6)** → spec lines 101-107. Pure migration has no specs to author, so no planner/evaluator role-spawn in the migration; `/loom:init` runs detection → owner gate → reconciliation inline → hands back Initialized; subsequent design resumes via `/loom:run`.
- **Recipe deferred to playbook (ADR §5/§7)** → spec lines 108-112. Ordered idempotent cross-ref rewrite, numbered-spine → `spec/` + `status/` split, and operational preconditions named as a reusable playbook recipe; load-bearing properties referenced ("see ADR 0009"), not transcribed; recipe text deferred to a follow-on slice.
- **Authority cited** → ADR 0009 linked at line 52 and referenced at line 111.

### No over-reach

The spec records design, not the recipe. It does not write the cross-ref-rewrite recipe inline, does not enumerate concrete detection heuristics (the `docs/`, `doc/`, `documentation/` paths appear only as examples, matching the ADR's own examples), and invents no policy beyond ADR 0009. Scope is confined to the Detection block and §2.

### Consistency / no contradiction

Detection block and §2 agree (spine present → migrate, in both places). The new text does not contradict §1 Greenfield, §3 Initialized, Gate establishment, or Playbook re-application — `git show 7b2808b` shows those sections untouched (hunks fall only in the Detection block and §2; the `@@ -29` hunk's "Start from nothing" lines are unchanged §1 context). Status preservation is coherent with ADR 0005's freeze model rather than weakening it.

### Lifecycle correctness

- `Status: Plan Review` — correct: spec 06 was Approved/frozen, so a deliberate planning-cycle amendment re-enters review per ADR 0005.
- Single file touched — `git show --stat 7b2808b` shows only `.docs/spec/06-init-modes.md` (1 file, +75/-4).
- A planning-cycle amendment, not a slice; no spec/ADR edit smuggled through a build path.

## Required changes (for FAIL)

None.

## Notes

The status-line transition itself (Approved → Plan Review) is part of the amendment commit, which is the correct entry mechanism for re-opening a frozen spec under ADR 0005; this evaluator leaves the `Status:` line unchanged. ADR §6's secondary observation — that `unaligned.md` Step 3's "planner authors / evaluator reviews blind" wording conflicts with init scaffolding inline — is correctly absent from this spec amendment, since the ADR Consequences scope that to a separate playbook follow-on slice, not to spec 06 text. Its omission is not a gap.

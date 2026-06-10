# Evaluation: ADR 0009 — Unaligned-migrate Sub-mode

Verdict: PASS
Round: 0
Reviewed against: `.docs/research/2026-06-09-unaligned-init-migration-field-report.md` (the problem/research it resolves); `.docs/spec/06-init-modes.md` §2 + `references/unaligned.md` + `references/init-detection.md` (the design it refines, frozen); ADR 0005 and ADR 0001 (claimed to build on); rubric `references/plan-eval-rubric.md` + `references/severity.md`.

## Findings

- [MINOR] The Context and Consequences cite ADR 0001 by name ("only the orchestrator spawns") but, unlike spec 06 and ADR 0005, ADR 0001 is not hyperlinked. ADR 0005's link resolves (`0005-specs-frozen-after-approval.md`); a parenthetical link to `0001-plugin-architecture-and-orchestrator.md` would match. Non-load-bearing; the dependency is stated in prose and the ADR README index already records "builds on ADR 0001/0005."
- [MINOR] Decision §5's recipe-property text uses bare-link-like literals (e.g. `](X.md)`, `](]X.md)` patterns) as illustrative reference forms. These are example tokens, not real links, and do not resolve — correctly so. Worth a glance only to confirm they are not mistaken for broken links (they are not).

## Required changes (for FAIL)

None — verdict is PASS.

## Notes

This ADR meets every gate I checked, verified mechanically rather than by eye:

- **Decision-record, not implementation.** Context "Out of scope" and the
  Consequences explicitly defer the amended spec 06 text, the `init-detection.md`
  classifier change, the `unaligned.md` split, and the migration-recipe body to
  named follow-on cycles (one spec-amendment cycle + three playbook slices). §5
  names the recipe's *load-bearing properties* without writing the recipe text,
  and §7 names hazards as recipe requirements without their commands. It does not
  over-reach into writing the recipe/spec inline.

- **Each decision traces to a real field-report finding**, and the report's
  premises are real. I confirmed the seven decisions map to report §1 (split),
  §2 (undotted-spine detection), §3 (migrate/thin-pointer/abort owner gate with
  consequences), §6 (status preservation), §4+§5 (reusable ordered/idempotent
  recipe with the self-match `(?<!\.)` hazard, three reference forms, the
  numbered-spine→spec+status two-directional rewrite, living-vs-archived
  boundary), §7 (init-inline vs role-spawned), and "Operational failures" (the
  three preconditions: `git mv` untracked skip, NUL-delimited lists, dirty-tree
  check). I spot-checked the report's premises on `~/git/ballboy`: it is now
  loom-shaped with `.docs/spec/00-07,11..` (the gap at 08/09/10 is exactly the
  roadmap/handoff/progress extraction the report describes), `.docs/status/` holds
  the three living docs, and commit `564d8a4` is "Align repo to loom: migrate
  docs/ to .docs/ layout." No decision contradicts the report or invents
  unsupported policy.

- **Consistency with spec 06 / ADR 0005.** The ADR refines spec 06 §2 without
  contradicting it: I confirmed `unaligned.md` Step 3 is "Descriptive back-fill"
  and line 120 says "the planner authors the descriptive specs and the plan
  evaluator reviews them blind" — exactly what §4 and §6 cite, and §4 correctly
  scopes that Draft-entry rule to Unaligned-bare (a refinement, not a
  contradiction). `init-detection.md` rule 3 is the Unaligned catch-all the ADR
  references. Spec 06 is treated as Approved/frozen and the amendment is deferred
  to a deliberate, blind-evaluated planning pass — coherent with ADR 0005, whose
  spec-freeze model is the stated reason both that the spec change is a separate
  cycle and that migrated specs keep their status (a relocation, not a re-review).
  Builds on ADR 0001 (orchestrator-only spawn → migration runs inline, no spawn),
  which I confirmed ADR 0001 states. It supersedes no ADR and says so.

- **Scope discipline.** Scope is the Unaligned-migrate decision only; Consequences
  name the follow-on cycles and what gets harder (classifier heuristic, the init
  owner gate + inline migration path, executable-shaped recipe). The "No
  status-machine or threshold changes" note guards against unrelated policy drift.

- **Hygiene.** House format (Context / Decision / Consequences / Notes),
  `Status: Plan Review`, number 0009 (no collision in `.docs/ADR/`), README index
  lists it under "In Review" with the correct "refines spec 06 §2 / builds on ADR
  0001/0005" annotation. All four real relative links resolve.

No blockers and no majors; the two minors are hygiene that do not block landing.

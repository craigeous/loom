# Evaluation: ADR 0008 fold into specs 04 (Parallelism) and 08 (Playbook)

Verdict: PASS
Round: 1
Reviewed against: ADR 0008 (Accepted) as primary authority; spec 03 (artifact
lifecycle, frozen-spec rule); the commit `c3cd354` diff; plan-eval rubric +
severity.md.

## Findings

- [MINOR] Spec 04 — the ADR §4 "What stays serial" boundary is only partially
  surfaced. The fold captures the serialized living-doc/index writes and the
  slicer-independence rule, but does not explicitly carry ADR 0008's point that
  *planning passes that write `spec/`/`ADR/`/`research/` run non-parallel on main*
  (parallelism is for building already-approved independent slices, not for
  concurrent planning). The fold defers to ADR 0008 as "the authority for detail,"
  so this is not a contradiction — the matter is already covered by spec 04's
  existing frozen-spec/planning-cycle text and ADR 0005 — but a one-line mention
  that concurrent *planning* of shared design memory stays serial would make the
  Parallelism section self-contained. Non-blocking.

## Required changes (for FAIL)

None — verdict is PASS.

## Notes

Faithfulness and completeness of the fold (rubric: Authority, Internally
consistent, Scoped). Verified mechanically against ADR 0008, not by eye:

- All seven required ADR 0008 elements are present in spec 04's Parallelism
  section (`rg` confirmed each):
  - Three living docs named (`roadmap.md`, `progress.md`, `handoff.md`) **and** the
    slice-plans index `slice-plans/README.md` marked orchestrator-owned, main-only,
    serialized; a slice branch never edits them (line 84-86) — matches ADR §1 row 1
    and §1 bullet 1.
  - Slice branches carry only disjoint, uniquely-named `<slice>-plan.md`,
    `<slice>-eval.md`, and code; merge conflicts cannot arise by construction
    (line 87-90) — matches ADR §1 bullet 3 and §2 invariant.
  - Serial merge + finalize on main, moving the index entry Active → Archived
    (line 91-94) — matches ADR §2.
  - Concurrency safety: `index.lock` exponential backoff; crash cleanup via
    `git worktree remove -f` / `git worktree prune`; one checkout per branch
    (line 95-98) — matches ADR §3 bullets 1-3.
  - Slicer-independence rule: only disjoint-source-file slices run in parallel;
    overlapping/dependent slices sequenced (line 99-100) — matches ADR §4 and the
    Consequences "Constraint on the slicer/planner."

- The previously-open "`.docs/` coordination across branches … see 09" pointer is
  resolved in the text: `rg -i "open question|see \[09\]|09-open-questions"` over
  spec 04 returns no matches. The bullet now points to ADR 0008 as the decided
  authority. Spec 09 already records OQ-A as RESOLVED → ADR 0008 (line 53), and
  spec 09 was not part of this commit, so no dangling open-question framing remains.

- Spec 08 captures the ownership change ADR 0008's Consequences require: the new
  "Slice-plans index ownership under parallelism" subsection (line 44-54) states the
  index is orchestrator-maintained on main, planner/developer no longer touch
  `slice-plans/README.md` under parallelism, and explains the change from the
  M1-sequential habit — matching ADR §1 bullet 2 and the "Change from the M1 habit"
  Consequence.

No over-reach / no contradiction (rubric: Scoped, Internally consistent):

- `git show --stat c3cd354` confirms only `.docs/spec/04-orchestrator.md` and
  `.docs/spec/08-playbook.md` were touched (25 / 14 line changes).
- The `claude -p` fallback note in spec 04 is left intact (line 102-104) — correctly
  out of scope.
- The fold adds no policy beyond ADR 0008: every claim traces to a specific ADR
  section, and the bullet explicitly names ADR 0008 as "the authority for detail."
  No contradiction with ADR 0008 or other approved specs detected. Cross-reference
  links (`../ADR/0008-…md`) resolve to existing files.

Lifecycle correctness (rubric: Playbook conformance; spec 03 frozen-spec rule):

- Both specs carry `Status: Plan Review` (verified), correctly re-entering the
  Draft → Plan Review → Approved cycle per spec 03 for a frozen-spec amendment. This
  is a deliberate planning-cycle pass, not a slice landing — exactly the path ADR
  0008's Consequences prescribe ("the spec is frozen, so that is a deliberate
  planning pass, not a landing side effect"). No code, no slice-plan, no status-token
  change; spec 03's state machine is untouched (ADR 0008 §"No new status tokens").

Internal consistency: cross-references resolve; the spec 04 bullet and the spec 08
subsection are mutually consistent and both consistent with ADR 0008.

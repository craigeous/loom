# Living Document Shape — Plan Evaluation

Artifact: `.docs/slice-plans/living-doc-shape.md`
Reviewed against: `.docs/spec/00-overview.md`, `.docs/spec/03-artifact-lifecycle.md`, `.docs/spec/08-playbook.md`, `plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md`
Round: 0
Verdict: PASS

## Summary

The plan is a single-purpose slice: add mechanical living-document shape rules to the
`--all` docs-state validator, and bring the real living docs into compliance. It follows
the slice-plan template and satisfies the rubric's structure, authority, threat-model and
verification checks. It has no BLOCKER or MAJOR findings. Four MINOR findings are advisory;
none needs a revision round.

## Findings

### Rubric checks

- **Structure:** pass. `Status:`, `Target specs:`, `Target size: <= 250 LOC`, `Context`,
  `Out of Scope & Threat-Model Boundary`, `Steps`, `Verification`, `Notes` and `Revision Log`
  are present. The plan is 88 lines, well under the 250-line limit.
- **Authority:** pass. It targets specs 03 and 08. Spec 08 `## Mechanical invariants` already
  requires "living-doc ownership/shape ... and README status agreement", and the improvement
  plan's `living-doc-shape` slice matches the plan's scope.
- **Single purpose:** pass. Docs restructuring, validator rules and tests all serve one goal.
- **Non-goals and threat model:** pass. The boundary section cites spec 00 Non-goals. It does
  not claim to prove prose truth and does not weaken the existing lifecycle or link validation.
  It does not demand hostile-local defenses.
- **Non-expansion:** pass. Round 0 has no prior findings to freeze. The plan adds no
  competing sections; the revision log is compact.
- **Verified against the tree:** the plan's factual claims hold.
  - The handoff is 111 lines, under the 150 cap, and holds old landing summaries.
  - The roadmap line 34 still shows `[ ] docs-state-validator`, though the handoff and the
    landing commit record it as landed.
  - `validateDocsState()`, `readText`, `ruleReport` and `headingTexts` exist in
    `scripts/validate-repository.mjs`.
  - `handoff.md` has exactly the two headings Step 1 names.
  - `.docs/status/archive/handoff-history.md` already exists, so "append" is valid.
  - `progress.md` has no `## Action history`, so Step 2 adds it.
  - The README currently says "M6 in progress".

### [MINOR] Roadmap historical narrative is vague (Step 2)

"Move historical narrative to progress where needed" does not say whether the roadmap's long
M0–M4 sections (roadmap lines 59–179) must move. The improvement plan says the roadmap holds
"milestones and future work only". The mechanical contract does not depend on this, so a
conservative reading passes. Say explicitly either "leave lines 59–179" or "move them", because
moving them is a large churn item.

### [MINOR] Scope of the in-progress rule is unbounded (Steps 3–4)

The "exactly one unchecked `(in progress)` milestone" rule is scoped to "the program list". The
plan does not say how the validator bounds that list. The natural reading is from
`## Repository improvement program (2026)` to the next heading. The older `## M0 — Design`
through `## M4` sections also contain checkbox lists. State the bound so the implementation and
the fixtures agree.

### [MINOR] Verification lacks concrete commands and a mechanical archive check

Verification names the full gate but not a copy-pasteable fast command (for example
`TMPDIR=/private/tmp bats --filter 'docs state' scripts/tests/repository-validation.bats`).
"The pinned Node setup used by the repository" is vague. "Confirm the archive retains moved
text" and "stays within 250 net changed lines" have no stated method. Per the rubric's
mechanical-invariants check, name them, for example `rg -F` over removed lines and
`git diff --shortstat`.

### [MINOR] Size budget is tight and the metric is unstated

The tests in Step 5 are enumerated broadly: 150 vs 151 lines, each missing file or heading,
duplicate and malformed markers, four-way mismatch, in-progress milestone cases, and
`--metadata`/`--links` regressions. The validator adds roughly 80–100 lines. This is close to
250 even if the cases are table-driven. Say whether net change is measured across the whole
slice or only on code, and recommend table-driven cases. A split would be reasonable if the
budget is exceeded.

### Also noted, not findings

- Step 4 does not pin the `Action history` entry format as a regex (em dash vs hyphen). It
  gives the literal `- YYYY-MM-DD — <action>`, which is enough.
- The handoff's "Notes for the next agent" section is not mentioned in Step 1. It falls outside
  the two named headings, so the plan should say whether it is kept.

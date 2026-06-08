# Retire the `Code Review` status token from playbook & agent files

Status: Plan Review
Target specs: 03-artifact-lifecycle.md

## Context

Approved spec `03-artifact-lifecycle.md` establishes that **code review is a phase
(an action the code evaluator performs over an `Implemented` artifact), not a
`Status:`**. There is no `Code Review` row in spec 03's Statuses table (line 19 makes
`Implemented` the "awaiting code review" status) nor in any dispatch table; the
code evaluator dispatches off `Implemented`, setting `Landed` on PASS or
`In Progress` on FAIL. Spec 03 represents the loop's full string as
`… Implemented → (code review) → Landed → Archived` (line 65), where *code review*
is a parenthetical phase label, never a status token.

Three playbook/agent files were **not** reconciled when spec 03 landed and still
present `Code Review` as a status step in a lifecycle string (or imply a `Code
Review` status). This slice removes the obsolete `Code Review` **status token** from
those three files and aligns them with spec 03's representation. It deliberately
**preserves** every correct generic/action use of the words "code review".

In scope — exactly these three files (verified with `git grep -n "Code Review"`):

- `plugins/loom/skills/loom-playbook/SKILL.md` line 38 — slice-plan "Status flow"
  cell reads `… → Implemented → Code Review → Landed → Archived`.
- `plugins/loom/skills/loom-playbook/references/status-machine.md` lines 49–50 —
  slice-plan lifecycle string reads `… Implemented → Code Review → Landed →
  Archived`.
- `plugins/loom/agents/developer.md` line 16 — "A slice was approved at Code Review
  — run the **finalize pass**" implies a `Code Review` status as the approval point.

Explicitly **out of scope** (do not touch — these are correct authority or correct
generic/action wording):

- `.docs/spec/03-artifact-lifecycle.md` — the authority; already reconciled.
- `.docs/spec/07-command-surface.md` (line 21, "blind code review → verdict") and
  README.md (line 64, "blind code review") — generic action wording.
- `.docs/ADR/0003-...md` (line 25, "Code review and plan re-review…") — immutable
  ADR, and correct action wording regardless.
- The `Implemented` rows' meaning text "awaiting code review" in both
  `status-machine.md` (line 15) and `SKILL.md`'s upstream tables / spec 03 (line 19)
  — correct phase wording; **must not change**.
- `.docs/evaluations/`, `.docs/status/` — eval records and status logs; not
  normative playbook surface, untouched by this slice.
- `.docs/slice-plans/README.md` line 15–16 — its lifecycle string also carries the
  `Code Review` token (line-wrapped, so a line-based `git grep` misses it). This is
  the same defect class but is **outside this slice's three named targets**; see
  `## Notes` for the flag and rationale.

This is a markdown-only repo with no compiled gate (per CLAUDE.md), so verification
is review-against-spec, not a build.

## Steps

1. **`plugins/loom/skills/loom-playbook/SKILL.md` (line 38).** In the Templates
   table's Slice-plan row, change the "Status flow" cell from:

   `Draft → Plan Review → Approved → In Progress → Implemented → Code Review → Landed → Archived`

   to (removing `Code Review` as a status step, using spec 03's parenthetical phase):

   `Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived`

   Touch only that cell; leave the other rows and the table structure unchanged.

2. **`plugins/loom/skills/loom-playbook/references/status-machine.md` (lines
   49–50).** In the `## Lifecycles` list, the Slice-plan bullet currently reads
   (across the line wrap):

   `Slice-plan: \`Draft → Plan Review → Approved → In Progress → Implemented → Code Review → Landed → Archived\`, with FAIL edges back to \`Draft\` (plan) or \`In Progress\` (code). Archive happens only **after** code-eval PASS.`

   Replace the status token `Code Review` with the parenthetical phase `(code
   review)` so the string reads `… → Implemented → (code review) → Landed →
   Archived`. Keep the rest of the bullet (the FAIL-edges clause and the
   archive-after-PASS clause) verbatim.

   Confirm — and make **no change** to — the rest of this file: the `Implemented`
   row (line 15, "Gate green; awaiting code review") and the Dispatch table (lines
   23–31, which route `Implemented` → code evaluator and `Landed` → developer
   finalize) are already correct and consistent with spec 03.

3. **`plugins/loom/agents/developer.md` (line 16).** The "When to invoke" bullet
   currently reads:

   `A slice was approved at Code Review — run the **finalize pass** (below).`

   Reword so it does not imply a `Code Review` status, matching how the developer is
   actually dispatched (off `Landed` per spec 03 line 20 and the status-machine
   dispatch table line 29 "`Landed` → developer (finalize)"):

   `A slice's code-eval returned PASS (`Landed`) — run the **finalize pass** (below).`

   Touch only this bullet; the other two "When to invoke" bullets (Approved →
   implement; In Progress + FAIL → fix) are correct and unchanged.

## Verification

Review-against-spec (no compiled gate in this markdown repo):

1. **No status token remains.** After the edits,
   `git grep -n "Code Review" -- plugins/loom/skills/loom-playbook/SKILL.md plugins/loom/skills/loom-playbook/references/status-machine.md plugins/loom/agents/developer.md`
   returns **no matches** (the `Code Review` status token is gone from all three
   files).

2. **Spec-03 alignment.** Each edited lifecycle string matches spec 03's
   representation: `… Implemented → (code review) → Landed → Archived`
   (spec `03-artifact-lifecycle.md` line 65). The developer's invoke trigger names
   `Landed` (PASS) as the finalize entry point, matching spec 03 line 20 and
   status-machine dispatch line 29.

3. **No generic-wording collateral damage.** The phrase "awaiting code review" still
   appears on the `Implemented` rows; "blind code review" still appears in spec 07
   and README; ADR 0003's "Code review and plan re-review" is untouched. Confirm with
   `git grep -in "code review"` that the only diffs versus pre-slice are the three
   intended status-token edits — every remaining hit is a correct generic/action use.

4. **Scope containment.** `git diff --name-only` lists exactly the three target
   files and this slice-plan / the slice-plans README index — nothing else.

## Notes

- **Related out-of-scope occurrence flagged (planner, 2026-06-08):** the slice-plans
  index `.docs/slice-plans/README.md` (lines 15–16) carries the same `Code Review`
  status token in its lifecycle string; it is only **line-wrapped** ("Code\nReview"),
  so a line-based `git grep -n "Code Review"` does not surface it. It is the same
  defect class as the three targets but lies outside this slice's explicitly named
  three-file scope, so it is **not** changed here. Recommend a follow-up (or owner
  approval to fold it into this slice) to align that string to
  `… Implemented → (code review) → Landed → Archived` as well. Left as a note rather
  than silently fixed to keep this slice single-purpose and to respect the stated
  scope boundary.

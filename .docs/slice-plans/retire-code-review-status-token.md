# Retire the `Code Review` status token from playbook & agent files

Status: In Progress
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

Four playbook/agent/index files were **not** reconciled when spec 03 landed and
still present `Code Review` as a status step in a lifecycle string (or imply a `Code
Review` status). This slice removes the obsolete `Code Review` **status token** from
those four files and aligns them with spec 03's representation. It deliberately
**preserves** every correct generic/action use of the words "code review".

In scope — exactly these four files:

- `plugins/loom/skills/loom-playbook/SKILL.md` line 38 — slice-plan "Status flow"
  cell reads `… → Implemented → Code Review → Landed → Archived`.
- `plugins/loom/skills/loom-playbook/references/status-machine.md` lines 49–50 —
  slice-plan lifecycle string reads `… Implemented → Code Review → Landed →
  Archived`.
- `plugins/loom/agents/developer.md` line 16 — "A slice was approved at Code Review
  — run the **finalize pass**" implies a `Code Review` status as the approval point.
- `.docs/slice-plans/README.md` lines 15–16 — the index's own `Lifecycle:` string
  reads `Draft → Plan Review → Approved → In Progress → Implemented → Code
  Review → Landed → Archived`, where the `Code Review` token is **line-wrapped**
  ("Code\nReview"), so a line-based `git grep -n "Code Review"` misses it. Same
  defect class as the first three; folded in here as the same single purpose.

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
- `.docs/slice-plans/README.md` line 22 — the **prose description of this slice**
  names the `Code Review` status token in backticks to say what is being removed;
  that is a correct reference to the token's name, not a lifecycle string, and
  **must not change**. (Only the `Lifecycle:` string at lines 15–16 is edited.)

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

4. **`.docs/slice-plans/README.md` (lines 15–16).** The `Lifecycle:` line currently
   reads (across the line wrap):

   `Lifecycle: \`Draft → Plan Review → Approved → In Progress → Implemented → Code\nReview → Landed → Archived\` (see ...)`

   i.e. the `Code Review` status token is split by the line wrap as `Code\nReview`.
   Replace that status token with spec 03's parenthetical phase so the string reads
   `… → Implemented → (code review) → Landed → Archived`. Concretely, change line 15
   from `… → Implemented → Code` and line 16's leading `Review → Landed → Archived\``
   so the joined string is:

   `Lifecycle: \`Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived\` (see ...)`

   Keep the trailing `(see [../spec/03-artifact-lifecycle.md](...))` reference and
   the surrounding prose verbatim. Re-wrapping the bullet to fit is fine; the only
   semantic change is `Code Review` → `(code review)`. **Do not** touch line 22 (the
   Active-plans description of this slice), which correctly names the token.

## Verification

Review-against-spec (no compiled gate in this markdown repo):

1. **No status token remains in the lifecycle strings.** After the edits, run a
   wrap-aware search across all four files (a plain line-based `git grep "Code
   Review"` would miss the README's line-wrapped token, so match across newlines):

   ```
   grep -rIzoP "Code\s+Review" \
     plugins/loom/skills/loom-playbook/SKILL.md \
     plugins/loom/skills/loom-playbook/references/status-machine.md \
     plugins/loom/agents/developer.md \
     .docs/slice-plans/README.md
   ```

   The only remaining hit is the README line-22 prose that *names* the token in
   backticks (intentionally retained). Equivalently, `tr '\n' ' '` each file and
   `grep -o "Code *Review"`: every lifecycle string is now clear; only the README
   slice-description reference remains. No lifecycle string in any of the four files
   contains a `Code Review` status step.

2. **Spec-03 alignment.** Each edited lifecycle string (SKILL.md, status-machine.md,
   and the slice-plans README index) matches spec 03's representation:
   `… Implemented → (code review) → Landed → Archived` (spec
   `03-artifact-lifecycle.md` line 65). The developer's invoke trigger names
   `Landed` (PASS) as the finalize entry point, matching spec 03 line 20 and
   status-machine dispatch line 29.

3. **No generic-wording collateral damage.** The phrase "awaiting code review" still
   appears on the `Implemented` rows; "blind code review" still appears in spec 07
   and README; ADR 0003's "Code review and plan re-review" is untouched; the README's
   line-22 description of this slice still names the `Code Review` token in backticks.
   Confirm with `git grep -in "code review"` that the only diffs versus pre-slice are
   the four intended status-token edits — every remaining hit is a correct
   generic/action use or the intentional token reference.

4. **Scope containment.** `git diff --name-only` lists exactly the four target files
   (SKILL.md, status-machine.md, developer.md, slice-plans/README.md) plus this
   slice-plan — nothing else.

## Notes

- **Fourth occurrence folded in (planner, 2026-06-08):** the slice-plans index
  `.docs/slice-plans/README.md` (lines 15–16) carried the same `Code Review` status
  token in its `Lifecycle:` string, only **line-wrapped** ("Code\nReview"), so a
  line-based `git grep -n "Code Review"` did not surface it. It was originally flagged
  here as a related out-of-scope occurrence; on owner direction it is folded into
  this slice as Step 4 because it is the same single purpose (retire the `Code
  Review` status token), and its line-wrap is precisely why a per-file grep can hide
  it — so the Verification step now uses a wrap-aware (`-z`/`tr`/`Code\s+Review`)
  search across all four files. The README's line-22 prose that *names* the token in
  backticks (describing what this slice removes) is intentionally retained.

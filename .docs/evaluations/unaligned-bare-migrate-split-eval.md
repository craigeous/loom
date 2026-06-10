# Evaluation: unaligned-bare-migrate-split

Verdict: FAIL
Round: 1
Reviewed against: spec 06-init-modes.md §2a/§2b (target spec); ADR
0009-unaligned-migrate-sub-mode §3 (owner gate) / §4 (status preservation) / §6
(inline, no role-spawn); references/unaligned.md (current body),
references/migration-recipe.md + references/init-detection.md (landed siblings);
SKILL.md References list; spec 03-artifact-lifecycle §finalize-pass + spec
08-playbook §"CLAUDE.md auto-propagation"; the landed/archived sibling slice 2
(migration-recipe-reference-plan) + its eval; plan-eval-rubric.md + severity.md.

## Findings

- [MAJOR] Step 5 / "Out of scope" (plan lines 49–61) + Verification scope guard
  (lines 273–298): the plan **defers the `SKILL.md` `unaligned.md` description-line
  update to the developer's finalize pass**, conflating it with the (correctly
  deferred) `CLAUDE.md` curated-digest update, and the verification scope guard
  *requires* `SKILL.md` to NOT appear in the implement commit. The cited authority
  does not support that deferral. Spec 03 finalize-pass step 2 and the spec 08
  "*CLAUDE.md auto-propagation (the curated digest)*" section are about **`CLAUDE.md`
  specifically** — the derived, non-spec *curated digest*. Neither names `SKILL.md`.
  `SKILL.md` is a **playbook component** shipped inside the plugin (spec 08 layout:
  `loom/skills/loom-playbook/SKILL.md`), not the curated digest, so the
  finalize-pass curated-digest carve-out does not cover it. The direct sibling in
  this same thread — slice 2 (`migration-recipe.md`, landed `a34d726`/`da21d2c`/
  `fdbbb60`, eval PASS) — **edited `SKILL.md`'s References list at the implement
  step**: `SKILL.md` was an explicitly *allowed* path in that plan's scope guard,
  and its eval treated `SKILL.md` as in-scope while flagging only the `CLAUDE.md`
  edit as wrong-step. By that accepted precedent, bringing `SKILL.md`'s
  `unaligned.md` description into consistency with the restructured body is an
  implement-step playbook edit, not a finalize-pass digest edit. Current SKILL.md
  line 53 reads "*alignment pass: reuse Greenfield scaffold + gate, then descriptive
  `spec/` back-fill*" — after this slice that is stale (no migrate sub-mode, no owner
  gate). The plan should include the `SKILL.md` `unaligned.md` line update in THIS
  slice's implement (and add `SKILL.md` to the allowed paths in the scope guard,
  while keeping `CLAUDE.md` excluded). (Not a BLOCKER: the pointer `unaligned.md`
  still resolves and nothing dispatches off the SKILL.md prose, so the shipped body
  does not behave incorrectly — but the deferral rationale is wrong on the authority
  and contradicts the sibling slice's accepted precedent, leaving a knowingly stale
  playbook component on a bad justification.)

- [MINOR] Verification check 7 self-match guard uses `rg -n '\.\.docs/'` to assert
  the `..docs/` artifact is not discussed in `unaligned.md`. That literal also
  appears in the *recipe's* idempotency narrative, which is fine to exclude — but the
  plan's step 5.3 narrative ("no NUL-delimited list … no lookbehind") could
  inadvertently tempt the author to name `..docs/` while explaining what is NOT
  restated. The guard correctly catches it; no change required, just confirm by
  review that the migrate flow points at `migration-recipe.md`'s idempotence rather
  than describing the `..docs/` hazard.

- [MINOR] Step 8/9 and the README: the README Active entry already exists (the
  planning commit appears to have landed it). The plan text still describes step 8
  as work to do ("replace `(none)`"); harmless, but on re-review confirm the README
  entry matches the final scope (it currently does, including the `SKILL.md`
  exclusion claim which this eval disputes — that line will need a touch-up if the
  MAJOR is addressed by moving the SKILL.md update into implement).

## Required changes (for FAIL)

1. Move the `SKILL.md` `unaligned.md` References-line update into **this slice's
   implement step** (a one-line description refresh so it names both sub-modes /
   the migrate flow), and add `plugins/loom/skills/loom-playbook/SKILL.md` to the
   allowed-paths list in the Verification scope guard. Keep `CLAUDE.md` excluded
   (its curated-digest update is correctly the finalize pass — and a prior slice
   FAILed for editing `CLAUDE.md` at implement). Correct the "Out of scope" prose
   and the "Process note for the developer" so they no longer cite spec 03/08
   finalize as authority for deferring `SKILL.md`; that authority governs
   `CLAUDE.md` only. Align the README Active entry's "no … SKILL.md edits at
   implement" claim accordingly.

## Notes

Everything else in the plan is sound and I would PASS it on those points:

- **Executable & faithful.** The plan faithfully restructures `unaligned.md` to
  present both flows. Bare = the existing Steps 1–5 wrapped under an Unaligned-bare
  heading, with the no-decisions boundary and the Draft→Plan-Review→Approved
  lifecycle preserved and explicitly scoped bare-only (step 3) — matches spec 06
  §2a. Migrate (step 5) carries the owner gate with all three options and their
  named consequences (migrate→Initialized; thin-pointer→re-detect Unaligned;
  abort→re-detect Unaligned), pointing at spec 06 §2b / ADR 0009 §3 — matches the
  spec's and ADR's option semantics verbatim. Status preservation points at §2b/§4
  (step 5.4); inline / no-role-spawn points at §6 (step 5.5); thin-pointer/abort
  consequences (step 5.6). Authority line updated to §2a/§2b (step 1). Identity
  pre-flight made shared across both flows (step 4) — correct, since both flows
  commit.

- **Single-source discipline is strong.** The recipe is explicitly NOT restated
  (step 5.3 forbids restating any recipe step), and the verification includes
  *negative* `rg` guards that recipe mechanics are not duplicated into
  `unaligned.md`: check 7 asserts `print0|xargs -0`, `lookbehind|(?<!`,
  `git mv|git stash|git status --porcelain`, and `\.\.docs/` each return **no
  matches**. The gate option semantics and the status policy point AT spec 06 §2b /
  ADR 0009 §3–§4 rather than being re-derived. This is exactly the discipline the
  authority requires (spec 06 §2b defers the recipe text to the playbook reference;
  the reference already exists from slice 2).

- **Verification is mechanical & repo-correct.** Correctly states there is no
  compiled gate (markdown) and uses review-against-spec plus concrete `rg` checks
  for both presence (authority line, both flows, three gate options, status pointer,
  inline/no-spawn, links to the two landed siblings, bare-only Draft rule, shared
  identity pre-flight) and the single-source negative guard, plus a load-bearing
  scope guard via `git diff --name-only`.

- **Hygiene.** Standard plan template, `Status: Plan Review`, target spec
  06-init-modes.md, README Active entry present.

The sole reason for FAIL is the SKILL.md-deferral misclassification (the MAJOR).
The fix is small and local: move one description line into the implement scope and
correct the authority citation. No author identity is referenced — this verdict is
blind.

---

# Re-review (resolving review of round 1)

Verdict: PASS
Round: 1
Reviewed against: the Round-1 MAJOR above; the plan revision (`d393ffe`) and the
slice-plans README index fix (`c93e51e`); spec 03-artifact-lifecycle §finalize-pass
+ spec 08-playbook §"CLAUDE.md auto-propagation" (the carve-out the MAJOR turned
on); the landed sibling slice 2 precedent (SKILL.md edited at implement); current
`SKILL.md` line 53 (still the stale single-flow entry, confirming the work is real).

## Findings

- The Round-1 [MAJOR] is **resolved**. The plan no longer defers the `SKILL.md`
  `unaligned.md` description to the finalize pass. All five required points land:
  1. New **step 8** (plan lines 212–228) refreshes the `SKILL.md` `unaligned.md`
     References line to name **both** sub-modes (Unaligned-bare back-fill +
     Unaligned-migrate reconcile-via-recipe) and states explicitly it is "part of
     the **implement** commit (alongside `unaligned.md`), NOT the finalize pass."
  2. `plugins/loom/skills/loom-playbook/SKILL.md` is now in the implement
     allowed-paths (line 306) and **removed** from the EXCLUDED list; `CLAUDE.md`
     remains excluded (line 319) and finalize-only — the part that had to stay
     correct is intact. (A prior slice FAILed for an implement-step `CLAUDE.md`
     edit; that boundary is preserved.)
  3. The authority citation is corrected in both Out-of-scope (lines 54–67) and the
     process note (lines 337–343): the spec 03/08 finalize carve-out now governs
     "the **curated digest (`CLAUDE.md`) only** — it does NOT cover `SKILL.md`,"
     matching the authority (neither spec names SKILL.md) and the sibling precedent.
  4. The Verification scope guard allows `unaligned.md` + `SKILL.md` (+ plan +
     README), still hard-fails on `.docs/spec/`, `.docs/ADR/`, `CLAUDE.md`,
     `migration-recipe.md`, `init-detection.md` (lines 313–325), and adds an `rg`
     check (lines 327–333) asserting the `SKILL.md` `unaligned.md` entry now names
     the migrate/reconcile sub-mode and was not collapsed to back-fill-only.
  5. The slice-plans README index entry (`c93e51e`) is consistent: "Implement
     touches `unaligned.md` + `SKILL.md` … no … CLAUDE.md edits at implement
     (CLAUDE.md curated-digest update is finalize-only)." The disputed
     "no … SKILL.md edits" claim is gone.

- **No regression.** The bare/migrate split steps the Round-1 review approved
  (steps 1–7) are unchanged; single-source discipline is intact — the recipe is
  still not restated (step 5.3 + the negative `rg` guards in check 7), and the
  gate-option/status policy is still pointed AT (spec 06 §2b / ADR 0009 §3–§4)
  rather than re-derived. Step renumbering (former 8/9 → 9/10) is purely
  consequential to inserting the new step 8.

- The two Round-1 [MINOR]s were advisory (no change required) and remain
  non-blocking; nothing in the revision disturbs them.

## Required changes (for FAIL)

None — PASS.

## Notes

Round counting (spec 03): the Round-1 FAIL opened round 1; this is the resolving
review of that same cycle, so it records as **Round 1** (a PASS that resolves a
prior FAIL repeats that FAIL's round number; it does not advance to round 2). No
author identity is referenced — this verdict is blind.

---

# Code review (first code review of the implementation)

Verdict: PASS
Round: 1
Reviewed against: the implement commit `61bc6e9` (diff of
`references/unaligned.md` + `SKILL.md`); the slice-plan
(`unaligned-bare-migrate-split-plan.md`, the body and its mechanical checks); spec
06-init-modes.md §2a/§2b; ADR 0009 §3 (owner gate) / §4 (status preservation) / §6
(inline, no role-spawn); the landed siblings `migration-recipe.md` +
`init-detection.md` (pointed at, not edited); code-eval-rubric.md + severity.md.
Mechanical checks re-run from repo root (`rg`/`git show`), not trusted from the
plan's evidence block.

## No compiled gate

loom's own repo is markdown — acceptance is review-against-spec; no fmt/lint/test
gate exists to re-run and none was invented.

## Findings

All plan steps and authority requirements are satisfied; no BLOCKER, MAJOR, or
MINOR findings.

- **Both flows present and correctly scoped.** The intro/authority block reframes
  to §2a/§2b (line 6) and keeps the "spec wins on conflict" + precondition +
  "alignment/migration pass, not a config interview" framing. A `## Two sub-modes`
  section (lines 19–34) names both flows with one-sentence semantics + a §2a/§2b
  pointer, and routes off `init-detection.md`'s sub-classification without
  restating its heuristics. The existing Steps 1–5 are wrapped under
  `## Unaligned-bare flow — no pre-existing docs spine` (line 38) with a scope line;
  internal `§2` citations are updated to `§2a` (lines 112, 142, 173, 185). The
  no-decisions boundary (lines 124–135) is preserved unchanged.

- **Bare-only Draft→review rule preserved and scoped.** Lines 139–150 keep the
  `Draft → Plan Review → Approved` lifecycle, cite spec 03, and add an explicit
  "This `Draft → review` rule is **Unaligned-bare only** … does **not** apply to
  Unaligned-migrate" (lines 148–150) — matching spec 06 §2a/§2b and ADR 0009 §4.
  The migrate flow correctly claims no Draft→review pass.

- **Owner gate faithful to ADR §3 / spec §2b.** Lines 209–222 present an explicit,
  required owner decision before any files move (not the generic "ambiguity → ask"
  fall-through), with all three options and their consequences named verbatim to
  the ADR: migrate → Initialized; thin-pointer → re-detect Unaligned; abort →
  re-detected Unaligned on every run. The canonical semantics are pointed AT (spec
  06 §2b / ADR 0009 §3), not re-derived.

- **Status preservation, inline/no-role-spawn.** Lines 235–240 state migrated specs
  retain prior status / migration is not a re-review trigger, pointing at §2b / ADR
  §4 — no policy re-derivation. Lines 242–266 state the inline `/loom:init` sequence
  (detection → owner gate → recipe on migrate → seed/reconcile `status/` → hand back
  Initialized) and that a pure migration authors no specs so there is no
  planner/evaluator role-spawn (ADR 0009 §6 cited). Both match the ADR's division.

- **Single-source discipline (scrutinized).** All four negative guards re-run on
  `unaligned.md` return **no matches**: `print0|xargs -0`, `lookbehind|\(\?<!`,
  `git mv|git stash|git status --porcelain`, `\.\.docs/`. The recipe mechanics are
  named only as a pointer list (lines 227–233) routed to `migration-recipe.md`; the
  idempotence note (lines 278–280) points at the recipe's no-op guarantee rather
  than restating it.

- **Identity pre-flight shared, stated once.** Exactly one authoritative statement
  (lines 30–34, in `## Two sub-modes`); the bare flow (line 77) and the migrate flow
  (lines 257–258) both reference it rather than duplicating the prose. The
  `commit-convention.md` rationale pointer is kept.

- **SKILL.md.** The `unaligned.md` References entry (line 53) now names both
  sub-modes — Unaligned-bare (back-fill via Greenfield scaffold + gate) and
  Unaligned-migrate (owner gate + inline `migration-recipe.md` recipe) — and was not
  collapsed to a back-fill-only line. No other References entry is touched.

- **Scope/hygiene.** `git show --name-only 61bc6e9` shows only the slice-plan,
  `SKILL.md`, and `unaligned.md`. The forbidden-path filter (`.docs/spec`,
  `.docs/ADR`, `migration-recipe.md`, `init-detection.md`, `CLAUDE.md`) returns
  empty — no out-of-scope edits, and notably no implement-step `CLAUDE.md` edit
  (the boundary a prior slice FAILed for is preserved; the stale curated-digest line
  is correctly left to the developer's finalize pass). Commit author identity is
  `Craig Pfeiffer <craigeous@gmail.com>` — author-neutral configured identity, not
  `loom@localhost`.

- **Links resolve.** `init-detection.md`, `commit-convention.md`,
  `migration-recipe.md`, `greenfield.md`, and the five-levels-up spec links
  (`06-init-modes.md`, `03-artifact-lifecycle.md`) all resolve from the
  `references/` directory.

## Required changes (for FAIL)

None — PASS.

## Notes

Round counting (spec 03, FAIL-only): the prior FAIL was a *plan-eval* FAIL (round 1,
resolved by the round-1 re-review above). This is the first *code* review of the
implementation and it PASSes, so it is the resolving review and stays at the
artifact's current round — **Round 1**. It does not open a new round (a new round is
opened only by a FAIL). No author identity is referenced — this verdict is blind.

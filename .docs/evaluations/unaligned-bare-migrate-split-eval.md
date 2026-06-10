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

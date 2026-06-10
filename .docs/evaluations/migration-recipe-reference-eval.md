# Evaluation: migration-recipe-reference

Verdict: PASS
Round: 0
Reviewed against: ADR 0009 §5 (load-bearing properties) + §7 (operational
preconditions); spec 06-init-modes.md §2b (target spec; "the recipe text is a
playbook reference… not spec text"); field report 2026-06-09-unaligned-init-
migration-field-report.md (§4, §5, Operational failures); gate-learning.md
(structural model) + SKILL.md (References list); plan-eval-rubric.md + severity.md.

## Findings

- [MINOR] Verification check F (`rg -nF -- '](X.md)'`) demands the literal
  `](X.md)` example string, while the plan's preamble says "Wording may be the
  author's." The example is itself load-bearing (it is ADR 0009 §5's own notation
  for the bare-markdown-link form), so the demand is defensible, but it sits in
  mild tension with the flexible-wording note. Consider phrasing the check around
  the *concept* (bare markdown link target) rather than the exact glyphs, or note
  that this literal is intentionally required. Does not block.

## Required changes (for FAIL)

None.

## Notes

The plan is executable and file-scoped. Each load-bearing property required by
the authority is mapped to a concrete recipe section with a `rg` verification:

- ADR 0009 §7 dirty-tree check → Step A.1 (with `git status --porcelain` /
  stash sketch) → check B.
- ADR 0009 §7 untracked `git mv`-skip → Step A.2 (`git ls-files --others`,
  `mv` + `git add` separately) → check B.
- ADR 0009 §7 NUL-delimited lists → Step A.3 (`-print0 | xargs -0`, `$(find …)`
  named as the anti-pattern) → check B.
- ADR 0009 §5 numbered-spine → `spec/` + `status/` split with two-directional
  rewrite → Step B (08/09/10 → status/, rest → spec/; numbering gaps accepted;
  same-dir → `../status/`, outbound → `../spec/`) → check C.
- ADR 0009 §5 ordered specific-before-generic → Step C → check D.
- ADR 0009 §5 idempotency / self-match `(?<!\.)` → Step D (`..docs/` artifact
  named; re-run no-op stated) → check E.
- ADR 0009 §5 three reference forms separately → Step E → check F.
- ADR 0009 §5 living-rewritten vs archived-snapshot boundary → Step F (archive
  excluded from rewrite passes) → check G.
- ADR 0009 §4 / spec 06 §2b status-preservation → Step G as a *pointer*, not a
  restatement → check H.
- Final link validation → Step H (concrete `rg` for un-rewritten `docs/` and
  `..docs/` artifacts) → check I.

Faithfulness / no over-reach confirmed: the recipe is positioned as the
mechanical "how" of the migrate path and explicitly declines to restate the owner
gate (ADR 0009 §3), the status-preservation *policy* (§4), and the
init-inline-vs-spawn division (§6), keeping those single-sourced in the frozen
spec / Accepted ADR. This matches spec 06 §2b's deferral of the recipe text to
the playbook.

Scope/hygiene confirmed: the out-of-scope list forbids edits to `.docs/spec/`,
`.docs/ADR/`, `references/unaligned.md`, and `references/init-detection.md`, with
a hard-fail scope guard (check L). The plan delivers only the new reference +
`SKILL.md` (+ plan + README), uses the standard template, carries
`Status: Plan Review`, targets spec 06, and the README Active entry is present
and accurate.

Mechanical checks verified against the real tree: the relative-link form
`../../../../../.docs/...` resolves correctly from
`plugins/loom/skills/loom-playbook/references/` to repo root (confirmed); the
sibling structural model `gate-learning.md` uses that exact form; the slice-1
landing (`c96fd90`) and its archived plan both exist as the Context claims; the
SKILL.md References list style (backtick-name + dash-description, no link) matches
the suggested entry. No compiled gate is correctly declared (markdown repo);
acceptance is review against authority plus the per-property `rg` checks.

---

# Code Review (slice implemented at `a34d726`)

Verdict: FAIL
Round: 1
Reviewed against: commit `a34d726` diff; slice-plan
`migration-recipe-reference-plan.md` (Steps A–H + scope statement); ADR 0009 §5
(load-bearing properties) / §7 (operational preconditions); spec 06-init-modes.md
§2b; spec 03-artifact-lifecycle.md (finalize pass step 2) + spec 08-playbook.md
(`CLAUDE.md` auto-propagation boundary); code-eval-rubric.md + severity.md. No
compiled gate (markdown repo); acceptance = review-against-spec.

## Findings

- [BLOCKER] Out-of-scope edit to root `CLAUDE.md`. The plan authorizes exactly
  four files (the new `migration-recipe.md`, `SKILL.md`, the plan file, and
  `slice-plans/README.md`); `CLAUDE.md` is not among them, and the plan's
  out-of-scope section does not name it. Independently, **spec 03 finalize-pass
  step 2** and **spec 08 (`CLAUDE.md` auto-propagation — "Who and when")** both
  reserve curated-digest maintenance for the **developer's finalize pass**, which
  runs *after* code-eval PASS (status `Landed`) — **not** in the implement commit
  at `Implemented`. Editing `CLAUDE.md` here pre-empts a later, different
  role-pass step and adds a file the plan did not sanction. Per severity.md an
  out-of-scope change is a BLOCKER ("A correctness, spec-fidelity, or scope
  violation is a BLOCKER, not a MAJOR"), regardless of the digest content being
  correct. The CLAUDE.md block added (commit lines under the parallelism bullet)
  is accurate and is the very edit the finalize pass would make — so the fix is
  process, not content: remove it from the implement commit; it lands at finalize.

## Confirmed correct (not blocking)

- **Recipe completeness — PASS.** Every ADR 0009 §5/§7 property and plan Steps
  A–H are present and faithful (mechanically re-verified with `rg`, not
  eyeballed):
  - §7 preconditions: dirty-tree check with `git status --porcelain`/stash
    (Step A.1); untracked-skip handling via `git ls-files --others
    --exclude-standard` + separate `mv`+`git add` (A.2); NUL-delimited lists
    `find … -print0 | xargs -0` with `$(find …)` named as the anti-pattern (A.3).
  - §5 spine split: living docs → `.docs/status/`, rest → `.docs/spec/`; numbering
    gaps accepted (B.1–B.2); two-directional rewrite — sibling refs →
    `../status/`, outbound refs → `../spec/` (B.3); both `../status/` and
    `../spec/` targets present.
  - §5 ordered rules: specific-before-generic stated as a hard, load-bearing
    requirement (Step C).
  - §5 idempotency: self-match hazard named, `..docs/` artifact named, literal
    negative lookbehind `(?<!\.)` shown, re-run-is-a-no-op stated (Step D).
  - §5 three reference forms handled separately, incl. the `](X.md)` bare-target
    example and "relative to the file's new location" (Step E).
  - §5 living-vs-archived boundary: archive left as historical snapshot, excluded
    from the NUL-delimited rewrite list (Step F).
  - §5/§4 status preservation as a **pointer** to spec 06 §2b / ADR 0009 §4, not
    re-derived (Step G).
  - Final link validation with concrete `rg` checks as the last step (Step H).
- **No over-reach in the recipe — PASS.** It is the mechanical "how" and points
  to spec 06 §2b / ADR 0009 for the owner gate, status policy, and inline-vs-spawn
  division rather than restating them.
- **SKILL.md — PASS.** New `migration-recipe.md` entry added to the References
  list in the existing backtick-name + dash-description style, grouped with the
  other init/Unaligned references.
- **Scope guard (the BLOCKER set) — PASS.** No edits to `.docs/spec/`,
  `.docs/ADR/`, `references/unaligned.md`, or `references/init-detection.md`.
- **Hygiene — PASS.** Commit author is `Craig Pfeiffer <craigeous@gmail.com>`
  (the configured identity), not `loom@localhost`.

## Required changes (for PASS)

1. Remove the `CLAUDE.md` edit from the implement commit. The recipe + SKILL.md
   entry are correct and stay. The `CLAUDE.md` curated-digest reflection is made
   by the developer's finalize pass after code-eval PASS (spec 03 step 2 / spec
   08), not in the `Implemented` commit. (No content change needed — only move it
   out of this slice's implement commit.)

---

# Code Review — Re-review (round 1 resolving review)

Verdict: PASS
Round: 1
Reviewed against: fix commits `da21d2c` (revert CLAUDE.md) + `3d690e9` (status);
net slice `git diff 448898e..HEAD`; the round-1 FAIL above; slice-plan
`migration-recipe-reference-plan.md`; ADR 0009 §5/§7; spec 06-init-modes.md §2b;
spec 03-artifact-lifecycle.md (finalize-pass step 2) + spec 08-playbook.md
(`CLAUDE.md` auto-propagation boundary); code-eval-rubric.md + severity.md. No
compiled gate (markdown repo); acceptance = review-against-spec.

**Round assignment:** This is the resolving review of the round-1 FAIL. Per spec
03 `## Round limits`, a PASS resolving a FAIL shares that FAIL's round number — so
this is recorded as **Round 1**, not a new round.

## BLOCKER resolution — CONFIRMED

The round-1 BLOCKER (out-of-scope edit to root `CLAUDE.md`) is fully resolved:

- `git diff 448898e HEAD -- CLAUDE.md` is **empty**; `CLAUDE.md` is **absent**
  from `git diff --name-only 448898e HEAD`; `rg -n "Migration recipe" CLAUDE.md`
  returns nothing. Commit `da21d2c` restored `CLAUDE.md` to its pre-slice
  baseline. The curated-digest update will be re-made by the finalize pass after
  this PASS, per spec 03/08 — the correct step.

## Findings

- None. (The round-1 [MINOR] on verification-check F wording was a plan-eval
  note, not a defect in the artifact, and does not block.)

## Confirmed correct (re-verified on the net slice)

- **Scope now clean.** The net slice (`448898e..HEAD`) touches exactly:
  `references/migration-recipe.md`, `SKILL.md`, the plan file, and this eval
  file. No `.docs/spec/`, `.docs/ADR/`, `references/unaligned.md`, or
  `references/init-detection.md` edits (scope guard: `OK: scope clean`).
- **Recipe intact and unchanged.** `git diff a34d726 HEAD --
  migration-recipe.md SKILL.md` is empty — the fix touched only `CLAUDE.md` (and
  the plan), leaving the round-1-confirmed content untouched. All ADR 0009 §5/§7
  properties (Steps A–H: dirty-tree/stash, untracked `git mv`-skip via
  `git ls-files --others`, NUL-delimited `-print0 | xargs -0` with `$(find …)`
  named anti-pattern; spine→`spec/`+`status/` split with two-directional rewrite
  and accepted numbering gaps; specific-before-generic ordering; `(?<!\.)`
  self-match guard and `..docs/` artifact; three reference forms; living-vs-
  archived boundary; status-preservation pointer; final link validation) remain
  present and faithful.
- **SKILL.md** References entry present (line 54), unchanged.
- **Author identity.** Both fix commits are `Craig Pfeiffer
  <craigeous@gmail.com>` (configured identity), not `loom@localhost`.

## Required changes (for FAIL)

None.

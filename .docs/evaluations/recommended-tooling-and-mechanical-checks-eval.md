# Evaluation: recommended-tooling-and-mechanical-checks

Verdict: PASS
Round: 1
Reviewed against: spec 08-playbook.md; the existing references/ (SKILL.md, plan-eval-rubric.md, code-eval-rubric.md, severity.md, gates/), and the three agent files (developer.md, plan-evaluator.md, code-evaluator.md); spec 10-packaging.md for the motivating defect claim.

## Findings

- [MINOR] Step 7 (the `.docs/slice-plans/README.md` "Active plans" entry) is
  already present in the tree and was committed together with the plan
  (`9e567ab`), rather than being a remaining implementation step. The step's
  prescribed text matches what is already on disk, so this is a bookkeeping
  wrinkle, not a content defect — the developer should treat step 7 as
  already-satisfied and the code-evaluator should not flag the pre-existing
  README line as out-of-scope drive-by.
- [MINOR] The code-eval-rubric bullet (step 4) leads with code-symbol/"did this
  diff break callers?" framing. loom's own markdown repo has no symbols/callers,
  so for self-review only the `rg -U` clause applies. This is acceptable because
  the rubric governs managed CODE projects too, and the bullet keeps the `rg -U`
  text clause for the markdown case — but a reader could momentarily read it as
  code-only. The step-1 managed-code-vs-markdown distinction in `tooling.md`
  mitigates this; no change required.
- [MINOR] Verification check 1's `rg` regex enumerates a fixed tool list
  (`ast-grep|yq|difft|shellcheck|comby|scc`); if the author adds another tool to
  `tooling.md` in a "must install" phrasing it would not be caught. The check is
  a backstop to a manual read (check 2), so this is a hygiene note only.

## Required changes (for FAIL)

None — no BLOCKER or MAJOR findings. The plan PASSes.

## Notes

Assessed against each judgment axis:

1. **Executable / file-line-scoped / single-purpose.** Yes. Seven numbered steps,
   each naming the exact file and the exact insertion point with a verified line
   anchor (SKILL.md L52; plan-eval-rubric L39–41; code-eval-rubric L28–30;
   developer.md L23–24; plan-evaluator.md L37 + L43–45; code-evaluator.md
   L27–29; README L20). All anchors were checked against the real tree and are
   correct. The single-purpose justification in `## Notes` is sound: one goal
   (adopt the toolkit + mechanical-check discipline), every edit a small additive
   pointer off the one new reference. Correctly kept as one slice rather than
   over-split.

2. **Every tool RECOMMENDED/optional with graceful fallback.** Yes, and enforced
   redundantly: the step-1 policy header states verbatim "RECOMMENDED, not
   required … A missing tool is never a blocker"; the task table gives every row a
   fallback column; each role entry names a fallback; the closing instruction
   requires "prefer X; fall back to Y" form; and verification check 1 greps to
   prove no "must install / hard-require" phrasing survives. No step reads as
   mandatory. The "same rule as gates" framing matches spec 08 (Rust is the only
   *verified* gate; others learned, none hard-required).

3. **Per-role guidance concrete and accurate to the real agents.** Verified
   against the actual files. Developer guidance attaches to developer.md step 3's
   real sentence "Verify signatures/types against the tree — don't code from
   memory" and makes it deterministic via ast-grep/LSP — accurate. Code-evaluator
   guidance ("did this diff break callers?" via find-references; `difft` over the
   commit diff) matches code-evaluator.md step 1's diff-reading workflow and the
   code-eval-rubric "No silent regressions" concern. Plan-evaluator/planner
   "verify the invariant against the real tree, not by read" matches the existing
   "verified sketches / verify references" discipline. Researcher guidance is
   appropriately light (confirm a cited string exists, un-wrapped).

4. **Mechanical-check rule in BOTH rubrics, citing tooling.md, actionable.** Yes.
   Step 3 adds the bullet to plan-eval-rubric under `## Slice-plans` after
   `Verification named`; step 4 adds it to code-eval-rubric under `## Correctness`
   after `Tests prove behavior`. Both cite `[`tooling.md`](tooling.md)` (resolves:
   both rubrics live in `references/`, target is the new same-dir file). Both
   spell out the actionable mapping: `rg -U` for text/wrapped-token invariants,
   `yq`/`jq` for config, `ast-grep`/LSP find-references for code symbols. The
   wrapped-`Code\nReview` example is concrete and real.

5. **No spec/ADR edits; referenced paths real.** Confirmed. Out-of-scope section
   explicitly freezes `.docs/spec/` and `.docs/ADR/` and declines a new ADR
   (correctly — no decision is reversed; spec 08 already authorizes evolving the
   playbook via dogfooded slices). Verification check 6 guards this with
   `git diff --stat`. Every referenced path exists: the six cross-link target
   files, `gates/rust.md` (only shipped gate, correctly noted), the spec-08 link
   (`../spec/08-playbook.md` resolves from `.docs/slice-plans/`).

6. **Managed-code-vs-loom-markdown distinction handled honestly.** Yes. The
   step-1 policy header requires the sentence: most tools help managed CODE
   projects; loom's own markdown repo benefits mainly from `rg -U`, `yq`/`jq`, and
   the discipline. The developer role entry splits "on managed CODE projects" vs
   "on loom's markdown repo" explicitly. This is the honest framing.

7. **Verification in checkable review-against-spec terms.** Yes. Six numbered
   checks, several mechanical (and explicitly dogfooding the rule the slice adds):
   new file + policy present (grep proves nothing reads as required); every tool
   has a fallback; rule in both rubrics (`rg -l 'mechanically'` lists both);
   cross-links resolve in all six files + target exists; internal consistency of
   the tool set across files; scope discipline via `git diff --stat`. Acceptance
   is fully review-against-spec, appropriate for this no-compiled-gate repo.

The motivating-defect claim in `## Context` was independently verified: spec
10-packaging.md line 107 does contain a bare `/loom` in prose, and the convention
(SKILL.md / CLAUDE.md) is the namespaced `loom:<name>` form — so the rationale for
the slice is grounded in a real miss, not a hypothetical.

All findings are MINOR; none blocks landing. Verdict: PASS.

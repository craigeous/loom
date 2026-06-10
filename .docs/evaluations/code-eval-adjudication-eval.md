# Evaluation: code-eval-adjudication-plan (Slice C)

Verdict: FAIL
Round: 1
Reviewed against: spec 02-roles.md (Code Evaluator, Approved/frozen), ADR 0010 §4,
references/review-findings.md (format authority), references/severity.md (verdict
authority), references/code-eval-rubric.md.

## Code review (round 1)

Commit reviewed: `617b828` (`HEAD` of `slice/code-eval-adjudication`), diffed against
its parent. Pure-markdown slice — no `format → lint → test` gate applies; an absent
code gate is not a red gate. Invariants checked mechanically (`rg -U`, `test -e`).

### Findings

- [MAJOR] **Broken cross-reference in the agent file** —
  `plugins/loom/agents/code-evaluator.md` step 1 (new line 30) links the ADR as
  `[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)`.
  The agent file lives at `plugins/loom/agents/`, three directories below the repo
  root, so a project-root `.docs/` target needs **three** `../` (agents → loom →
  plugins → root). The link uses **five** `../`, resolving above the repo root.
  Verified mechanically from the agent's own directory: `test -e
  ../../../../../.docs/ADR/0010-...md` → FAIL, while `test -e ../../../.docs/ADR/0010-...md`
  → OK. This same five-`../` string is correct in the rubric (which sits five levels
  deep) and was evidently copied into the agent file without re-rooting. The plan's
  task (Step 2a) directs the agent to point to ADR 0010, and Verification requires
  cross-refs to resolve; as written the reader following this pointer hits a dead
  link. A real defect introduced by the slice → MAJOR; an unaddressed MAJOR is a
  FAIL per `severity.md`.

### What passed (recorded so the fix stays narrow)

- **Scope is disjoint and correct.** `git show --stat` / `git diff --name-only
  HEAD~1..HEAD`: exactly `code-eval-rubric.md`, `code-evaluator.md`, and the
  slice-plan changed. No `orchestration.md` (Slice B), no `review-findings.md`
  (Slice A), no `SKILL.md`, no `spec/`/`ADR/`, no index, no living docs, no
  `CLAUDE.md`.
- **Rubric section present and in order.** `rg -n "^## "` →
  Gate → Fidelity → Correctness → **Review-findings adjudication** → Hygiene →
  Re-review. Exactly as the plan specifies (after Correctness, before Hygiene).
- **Single-source discipline holds.** The rubric owns the procedure; the agent step 3
  points to it by exact section name ("Review-findings adjudication") and does not
  restate the confirm/reject/map/discard body. Both files point to
  `review-findings.md` and `severity.md` rather than restating. Negative check:
  `rg "ran-with-findings|ran-clean|skipped: command-unavailable|skipped: docs-only"`
  returns **nothing** in either the rubric or the agent — the four-token table is not
  reproduced. The lone illustrative `skipped:`/`ran-clean` mention in the rubric's
  informational note is the single permitted usage.
- **Spec 02 / ADR 0010 §4 fidelity.** Spec 02 (lines 107–123) carries the amended
  Reads (review-findings artifact) and the "Adjudicates the review findings (ADR
  0010)" behavior; the rubric's four beats (advisory not auto-FAIL; confirm/reject;
  map confirmed to severity; discard false positives with a recorded reason; own the
  verdict) and the skip-is-not-clean note match ADR 0010 §4 with no contradiction.
- **Other links resolve.** `review-findings.md`, `severity.md`, and the rubric ADR
  link all resolve (`test -e`). The agent's rubric/`severity.md` references use the
  `${CLAUDE_PLUGIN_ROOT}/...` idiom correctly. Only the agent's ADR markdown link is
  broken.
- **Commit is author-neutral and single-slice** — `Craig Pfeiffer
  <craigeous@gmail.com>`, not a `*@localhost` fallback.

### Required changes

1. In `plugins/loom/agents/code-evaluator.md`, fix the ADR 0010 link depth: change
   `../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md`
   to `../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md`
   (three `../`, not five), so it resolves from the agent file's location. (Confirm
   with `test -e` from `plugins/loom/agents/`.) Alternatively, if the agent's
   established idiom for cross-file pointers is preferred, render it as a non-link
   project-relative mention (`.docs/ADR/0010-...md`) consistent with how the agent
   already names `.docs/...` paths elsewhere.

---

## Plan review (round 0 — PASS, retained)

## Findings

- [MINOR] Step 1 sketch line "A `skipped:`/`ran-clean` status is **informational**"
  names two of the four canonical tokens. The plan's own negative check (Verification
  step 3) explicitly permits "a single illustrative mention of `skipped`/`ran-clean`
  in the informational-note line" while forbidding reproduction of the four-token
  table, so this is consistent with the single-source boundary and not a defect — but
  the implementer should keep that line to the illustrative mention only and not let
  it grow toward the `review-findings.md` table. Recorded for follow-up; does not
  block.

## Required changes (for FAIL)

(none — PASS)

## Notes

Conformance verified against each authority:

- **Spec 02 fidelity.** The Code Evaluator section (spec 02 lines 110–122, Approved)
  already carries both the amended `Reads` (review-findings artifact) and the
  "Adjudicates the review findings (ADR 0010)" behavior with `references/severity.md`
  as the single verdict authority and findings framed advisory/not-auto-FAIL. The
  plan's two planned edits mirror this exactly: rubric gains the adjudication
  procedure (confirm/reject → map confirmed to severity → discard false positives with
  a recorded reason → evaluator owns the verdict), and the agent gains the artifact in
  its inputs plus a pointer.

- **ADR 0010 §4 fidelity.** The four procedure beats in Step 1 match §4: advisory not
  auto-FAIL; confirm/reject each against diff/plan/specs; map confirmed to severity per
  `severity.md`; discard false positives with a one-line recorded reason; evaluator
  owns the verdict. The plan correctly defers the §4 example severity mappings to
  `severity.md` rather than restating the ladder — the cleaner single-source choice.

- **Single-source discipline (load-bearing) — verified.** The rubric is named the
  procedure's single home; the agent only adds the artifact to its inputs and points
  to the rubric (Step 2 explicitly forbids restating the procedure there). Both files
  point to `review-findings.md` (format) and `severity.md` (verdict) rather than
  restating. The plan forbids re-listing the four status tokens or the severity ladder
  and includes a mechanical negative check for it (Verification step 3). Confirmed the
  rubric today contains none of the four tokens (`rg` returned nothing), so the
  negative check starts from a clean baseline.

- **Scope disjoint (load-bearing for parallelism) — verified mechanically.** In scope
  is exactly `references/code-eval-rubric.md` + `agents/code-evaluator.md`. The plan's
  "Out of scope" explicitly excludes `orchestration.md` (Slice B, parallel),
  `review-findings.md` (Slice A), `SKILL.md`, any `spec/`/`ADR/`, the slice-plans
  index, living docs, and `CLAUDE.md`. Cross-checked Slice B's plan
  (`orchestration-review-step-plan.md`): its in-scope set is `orchestration.md` ONLY,
  with `code-eval-rubric.md` + `code-evaluator.md` named Slice C / out of scope. File
  sets are disjoint; parallel execution is safe.

- **Implementable & single-purpose.** Steps are numbered, file-scoped, and reference
  concrete insertion points. The claimed section order (Gate → Fidelity → Correctness
  → **Review-findings adjudication** → Hygiene → Re-review) was verified against the
  live rubric headers (`rg -n "^## "`): current order is Gate → Fidelity → Correctness
  → Hygiene → Re-review, so inserting after Correctness and before Hygiene yields the
  claimed order. Verification names mechanical acceptance checks (`rg`/`test -e`) with
  a positive and a negative check, and correctly notes this is a pure-markdown slice
  with **no `format → lint → test` gate** — consistent with the loom gate applying to
  code, not prose.

- **Round counting.** No prior eval file for this artifact; fresh → Round 0.

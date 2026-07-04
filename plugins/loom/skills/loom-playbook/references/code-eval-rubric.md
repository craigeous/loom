# Code-Evaluation Rubric

The code evaluator judges blind, against the slice-plan and target specs, from the
commit **diff**. Tag findings and derive the verdict per
[`severity.md`](severity.md) (BLOCKER/MAJOR/MINOR → PASS/FAIL).

## Gate (verify, don't trust)

- **Re-run the gate** (format → lint → test) rather than trusting the recorded
  result. A red gate is an automatic BLOCKER.
- Confirm the recorded gate evidence matches reality.

## Fidelity to plan & specs

- **Satisfies the plan** — every step's intent is realized; nothing required is
  missing.
- **Consistent with specs** — does not contradict approved spec text. (If the code
  reveals the spec is wrong, that's a planning matter — flag it; do not approve a
  spec contradiction.)
- **In scope** — the diff contains only this slice's work; no unrelated changes,
  no drive-by edits to specs/ADRs (developers must not touch those).

## Correctness

- **Logic** — trace the changed paths; check edge cases and error handling.
- **No silent regressions** — existing behavior preserved; for a refactor, the
  prior tests pass unchanged (that is the regression proof).
- **Tests prove behavior** — new tests actually exercise the new behavior, not just
  compile. A passing gate is necessary, not sufficient.
- **Invariants verified mechanically** — check invariants with a tool, never by
  eye: `rg -U` for text/wrapped-token invariants (a line-based grep cannot see
  `Code\nReview`), `yq`/`jq` for config facts, `ast-grep`/LSP find-references for
  code-symbol invariants and "did this diff break callers?". Never assert an
  invariant (e.g. "no bare `/loom`") from reading alone. See
  [`tooling.md`](tooling.md).

## Review-findings adjudication

The orchestrator hands you a **review-findings artifact**
(`.docs/evaluations/<slice-name>-review-findings.md`, produced by running `/code-review`
and `/security-review` on the slice diff —
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md),
[ADR 0011](../../../../../.docs/ADR/0011-correct-automated-review-command-to-code-review.md))
as an additional input. It is **advisory input, not an oracle and not an auto-FAIL.**
See [`review-findings.md`](review-findings.md) for the artifact's shape and per-command
status tokens — do not restate them here.

- **Confirm or reject** each reported finding against the diff, plan, and specs.
- For each **confirmed** finding, map it to severity per [`severity.md`](severity.md);
  the verdict then follows from your own severity-tagged findings, exactly as for any
  other finding.
- **Discard false positives** with a one-line reason recorded in the eval file
  (`/code-review` scores confidence and explicitly expects false positives — an unadjudicated
  finding must not decide a landing).
- You **still own the verdict** — [`severity.md`](severity.md) is the single verdict
  authority; the findings add a review dimension, not a verdict path.
- A `skipped:`/`ran-clean` status is **informational, not itself a finding** — a skip
  means the review did not run and must never be read as a clean review. See
  [`review-findings.md`](review-findings.md) for what each status token means.

## Hygiene

- **Playbook conformance** — commit is author-neutral and single-slice; status set
  correctly; slice-plan records the evidence.
- **CLAUDE.md shape (finalize diffs only).** When the diff touches a `CLAUDE.md`,
  flag as findings, per spec 08 § "Shape and Concision Discipline": **restatement**
  (a paragraph that mirrors a named `spec/`/`ADR/`/`references/` file where a
  single-clause pointer belongs); **over-bound** (loom's root `CLAUDE.md` > ~100
  lines, a managed project's > ~200 — check with `wc -l`); and **lost coverage** (a
  reference file / component / gate / read-first pointer present before the diff and
  no longer pointed to — diff the pointer set, don't eyeball). Severity per
  [`severity.md`](severity.md); this is a digest-hygiene dimension, not the
  `format → lint → test` gate.

## Re-review

- Confirm each prior `[BLOCKER]`/`[MAJOR]` was resolved; cite the diff since the
  prior reviewed commit. Don't re-litigate resolved points; don't pass with an
  unaddressed blocker.

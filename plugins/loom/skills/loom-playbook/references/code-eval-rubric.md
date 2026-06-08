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

## Hygiene

- **Playbook conformance** — commit is author-neutral and single-slice; status set
  correctly; slice-plan records the evidence.

## Re-review

- Confirm each prior `[BLOCKER]`/`[MAJOR]` was resolved; cite the diff since the
  prior reviewed commit. Don't re-litigate resolved points; don't pass with an
  unaddressed blocker.

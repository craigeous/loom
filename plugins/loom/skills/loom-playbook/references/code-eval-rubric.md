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
- **Threat-model & proportionality alignment** — judge edge cases within the target
  spec and [`00-overview.md`](../../../../../.docs/spec/00-overview.md)
  `## Non-goals` boundary per [`severity.md`](severity.md) (`### Threat-model &
  non-goals alignment` and `### Proportionality & simplicity`). Do not raise
  `[BLOCKER]`/`[MAJOR]` findings for out-of-scope hostile local filesystem racing
  inside private `0700` directories or post-return monkeypatching of internal `_`
  helpers, and prescribe minimal fail-closed guards rather than new state machines.
- **No silent regressions** — existing behavior preserved; for a refactor, the
  prior tests pass unchanged (that is the regression proof).
- **Tests prove behavior** — new tests actually exercise the new behavior, not just
  compile, and register any background processes for teardown before assertions. A
  passing gate is necessary, not sufficient.
- **Invariants verified mechanically** — check invariants with a tool, never by
  eye: `rg -U` for text/wrapped-token invariants (a line-based grep cannot see
  `Code\nReview`), `yq`/`jq` for config facts, `ast-grep`/LSP find-references for
  code-symbol invariants and "did this diff break callers?". Never assert an
  invariant (e.g. "no bare `/loom`") from reading alone. See
  [`tooling.md`](tooling.md).

## Review-findings adjudication

The orchestrator hands you a **review-findings artifact**
(`.docs/evaluations/<slice-name>-review-findings.md`), assembled by `loom-review`
from a validated `loom-local-review/v1` three-finder run
([ADR 0021](../../../../../.docs/ADR/0021-loom-owned-local-review-protocol.md)), or
an explicit `skipped: docs-only` for a pure-docs slice, as an additional input
alongside the controlled inputs of
[ADR 0022](../../../../../.docs/ADR/0022-controlled-input-independent-evaluation.md)
(the gate rerun remains mandatory). A missing or invalid required review is not
valid evidence and not permission to land. The artifact is **advisory input, not an
oracle and not an auto-FAIL.** The `loom-repository-bootstrap/v1`
([ADR 0023](../../../../../.docs/ADR/0023-repository-self-hosting-bootstrap-transition.md) §3)
fallback is separate and is not an ordinary local-review run. See
[`review-findings.md`](review-findings.md) for the artifact's shape and status
tokens — do not restate them here.

- **Confirm or reject** each reported finding against the diff, plan, and specs
  (including the threat-model and proportionality rules in [`severity.md`](severity.md)).
- For each **confirmed** finding, map it to severity per [`severity.md`](severity.md);
  the verdict then follows from your own severity-tagged findings, exactly as for any
  other finding.
- **Discard false positives** with a one-line reason recorded in the eval file
  (local review finders surface candidate issues and
  expect false positives — an unadjudicated finding must not decide a landing).
- You **still own the verdict** — [`severity.md`](severity.md) is the single verdict
  authority; the findings add a review dimension, not a verdict path.
- A `skipped: docs-only`/`ran-clean` status is **informational, not itself a finding** — a skip
  means the review did not run and must never be read as a clean review. See
  [`review-findings.md`](review-findings.md) for what each status token means.

## Hygiene

- **Playbook conformance** — commit is author-neutral and single-slice; status set
  correctly; slice-plan records the evidence in place without append-only bloat.
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
- Apply the **Anti-goalpost-moving on re-review (`Round >= 1`)** rule in
  [`severity.md`](severity.md): only defects introduced by the revision diff or
  deterministic failures of an explicit spec invariant/gate test may be raised as
  new `[BLOCKER]`/`[MAJOR]` findings on `Round >= 1`.

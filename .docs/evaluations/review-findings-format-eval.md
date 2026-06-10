# Evaluation: review-findings-format-plan

Verdict: PASS
Round: 0
Reviewed against: ADR 0010 (§2 location/naming + four distinguishable states, §3
identity scrub, §4 advisory/adjudication, §5 docs-only skip, §7 command-unavailable
skip; ADR 0001 spawn rationale; ADR 0004 blind contract); spec 04-orchestrator.md §
"Automated review before a slice lands"; spec 02-roles.md (Code Evaluator);
references/code-eval-rubric.md; references/severity.md. This is the code-review phase
on the same artifact whose plan-review PASSED at round 0; a PASS here holds the round.

## Mechanical checks performed

- **Scope (`git diff --name-only HEAD~1 HEAD`).** Exactly three paths:
  `references/review-findings.md` (new), `SKILL.md` (additive — `--numstat` 4/0, no
  deletions), and the slice-plan (status + evidence). No edits to `orchestration.md`,
  `agents/code-evaluator.md`, `code-eval-rubric.md`, any `spec/`/`ADR/`, the
  slice-plans index/README, `.docs/status/` living docs, or `CLAUDE.md`. In scope.
- **Four status tokens (`rg`).** `ran-with-findings`, `ran-clean`,
  `skipped: docs-only`, `skipped: command-unavailable` all present verbatim in the
  status table (lines 77–80) and demonstrated in the two skeletons (lines 124, 127,
  142, 145). The "a skip is never confusable with a clean review" rule and the
  two-skips-distinguishable rule are stated explicitly (lines 82–85). All four ADR
  0010 §2 states are represented and a skip cannot be read as clean.
- **Single-source boundary (`rg severity.md|code-eval-rubric|04-orchestrator`).** The
  file points to spec 04 for the run procedure and to `severity.md` +
  `code-eval-rubric.md` for adjudication, and explicitly states "This file owns the
  artifact format; the rubric owns the adjudication procedure" (line 111). The only
  hits for procedure terms (lines 44, 109) are deferral pointers ("…is spec 04 scope
  — point there, not here"; "See … for the adjudication procedure"), not
  restatements. No confirm/reject/discard steps, no severity mapping, no driver-loop
  run sequence is reproduced.
- **Link resolution (`test -e` from `references/`).** All 10 relative targets
  resolve: ADR 0001/0004/0008/0010, spec 02/04 (via `../../../../../.docs/...`), and
  `code-eval-rubric.md`/`commit-convention.md`/`parallelism.md`/`severity.md` (bare
  sibling form) — matching existing reference convention.
- **SKILL.md bullet.** Present at line 50, backticked-filename + em-dash style
  matching neighbors, names what it owns and cites ADR 0010, placed after
  `severity.md` in the References list.
- **Gate.** Pure-markdown slice; `format → lint → test` does not apply — absence of a
  code gate is correct here, not a red gate.

## Findings

- [MINOR] ADR 0010 §2 (prose) writes the fourth state as "skipped: command
  unavailable" (space), while the reference encodes the token as
  `skipped: command-unavailable` (hyphen). This is the concrete encoding decision
  ADR 0010 §2 explicitly deferred to this slice, and the two skip tokens remain
  mutually distinguishable and unambiguous, so it is consistent rather than
  contradictory. Noted only so the later Slice B/C consumers adopt the same hyphenated
  token. Not blocking.

## Required changes (for FAIL)

(none — PASS)

## Notes

Authority conformance, point by point:

- **Purpose & authority + spawn rationale.** The header states the artifact carries
  `/review` + `/security-review` output from the orchestrator to the blind evaluator
  as an additional input alongside diff/plan/specs/gate evidence, and gives the
  one-sentence "orchestrator, not evaluator, produces it — only the orchestrator may
  spawn" rationale citing ADR 0001. Matches spec 04 and ADR 0010 §1; does not stray
  into the run procedure.
- **Location & naming.** Fixes `.docs/evaluations/<slice-name>-review-findings.md` as
  a per-slice companion to `<slice-name>-eval.md`, distinct from the verdict file,
  branch-local/uniquely-named under parallelism (parallelism.md / ADR 0008), and
  committed author-neutral (commit-convention.md). Correctly defers *when* it is
  written/committed to spec 04 / Slice B. Matches ADR 0010 §2 and spec 04 line 63.
- **Identity-neutral invariant.** Stated as a hard invariant ("records findings
  only" — no author, no PR metadata/number/owner, no SHAs-as-identity, nothing
  leaking authorship), with the §3 scrub, citing ADR 0004. Does not weaken the blind
  contract.
- **Finding-entry fields + advisory framing.** source command / location /
  description / confidence-signal-if-present, with the absent-confidence case
  ("omit if the command emits none") handled, and the entry framed as advisory input
  the evaluator adjudicates — consistent with ADR 0010 §4.
- **Skeleton.** Two terse illustrative skeletons demonstrate the distinguishable
  states concretely (one command `ran-clean` + one `ran-with-findings`; plus a
  docs-only skip pair), satisfying the plan's item-7 demonstrability requirement.

Does not contradict spec 04 § "Automated review before a slice lands" or spec 02's
Code Evaluator section. Single-source discipline, scope discipline, and cross-ref
integrity all hold. Slice status set to Landed.

# Evaluation: ADR-0011 spec amendment (specs 04 + 02)

Verdict: PASS
Round: 0
Reviewed against: ADR 0011 (Accepted), ADR 0010 (surviving decisions), references/plan-eval-rubric.md, references/severity.md

## Findings

No blockers, no majors, no minors.

Verified mechanically and against the authority:

- **Faithful & minimal.** The amendment (commit `c9a6f3d`, diffed against
  `c9a6f3d~1`) changes exactly three things and nothing else:
  1. `/review` → `/code-review` in spec 04 (§ "Automated review before a slice
     lands") and spec 02 (Code Evaluator "Reads" bullet).
  2. An ADR 0011 citation added alongside the existing ADR 0010 citation in both
     locations.
  3. A new bullet in spec 04 — "**Target the slice's commit range.**" — folding in
     ADR 0011 §2 (slice committed at `Implemented` → working tree empty → target
     the commit range / branch, never the empty working tree), citing ADR 0011 §2.
- **`/security-review` untouched.** It is unchanged in both specs.
- **No stray `/review`.** `rg -n '/review\b' .docs/spec/04-orchestrator.md
  .docs/spec/02-roles.md` returns nothing (exit 1). `/code-review` and
  `/security-review` are intact and not mangled (`rg '/code-review|/security-review'`
  confirms both present and well-formed).
- **Accurate against ADR 0011.** The "Local diff mode only" framing is now
  genuinely correct for `/code-review` (ADR 0011 §1 — `/code-review` is the local
  code-review command; `/review` was PR-bound). The commit-range invocation detail
  matches ADR 0011 §2 verbatim in substance, including the `git diff
  <base>...<slice-HEAD>` example and the "never the empty working tree" caveat.
- **ADR 0010's surviving decisions unchanged.** Still present and unmodified in
  spec 04: orchestrator-runs-it (never the code-evaluator, ADR 0001), local-only
  preserves the blind contract (ADR 0004), the findings artifact handed as advisory
  input, docs-only skip-with-a-note, the four distinguishable statuses, and
  not-the-gate. Spec 02 retains the evaluator's adjudication-with-severity.md
  verdict authority (ADR 0010). None were touched.
- **In scope.** `git show --stat c9a6f3d` confirms only `.docs/spec/04-orchestrator.md`
  and `.docs/spec/02-roles.md` changed — no ADR, playbook, reference, or index
  edits. No new `Status:` value introduced (the artifacts sat at the existing
  `Plan Review` status pending this review).

## Required changes (for FAIL)

None.

## Notes

The amendment correctly mirrors ADR 0011's own framing: it supersedes ADR 0010
only on the command identification and adds the commit-range invocation detail,
leaving the rest of ADR 0010 in force. The frozen-spec amendment discipline
(ADR 0005) is respected — this is a deliberate, blind-evaluated planning pass, not
an in-slice spec edit. On this PASS both specs are returned to `Approved`
(re-frozen).

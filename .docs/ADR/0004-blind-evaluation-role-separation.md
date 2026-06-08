# 0004 — Blind Evaluation by Controlled Inputs & Role Separation

Status: Accepted
Date: 2026-06-08

## Context

Evaluators must stay impartial and critical. The classic failure is an agent going
easy on work it produced, plus general rubber-stamping/sycophancy. Since every role
is ultimately the same underlying model, blindness cannot rely on the evaluator
"pretending" not to know authorship.

## Decision

- **Blindness is enforced by controlling the evaluator's prompt inputs**, not by
  instruction. An evaluator receives only: the artifact (minus identity metadata),
  the upstream authority it is judged against, the playbook rubric, and — on
  re-review — the prior eval file and the diff. It never receives author identity
  or author reasoning.
- **Role separation guarantees no self-approval:** the role that produced an
  artifact is never the role that approves it, and the orchestrator never routes an
  artifact to its own author. Because agents are cold and anonymous, this holds by
  construction.
- Verdicts are structured (PASS/FAIL + severity-tagged findings) and live in
  `evaluations/<name>-eval.md`; any `BLOCKER` ⇒ FAIL.

## Consequences

- "Going easy on my own work" is impossible: the evaluator cannot know it authored
  anything.
- Sycophancy is countered by judging against an explicit authority + rubric and by
  the blocker-⇒-fail rule.
- The orchestrator must scrub identity metadata from evaluator inputs; artifact
  files therefore carry no author names (attribution, if any, is by role label).
- **Commit metadata is part of the evaluator's inputs** (the code evaluator reads
  diffs and `git log`), so it must also be author-neutral: no AI co-author
  trailers, no role/author identity in messages, and a single uniform git identity
  across roles. See ADR 0003.

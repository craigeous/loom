# Slice Plans

Transient working memory: plans for **in-flight slices** before they land. Authored
by the **planner**, approved by the **plan evaluator** (or owner), implemented by
the **developer**, reviewed by the **code evaluator**.

A **slice** is a small, single-purpose, vertically-shippable unit of work. If a
plan grows multiple unrelated goals, split it.

Plans **propose**; specs **decide**. On any conflict, the spec in `../spec/` wins.
When a slice lands, its outcomes are folded into the durable specs and the plan is
`git mv`'d into [`archive/`](archive/) — **after** code-eval PASS, in the same
landing step.

Lifecycle: `Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived` (see
[../spec/03-artifact-lifecycle.md](../spec/03-artifact-lifecycle.md)).

## Active plans

(none)

## Archived plans

- [archive/init-mode-detection.md](archive/init-mode-detection.md) — `Archived` —
  one authoritative, precise init-mode classifier (first M2 slice; landed 5fef2ed).
- [archive/greenfield-init-behavior.md](archive/greenfield-init-behavior.md) — `Archived` —
  Greenfield init behavior body: scaffold `.docs/`, seed `status/`, write project
  `CLAUDE.md`, establish the gate (second M2 slice; landed a58ff7e).
- [archive/retire-code-review-status-token.md](archive/retire-code-review-status-token.md) — `Archived` —
  retired the obsolete `Code Review` status token from `SKILL.md`, `status-machine.md`,
  `developer.md`, and the slice-plans README `Lifecycle:` string; aligned to spec 03
  (landed a85885f).

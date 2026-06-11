# Architecture Decision Records

Numbered, durable decision records. Authored by the **planner**, approved by the
**plan evaluator** (or owner).

An accepted ADR is **immutable**: if a decision becomes wrong, write a new ADR that
marks the old one *superseded* — never rewrite history. Living architecture text
belongs in `../spec/`, not here.

Naming: `NNNN-short-title.md`. Lifecycle: `Draft → Plan Review → Approved` (see
[../spec/03-artifact-lifecycle.md](../spec/03-artifact-lifecycle.md)).

## Accepted

- [0001 — Plugin Architecture & Orchestrator Model](0001-plugin-architecture-and-orchestrator.md)
- [0002 — Model Selection by Tier](0002-model-selection-by-tier.md)
- [0003 — File-Based Cold Handoffs with a Commit per Handoff](0003-cold-handoffs-commit-per-handoff.md)
- [0004 — Blind Evaluation by Controlled Inputs & Role Separation](0004-blind-evaluation-role-separation.md)
- [0005 — Specs Frozen After Approval; Change Only via Planning](0005-specs-frozen-after-approval.md)
- [0006 — Distribution as a Single-Plugin Self-Marketplace](0006-distribution-self-marketplace.md)
- [0007 — Namespaced Command Surface](0007-namespaced-command-surface.md) — supersedes the bare-`/loom` command-naming in 0001
- [0008 — Parallel `.docs/` Coordination for Worktree-per-Slice](0008-parallel-docs-coordination-worktree-per-slice.md) — resolves OQ-A; builds on ADR 0003/0001
- [0009 — Unaligned-migrate Sub-mode](0009-unaligned-migrate-sub-mode.md) — refines spec 06 §2 Unaligned; builds on ADR 0001/0005
- [0010 — Orchestrator-Run Automated Review Feeds the Blind Code-Evaluator](0010-orchestrator-run-automated-review-in-code-eval.md) — adds automated review to the code-review phase; builds on ADR 0001/0004/0002/0003/0008 — **command identification corrected by 0011** (`/review` → `/code-review`)
- [0011 — Correct the Automated-Review Command to `/code-review`](0011-correct-automated-review-command-to-code-review.md) — supersedes ADR 0010 **only** on the command (`/review` is PR-bound → use the local-diff `/code-review`) and adds the commit-range invocation detail; rest of 0010 stands
- [0012 — Thin Orchestrator: `sonnet` Default + Bounded Role-Return Contract](0012-thin-orchestrator-sonnet-default-bounded-return.md) — **extends** ADR 0002 (adds the orchestrator tier row) and builds on ADR 0001/0003/0004/0010/0011; keeps the orchestrator's context flat via pass-references-not-bodies + a bounded return contract
- [0013 — Starvation-Loop Guards for the Orchestrator Cold-Restart](0013-starvation-loop-guards-cold-restart.md) — builds on ADR 0012/0003/0010/0011; write-ahead checkpoint + restart-before-big-op + forward-progress escalation + lossless-beats-lossy, plus a follow-on PreCompact mechanical-backstop slice

## In Review

_(none)_

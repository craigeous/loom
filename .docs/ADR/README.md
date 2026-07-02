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
- [0014 — Multi-Session Worktree Coordination](0014-multi-session-worktree-coordination.md) — **extends** ADR 0008 (single-orchestrator "serialized on main" → cross-session lock + slice-lease for N concurrent `/loom:run` sessions); builds on ADR 0001/0003/0012/0013 (relocates ADR 0013's write-ahead cold-restart anchor to off-`main` per-session state) — **liveness signal superseded by 0015** (worktree-membership/pid → lease-renewal heartbeat); **lock/claim *mechanism* superseded by 0016** (mkdir-CAS → git `update-ref` CAS); rest of 0014 stands
- [0015 — Lease-Renewal Heartbeat as the Liveness Signal](0015-lease-renewal-heartbeat-liveness.md) — supersedes ADR 0014 on the **liveness signal only** (worktree-list membership / ephemeral pid → lease-freshness heartbeat within the TTL; a session that stops renewing becomes reclaimable); rest of 0014 stands; builds on ADR 0014/0001/0003
- [0016 — Git-Native Ref Compare-and-Swap as the Lock/Claim Substrate](0016-git-native-ref-cas-lock-mechanism.md) — supersedes ADR 0014's lock/claim **mechanism** only (mkdir-CAS + rename-capture + TSV registry → git `update-ref` CAS on `refs/loom/lock` + `refs/loom/claims/*`); keeps ADR 0014 coordination model + ADR 0015 lease-freshness liveness; builds on ADR 0014/0015/0001/0003. Eliminates review defects U1/U4 and fixes U3 by heartbeating the lock ref; carries U2/U5/U6 + secondary forward as re-implementation obligations.

## In Review

_(none)_

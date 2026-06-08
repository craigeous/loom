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

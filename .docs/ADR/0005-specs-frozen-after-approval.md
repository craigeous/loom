# 0005 — Specs Frozen After Approval; Change Only via Planning

Status: Accepted
Date: 2026-06-08

## Context

The ballboy prototype folded each landed slice's outcomes back into its specs, so
specs tracked "current state." That couples developers to spec authorship and
risks silent drift. The owner wants developers to "work only in slices and
handoffs," with spec changes owned by the planner.

## Decision

- An **approved spec is frozen.** It changes only by re-entering the planning
  cycle (`Draft → Plan Review → Approved`), authored by the **planner**.
- **Developers never edit specs or ADRs.** They touch only slice-plans and the
  living docs (`status/`).
- **Landing a slice does not edit the spec.** On code-eval PASS, the developer's
  finalize pass updates `status/progress.md` + `status/handoff.md` and archives the
  slice-plan.
- If implementation reveals the spec is wrong, the developer stops and the
  orchestrator opens a **planning task**; the spec is never patched silently.

## Consequences

- The spec is **intended design**, not current state; the living docs + git history
  carry "what actually happened."
- Spec/reality divergence is surfaced as explicit planning work — healthier than
  silent drift, at the cost of an extra planning loop when designs change.
- Clear ownership: planner owns durable design, developer owns implementation.

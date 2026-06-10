# Status Machine & Dispatch

Status is loom's dispatcher. The orchestrator reads `Status:` lines (and git) to
decide which role to spawn next. Every transition is paired with a commit.

## Statuses

| Status               | Meaning                                     | Next actor            |
|----------------------|---------------------------------------------|-----------------------|
| `Draft`              | Author writing / revising                   | author (researcher/planner) |
| `Research Review`    | Research note ready for source check        | plan evaluator        |
| `Plan Review`        | Planning artifact ready for blind review    | plan evaluator        |
| `Approved`           | Artifact accepted                           | developer (if a slice)|
| `In Progress`        | Developer implementing                      | developer             |
| `Implemented`        | Gate green; awaiting code review            | code evaluator        |
| `Landed`             | Code approved; finalize underway            | developer (finalize)  |
| `Archived`           | Plan moved to archive/; history             | —                     |
| `Needs Clarification`| Blocked on a `## Notes` question            | clarifying role       |
| `Abandoned`          | Dropped; kept for history                   | —                     |

## Dispatch table (status → role)

| Sees…                                  | Spawns…          |
|----------------------------------------|------------------|
| `Research Review`                      | plan evaluator   |
| `Plan Review`                          | plan evaluator   |
| `Approved` (slice-plan)                | developer        |
| `Implemented`                          | code evaluator   |
| `Landed`                               | developer (finalize) |
| `Needs Clarification`                  | clarifying role  |
| `Draft` (after a reject, within scope) | author           |

## Approval authority

By default evaluator approval advances the loop. The owner declares **claimed
gates** at kickoff (`all` or a named list); at a claimed gate the orchestrator
pauses for owner sign-off before proceeding past it.

## Round limit

- A **FAIL** increments `Round:`; a **PASS does not**. A resolving PASS carries the
  **same** round number as the FAIL it closes (the round is closed, not advanced).
- A fresh artifact's first review is **round 0** (not yet counted); the first FAIL
  moves it to round 1. Counted rounds run **1..N**.
- **One** counter per artifact in its single eval file
  (`.docs/evaluations/<artifact-name>-eval.md`), spanning **both** review phases —
  plan-review FAILs and code-review FAILs accumulate toward the same limit.
- After **5** rounds (the 5th FAIL) the orchestrator stops and escalates = **pause +
  summary** to the owner.

See [spec 03 `## Round limits`](../../../../../.docs/spec/03-artifact-lifecycle.md)
for the full counting rule, the reset rule, and the escalation-summary contract.

## Lifecycles

- Research: `Draft → Research Review → Approved`.
- ADR / Spec: `Draft → Plan Review → Approved` (ADR then immutable; spec frozen).
- Slice-plan: `Draft → Plan Review → Approved → In Progress → Implemented →
  (code review) → Landed → Archived`, with FAIL edges back to `Draft` (plan) or
  `In Progress` (code). Archive happens only **after** code-eval PASS. The
  finalize pass that runs after code-eval PASS also updates the relevant
  `CLAUDE.md` when the landed slice changed something in the curated-digest scope
  (a derived non-spec digest; per-slice history stays in `progress.md`) — see
  [spec 03](../../../../../.docs/spec/03-artifact-lifecycle.md) (*finalize pass*)
  and [spec 08](../../../../../.docs/spec/08-playbook.md) (the curated-digest
  boundary).

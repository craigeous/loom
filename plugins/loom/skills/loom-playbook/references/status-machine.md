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

A reject→revise cycle increments `Round:` in the eval file. After **5** rounds on
one artifact, the orchestrator stops and escalates = **pause + summary** to the
owner.

## Lifecycles

- Research: `Draft → Research Review → Approved`.
- ADR / Spec: `Draft → Plan Review → Approved` (ADR then immutable; spec frozen).
- Slice-plan: `Draft → Plan Review → Approved → In Progress → Implemented →
  Code Review → Landed → Archived`, with FAIL edges back to `Draft` (plan) or
  `In Progress` (code). Archive happens only **after** code-eval PASS.

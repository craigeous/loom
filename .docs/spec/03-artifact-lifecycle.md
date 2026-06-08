# 03 — Artifact Lifecycle & Status State Machine

Status: Draft

Status is loom's dispatcher. Each gated artifact carries a `Status:` line; the
orchestrator reads it (and git state) to decide which role to spawn next. **Every
role pass ends in a commit** (ADR 0003), so status transitions are paired with
commits the next role can diff against.

## Statuses

| Status               | Meaning                                      | Next actor            |
|----------------------|----------------------------------------------|-----------------------|
| `Draft`              | Author is writing / revising                 | author (researcher/planner) |
| `Research Review`    | Research note ready for source check         | plan evaluator        |
| `Plan Review`        | Planning artifact ready for blind review     | plan evaluator        |
| `Approved`           | Artifact accepted                            | developer (if a slice)|
| `In Progress`        | Developer implementing                       | developer             |
| `Implemented`        | Developer done; gate green; awaiting review  | code evaluator        |
| `Code Review`        | Code under blind review                       | code evaluator        |
| `Landed`             | Code approved; finalize pass underway        | developer (finalize)  |
| `Archived`           | Plan moved to `archive/`; history            | —                     |
| `Needs Clarification`| Blocked on a question in `## Notes`          | clarifying role       |
| `Abandoned`          | Dropped; kept for history                    | —                     |

## Research lifecycle

```
Draft ──▶ Research Review ──approve──▶ Approved (usable by planner)
   ▲             │
   └───reject────┘   (eval: sources missing or don't support claims)
```

Research approval is a light gate: citations present, sources exist and support
the summary.

## ADR / Spec lifecycle (no implementation)

```
Draft ──▶ Plan Review ──approve──▶ Approved
   ▲           │
   └──reject───┘   (eval notes written; planner revises)
```

- An **accepted ADR** is immutable. To change it, write a new ADR that supersedes
  it.
- An **approved spec is frozen** (ADR 0005). It changes only by re-entering this
  cycle in a new planning phase — never as a side effect of a slice landing, and
  never by a developer.

## Slice-plan lifecycle (the full loop)

```
Draft ──▶ Plan Review ──approve──▶ Approved ──▶ In Progress ──▶ Implemented
  ▲            │                                    ▲                │
  └──reject────┘                                    │                ▼
   (planner revises)                                │          Code Review
                                                    │           │      │
                                       reject (eval notes)──────┘      │approve
                                                                       ▼
                                                            Landed ──▶ Archived
```

On **approve at Code Review**, the developer runs a **finalize pass** (cold):
1. Update `status/progress.md` and `status/handoff.md` (and `roadmap.md` if a
   milestone closed).
2. `git mv` the plan into `slice-plans/archive/`, set status `Archived`, commit.

**No spec edit happens at landing.** The slice-plan and the living docs record
what was built; the spec only ever changes through a planning cycle. If
implementation showed the spec to be wrong, the developer stops and the orchestrator
opens a planning task instead of patching the spec.

> **Why this differs from the prototype:** ballboy folded slice outcomes back into
> its specs at landing. loom instead **freezes specs** (ADR 0005) and treats the
> spec as *intended design*, not *current state*. Divergence is surfaced as
> explicit planning work rather than silent spec drift.

## Clarification sub-flow

```
<any status> ──role asks in ## Notes, sets──▶ Needs Clarification
                                                   │
                  orchestrator spawns clarifying role (cold)
                                                   │
                  answer written in ## Notes, status restored, commit
                                                   ▼
                                          <prior status resumes>
```

## Dispatch rules (status → role)

| When it sees…                          | It spawns…       |
|----------------------------------------|------------------|
| `Research Review`                      | plan evaluator   |
| `Plan Review`                          | plan evaluator   |
| `Approved` slice-plan                  | developer        |
| `Implemented`                          | code evaluator   |
| `Landed`                               | developer (finalize) |
| `Needs Clarification`                  | clarifying role  |
| `Draft` (after a reject, within scope) | author           |

Approval authority: by default **evaluator approval advances the loop**. The owner
declares claimed gates at kickoff — `all` or a named list ([04](04-orchestrator.md));
at a claimed gate, the orchestrator pauses for owner sign-off before proceeding.

## Round limits

Each reject→revise cycle increments a round counter recorded in the eval file.
After **5** rounds for a given artifact, the orchestrator stops and **escalates =
pause + summary** to the owner rather than looping indefinitely.

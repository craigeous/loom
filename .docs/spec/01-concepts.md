# 01 — Concepts & `.docs/` Layout

Status: Approved

## The `.docs/` directory

Every project loom manages has a `.docs/` directory, committed to git. It is the
project's durable and working memory.

```
.docs/
├── research/                 # research findings, gathered context (input to planning)
├── ADR/                      # architecture decision records (numbered, immutable)
├── spec/                     # durable, authoritative specs (numbered spine)
├── slice-plans/              # transient plans for in-flight slices
│   └── archive/              # landed/abandoned plans (history)
├── evaluations/              # blind verdicts: <artifact-name>-eval.md
└── status/                   # living docs (kept separate)
    ├── roadmap.md            # milestone order — what's next and why
    ├── progress.md           # status source of truth / decision index
    └── handoff.md            # restart instructions, compact current context
```

> loom dogfoods this layout. The directory you are reading lives at the loom
> repo's own `.docs/`.

## Artifact types

| Artifact    | Folder         | Durability | Authored by | Approved by            |
|-------------|----------------|------------|-------------|------------------------|
| Research    | `research/`    | reference  | researcher  | (not gated)            |
| ADR         | `ADR/`         | durable    | planner     | plan evaluator / owner |
| Spec        | `spec/`        | durable    | planner     | plan evaluator / owner |
| Slice-plan  | `slice-plans/` | transient  | planner     | plan evaluator / owner |
| Evaluation  | `evaluations/` | reference  | evaluators  | (not gated)            |
| Code        | the repo       | durable    | developer   | code evaluator / owner |

## Durable vs transient

- **Durable** (`spec/`, `ADR/`) — the authoritative model of the system. An
  approved spec is **frozen** (ADR 0005): it changes **only through a planning
  cycle** (`Draft → Plan Review → Approved`), authored by the planner — never as a
  side effect of a slice landing. On any conflict between a plan and a spec, the
  **spec wins**. ADRs are immutable once accepted (ADR 0005): to change a decision,
  write a new ADR that supersedes the old one.

- **Transient** (`slice-plans/`) — proposals for the next unit of work. They are
  discussed, evaluated, executed, and on landing **archived**, with the **living
  docs (`status/`) updated** to record what was built (ADR 0005). The spec is
  **not** edited at landing — it is intended design, not current state. If
  implementation reveals the spec is wrong, the divergence is surfaced as explicit
  planning work rather than patched silently.

## Research

Research notes are gathered context: web findings, GitHub references, summaries of
local projects/files, database schemas, prior art. They are **inputs** the planner
draws on; they are not authoritative and are not status-gated. They live as dated,
topic-named files in `research/`.

## Evaluations

Each evaluation is a separate file `evaluations/<artifact-name>-eval.md` paralleling
the artifact it judges (e.g. `slice-plans/native-result-thread.md` →
`evaluations/native-result-thread-eval.md`). Keeping verdicts in their own file
(rather than inline in the artifact, as the prototype did) keeps the work file
clean and the verdicts scannable. See [05 — Blind Evaluation](05-blind-evaluation.md).

The artifact itself still carries a lightweight **`## Notes`** section used for
*clarification requests* between roles (e.g. a developer asking the planner to
disambiguate a step). Notes are conversation; the eval file is the verdict.

## Slices

A **slice** is a small, single-purpose, vertically-shippable unit of work derived
from a spec — the developer's atomic unit. If a plan grows multiple unrelated
goals, it is split. Slices keep each loop iteration bounded and each evaluation
focused.

## Status as the dispatcher

Every gated artifact carries a `Status:` line. The orchestrator reads status
across `.docs/` to decide which role to spawn next. Status — not memory and not a
message queue — is the coordination mechanism. The full state machine is in
[03 — Artifact Lifecycle](03-artifact-lifecycle.md).

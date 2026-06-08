# 07 — Command Surface

Status: Draft

loom is a Claude Code **plugin**. The surface is one orchestrated entry command
plus per-role one-off commands (in `commands/`), backed by the five role agents
(in `agents/`). See [10 — Packaging](10-packaging.md) for the full layout.

## Plugin files behind the surface

```
loom/
├── commands/        # the invokable slash-command surface
│   ├── loom.md            # /loom — the orchestrator
│   ├── loom-research.md   # one-off researcher
│   ├── loom-plan.md       # one-off planner
│   ├── loom-eval-plan.md  # one-off plan evaluator
│   ├── loom-develop.md    # one-off developer
│   ├── loom-eval-code.md  # one-off code evaluator
│   ├── loom-status.md     # print .docs/ state
│   └── loom-init.md       # explicit init/alignment
└── agents/          # the cold role agents the orchestrator spawns
    ├── researcher.md      (haiku)
    ├── planner.md         (opus)
    ├── plan-evaluator.md  (opus)
    ├── developer.md       (sonnet)
    └── code-evaluator.md  (opus)
```

> Exact invocation naming (`/loom-research` vs. subdir-namespaced `/loom:research`)
> is a build-time detail; the intent below is stable. Per-role commands may set
> `disable-model-invocation: true` where an owner-only action is intended.

## Orchestrated entry

- **`/loom`** — detect init mode ([06](06-init-modes.md)); for greenfield/unaligned
  bootstrap or align, for initialized show the resume menu; then ask **scope** and
  **claimed gates** and run the driver loop ([04](04-orchestrator.md)).
- **`/loom <scope>`** — start with scope pre-declared
  (`research` | `adr` | `plan` | `implement` | `slice` | `full` | ranges).

## One-off role commands

Each runs a single cold-agent pass against current `.docs/` + git state, then
commits — no chaining:

- **`/loom-research <topic>`** — researcher writes a cited `research/` note.
- **`/loom-plan`** — planner advances planning per current state + owner input.
- **`/loom-eval-plan [<artifact>]`** — plan evaluator blind-reviews the named (or
  next `Plan Review`/`Research Review`) artifact.
- **`/loom-develop [<slice>]`** — developer implements the named (or next
  `Approved`) slice-plan.
- **`/loom-eval-code [<slice>]`** — code evaluator blind-reviews the named (or next
  `Implemented`) slice's commit diff.

## Utility commands

- **`/loom-status`** — summary of `.docs/` state (roadmap target, in-flight
  artifacts + statuses, blockers, round counts).
- **`/loom-init`** — explicitly run init/alignment for the current repo.

## Mediation note

The one-off commands are how a human drives manually; `/loom` is how loom drives
itself. Both spawn the same cold role agents against the same files — the only
difference is whether the orchestrator chains the next role automatically
(orchestrated) or stops after one pass (one-off).

# 08 — Playbook

Status: Plan Review

The **playbook** is loom's bundled, evolving set of conventions and templates. It
makes loom opinionated: loom imposes the playbook on the projects it manages
rather than conforming to each project. Improving how you work = editing the
playbook; future inits and re-alignments pick up the change.

## Where it lives (packaging)

The playbook ships **inside the plugin** as a bundled skill:

```
loom/skills/loom-playbook/
├── SKILL.md
├── templates/        # artifact skeletons (research, ADR, spec, slice-plan, eval)
├── references/       # convention docs, the status machine, role rubrics
└── gates/            # known gate definitions (Rust verified; others learned)
```

Commands and agents reference it at runtime via the plugin-root variable, e.g.
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/templates/spec.md`. The playbook is
**not** copied verbatim into managed projects — they receive the *applied result*
(a `.docs/` tree, a `CLAUDE.md`, concrete gate commands), while the playbook
remains the single source loom applies from.

## What the playbook contains

- **`.docs/` structure** — the canonical directory layout ([01](01-concepts.md)).
- **Artifact templates** — skeletons for research notes (with required citation
  format), ADRs, specs, slice-plans, and evaluations, each with its `Status:` line.
- **Status lifecycle** — the state machine and dispatch rules ([03](03-artifact-lifecycle.md)).
- **Role prompts & rubrics** — the cold-agent instructions and each evaluator's
  rubric, including the blind-input contract ([05](05-blind-evaluation.md)). These
  are largely the same content as the `agents/*.md` system prompts.
- **Gate definitions** — the `format → lint → test` standard plus known per-stack
  commands. **Rust is the only verified gate**; others are *learned* during init
  (see [06](06-init-modes.md)) and recorded back here.
- **`CLAUDE.md` template** — the project-level conventions loom writes into managed
  repos, plus guidance for root-level `CLAUDE.md`.
- **Naming conventions** — artifact ↔ `<artifact>-eval.md`, ADR/spec numbering.

### Slice-plans index ownership under parallelism

Under parallelism the slice-plans index (`slice-plans/README.md`) Active/Archived
sections are maintained by the **orchestrator on main**, not by the planner or
developer in a slice branch. This is a change from the M1-sequential habit, where
the planner wrote the Active-plans entry in the *same plan commit* as the plan file
and the developer/finalize touched it again when archiving. Once parallelism is on,
the planner authoring a slice-plan on its branch writes **only** the uniquely-named
plan file (`<slice>-plan.md`) — never the index; the orchestrator adds the Active
entry when it creates a slice and moves it to Archived when it lands one. See
[ADR 0008](../ADR/0008-parallel-docs-coordination-worktree-per-slice.md) for detail.

## Model tiers

The playbook records the per-role tier assignment (researcher `haiku`, developer
`sonnet`, planner + both evaluators `opus`). Only tiers are pinnable; exact
versions track the user's environment (ADR 0002).

## Evolving the playbook

- The playbook is itself developed through loom (dogfooding): changes are planned,
  evaluated, and landed like any other slice.
- **Gate learning:** when init creates a gate for a new stack, that gate is written
  back into `gates/` so the next project on that stack inherits it.
- Long-term, loom maintains best practices in **root- and project-level
  `CLAUDE.md`** files automatically, so conventions live where agents already look.

## Verified gate (Rust)

| Step   | Command                                      |
|--------|----------------------------------------------|
| format | `cargo fmt --check`                          |
| lint   | `cargo clippy --all-targets -- -D warnings`  |
| test   | `cargo test`                                 |

Other stacks: no shipped defaults. loom identifies and creates the gate on first
encounter ([06](06-init-modes.md)), confirms with the owner, runs it green once to
mark it verified, then records it.

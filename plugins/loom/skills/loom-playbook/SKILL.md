---
name: loom-playbook
description: loom's canonical conventions — the .docs/ layout, artifact templates, evaluation rubrics, status machine, commit convention, and gate definitions. Use when an agent or the orchestrator needs the standard template, rubric, or convention to apply to a managed project, or when aligning/initializing a project to loom's patterns.
---

# loom Playbook

The single source of conventions loom imposes on the projects it manages. The
orchestrator and the five role agents read from here; init applies it to a target
project. Improving how loom works = editing these files.

> loom does not copy this playbook into managed projects. It applies the *result*:
> a `.docs/` tree, a project `CLAUDE.md`, and concrete gate commands. This skill
> stays the source loom applies from.

## The `.docs/` layout (what loom creates in a managed project)

```
.docs/
├── research/      cited research notes (input to planning)
├── ADR/           numbered, immutable architecture decision records
├── spec/          durable, authoritative specs (frozen after approval)
├── slice-plans/   transient plans for in-flight slices (+ archive/)
├── evaluations/   <artifact-name>-eval.md blind verdicts
└── status/        roadmap.md · progress.md · handoff.md  (kept separate)
```

Durable (`spec/`, `ADR/`) changes only via planning. Transient (`slice-plans/`) is
archived on landing. On conflict, the spec wins.

## Templates (`templates/`)

| Artifact   | Template                | Authored by | Status flow |
|------------|-------------------------|-------------|-------------|
| Research   | `research.md`           | researcher  | Draft → Research Review → Approved |
| ADR        | `adr.md`                | planner     | Draft → Plan Review → Approved (then immutable) |
| Spec       | `spec.md`               | planner     | Draft → Plan Review → Approved (then frozen) |
| Slice-plan | `slice-plan.md`         | planner     | Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived |
| Evaluation | `evaluation.md`         | evaluators  | (verdict file, not gated) |

## References (`references/`)

- `status-machine.md` — statuses, transitions, and the dispatch table.
- `commit-convention.md` — **author-neutral** commit rules (no AI co-author, no
  role identity; blind review reads commits).
- `plan-eval-rubric.md` — what the plan evaluator checks.
- `code-eval-rubric.md` — what the code evaluator checks.
- `severity.md` — the shared BLOCKER/MAJOR/MINOR taxonomy and the PASS/FAIL rule
  both evaluators apply.
- `docs-layout.md` — the `.docs/` layout loom scaffolds, with seed contents.
- `init-detection.md` — the single authoritative init-mode classifier (Greenfield / Unaligned / Initialized).
- `greenfield.md` — the Greenfield init behavior body (scaffold + seed + CLAUDE.md + gate).

## Gates (`gates/`)

The gate is `format → lint → test`, run in that order before a slice is
`Implemented`. **Rust is the only verified gate** (`gates/rust.md`). For an unknown
stack, init identifies the tooling, creates the gate, confirms with the owner, runs
it green once, and records a new `gates/<stack>.md`.

## Model tiers (ADR 0002)

researcher `haiku` · developer `sonnet` · planner + plan-evaluator + code-evaluator
`opus`. Only tiers are pinnable; exact versions track the environment.

## Roles (ADR 0001, 0004)

The orchestrator (the main `/loom:run` session) spawns five cold role agents; they
hand off through `.docs/` files and a commit per handoff. Evaluators review blind; no
role approves its own work. Plugin commands are namespaced `/loom:<name>`; agents are
`loom:<role>`.

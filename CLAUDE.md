# CLAUDE.md — loom

loom is a Claude Code skill that automates a spec-driven development loop with
five blind-reviewed roles. This file is the entry point for any agent working in
this repo.

## Read first

1. `.docs/spec/README.md` — reading order and non-negotiable decisions.
2. The specific spec for the area you are changing.
3. `.docs/status/handoff.md` — restart instructions and current next step.
4. `.docs/status/progress.md` — status source of truth.

## What loom is (one paragraph)

loom is a Claude Code **plugin**. The **orchestrator is the main session running
the `/loom` command**; it spawns five cold role agents — researcher, planner, plan
evaluator, developer, code evaluator — each on a chosen model **tier** (sub-agents
can't spawn sub-agents, so only the orchestrator spawns). Roles never share live
context; they hand off through files in `.docs/`, and **every handoff commits**.
An artifact's **status** is the dispatcher. Evaluators review work **blind** (no
author identity, no author reasoning, diffing commits), and no role ever reviews
work it produced — role separation guarantees no self-approval. Specs are frozen
after approval and change only via planning. Design decisions are in
`.docs/spec/` and `.docs/ADR/` (ADRs 0001–0006).

## Repo layout (M1)

- The **shippable plugin** lives in `plugins/loom/` (`commands/loom.md`, `agents/`,
  `skills/loom-playbook/`); the marketplace catalog is `.claude-plugin/marketplace.json`.
- `.docs/` is loom's **own** design memory (dogfooding) — not a plugin component.
- No compiled code: loom is markdown (prompts/templates), so this repo has no gate
  to run. The Rust gate loom *imposes on managed projects* is in
  `plugins/loom/skills/loom-playbook/gates/rust.md`.
- When editing the playbook/agents, keep them consistent with `.docs/spec/` + ADRs.

## Project conventions

- Durable memory is `.docs/spec/` and `.docs/ADR/`. Specs win over plans on
  conflict. ADRs are immutable after acceptance (supersede, never rewrite).
- Transient working memory is `.docs/slice-plans/`. Plans propose; specs decide.
- Evaluation verdicts live in `.docs/evaluations/<artifact-name>-eval.md`.
- The three living docs in `.docs/status/` (roadmap, progress, handoff) are kept
  separate, each with one job.

## Gate

The standard loom gate is **format → lint → test**, run in that order before any
slice is considered `Implemented`. **Rust is the only verified gate**
(`cargo fmt --check` → `cargo clippy --all-targets -- -D warnings` → `cargo test`);
for other stacks, loom identifies and creates the gate during init and records it
back into the playbook. loom imposes this gate on managed projects and on itself.
This repo has no compiled code yet, so it has no concrete gate to run.

## Update this file before committing

Keep this file and `.docs/` current with the design as it evolves, per the user's
workflow rule.

# Session Handoff

Status: Living

Restart instructions and compact current context. `progress.md` is the status
source of truth; `roadmap.md` is milestone order.

## Start here each session

1. Confirm repo:
   ```sh
   cd /Users/craig/git/loom
   git status --short
   ```
2. Read `.docs/spec/README.md`, then `.docs/status/progress.md` and this file.

## Where things stand

- loom is finishing **design (M0)**. The spec spine (`00`–`10`) is revised and the
  firm decisions are captured in ADRs 0001–0006.
- No plugin code yet (no `commands/`, `agents/`, `skills/` — those are M1).
- loom is its own git repo (`master`), distributed later as a single-plugin
  self-marketplace (ADR 0006).
- Design derived in conversation with the owner, informed by the prototype at
  `/Users/craig/git/ballboy` and by Anthropic's `feature-dev`/`plugin-dev`
  plugins (see `research/2026-06-07-claude-code-plugin-mechanics.md`).

## Key decisions to carry forward

- Orchestrator = the main `/loom` session; it spawns all roles (sub-agents can't
  spawn sub-agents). Roles are cold; every handoff commits; evaluators diff.
- Blind eval by controlled inputs + role separation. Specs frozen after approval
  (planner-only changes). Models by tier. Rust-only verified gate; others learned.
- Parallelism designed-for (worktree-per-slice) but built after the sequential
  loop.

## Immediate next steps

1. Owner final review of the revised spec + ADRs.
2. Begin **M1 — Minimum loop** (see `roadmap.md`): scaffold the plugin, write the
   five agents and the `/loom` orchestrator, and the playbook with the Rust gate.
3. Before/while building M1, resolve OQ-D (command namespacing), OQ-E (marketplace
   root form `source:"."` vs `plugins/loom/`), OQ-F (keep helpers in-prompt/shell
   for portability) — verify each against current Claude Code docs.

## Notes for the next agent

- The spec is stabilizing but still `Draft`; confirm material changes with the
  owner.
- Verify the marketplace root-plugin form and `/plugin` install commands against
  current docs before relying on them (only local examples were inspected).

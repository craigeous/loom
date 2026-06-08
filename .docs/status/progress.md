# Progress

Status: Living

The status source of truth and decision index for building loom.

## Current state

- **Phase:** M1 — Minimum loop. **Scaffold built; not yet run end-to-end.**
- **Last action:** built the loom plugin — manifests (`marketplace.json`,
  `plugins/loom/.claude-plugin/plugin.json`), the five role agents, the
  `skills/loom-playbook/` (templates, rubrics, conventions, Rust gate), and the
  `/loom` orchestrator command. Resolved OQ-D/E/F.
- **Next:**
  1. Install (`/plugin marketplace add ./loom` → `/plugin install loom@loom`) and
     `/plugin validate`; confirm `/loom` resolves and the `loom:*` agents load.
  2. First real run: a sequential single slice on a throwaway target to exercise
     the full loop (research/plan → eval → develop → eval → land).

## Accepted decisions (ADRs)

0001 plugin/orchestrator · 0002 model tiers · 0003 commit-per-handoff · 0004 blind
eval + role separation · 0005 frozen specs · 0006 self-marketplace (subdir layout).

## Resolved build-time questions (M1)

- OQ-D — one `/loom` command dispatches on its first argument; roles are `agents/`.
- OQ-E — plugin under `plugins/loom/`, `source: "./plugins/loom"` (root undocumented).
- OQ-F — no compiled helpers; agents do detection/parsing with their own tools.

## Open

Deferred to later milestones: OQ-A (parallel `.docs/` coordination — M3), OQ-B
(research-review tier — empirical), OQ-C (finalize-pass owner). See
[`../spec/09-open-questions.md`](../spec/09-open-questions.md).

## Known unknowns to verify on first install

- Exact invocation string for the command (`/loom` vs `/loom:loom`) and the Task
  `subagent_type` form for namespaced agents (`loom:researcher` vs `researcher`).
- Whether `/plugin marketplace add ./loom` + `source: "./plugins/loom"` resolves as
  expected locally.

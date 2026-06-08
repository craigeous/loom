# Progress

Status: Living

The status source of truth and decision index for building loom.

## Current state

- **Phase:** M1 — Minimum loop. **COMPLETE** (built, installed, run end-to-end).
- **Last action:** ran the first full sequential slice on a throwaway Rust sandbox
  (`/Users/craig/git/loom-sandbox`, `slugify`): planner → blind plan-eval (PASS) →
  developer (Rust gate green) → blind code-eval (re-ran gate, PASS) → finalize +
  archive. Both evaluators ran blind and independently flagged the same lone MINOR.
- **First-run finding (fixed):** the code-eval agent committed under a stray git
  identity `loom <loom@localhost>`, violating ADR 0003's uniform-identity rule.
  Fixed the playbook commit-convention: roles must not set/override git `user.*`.
- **Next:** M2 — init modes (greenfield / unaligned alignment / initialized) and
  gate learning; then M3 parallelism (the worktree research note is ready input).

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

## Verified at first install (M1)

- Local marketplace add + `source: "./plugins/loom"` installs cleanly; `/plugin
  validate ./loom` passes.
- Plugin components are **namespaced** — no bare `/loom`. Command surface split into
  one file per command (`/loom:run` + one-off `/loom:<role>`); agents are
  `loom:<role>`. `${CLAUDE_PLUGIN_ROOT}` resolves correctly.
- **Rung 1 passed:** `/loom:run` (status) loads, reads `.docs/` + git, and reports.

## Verified at rung 2 (first agent spawn)

- `subagent_type: loom:researcher` resolves — the orchestrator spawns a namespaced
  plugin agent via the Task tool. The haiku researcher wrote a cited note
  (`Status: Research Review`, sources + citations) and committed author-neutral;
  the orchestrator verified it. The full spawn → work → commit → verify pipeline
  works for one role.
- Remaining for M1: rung 3 — first full slice (plan → eval → develop → eval → land)
  on a throwaway target.

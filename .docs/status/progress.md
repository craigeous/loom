# Progress

Status: Living

The status source of truth and decision index for building loom.

## Current state

- **Phase:** M2 — Init modes & gate learning. **In progress.**
- **Last action:** M2 slice 1 (init-mode detection classifier) landed.
  Both plan-eval and code-eval ran blind and independently: both PASS.
  Deliverable: `plugins/loom/skills/loom-playbook/references/init-detection.md` —
  the single authoritative, executable init-mode classifier. Four call sites
  (`orchestration.md`, `init.md`, `run.md`, `status.md`) repointed at it;
  divergent restatements removed. Slice archived at commit 5fef2ed.
- **Evaluator hardening (dogfooding):** a planted-defect battery (plan/spec
  contradiction, green-but-wrong code, misleading tests, scope creep) confirmed
  blind evaluators catch gate-invisible defects — all FAILed for the right reason.
  Added `references/severity.md` (single-source BLOCKER/MAJOR/MINOR → PASS/FAIL),
  repointed both rubrics + the evaluation template at it, and anchored the
  code-evaluator's verdict vocabulary on the template regardless of phrasing.
- **First-run finding (fixed, M1):** the code-eval agent committed under a stray
  git identity `loom <loom@localhost>`, violating ADR 0003's uniform-identity rule.
  Fixed the playbook commit-convention: roles must not set/override git `user.*`.
- **Next:** M2 slice 2 — per-mode behaviors (greenfield scaffold, unaligned
  alignment + descriptive back-fill, initialized summarize/continue) and gate
  establishment. The classifier in `init-detection.md` is the input; behavior
  bodies are the next M2 slice(s).

## Accepted decisions (ADRs)

0001 plugin/orchestrator · 0002 model tiers · 0003 commit-per-handoff · 0004 blind
eval + role separation · 0005 frozen specs · 0006 self-marketplace (subdir layout).

## Resolved build-time questions (M1)

- OQ-D — command surface is split into namespaced `/loom:<name>` commands
  (`/loom:run` + one-off role commands); roles are `agents/` (`loom:<role>`).
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

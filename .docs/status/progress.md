# Progress

Status: Living

The status source of truth and decision index for building loom.

## Current state

- **Phase:** M2 — Init modes & gate learning. **In progress.**
- **Last action:** M2 slice 2 (Greenfield init behavior body) landed.
  Both plan-eval and code-eval ran blind and independently: both PASS (code-eval
  Round 2 PASS at commit a58ff7e; one MINOR recorded — spec 06 §1 says seed
  "empty" status files while `greenfield.md` seeds `progress.md`/`handoff.md` with
  phase metadata; non-blocking, noted in open/decision index below).
  Deliverable: `plugins/loom/skills/loom-playbook/references/greenfield.md` —
  the single authoritative Greenfield behavior body (scaffold + seed + CLAUDE.md +
  gate). Three call sites (`orchestration.md`, `run.md`, `init.md`) repointed at
  it; the Greenfield branch wired to the body. Slice archived.
- **M2 slice 1 (previously landed):** init-mode detection classifier in
  `plugins/loom/skills/loom-playbook/references/init-detection.md`. Four call
  sites repointed at it; divergent restatements removed. Archived at commit 5fef2ed.
- **Evaluator hardening (dogfooding):** a planted-defect battery (plan/spec
  contradiction, green-but-wrong code, misleading tests, scope creep) confirmed
  blind evaluators catch gate-invisible defects — all FAILed for the right reason.
  Added `references/severity.md` (single-source BLOCKER/MAJOR/MINOR → PASS/FAIL),
  repointed both rubrics + the evaluation template at it, and anchored the
  code-evaluator's verdict vocabulary on the template regardless of phrasing.
- **Red-gate discipline (dogfooding, fixed):** with a pre-existing out-of-scope
  test failure (red gate), the developer implemented its slice correctly but
  marked it `Implemented` anyway, rationalizing "pre-existing / out of scope" —
  violating the gate rule. The blind code-evaluator caught it (red gate = auto
  BLOCKER → FAIL), so a red slice can't land, but the developer shouldn't hand one
  off. Hardened `agents/developer.md`: a red gate blocks `Implemented` regardless of
  cause; if the red is out-of-scope, escalate (`Needs Clarification`) instead of
  proceeding.
- **First-run finding (fixed, M1):** the code-eval agent committed under a stray
  git identity `loom <loom@localhost>`, violating ADR 0003's uniform-identity rule.
  Fixed the playbook commit-convention: roles must not set/override git `user.*`.
- **Next:** M2 slice 3 — Unaligned back-fill: study the repo, scaffold (reusing the
  Greenfield body in `greenfield.md`), then descriptive `spec/` back-fill mapping
  what the project currently is (spec `06 §2`). Follow-up slices: Initialized
  resume menu (spec `06 §3`, "initialized-init-behavior"), and gate-learning for
  unknown stacks ("gate-learning").

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

**Open spec clarification (non-blocking):** code-eval MINOR on greenfield-init-behavior
— spec `06 §1` says seed "empty" status files, but `greenfield.md` seeds
`progress.md` and `handoff.md` with phase metadata (Phase: init / Greenfield
scaffold complete; next step: declare scope and run `/loom:run`). Spec `06` may
need a clarification distinguishing "empty" (no prior design content) from
"blank" (zero bytes). Not acted on here; warrants a spec-clarification slice if
the ambiguity causes a future conflict.

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

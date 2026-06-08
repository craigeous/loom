# Progress

Status: Living

The status source of truth and decision index for building loom.

## Current state

- **Phase:** M2 — Init modes & gate learning. **In progress.**
- **Last action:** `retire-code-review-status-token` slice landed (commit a85885f,
  code-eval PASS). The obsolete `Code Review` status token has been removed repo-wide
  from `SKILL.md`, `status-machine.md`, `developer.md`, and the slice-plans README
  `Lifecycle:` string. All four lifecycle strings now read
  `… → Implemented → (code review) → Landed → Archived`, matching spec 03.
  The deferred follow-up tracking this work is now resolved (see Resolved below).
- **Prior action:** retroactive spec-approval pass completed. All ten content specs
  (00–08, 10) ran through blind plan-eval and are now `Status: Approved`, each with
  an eval record in `.docs/evaluations/spec-*-eval.md`. Several FAILed round 1 and
  were fixed before approval — evidence the blind review caught real drift:
  - **00** — loom called a "skill" not a "plugin"; bare `/loom` instead of
    `/loom:run`; stale status labels.
  - **01** — old "specs change at landing / fold back into specs" model corrected to
    the frozen-spec model (ADR 0005).
  - **02** — bare `/loom` → `/loom:run` plus 3 minors.
  - **03** — `Code Review` was a phantom first-class status; reconciled so the code
    evaluator dispatches off `Implemented`.
  - **10** — agent-frontmatter verified-fields list corrected to
    `name,description,model,color,tools`; M3 isolation/background reframed as
    forward-looking.
  - 04, 05, 07, 08 passed round 1.
  Spec `09-open-questions.md` and the spec `README.md` are not frozen designs and are
  now `Status: Living` (09 is a live OQ tracker; README is the spec index).
- **Prior action:** resolved the spec 06 §1 "empty" vs scaffold-metadata
  clarification: spec `06 §1` was amended and re-approved (blind plan-eval PASS,
  commit 86fa7d1, eval `spec-06-status-seed-clarification-eval.md`) to define
  "empty" as no design content — authorizing the scaffold metadata
  `greenfield.md` seeds. The prior code-eval MINOR is now closed.
- **Earlier:** M2 slice 2 (Greenfield init behavior body) landed.
  Both plan-eval and code-eval ran blind and independently: both PASS (code-eval
  Round 2 PASS at commit a58ff7e; the one MINOR — spec 06 §1 "empty" vs
  `greenfield.md` phase metadata — has since been resolved, see Prior action).
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

## Resolved build-time questions (M2)

- Spec 06 §1 "empty" vs scaffold-metadata (was a code-eval MINOR on
  greenfield-init-behavior): spec `06 §1` was amended and re-approved (commit
  86fa7d1, eval `spec-06-status-seed-clarification-eval.md`) to define "empty" as
  no design content, authorizing the scaffold/phase metadata `greenfield.md` seeds.

## Open

Deferred to later milestones: OQ-A (parallel `.docs/` coordination — planner owns,
M3), OQ-B (research-review tier — owner leans haiku-sufficient, decide empirically),
OQ-C (finalize-pass owner — owner undecided, wants a compare-and-contrast of
re-spawned cold role vs. orchestrator-direct before choosing). Owner guidance is
recorded inline in [`../spec/09-open-questions.md`](../spec/09-open-questions.md).

Deferred follow-ups discovered during the retroactive spec-approval pass (flagged
for a future slice / owner decision):

- **Bare `/loom` in ADR 0001 (and possibly the spec README history)** still appears.
  ADRs are immutable (ADR 0005 / 0004 discipline), so this needs a **superseding ADR
  or an erratum note, not a rewrite**. Owner decision.
- ~~**The "Code Review" phase-label string**~~ **Resolved (commit a85885f).** The
  `Code Review` status token has been retired repo-wide. All four lifecycle strings
  (`SKILL.md`, `status-machine.md`, `developer.md`, slice-plans `README.md`) now
  match spec 03: `… → Implemented → (code review) → Landed → Archived`. Only
  legitimate action-phrasing and historical eval/status records remain.
- **Commit-identity guard gap.** The role guard blocks `git config` and `-c user.*`
  but **not** `--author=` or `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env vars — a planner
  commit slipped through as `loom <loom@localhost>` this run and had to be repaired.
  `commit-convention.md` / the agent guards should close that hole.

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

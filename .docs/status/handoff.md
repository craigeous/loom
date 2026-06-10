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

- **Post-M4: implementing ADR 0009 (Unaligned-migrate), from the ballboy field report.**
  ADR 0009 Accepted; **spec 06 amended + Approved** (commit 7b2808b) — Detection branches
  Unaligned → migrate/bare; §2 split into 2a bare (back-fill) + 2b migrate (reconcile: named
  migrate/thin-pointer/abort gate; status preservation; inline `/loom:init`; recipe deferred).
  **Remaining: 3 playbook conformance slices** (normal plan→eval→develop→eval→land each):
  (1) `init-detection.md` undotted-spine signal; (2) new migration-recipe reference
  (ordered+idempotent cross-ref rewrite, numbered-spine→spec/status split, operational
  gotchas — git-mv-skips-untracked, NUL-delimited lists, dirty-tree check); (3) split
  `unaligned.md` into bare+migrate flows pointing at (1) + (2). Do (1)+(2) before (3).
- **M4 COMPLETE — all M0–M4 milestones done.** Owner-gates/round-limit escalation
  (polished + live-tested) ✓, CLAUDE.md auto-propagation ✓, identity-verification hardening
  (emergent) ✓, `claude -p` evaluated & closed ✓ (reserve in spec 04), resume across
  machines ✓, and the holistic "loom manages its own development end to end" ✓ (this whole
  session is the evidence — every change ran the full blind loop via the orchestrator with
  real defects caught pre-merge). **No planned milestones remain.** Future work is
  owner-directed: new ADR/spec-driven features or a packaging/release pass. The loom plugin
  is built, installed, validated, dogfooded end-to-end, and on GitHub (`craigeous/loom`,
  branch `main`).
- **M4 CLAUDE.md auto-propagation — COMPLETE** (both cycles landed). Cycle 1: specs 03 + 08
  amended + Approved (commit 56e1a8d). Cycle 2: playbook conformance landed (commit b661f7a,
  code-eval PASS round 0) — the developer finalize pass now has an explicit step to maintain
  `CLAUDE.md` as a **curated digest** (spec 03 finalize step 2; boundary in spec 08
  *Evolving the playbook → CLAUDE.md auto-propagation*): update only when the slice changed
  a durable convention / repo-layout fact / gate definition / read-first pointer; per-slice
  history stays in `progress.md`; covers root and managed-project CLAUDE.md. Five playbook
  files updated to reflect and point to spec 08. Slice `claude-md-autopropagation-conformance`
  archived. Non-blocking MINOR (spec 08 template bullet lacks forward-link to the
  auto-propagation subsection) is carried — requires its own spec-amendment planning cycle.
- **M4 escalation thread — COMPLETE** (roadmap item "owner approval gates, round
  limits/escalation polished" ✓). Cycle 1: spec 03 `## Round limits` amended + Approved
  (commits 5de67fd → df72df0); `Round:` counts FAIL cycles only, one cross-phase counter
  per artifact, escalation pause+summary contract defined. Cycle 2: playbook conformance
  landed (commit f161fa0, code-eval PASS Round 0) — `status-machine.md`,
  `orchestration.md`, eval template, and both evaluator prompts match the amended spec
  (evaluators no longer number PASSes as new rounds). Slice `round-limit-conformance`
  archived. **Live 5-round stress-test passed** (throwaway fixture, since removed): real
  blind evals continued the counter 3→4→5 on a recurring BLOCKER, and the orchestrator
  halted at the 5th FAIL with the full escalation summary (thrashing classification +
  owner options) instead of dispatching a 6th revision.
  **M4 finding (identity-guard gap) — ADDRESSED:** the recurring `loom@localhost` fallback
  identity issue (M1 + M4, planner commit d008bc3) is now closed structurally by the
  `identity-verification-hardening` slice (commit a816979, code-eval PASS round 0): init
  verifies a real identity is configured and stops if absent (Greenfield Step F, pointed at
  by Unaligned/Initialized); agents verify the commit identity after committing (single-sourced
  in `commit-convention.md`; all five agent prompts carry a pointer). A separate one-off
  environment mitigation (repo-local git identity set by orchestrator) is also in place.
  **Remaining M4 threads:** CLAUDE.md auto-propagation; resume-across-machines; `claude -p`
  deep-nesting fallback.
- **M4 (Dogfooding & hardening) in progress.** `shell-gate` slice landed (commit
  34de27c, code-eval PASS Round 3, gate green 28/28): first end-to-end exercise of
  the gate-learning mechanism on real code. Delivered: 28-case bats suite for
  `git-identity-guard.sh`, `gates/shell.md` (Status: Verified), root `CLAUDE.md`
  Shell gate section. Plan-eval caught a real BLOCKER (jq-absent recipe), fixed
  Round 2. Deferred M2 follow-up `gates/shell.md` is **DONE**. Also landed: ADR
  0008 folded into frozen specs 04 + 08 (commit c3cd354, plan-eval PASS,
  owner-approved) — driven through loom's own loop in strict route-only mode with
  zero orchestrator intervention. Spec 04's Parallelism section now states ADR 0008's
  coordination model; spec 08 records the slice-plans-index ownership change.
  M0–M3 all complete.
- **M3 (Parallelism) is complete**, including the live parallel demonstration.
  `references/parallelism.md` (ADR 0008) is the single authoritative
  worktree-per-slice operational body. The model was proven end-to-end: 2 developer
  agents ran in parallel worktrees (`slice-casing` / `slice-reverse`), each isolated
  to a disjoint module, each gate-green independently (commits f66aeca, fb71dad);
  serial land → master with no conflicts; integrated gate green (21 unit + 2
  doc-tests); worktrees and branches cleaned up cleanly. ADR 0008's
  conflict-free-by-construction model is confirmed in practice. **M2 and M3 are
  both complete.**
- **M1 is complete.** The loom plugin under `plugins/loom/` is built, installed,
  validated, and **run end-to-end**: command surface is split into namespaced
  `/loom:<name>` commands; agents are `loom:<role>`; the full slice loop works
  (planner → blind plan-eval → developer+gate → blind code-eval → finalize/archive).
- **M2 slice 1 landed (5fef2ed).** Init-mode detection is now single-sourced in
  `plugins/loom/skills/loom-playbook/references/init-detection.md` — concrete
  classifier with defined "loom-shaped" and "empty/near-empty" tests; four call
  sites repointed. Both plan and code evals: PASS (blind, independent).
- **M2 slice 2 landed (a58ff7e).** Greenfield init behavior is now single-sourced in
  `plugins/loom/skills/loom-playbook/references/greenfield.md` — concrete ordered
  steps: scaffold `.docs/`, seed `status/`, write project `CLAUDE.md`, establish
  the gate, commit + hand back. Three call sites (`orchestration.md`, `run.md`,
  `init.md`) repointed at it. Both plan and code evals: PASS (blind, independent;
  one MINOR on status file seeding — non-blocking). Deferred follow-up slices:
  unaligned-init-behavior, initialized-init-behavior, gate-learning.
- **`author-identity-enforcement-guard` landed (a47bf95).** PreToolUse hook
  (`plugins/loom/hooks/hooks.json` + `git-identity-guard.sh`) and hardened
  `commit-convention.md` now block all identity-override paths (`--author=`,
  `-c user.*`, `GIT_AUTHOR_*`/`GIT_COMMITTER_*`). 26-case acceptance matrix
  passed; jq-absent grep-fallback verified; code-eval Round 4 PASS (independent
  re-verification). Slice archived. The commit-identity guard gap follow-up is
  resolved. One new Open item: `--author` detection is not scoped to
  commit-creating subcommands, so read-only commands like `git log --author=` are
  also blocked — a usability refinement candidate for a future slice.
- **`retire-code-review-status-token` landed (a85885f).** The obsolete `Code Review`
  status token removed repo-wide from `SKILL.md`, `status-machine.md`,
  `developer.md`, and the slice-plans README `Lifecycle:` string. All lifecycle
  strings now match spec 03: `… → Implemented → (code review) → Landed → Archived`.
  Slice archived.
- **`gate-learning` landed (b2463c4). M2 complete.** Gate-learning for unknown
  stacks is now single-sourced in
  `plugins/loom/skills/loom-playbook/references/gate-learning.md` — the authoritative
  mechanism: inspect toolchain → propose `format → lint → test` → owner-confirm →
  run-green-once → record `gates/<stack>.md` + project `CLAUDE.md`; UNVERIFIED until
  green; idempotent for known stacks. The three init bodies had their stale
  "forthcoming/deferred" forward pointers replaced with live links. `SKILL.md` +
  root `CLAUDE.md` updated. Code-eval Round 2 PASS (blind, independent). Slice
  archived. **M2 (Init modes & gate learning) is now complete** — all four items
  delivered: Detection classifier, per-mode trio (Greenfield/Unaligned/Initialized),
  idempotent re-application, gate-learning.
- **`initialized-init-behavior` landed (b0bd3e9).** Initialized init behavior is now
  single-sourced in `plugins/loom/skills/loom-playbook/references/initialized.md` —
  resume: state-derived menu from `.docs/` + git state mapped to the dispatch table
  in `status-machine.md`; scope + gates + driver-loop handoff; Q10 idempotent
  playbook re-application single-sourced here (auto-apply clean, recommend for
  conflicts, never clobber). Three call sites (`orchestration.md`, `run.md`,
  `init.md`) repointed. Code-eval Round 2 PASS (blind, independent). Slice archived.
  The per-mode behavior trio (Greenfield + Unaligned + Initialized) is complete.
- **`unaligned-init-behavior` landed (e83e219).** Unaligned init behavior is now
  single-sourced in `plugins/loom/skills/loom-playbook/references/unaligned.md` —
  alignment pass: study the repo, scaffold + gate (reusing `greenfield.md` Steps
  A–E), descriptive `spec/` back-fill with explicit no-decisions boundary, seed
  `status/`, leave project ready to resume as Initialized. Three call sites
  (`orchestration.md`, `run.md`, `init.md`) repointed. Code-eval Round 2 PASS
  (blind, independent). Slice archived.
- **`recommended-tooling-and-mechanical-checks` landed (db39d44).** New
  `plugins/loom/skills/loom-playbook/references/tooling.md` (recommended CLI/LSP
  toolkit by role, all optional with fallback). "Invariants verified mechanically"
  rule added to both eval rubrics (`plan-eval-rubric.md`, `code-eval-rubric.md`);
  cross-links in `SKILL.md` and three agent files. Root cause of prior eval misses
  (eyeballing invariants) is now addressed. Slice archived.
- **`scope-identity-guard-to-commit-subcommands` ABANDONED (commit d35b565).** Guard
  scoping was attempted across two code-eval rounds; the blind evaluator caught a
  real security regression each time (override reaching exit 0, author=Evil
  confirmed). Owner reverted to unconditional `--author` blocking. The read-filter
  false-positive (`git log --author=alice` blocked) is now an ACCEPTED, DOCUMENTED
  limitation in `commit-convention.md`. Slice archived as Abandoned.
- **Published:** GitHub repo `craigeous/loom` (public), default branch `main`.
- **All ten content specs (00–08, 10) are `Status: Approved`** after a retroactive
  blind plan-eval pass (eval records in `.docs/evaluations/spec-*-eval.md`). Several
  FAILed round 1 and were fixed (00/01/02/03/10) — see `progress.md` for the
  findings. Spec `09-open-questions.md` and the spec `README.md` are now
  `Status: Living` (09 is a live OQ tracker; README is the index).
- Design + decisions stable in `.docs/spec/` (00–10) and `.docs/ADR/` (0001–0006).
- **Deferred follow-ups from the spec pass** (in `progress.md` Open, for a future
  slice / owner decision): bare `/loom` in ADR 0001 needs a superseding ADR or
  erratum (ADRs are immutable — no rewrite). ~~The "Code Review" phase-label string~~
  is **resolved** (commit a85885f — token retired repo-wide). ~~The commit-identity
  guard gap~~ is **resolved** (commit a47bf95 — hook + doc hardening).
  ~~Eval-miss root cause (eyeballing invariants)~~ is **resolved** (commit db39d44 —
  mechanical-check rule in both rubrics + `tooling.md`).
- **Open items:** (a) spec-10 line-107 bare-`/loom` — frozen-spec planner cycle
  required; (b) guard `--author` not scoped to commit-creating subcommands —
  **RESOLVED by decision** (scoping abandoned, unconditional blocking retained,
  read-filter false-positive documented as accepted limitation in
  `commit-convention.md`, commit d35b565).

## Immediate next steps

1. **M4 — Dogfooding & hardening:** remaining threads:
   - **CLAUDE.md auto-propagation:** best practices propagated into root/project
     `CLAUDE.md` automatically.
   - **Escalation/round-limit stress-test:** owner approval gates, round
     limits/escalation polished.
   - **Resume-across-machines:** resume-after-interruption verified across machines.
   - **`claude -p` evaluate-and-close:** `claude -p` fallback evaluated if deeper
     nesting is needed.
2. **DONE — fold ADR 0008 into spec 04 (and spec 08):** completed as M4 dogfood
   run #1 (commit c3cd354, plan-eval PASS, owner-approved). Both specs re-Approved;
   spec 04's Parallelism section now carries ADR 0008's coordination model and spec
   08 records the slice-plans-index ownership change.
3. **DONE — `gates/shell.md`:** produced as M4 dogfooding via the gate-learning
   mechanism on loom's own hook (shell-gate slice, commit 34de27c, gate green 28/28).
   `gates/shell.md` is Status: Verified; 28-case bats suite committed.
4. **Spec-10 line-107 bare-`/loom` fix:** spec 10 still contains a bare `/loom`
   reference at line 107. This is a frozen-spec planner cycle (propose an amendment,
   plan-eval, amend via planning — not a direct edit). The mechanical-check rule now
   in the rubrics ensures this kind of miss is caught earlier in future reviews.

## Notes for the next agent

- Commits are **author-neutral** AND under a **single uniform git identity** —
  roles must not set/override `user.*` (commit-convention; learned from the M1
  first run, where an agent strayed to `loom@localhost`).
- Command surface is `/loom:run` + one-off `/loom:<role>`; agents spawn via Task
  `subagent_type: loom:<role>` (verified).

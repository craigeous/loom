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

- **M3 (Parallelism) behavior is specified and landed.** `references/parallelism.md`
  is the single authoritative worktree-per-slice operational body (ADR 0008), covering
  the create→work→land→cleanup workflow, the `.docs/` coordination model (living docs
  + slice-plans index orchestrator-owned/main-only/serialized; slice branches carry
  only disjoint plan/eval/code), concurrency safety, and the slicer-independence rule.
  Guards in `orchestration.md` + `run.md` relaxed; `SKILL.md` + `CLAUDE.md` updated.
  Slice `parallelism-behavior-body` archived (c6ec48e). **M3 remaining: live
  demonstration** — run 2+ independent slices in parallel worktrees end-to-end to prove
  the model in practice (M3's closeout proof, analogous to M1's rung-3 first-full-slice
  proof). **ADR 0008** (resolves OQ-A) sets the coordination model; OQ-A is Resolved
  in `09-open-questions.md`. **M2 remains complete.**
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

1. **M3 — Live parallel demonstration (closeout proof):** The parallelism behavior
   is fully specified in `references/parallelism.md` (ADR 0008). To close M3, run
   2+ independent/disjoint slices in parallel worktrees end-to-end:
   `git worktree add -b <slice-branch> <worktree-path> origin/main` per slice;
   spawn developer agents in each worktree; land serially from the main worktree
   (serial `git merge <branch>` + finalize pass per slice). This is M3's closeout
   proof — analogous to M1's rung-3 first-full-slice end-to-end proof.
2. **Deferred follow-up — fold ADR 0008 into spec 04 (and spec 08):** spec 04's
   Parallelism section is **frozen/Approved** and still leaves "`.docs/`
   coordination across branches" open; ADR 0008 answers it. This is a deliberate
   **spec-revision planning cycle** (propose amendment → plan-eval → amend per
   ADR 0005), **not** a direct edit and **not** a landing side effect — do NOT
   touch spec 04 outside that cycle. The fold should also note the M1→M3 habit
   change: the slice-plans-index Active/Archived edit moves off the slice branch
   to the orchestrator-on-main path.
3. **Deferred follow-up — `gates/shell.md`:** a first concrete learned gate for
   shell-stack projects (using `shellcheck` as the lint step). The gate-learning
   mechanism is now in place; this gate should be produced by running the mechanism
   on a real shell project (run-green-once is part of the lifecycle, not a
   hand-authored artifact). `shellcheck` is already pointed from `tooling.md`.
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

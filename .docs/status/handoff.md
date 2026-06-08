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
- **Published:** GitHub repo `craigeous/loom` (public), default branch `main`.
- Design + decisions stable in `.docs/spec/` (00–10) and `.docs/ADR/` (0001–0006).

## Immediate next steps

1. **M2 slice 3 — Unaligned back-fill:** study the repo, scaffold (reusing
   `references/greenfield.md` as the scaffold foundation), then author descriptive
   `spec/` back-fill mapping what the project currently is (spec `06 §2`). This is
   the natural next M2 slice — Greenfield provides the scaffold primitive; Unaligned
   adds the descriptive layer on top.
2. **Remaining M2 follow-ups (after Unaligned):** Initialized resume menu (spec
   `06 §3`, slice "initialized-init-behavior") and gate-learning for unknown stacks
   (slice "gate-learning").
3. **M3 — parallelism:** worktree-per-slice + background agents (research note
   `2026-06-08-git-worktree-parallel-slices.md` is ready input; resolve OQ-A).

## Notes for the next agent

- Commits are **author-neutral** AND under a **single uniform git identity** —
  roles must not set/override `user.*` (commit-convention; learned from the M1
  first run, where an agent strayed to `loom@localhost`).
- Command surface is `/loom:run` + one-off `/loom:<role>`; agents spawn via Task
  `subagent_type: loom:<role>` (verified).

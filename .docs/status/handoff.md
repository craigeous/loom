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
- **Published:** GitHub repo `Craigeous/loom` (public), default branch `main`.
- Design + decisions stable in `.docs/spec/` (00–10) and `.docs/ADR/` (0001–0006).

## Immediate next steps

1. **M2 slice 2 — per-mode behaviors:** implement Greenfield scaffold, Unaligned
   alignment + descriptive back-fill, and Initialized summarize/continue. Start
   from the classifier in `init-detection.md` (detection is done; behavior bodies
   are what remains). Gate establishment and idempotent re-application follow.
2. **M3 — parallelism:** worktree-per-slice + background agents (research note
   `2026-06-08-git-worktree-parallel-slices.md` is ready input; resolve OQ-A).

## Notes for the next agent

- Commits are **author-neutral** AND under a **single uniform git identity** —
  roles must not set/override `user.*` (commit-convention; learned from the M1
  first run, where an agent strayed to `loom@localhost`).
- Command surface is `/loom:run` + one-off `/loom:<role>`; agents spawn via Task
  `subagent_type: loom:<role>` (verified).

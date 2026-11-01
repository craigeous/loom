# Session Handoff

Status: Living

Restart instructions and compact current context. `progress.md` is the status
source of truth; `roadmap.md` is milestone order.

Current milestone: M6

## Start here each session

1. Confirm repo:
   ```sh
   cd /Users/craig/git/loom
   git status --short
   ```
2. Read `.docs/spec/README.md`, then `.docs/status/progress.md` and this file.
3. Commits are author-neutral under one uniform git identity; roles must not set or
   override `user.*`. The command surface is `/loom:run` plus one-off `/loom:<role>`.

## Where things stand

- **Next action:** M6 slice 3 `living-doc-shape` (plan Approved) — implement, code-eval, land.
- **M6 progress:** slices 1 `loom-doctor-foundation` and 2 `docs-state-validator` are landed; their
  landing summaries are archived in [`archive/handoff-history.md`](archive/handoff-history.md).
- **Earlier M1–M4 and post-M4 session history:** archived in
  [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays
  within the 150-line cold-start budget (older M1–M5 landing summaries moved there too).

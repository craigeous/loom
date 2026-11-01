# Session Handoff

Status: Living

Restart instructions and compact current context. `progress.md` is the status
source of truth; `roadmap.md` is milestone order.

Current milestone: M9

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

- **Current state:** Milestone M9 slices 1–3 (`herdr-client-adapter`, `herdr-native-app-hooks`, `herdr-verification`) Landed; 952 Bats tests passing. Verification is offline fixtures only.
- **Next action:** Owner decision: run live Herdr/native-app evidence to close M9 (no further planned slice), or plan a follow-up slice via planner. No slice is active.
- **Session history:** Archived in [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays within the 150-line cold-start budget.

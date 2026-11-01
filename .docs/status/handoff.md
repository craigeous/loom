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

## Where things stand

- **Next action:** M6 slice 3 `living-doc-shape` (plan Approved) — implement, code-eval, land.
- **M6 slice 2 `docs-state-validator` LANDED on `main` (2026-10-31):**
  Mechanical documentation state validation in `scripts/validate-repository.mjs` and `scripts/tests/repository-validation.bats`.
  Enforces active slice plan uniqueness, documentation lifecycle status transitions with baseline verification,
  clean owner reset validation, interval-bounded FAIL return evidence, authority reference resolution to applicable files,
  allowlist staleness enforcement under `--all`, and 13 new comprehensive Bats tests (867 total repository Bats tests passing).
- **M6 slice 1 `loom-doctor-foundation` LANDED on `main` (2026-10-31):**
  Read-only foundation diagnostics helper `plugins/loom/bin/loom-doctor` and top-level CLI `plugins/loom/bin/loom`.
  Implements read-only diagnostics across host/OS, required tools (Bash >= 3.2, Git >= 2.34, jq >= 1.6), effective Git author
  identity (`git var GIT_AUTHOR_IDENT`), repository root discovery, `.docs` layout, init modes, coordination state, and
  protocol assets (39 Bats tests, 833 total repository Bats tests passing).
- **Earlier M1–M4 and post-M4 session history:** archived in
  [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays
  within the 150-line cold-start budget (older M1–M5 landing summaries moved there too).

## Notes for the next agent

- Commits are **author-neutral** AND under a **single uniform git identity** —
  roles must not set/override `user.*` (commit-convention; learned from the M1
  first run, where an agent strayed to `loom@localhost`).
- Command surface is `/loom:run` + one-off `/loom:<role>`; agents spawn via Task
  `subagent_type: loom:<role>` (verified).

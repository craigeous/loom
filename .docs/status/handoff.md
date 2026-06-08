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

- **M1 scaffold is built.** The loom plugin exists under `plugins/loom/`:
  `commands/loom.md` (orchestrator), five `agents/*.md`, and
  `skills/loom-playbook/` (templates, rubrics, conventions, Rust gate). Marketplace
  catalog at `.claude-plugin/marketplace.json`.
- **Not yet run.** No end-to-end loop execution; not yet installed/validated.
- Design + decisions are stable in `.docs/spec/` (00–10) and `.docs/ADR/`
  (0001–0006).

## Immediate next steps

1. **Install & validate:**
   ```
   /plugin marketplace add ./loom        (or craigeous/loom once pushed)
   /plugin install loom@loom
   /plugin validate
   ```
   Confirm `/loom` resolves and the `loom:*` agents appear in `/agents`. Note the
   exact command invocation and the Task `subagent_type` form for the agents.
2. **First real run (dogfood):** point `/loom` at a throwaway repo (or a tiny slice
   here) and drive one sequential slice through the full loop. Watch for: blind
   inputs to evaluators, commit-per-handoff being author-neutral, status
   transitions matching the dispatch table.
3. Fix whatever the first run surfaces; then close M1 and move to M2 (init modes /
   gate learning).

## Notes for the next agent

- Commits in this repo are **author-neutral** (no co-author, no role identity) —
  see `plugins/loom/skills/loom-playbook/references/commit-convention.md`.
- The two "known unknowns" (invocation string, subagent_type form) can only be
  confirmed by installing; adjust `commands/loom.md` if the namespacing differs.

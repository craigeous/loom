# 0003 — File-Based Cold Handoffs with a Commit per Handoff

Status: Accepted
Date: 2026-06-08

## Context

Roles are cold agents with no shared live context; they coordinate only through
files. Evaluators need to review exactly what changed, re-reviews need to confirm
prior findings were addressed, and an interrupted loop must resume cleanly. The
owner observed that "if we are doing cold handoffs there should probably always be
a commit to diff against."

## Decision

- All coordination state is files in `.docs/` plus the repo and its git history.
- **Every role pass ends in a commit.** A status transition is always paired with
  a commit.
- Evaluators review the **diff** since the relevant prior commit (code: the
  developer's commit; plan: the artifact's prior version). Re-reviews diff against
  the prior reviewed commit.

## Consequences

- Code review and plan re-review have a precise, blind-friendly artifact: the diff.
- Any interruption resumes from the last commit + status; the orchestrator re-scans
  files and git after every agent.
- Commit-per-handoff is the foundation for safe parallelism: each in-flight slice
  is a branch/worktree, and landing is a merge (see spec 04, ADR 0001).
- **Commit metadata must be author-neutral** because the code evaluator reviews
  commit diffs and `git log` (see ADR 0004). Therefore:
  - **No AI co-author trailers** (no `Co-Authored-By: Claude ...`) and no agent
    or tool attribution in any loom commit.
  - Commit messages describe the **change / artifact / status**, never the role or
    author that produced it.
  - All roles commit under a **single, uniform git author/committer identity**, so
    the evaluator cannot infer the producing role from commit metadata.
  - This is a playbook item (commit-message template + git identity config) and is
    enforced by the orchestrator/role prompts.

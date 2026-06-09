# Research: git worktree workflow for parallel slices

Status: Approved
Date: 2026-06-08
Topic: How git worktree isolates parallel slice work and the workflow for landing changes back to main; constraints relevant to concurrent agent execution in loom's M3 parallelism milestone.

## Summary

### How git worktree works

- **Purpose:** git worktree allows a single repository to have multiple working trees checked out simultaneously, each with its own branch and working directory, without the need to stash or reset branches. [1]
- **Shared object store:** All worktrees share the repository's git objects (commits, blobs, trees) and most refs, reducing disk overhead. [1]
- **Separate per-worktree state:** Each worktree maintains its own `HEAD`, `index` file, and working directory. The linked worktree's `.git` is a file (not a directory) containing a `gitdir:` pointer back to the main repository's worktrees metadata directory. [1]

### Core operations

- **Add:** `git worktree add <path> [<commit-ish>]` creates a new worktree at `<path>`. With `-b <branch>`, it creates and checks out a new branch; without `-b`, it creates a branch inferred from the path's basename or creates one from `HEAD`. [1][2]
- **List:** `git worktree list` shows the path, commit, and branch of each active worktree; `-v` adds verbose output; `--porcelain` provides machine-readable format. [1]
- **Remove:** `git worktree remove <path>` deletes the worktree; `-f` forces removal of unclean worktrees. [1]
- **Move/Lock/Repair:** Worktrees can be moved (`git worktree move`), locked to prevent auto-pruning on portable media, and repaired if manually moved. [1]

### Branch checkout constraint and enforcement

- **Single-checkout rule:** A branch can be checked out in only one worktree at a time by default. `git worktree add` refuses to create a worktree for a branch already checked out elsewhere. [1][2]
- **Force override:** The `-f` or `--force` flag allows breaking this rule but is not recommended in normal workflows. [1]
- **Why it matters for loom:** Each in-flight slice must have its own unique branch; two agents cannot work on the same branch in parallel. [1]

### Merge workflow to land changes

- **Standard sequence:** Work (commits) are made in the worktree on its branch. To land: navigate to the main worktree, ensure it is updated (`git pull`), merge the slice branch (`git merge <slice-branch>`), push to remote, and verify the merge. Then remove the worktree with `git worktree remove <path>`. [2][3]
- **Conflict handling:** If main has diverged, rebase or merge the slice branch first, resolve conflicts in the worktree, then merge cleanly into main from the main worktree. [2]
- **No special syntax required:** Merging from a worktree branch to main is identical to merging any feature branch—git handles the branch names, not the worktree locations. [3]

### Gotchas for concurrent agent execution

1. **Index lock collisions:** Git creates transient `index.lock` files during write operations (add, commit, etc.). If N agents commit simultaneously on N branches in N worktrees, lock collisions are inevitable because certain operations still acquire locks on the shared `.git/` directory. [4] Recommended mitigation: exponential backoff retry (3–5 attempts at 200ms, 400ms, 800ms intervals) when a git commit fails with an `index.lock` error. [4]

2. **Submodule overhead and incompatibility:** Each worktree receives its own copy of all submodules, multiplying disk usage. Git's documentation notes submodules with worktrees are "still documented as experimental." Avoid worktrees entirely if the repo uses submodules. [1][5]

3. **Untracked and ignored files are not shared:** Each worktree has its own working directory; `.gitignore` rules are applied per-worktree, but untracked/ignored file state does not synchronize across worktrees. If a worktree creates artifacts (e.g., build output, caches), the main worktree will not see them. [1]

4. **Hooks run per-worktree:** Pre-commit and post-commit hooks execute in the worktree where the commit happens. If hooks assume a single global state (e.g., a central database, a lock file), concurrent hook execution in multiple worktrees can race. [1]

5. **`.git` is a file in linked worktrees:** The linked worktree's `.git` is a plain text file pointing to the main repository's worktrees metadata. Manual deletion or corruption of this pointer breaks the worktree. Use `git worktree move`, not `mv`, and `git worktree repair` if already moved. [1]

6. **No automatic cleanup on agent crash:** If an agent process crashes or is killed, its worktree remains on disk and may leave `index.lock` or other stale lock files. The main worktree cannot auto-detect this; manual `git worktree remove -f` or `git worktree prune` is required to reclaim the directory. [1]

7. **Per-worktree refs:** `HEAD`, `MERGE_HEAD`, and `REBASE_HEAD` are per-worktree, so each worktree can be in a different merge or rebase state. However, shared refs (e.g., `refs/heads/`, `refs/tags/`) are global. [1]

### Workflow suitable for loom

**Create phase:**
```
For each in-flight slice:
  git worktree add -b <slice-branch> <worktree-path> origin/main
  # Orchestrator passes this path to the developer agent as a working directory
```

**Work phase:**
- Developer works, makes commits, and passes control back to the orchestrator when the slice is ready for evaluation or landing.
- Commits use author-neutral metadata (see loom ADR 0003). [6]

**Land phase:**
```
# From the main worktree (orchestrator's control):
git merge <slice-branch>
git push origin main
# From the orchestrator or a finalize agent:
git worktree remove <worktree-path>
```

**Cleanup:**
- Always remove the worktree after landing. Stale worktrees consume disk and create stale `index.lock` files.
- `git worktree prune` can clean up missing/untracked worktrees older than the default age (3 months).

### Mapping to loom: `.docs/` coordination across branches

loom's `.docs/` directory lives in the repository root and is shared across all worktrees (all read the same files). This raises the open question OQ-A: **Where does status live during parallelism?** [7]

Two scenarios:

1. **Cross-slice dashboard on main, per-slice plan/eval on branches:** The status machine and roadmap stay on the main branch; each slice's plan and evaluation artifacts live on its feature branch. At landing, the slice's artifacts are merged into main, and the dashboard is updated. Coordination requires:
   - The orchestrator must commit status updates on main between slice handoffs (even while slices are in-flight in worktrees).
   - Each agent writes its artifact to `.docs/evaluations/<name>-eval.md` or `.docs/slice-plans/<name>-plan.md` on its own branch.
   - At merge time, the slice's plan/eval history becomes part of main.
   - **Risk:** Main's status/handoff.md is the single source of truth but is not on the slice branches; agents must read it from main even while working on a slice branch. This requires careful coordination and possibly per-worktree stale-state detection.

2. **All `.docs/` on main, per-slice plans stay transient:** The orchestrator updates `.docs/status/` on main; slice plans are written to `.docs/slice-plans/` on main (not on slice branches); slice branches contain only code. Evaluation artifacts are written to main after the slice is evaluated. This simplifies coordination but requires the developer agent to pull/update its view of `.docs/` before each commit (to avoid stale snapshots). [7]

loom has not yet settled this question. The choice affects:
- **Agent input freshness:** If the status is on main and the slice is on a branch, agents must handle potentially stale reads.
- **Merge conflicts:** If multiple slices write to the same `.docs/` file, merging back to main will conflict.
- **Orchestrator responsibility:** The orchestrator must decide when to update `.docs/` on main and when to defer.

## Sources

[1] https://git-scm.com/docs/git-worktree — Official git documentation for `git worktree`; defines operations, constraints, branch checkout rules, linked worktree structure, refs, and concurrent access considerations.

[2] https://www.gitkraken.com/learn/git/git-worktree — Step-by-step guide to adding, listing, removing worktrees, and merging back to main.

[3] https://www.kenmuse.com/blog/using-git-worktrees-for-concurrent-development/ — Best practices and gotchas for concurrent development with worktrees, including submodule incompatibility and cleanup.

[4] https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution — Concurrent agent execution with git worktrees; documents index.lock collision and exponential backoff mitigation.

[5] https://medium.com/ngconf/git-worktrees-in-use-f4e516512feb — Discussion of worktree use cases and experimental status with submodules.

[6] /Users/craig/git/loom/.docs/ADR/0003-cold-handoffs-commit-per-handoff.md — loom's architecture decision to use author-neutral commits and file-based cold handoffs; commit-per-handoff is the foundation for safe parallelism with worktrees.

[7] /Users/craig/git/loom/.docs/spec/04-orchestrator.md (Parallelism section) and /Users/craig/git/loom/.docs/spec/09-open-questions.md (OQ-A) — loom's planned worktree-per-slice parallelism design and the open coordination question for `.docs/` status across branches.

## Open questions

- **OQ-A escalation:** How should the orchestrator handle stale `.docs/` reads when a slice branch is checked out in a worktree? Should agents run `git pull origin main` before reading status, or should status be replicated to every slice branch?
- **Lock file recovery:** What is the recovery procedure if an agent crashes and leaves `index.lock` stale? Should the orchestrator have a per-worktree health check before spawning the next agent?
- **Merge conflict resolution for `.docs/`:** If two slices modify the same plan/eval artifact or roadmap entry, how should the orchestrator resolve the merge when landing both slices in sequence? (This is a variant of OQ-A.)
- **Per-worktree hook safety:** If loom uses git hooks (e.g., pre-commit format/lint), how should hooks be configured to run safely when multiple agents commit concurrently in parallel worktrees?
- **Disk cleanup on long-running sessions:** How often should the orchestrator run `git worktree prune` to reclaim disk from crashed/orphaned worktrees?

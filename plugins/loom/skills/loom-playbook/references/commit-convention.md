# Commit Convention (author-neutral)

Every loom handoff ends in a commit (ADR 0003). Because the code evaluator reviews
commit **diffs** and `git log` as part of *blind* evaluation (ADR 0004), commit
metadata must never reveal who produced the work.

## Rules

- **No AI co-author trailers.** Never add `Co-Authored-By: Claude ...` or any
  agent/tool attribution. (This overrides any global default to add such a line.)
- **No author/role identity in the message.** Do not write "as the developer",
  "planner:", "(researcher)", etc. The message describes the *change*, not the
  *producer*.
- **One uniform git identity** across all roles, so the producing role can't be
  inferred from author/committer metadata. Roles **must not set or override** git
  identity by any means — this is a binding rule regardless of whether the enforcement
  hook fires. Forbidden override paths:
  - `git commit --author=...` (the `--author` flag),
  - `git -c user.name=...` / `git -c user.email=...` / any `-c user.*=...`,
  - `git config user.*` (persistent config change),
  - the environment variables `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`,
    `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` (whether inline `VAR=... git ...`
    or via `export`).

  Always commit under the repository's already-configured identity. If no identity is
  configured, **stop and ask** rather than inventing one (e.g. never commit as
  `loom <loom@localhost>`); the orchestrator/`/loom:init` ensures an identity exists
  before any role commits.

  A plugin PreToolUse hook (`plugins/loom/hooks/git-identity-guard.sh`) enforces
  this by blocking the above commands before they run. The hook is best-effort
  defense-in-depth — it may not fire in every Claude Code version due to a known
  issue ([#34573](https://github.com/anthropics/claude-code/issues/34573)) — so
  **this rule is binding regardless of whether the hook fires**. Consistent with
  ADR 0003 (uniform identity rationale).

  **Known limitation:** the guard matches `--author` unconditionally, so
  read-only filter uses — `git log --author=alice`, `git shortlog --author=bob`,
  `git blame --author x` — are also blocked. This is an accepted fail-closed
  trade-off: scoping `--author` to commit-creating subcommands requires shell
  parsing that proved fragile (two code-eval-caught false-negative classes). To
  filter history by author, use `--pretty`/`--format`/`--grep` alternatives, or
  run the query outside a loom-guarded session.
- **One commit per handoff**, scoped to that handoff (a single slice's
  implementation, one evaluation, one planning artifact).

## Message shape

```
<imperative summary of the change / artifact / status>

<optional body: what and why, still author-neutral>
```

Examples:

- `Add slice-plan: native result-thread orchestration (Plan Review)`
- `Implement week-rollover auto-advance; gate green (Implemented)`
- `Evaluate week-rollover slice: PASS (Landed)`
- `Approve spec 03 data-model (Plan Review → Approved)`

Avoid: `Implemented by developer agent`, `Co-Authored-By: ...`, `planner draft`.

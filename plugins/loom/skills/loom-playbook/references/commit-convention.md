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

  A plugin PreToolUse hook (`plugins/loom/hooks/git-identity-guard.sh`) blocks
  commands containing **recognized identity-mutation tokens** before they run: the
  author flag, `-c user.*`/`author.*`/`committer.*` and `-c GIT_AUTHOR*`/
  `GIT_COMMITTER*`, `GIT_AUTHOR_*=`/`GIT_COMMITTER_*=` assignments, and
  `git config` writes (including `--unset`, `--replace-all`, `--add`, `--edit`, in
  any scope or `--file`) of `user|author|committer.name|email`. The raw command
  text is scanned, so tokens inside `sh -c`, `bash -c`, and `env` wrappers are
  seen. Bare reads (`git config user.name`, `--get`, `--list`) and ordinary
  commands are allowed. This is defense in depth, not a shell parser or sandbox:
  dynamically built commands, aliases, scripts, expansions, encoded text, and
  commands run outside an active hook can evade it. The hook may also not fire in
  every Claude Code version
  ([#34573](https://github.com/anthropics/claude-code/issues/34573)) — so **this
  rule is binding regardless of whether the hook fires**. Consistent with ADR 0003.

  **Accepted false positives:** recognized tokens are matched even inside quotes,
  so a commit message or read filter containing one — `git log --author=alice`,
  `git commit -m "fix --author= parsing"` — is blocked. To filter history by
  author, use `--pretty`/`--format`/`--grep` alternatives; reword messages.

  **Verify after committing (required):** capture the baseline **before** the
  commit command (`BASE=$(git rev-parse --verify HEAD 2>/dev/null || echo unborn)`),
  then invoke the verifier immediately afterward, before the workflow continues,
  by its absolute resolved path (`loom-resolve-helper claude loom-verify-identity`,
  or `loom-resolve-helper codex <abs SKILL.md path> loom-verify-identity`):

  ```
  "$VERIFY" "$BASE"      # $VERIFY = absolute path printed by loom-resolve-helper
  ```

  This is a required workflow step, not an automatic PostToolUse guarantee. If HEAD
  advanced, it checks every newly reachable commit (including an amended HEAD):
  author **and** committer must equal the configured `user.name`/`user.email`, and
  must **NOT** be `loom <loom@localhost>`, any `*@localhost` address, or any
  auto-generated fallback. Exit 0 = valid or no HEAD change; 1 = usage/config/
  verification error; 2 = identity violation (offending SHA and remediation on
  stderr). On exit 1 or 2, **stop the workflow**.

  - **Violation AND a real identity is configured:** for an unpushed commit, fix it
    in place with `git commit --amend --reset-author --no-edit` when safe, then
    re-run the verifier. (This is the one sanctioned `--amend --reset-author` use —
    it resets *to* the configured identity, not away from it.) **Published
    commits: escalate to the owner;** never automatically rewrite history.
  - **No real identity configured:** do NOT proceed — stop and report. The init
    "ensure identity" step (`greenfield.md` Step F) should have prevented this;
    this is the last-line safety net. The verifier fails closed (exit 1).
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
- `Evaluate week-rollover slice: PASS (Ready to Publish)`
- `Approve spec 03 data-model (Plan Review → Approved)`

Avoid: `Implemented by developer agent`, `Co-Authored-By: ...`, `planner draft`.

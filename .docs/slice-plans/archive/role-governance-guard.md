# Role Governance Guard & Anti-Drift Boundary (`role-governance-guard`)

Status: Landed
Target specs: 02-roles.md, 04-orchestrator.md, 08-playbook.md; Authority: accepted ADR 0004, ADR 0012, ADR 0027
Target size: <= 200 LOC net change (keep this plan document <= 250 lines)

## Context

Loom relies on strict separation between the orchestrator, planners, evaluators,
and developers (spec 02, ADR 0004, ADR 0012). However, two mechanical enforcement
gaps allow models to drift from instructions:

1. **Orchestrator Context Bloat & Token Waste:** In root chat sessions, language
   models frequently drift into executing long-running test suites (`scripts/check`,
   `bats`) directly instead of delegating to external worker agents. Dumping 500+
   lines of test logs into the root conversation bloats the context window, burns
   tokens, and forces premature context compactions.
2. **Evaluator Mutation Leakage:** Evaluator roles are strictly read-only and must
   never mutate the git checkout or history (spec 02, ADR 0004). Currently, this
   is only a prompt instruction without mechanical pre-tool interception.

This slice adds a focused, single-purpose `PreToolUse` hook (`role-governance-guard.sh`)
that enforces these role boundaries when `LOOM_ROLE` is explicitly set, failing
open when unset so normal user and developer sessions are never disrupted.

## Out of Scope & Threat-Model Boundary

- Hostile user bypasses with complex shell evasion (`.docs/spec/00-overview.md` `## Non-goals`).
  The hook provides deterministic defense-in-depth against agent behavioral drift
  within supported Claude and Codex tool invocations.
- Altering the 5 canonical loom lifecycle roles (ADR 0002).
- Rewriting frozen specs (governed by planner spec amendment).
- Bounded return schemas (deferred to a dedicated orchestrator-contracts slice).

## Steps

1. **Wire `LOOM_ROLE` Producer into `loom-launch-role` and Orchestrator:**
   - In `_launch_codex`: include `LOOM_ROLE="$role"` in the child environment via
     `exec env LOOM_LAUNCH_ROLE_ACTIVE=1 LOOM_ROLE="$role" ...`.
   - In `_launch_antigravity`: include `"LOOM_ROLE": "$role"` in the launch definition environment.
   - For orchestrator sessions: `loom-run` (`plugins/loom/skills/loom-run/SKILL.md`)
     and interactive root orchestration sessions explicitly export `LOOM_ROLE=orchestrator`.
   - Unset `LOOM_ROLE` fails open in the guard so normal user sessions and subagents
     lacking a role tag are never blocked.

2. **Implement Pre-Tool Role Guard (`plugins/loom/hooks/role-governance-guard.sh`):**
   - Implements a fail-closed `PreToolUse` hook script for Claude Code and Codex
     wire formats using shared root validation and exact wire encoding from
     `git-identity-guard.sh`:
     - Claude wire: prints reason to stderr and exits `2`.
     - Codex wire: prints `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<reason>"}}` and exits `0`.
     - Reason strings are sanitized, single-line, and capped at 512 bytes.
   - Reads `tool_input.command` from stdin JSON. If command is absent or empty, allow (`exit 0`).
   - Tokenizes and de-quotes commands following `git-identity-guard.sh` Stages A/B/C
     (stripping escaped quotes and quoted segments) to inspect leading command words,
     ensuring arguments like `git log --grep=bats` or `cat test.bats` are never blocked.
   - **Fail-Open Policy for Unset Role:** If `LOOM_ROLE` is unset or empty, allow
     execution (`exit 0`), ensuring uncoordinated user sessions and developer
     subagents without an explicit role tag are never blocked.
   - **Orchestrator Enforcement (`LOOM_ROLE=orchestrator`):**
     - If the de-quoted leading command matches a test runner (`scripts/check`,
       `bats`, `cargo test`, `npm test`, `pytest`) and `LOOM_ALLOW_ORCHESTRATOR_GATE`
       is not set:
       - Deny with reason: `"Loom policy: Orchestrators cannot run test suites directly; delegate to an external worker."`
     - When `LOOM_ALLOW_ORCHESTRATOR_GATE=1` is set, allow `scripts/check` to satisfy
       spec 04's normative landing gate rerun duty.
   - **Evaluator Enforcement (`LOOM_ROLE=plan-evaluator` or `LOOM_ROLE=code-evaluator`):**
     - If the de-quoted command attempts git mutation (`git commit`, `git push`,
       `git merge`, `git rebase`, `git cherry-pick`, `git apply`, `git reset --hard`):
       - Deny with reason: `"Loom policy: Evaluators are read-only and cannot mutate git history or checkout."`

3. **Register Guard in Hook Manifest (`plugins/loom/hooks/hooks.json`):**
   - Register `role-governance-guard.sh` in `PreToolUse` for matcher `Bash` as the second hook,
     after `git-identity-guard.sh`.
   - **Ordering & Combined-Block Behavior:** Hooks run sequentially. `git-identity-guard.sh`
     runs first (identity integrity takes precedence); `role-governance-guard.sh` runs
     second (role anti-drift). Whichever hook blocks halts execution. If both would
     block (e.g. an evaluator executing `git commit --author=...`), the identity guard halts first.
   - **Hook-Wire-v1 Fixture Invariant:** The canonical 12-case (48-file) `hook-wire-v1` product
     in `plugins/loom/hooks/fixtures/hook-wire-v1/` remains strictly unchanged (spec 08 and
     `CLAUDE.md`). `git-identity-guard.bats` continues to serve as the contract verifier for the
     pre-tool-use wire fixtures; `role-governance-guard.bats` tests exact wire conformance
     inline without altering fixture counts.

4. **Add Comprehensive Bats Test Suite (`plugins/loom/hooks/role-governance-guard.bats`):**
   - Test unset `LOOM_ROLE` allows all commands (fail open).
   - Test `LOOM_ROLE=orchestrator` blocks `scripts/check`, `bats foo.bats`, `cargo test`.
   - Test `LOOM_ROLE=orchestrator` allows `scripts/check` when `LOOM_ALLOW_ORCHESTRATOR_GATE=1`.
   - Test `LOOM_ROLE=orchestrator` allows non-test commands (`git status`, `git commit`, `git show`).
   - Test `LOOM_ROLE=code-evaluator` blocks `git commit`, `git apply`, `git push`.
   - Test `LOOM_ROLE=code-evaluator` allows read-only inspection (`git diff`, `git log`, `cat`, gate scripts).
   - Test arguments like `git log --grep=bats` or `echo bats` are allowed across all roles.
   - Test exact wire envelopes for both Claude (`exit 2`) and Codex (`deny` JSON `exit 0`).

## Verification

- **Fast inner-loop tests:**
  - `TMPDIR=/private/tmp bats plugins/loom/hooks/role-governance-guard.bats`
- **Mechanical invariant checks:**
  - Verify `hooks.json` registration & ordering:
    `jq -e '.hooks.PreToolUse[0].hooks | length == 2 and (.[0].command | contains("git-identity-guard.sh")) and (.[1].command | contains("role-governance-guard.sh"))' plugins/loom/hooks/hooks.json`
  - Verify 12-case `hook-wire-v1` product count is unchanged:
    `[ "$(find plugins/loom/hooks/fixtures/hook-wire-v1 -type f | wc -l | tr -d ' ')" = "48" ]`
  - Verify launcher propagation:
    `rg -q 'LOOM_ROLE' plugins/loom/bin/loom-launch-role`
- **Static checks:**
  - `shfmt -i 4 -d plugins/loom/hooks/role-governance-guard.sh`
  - `shellcheck -s bash plugins/loom/hooks/role-governance-guard.sh`
  - `node scripts/validate-repository.mjs --root . --all`
- **Repository gate:**
  - Run via external Orca worker: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`

## Implementation Evidence

- `role-governance-guard.bats`: 14/14 pass (Bash 3.2 and gate run).
- `shfmt -i 4 -d` / `shellcheck -s bash` on the hook: clean.
- `hooks.json` ordering jq check: true; `hook-wire-v1` fixture count: 48; `rg LOOM_ROLE` launcher: ok.
- `node scripts/validate-repository.mjs --root . --all`: passed.
- `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: All checks passed.
- Deviation: the closed `loom-role-launch-v1` schema gained an optional
  `antigravity.environment.LOOM_ROLE` property so the launch definition validates.

### Code-eval Round 0 fixes (3 MAJOR)

- Landing exception no longer short-circuits: other runners are checked independently of `scripts/check`.
- Git global options with values (`-C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`, ...) are skipped before the subcommand.
- Quoted words without whitespace/separators are de-quoted (`'bats'`, `"commit"`); other quoted segments are still deleted as arguments.
- Added 3 Bats tests with negative controls (`echo 'bats'`, `git log --grep="bats"`); role-governance-guard.bats: 17/17 pass; shfmt/shellcheck clean.
- `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: All checks passed (after fixes).

### Code-eval Round 1 fix (1 MAJOR)

- Quoted executable words containing spaces at command position (`"/tmp/my tools/bats" tests`, `'/tmp/space dir/scripts/check'`) are now de-quoted and blocked; quoted arguments are still ignored.
- Added 1 Bats test (4 assertions: blocked bats path, blocked/allowed `scripts/check` path with and without `LOOM_ALLOW_ORCHESTRATOR_GATE=1`, negative control `echo "/tmp/my tools/bats"`); role-governance-guard.bats: 18/18 via the gate.
- `shfmt -i 4 -d` / `shellcheck -s bash` clean; `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: All checks passed (545 Bats cases).

### Code-eval Round 2 fix (1 MAJOR)

- The de-quoting loop now accepts leading environment assignments at command position (same prefix as the guard's START pattern), so `FOO=1 "/tmp/my tools/bats" tests` and `FOO=1 "/tmp/space dir/scripts/check"` are blocked for the orchestrator; quoted arguments are still ignored.
- Added 1 Bats test (4 assertions: blocked bats path, blocked/allowed `scripts/check` path without/with `LOOM_ALLOW_ORCHESTRATOR_GATE=1`, negative control `echo FOO=1 "/tmp/my tools/bats"`); role-governance-guard.bats: 19/19 via the gate.
- `shfmt -i 4 -d` / `shellcheck -s bash` clean; `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: All checks passed. The standalone fast run needs `LOOM_TEST_BASH` and `LOOM_EXPECTED_BASH_VERSION` set by the gate, so it was exercised through the gate only.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft for role-governance-guard slice |
| 1 | Reconciled Codex wire output to spec 08 (deny JSON, exit 0); unset LOOM_ROLE fails open; reconciled spec 04 orchestrator landing gate via LOOM_ALLOW_ORCHESTRATOR_GATE; dropped orphaned schema; specified Stage A/B/C command tokenization |
| 2 | Resolved Finding 4 (MAJOR): specified hook ordering in hooks.json (identity guard first, role guard second; whichever blocks stops execution), documented that hook-wire-v1 12-case 48-file fixture count is preserved unchanged, and added mechanical verification checks; named orchestrator LOOM_ROLE producer in loom-run and interactive sessions (Finding 8) |

# Role Governance Guard & Anti-Drift Boundary (`role-governance-guard`)

Status: Plan Review
Target specs: 02-roles.md, 04-orchestrator.md, 08-playbook.md; Authority: accepted ADR 0004, ADR 0012, ADR 0027
Target size: <= 180 LOC net change (keep this plan document <= 250 lines)

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
3. **Missing `LOOM_ROLE` Producer:** The codebase does not systematically export
   the active role into the child process environment, preventing hooks from
   verifying role-specific boundaries deterministically.

This slice adds a universal `PreToolUse` hook (`role-governance-guard.sh`),
wires `LOOM_ROLE` export into `loom-launch-role`, registers the hook in `hooks.json`,
and defines a bounded return schema (`loom-bounded-return-v1.schema.json`).

## Out of Scope & Threat-Model Boundary

- Hostile, intentional user shell escapes outside client toolchains
  (`.docs/spec/00-overview.md` `## Non-goals`). This hook provides deterministic
  defense-in-depth against agent behavioral drift within supported Claude/Codex/Orca
  tool calls.
- Redefining the 5 canonical loom lifecycle roles (ADR 0002).
- Rewriting frozen specs (governed by planner spec amendment).

## Steps

1. **Add `LOOM_ROLE` Producer to `loom-launch-role` (`plugins/loom/bin/loom-launch-role`):**
   - Export `LOOM_ROLE="$role"` into the child process environment when launching
     workers:
     - For Codex: pass `LOOM_ROLE="$role"` in `exec env LOOM_LAUNCH_ROLE_ACTIVE=1 LOOM_ROLE="$role" ...`.
     - For Claude: include `LOOM_ROLE` guidance in role execution context.
     - For Antigravity: include `"role":"$role"` and export `LOOM_ROLE="$role"` in launch definitions.

2. **Implement Pre-Tool Role Guard (`plugins/loom/hooks/role-governance-guard.sh`):**
   - Implements a fail-closed `PreToolUse` hook script for Claude Code and Codex
     wire formats (using shared root validation and client wire adapters from `git-identity-guard.sh`).
   - Reads `tool_input.command` from stdin JSON.
   - Inspects `LOOM_ROLE` (defaulting to `orchestrator` if unset or `orchestrator`):
     - **Orchestrator Rule:** If `LOOM_ROLE` is `orchestrator`:
       - If `tool_input.command` matches test runner execution:
         `scripts/check`, `bats *`, `*bats`, `cargo test`, `npm test`, `pytest`.
       - Fail closed (`exit 2` on Claude, `{ "continue": false, "stopReason": ... }`
         on Codex wire) with exact diagnostic:
         `"LOOM_ROLE_POLICY_VIOLATION: Orchestrator sessions cannot run test suites directly. Delegate test execution to an external worker agent (e.g. via orca orchestration worker-start or loom-run)."`
     - **Evaluator Rule:** If `LOOM_ROLE` is `plan-evaluator` or `code-evaluator`:
       - If `tool_input.command` attempts git history or tree mutation:
         `git commit`, `git push`, `git merge`, `git rebase`, `git cherry-pick`,
         `git apply`, `git reset --hard`.
       - Fail closed (`exit 2`) with exact diagnostic:
         `"LOOM_ROLE_POLICY_VIOLATION: Evaluator sessions are read-only and cannot mutate git history or checkout."`
     - **Developer / Researcher Rule:** All test execution and development commands
       are allowed.

3. **Register Guard in Hook Manifest (`plugins/loom/hooks/hooks.json`):**
   - Add `role-governance-guard.sh` to the `PreToolUse` array for matcher `Bash`
     alongside `git-identity-guard.sh`.

4. **Add Bounded Return Schema (`plugins/loom/schemas/loom-bounded-return-v1.schema.json`):**
   - Define JSON Schema requiring:
     - `schema: "loom-bounded-return/v1"`
     - `verdict: "PASS"|"FAIL"`
     - `round: integer` (minimum 0)
     - `evalPath: string`
     - `reason: string` (maxLength 300)

5. **Add Comprehensive Bats Test Suite (`plugins/loom/hooks/role-governance-guard.bats`):**
   - Test orchestrator blocked on `scripts/check`, `bats foo.bats`, `cargo test`.
   - Test orchestrator allowed on `git status`, `git commit`, `git show`, `orca orchestration *`.
   - Test evaluator blocked on `git commit`, `git apply`, `git push`.
   - Test evaluator allowed on `git diff`, `git log`, `cat`, read-only tools.
   - Test developer allowed on all commands (`scripts/check`, `git commit`).
   - Test wire compatibility on both Claude and Codex wire payloads.

## Verification

- **Fast inner-loop tests:**
  - `TMPDIR=/private/tmp bats plugins/loom/hooks/role-governance-guard.bats`
  - `TMPDIR=/private/tmp bats plugins/loom/bin/loom-launch-role.bats`
- **Static checks:**
  - `shfmt -i 4 -d plugins/loom/hooks/role-governance-guard.sh`
  - `shellcheck -s bash plugins/loom/hooks/role-governance-guard.sh`
  - `node scripts/validate-repository.mjs --root . --all`
- **Repository gate:**
  - Run via external Orca worker: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft for role-governance-guard slice |

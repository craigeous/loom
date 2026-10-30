# Role Governance Guardrails & Anti-Drift Boundary (`role-governance-guardrails`)

Status: Plan Review
Target specs: 02-roles.md, 04-orchestrator.md, 05-blind-evaluation.md, 08-client-adapters.md, 10-packaging.md
Target size: <= 240 LOC net change (keep this plan document <= 250 lines)

## Context

Loom's multi-agent architecture relies on strict separation between the
orchestrator, planners, evaluators, and developers. However, three behavioral
and mechanical gaps exist across Claude, Codex, Antigravity, and Orca:

1. **Orchestrator Role Drift & Context Bloat:** In interactive root sessions,
   language models frequently drift into executing test suites (`scripts/check`,
   `bats`) or code fixes directly instead of delegating to external worker agents.
   Running 500+ line test outputs in the root chat bloats the context window,
   wastes tokens, and triggers unnecessary compactions.
2. **Evaluator Mutation Leakage:** Evaluators are strictly read-only and must
   never mutate the repository checkout or commit history. Today, this is only
   a prompt constraint rather than a mechanical pre-tool block.
3. **Stale Hardcoded Model Mapping:** `plugins/loom/adapters/compatibility/v0.2.0.json`
   hardcodes obsolete model names (`gpt-5.6`) which fail on modern Codex accounts
   (`ERROR: The 'gpt-5.6' model is not supported`). Antigravity supports
   `claude-opus-5-5-*` and `gemini-4-argon-*` via `agy models`, but loom lacks
   dynamic discovery, 24h caching, and explicit model/effort pinning.
4. **Unbounded Worker Output:** When external workers return, verbose logs or
   diffs can leak into orchestrator context unless bounded by an enforced schema.

This slice adds a universal `pre_tool_use` role guard hook, dynamic model
resolution with caching and pinning in `loom-launch-role`, and a bounded worker
receipt schema (`loom-bounded-return/v1`).

## Out of Scope & Threat-Model Boundary

- Hostile, intentional developer bypasses with arbitrary shell escapes outside
  the supported client toolchains (`.docs/spec/00-overview.md` `## Non-goals`).
  This hook provides deterministic defense-in-depth against agent behavioral
  drift within supported Claude/Codex/Orca tool executions.
- Redefining the 5 canonical loom lifecycle roles (ADR 0002).
- Rewriting existing frozen specs (`.docs/spec/*`).

## Steps

1. **Add Universal Pre-Tool Role Guard (`plugins/loom/hooks/role-governance-guard.sh`):**
   - Implements a fail-closed `PreToolUse` hook script for Claude Code and Codex
     wire formats (following `git-identity-guard.sh`'s root validation and wire
     adapters).
   - Reads `tool_input.command` from the hook JSON payload.
   - Inspects `LOOM_ROLE` (defaulting to `orchestrator` when invoked in the root
     interactive session without a role subagent tag).
   - **Orchestrator Guard:** If `LOOM_ROLE=orchestrator` (or root context):
     - Blocks commands matching test runners or repo gates: `scripts/check`,
       `bats`, `cargo test`, `cargo clippy`, `npm test`, `pytest`.
     - Fails closed (`exit 2` on Claude wire, `{ "continue": false, "stopReason": ... }`
       on Codex wire) with exact diagnostic:
       `"LOOM_ROLE_VIOLATION: Orchestrators cannot run test suites or build commands. Delegate this task to an external worker via orca orchestration worker-start or loom-run."`
   - **Evaluator Guard:** If `LOOM_ROLE=plan-evaluator` or `LOOM_ROLE=code-evaluator`:
     - Blocks commands that mutate git history or state: `git commit`, `git push`,
       `git merge`, `git rebase`, `git cherry-pick`, `git apply`.
     - Fails closed with diagnostic:
       `"LOOM_ROLE_VIOLATION: Evaluator sessions are read-only and cannot mutate git history or the checkout."`

2. **Register Hook in Manifest (`plugins/loom/hooks/hooks.json`):**
   - Add `role-governance-guard.sh` to the `PreToolUse` array alongside
     `git-identity-guard.sh`.

3. **Add Dynamic Model Discovery & Pinning (`plugins/loom/bin/loom-launch-role`):**
   - Add support for `--model <id>` and `--effort <level>` CLI overrides and
     optional repository configuration `.docs/loom-models.json`.
   - Dynamic Codex resolution: if `--model` is not pinned, inspect
     `~/.codex/config.toml` for `model = "..."` or use Orca catalog defaults
     (`gpt-6.1-terra` for Standard/Economy, `gpt-6.1-sol` for Deep review),
     completely replacing unsupported `gpt-5.6`.
   - Dynamic Antigravity resolution: add discovery helper that caches
     `agy models` output in `${XDG_CACHE_HOME:-~/.cache}/loom/agy-models.json`
     (24h TTL) and maps:
     - `Deep review` -> `claude-opus-5-5-high` (or `gemini-4-argon-high`)
     - `Standard` -> `claude-sonnet-5-5-medium` (or `gemini-4-argon-medium`)
     - `Economy` -> `gemini-3.8-flash-low`
   - Fail closed (`exit 2`) if an unknown or unavailable pinned model is specified.

4. **Add Bounded Return Schema (`plugins/loom/schemas/loom-bounded-return-v1.schema.json`):**
   - Draft JSON Schema requiring `schema: "loom-bounded-return/v1"`,
     `verdict: "PASS"|"FAIL"`, `round: integer`, `evalPath: string`, and
     `reason: string` (max 300 characters / <= 150 tokens).

5. **Write Comprehensive Bats Test Suites:**
   - Create `plugins/loom/hooks/role-governance-guard.bats`:
     - Tests orchestrator blocking `scripts/check`, `bats`, `npm test`.
     - Tests orchestrator allowing safe commands (`git status`, `git commit`, `git show`).
     - Tests evaluator blocking `git commit` and `git apply`.
     - Tests developer role allowing test execution and git operations.
     - Tests wire compatibility on both Claude and Codex wire payloads.
   - Update `plugins/loom/bin/loom-launch-role.bats`:
     - Tests dynamic model selection for Codex (`gpt-6.1-*`) and Antigravity.
     - Tests `--model` and `--effort` CLI overrides and `.docs/loom-models.json`.

## Verification

- **Fast inner-loop tests:**
  - `TMPDIR=/private/tmp bats plugins/loom/hooks/role-governance-guard.bats`
  - `TMPDIR=/private/tmp bats plugins/loom/bin/loom-launch-role.bats`
- **Static checks:**
  - `shfmt -i 4 -d plugins/loom/hooks/role-governance-guard.sh plugins/loom/bin/loom-launch-role`
  - `shellcheck -s bash plugins/loom/hooks/role-governance-guard.sh plugins/loom/bin/loom-launch-role`
  - `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all`
- **Repository gate:**
  - Run via external Orca worker: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

# Model Matrix Modernization & Dynamic Discovery (`model-matrix-and-dynamic-discovery`)

Status: Ready to Publish
Target specs: 08-playbook.md, 10-packaging.md; Authority: accepted ADR 0027
Target size: <= 180 LOC net change (keep this plan document <= 250 lines)

## Context

Loom's compatibility matrix and launch schemas previously locked Codex launches
to deprecated model names (`gpt-5.6*`), which fail on modern accounts (`ERROR: The
'gpt-5.6' model is not supported`). Accepted ADR 0027 partially supersedes ADR 0002
and ADR 0018 §3, authorizing ambient model inheritance as default, four-tier
resolution precedence (CLI flags > repository config > ambient client > matrix fallback),
role profile reasoning effort policy, and Antigravity as a private dogfood runtime adapter.

This slice implements ADR 0027's technical foundation:
1. Updating schemas and adding compatibility matrix `v0.3.0.json` to admit modern
   model families (`gpt-6*` patterns and Antigravity dogfood fields).
2. Implementing the four-tier model resolution precedence in `loom-launch-role`.
3. Adding Antigravity dynamic model discovery with atomic 24-hour file caching.
4. Supporting explicit `--model <id>` and `--effort <low|medium|high>` CLI overrides.

## Out of Scope & Threat-Model Boundary

- Session interception pre-tool hooks (owned by follow-up slice `role-governance-guard`).
- Altering the 5 canonical lifecycle roles or their profiles (ADR 0002 / ADR 0018).
- Live external network calls in tests: Bats tests must use local stubs/caches and
  never invoke live external APIs or live `codex exec`.
- Modifying public v0.2 release obligations: Antigravity remains a private dogfood
  adapter per ADR 0024 and ADR 0027 §4.

## Steps

1. **Update Compatibility & Launch Schemas (`plugins/loom/schemas/`):**
   - In `loom-compatibility-matrix-v1.schema.json`:
     - Allow version `0.2.0` or `0.3.0` (`"pattern": "^0\\.[23]\\.0$"`).
     - Broaden Codex model constraint: `"pattern": "^(gpt-6(\\.[0-9]+)?(-[a-z0-9]+)?|gpt-5\\.6(-[a-z0-9]+)?)$"`
   - In `loom-role-launch-v1.schema.json`:
     - Broaden Codex model pattern identically.
     - Add `antigravity` variant to `oneOf` with `model` (string),
       `subagentName` (string), `enableSubagentTools` (boolean),
       `enableWriteTools` (boolean), `rolePromptPath` (string), and
       `rolePromptSha256` (string), matching the exact emitted launcher fields.

2. **Add Compatibility Matrix `v0.3.0.json` (`plugins/loom/adapters/compatibility/`):**
   - Create `adapters/compatibility/v0.3.0.json` preserving v0.2.0 root bindings
     and profiles while updating Codex baseline floors:
     - `Economy`: `gpt-6.1-terra`, effort `low`
     - `Standard`: `gpt-6.1-terra`, effort `medium`
     - `Deep review`: `gpt-6.1-sol`, effort `high`

3. **Implement Four-Tier Model & Effort Resolution in `loom-launch-role`:**
   - In `plugins/loom/bin/loom-launch-role`:
     - Parse optional `--model <id>` and `--effort <low|medium|high>` flags.
     - Enforce 4-tier precedence:
       1. Explicit `--model` / `--effort` flags:
          - For `claude`: `--model` must be `haiku`, `sonnet`, or `opus` (fails closed `exit 2` otherwise).
          - For `codex`: `--model` must match the schema pattern (fails closed `exit 2` otherwise).
          - For `antigravity`: `--model` must be non-empty (fails closed `exit 2` if empty/malformed).
          - `--effort`: must be `low`, `medium`, or `high` (fails closed `exit 2` otherwise).
       2. `.docs/loom-models.json` (if present and valid JSON).
       3. Ambient client configuration:
          - Codex: inspect `~/.codex/config.toml` for `model = "..."`; if matching
            supported pattern, use it; if malformed/unsupported, fail closed (`exit 2`).
          - Antigravity: read cache `${XDG_CACHE_HOME:-~/.cache}/loom/agy-models.json`
            (mode 0600; valid if age <= 86400s). If missing or stale, query `agy models`
            (if available) and write atomically via temp file + `mv -f`. If `agy` is
            absent or fails, fall back safely to profile defaults (`pro`, `inherit`, `flash`).
          - Claude: floating tier selectors (`haiku`, `sonnet`, `opus`).
       4. Compatibility matrix `v0.3.0.json` fallback.
     - Profile reasoning effort: default `low` (Economy), `medium` (Standard),
       `high` (Deep review); map effort suffix on Antigravity models.

4. **Add Comprehensive Bats Test Suite (`plugins/loom/bin/loom-launch-role.bats`):**
   - Positive tests:
     - Codex launches inheriting ambient `gpt-6.1-*` model from config stub.
     - Explicit `--model` and `--effort` CLI overrides successfully emitted in launch JSON.
     - Antigravity cached discovery mapping `Deep review` to `claude-opus-5-5-high`.
     - Schema validation of emitted JSON against updated `loom-role-launch-v1.schema.json`.
   - Fail-closed negative tests:
     - Invalid `--effort foo` fails closed (`exit 2`).
     - Invalid `--model invalid@model` for Codex fails closed (`exit 2`).
     - Unsupported ambient Codex model in `config.toml` fails closed (`exit 2`).
     - Missing or corrupted `agy` cache with absent `agy` binary safely falls back to matrix profile baseline.
     - Cross-family evaluation rules preserved (`exit 2` on author client match).

## Verification

- **Fast inner-loop tests:**
  - `TMPDIR=/private/tmp bats plugins/loom/bin/loom-launch-role.bats`
- **Static checks:**
  - `shfmt -i 4 -d plugins/loom/bin/loom-launch-role`
  - `shellcheck -s bash plugins/loom/bin/loom-launch-role`
  - `node scripts/validate-repository.mjs --root . --all`
- **Repository gate:**
  - Run via external Orca worker: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`

## Verification Evidence

- `bats plugins/loom/bin/loom-launch-role.bats` (bash 3.2): 75/75 ok (60 existing re-pinned to
  matrix v0.3.0 + 15 new model/effort/discovery tests).
- `shfmt -i 4 -d` and `shellcheck -s bash` on the launcher: clean.
- `node scripts/validate-repository.mjs --root . --all`: passed.
- `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: "All checks passed", 0 `not ok`.
- `scripts/check-toolchain.json` digest for the matrix schema re-pinned.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft replacing multi-purpose role-governance-guardrails with focused model matrix & discovery slice |
| 1 | Cites accepted ADR 0027 as authority; defines 4-tier resolution precedence (CLI > repo > ambient > matrix); specifies matrix v0.3.0.json; adds fail-closed negative test cases |
| 2 | Reconciles Antigravity schema fields (enableSubagentTools, enableWriteTools); specifies --model validation rules per client; defines cache mode 0600 and fallback behavior; adds fail-closed Bats tests |

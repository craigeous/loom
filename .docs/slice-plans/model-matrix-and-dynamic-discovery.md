# Model Matrix Modernization & Dynamic Discovery (`model-matrix-and-dynamic-discovery`)

Status: Plan Review
Target specs: 08-playbook.md, 10-packaging.md
Target size: <= 180 LOC net change (keep this plan document <= 250 lines)

## Context

Loom's compatibility matrix (`adapters/compatibility/v0.2.0.json`) and schemas
currently lock Codex launches to deprecated model names (`gpt-5.6`, `gpt-5.6-terra`)
via strict JSON schema enums. On modern Codex accounts, launching with `gpt-5.6`
fails immediately:
```
ERROR: The 'gpt-5.6' model is not supported when using Codex with a ChatGPT account.
```
Simultaneously, Antigravity models (`agy models`) provide access to latest Anthropic
models (`claude-opus-5-5-*`, `claude-sonnet-5-5-*`) and Gemini models (`gemini-4-argon-*`,
`gemini-3.8-flash-*`), allowing developers to bypass direct Anthropic quota ceilings.
However, `loom-launch-role` currently lacks:
1. Support for modern `gpt-6*` model families in schemas and compatibility matrix.
2. Dynamic discovery and 24h caching of available Antigravity models via `agy models`.
3. Safe resolution of active Codex models from `~/.codex/config.toml` when unpinned.
4. Explicit model and effort pinning flags (`--model <id>` and `--effort <level>`).

This slice modernizes the compatibility matrix and schemas to support `gpt-6*`
models, adds Antigravity discovery and caching, and provides CLI model/effort pinning.

## Out of Scope & Threat-Model Boundary

- Modifying pre-tool execution hooks or session interception (owned by the
  follow-up `role-governance-guard` slice).
- Altering the 5 canonical lifecycle roles or their profiles (Economy, Standard,
  Deep review) defined in ADR 0002 / ADR 0018.
- Arbitrary network lookups in tests: Bats tests must use local stubs/caches and
  never invoke live external APIs or live `codex exec`.

## Steps

1. **Update Compatibility & Launch Schemas (`plugins/loom/schemas/`):**
   - In `loom-compatibility-matrix-v1.schema.json`, broaden the Codex model
     constraint to admit `gpt-6*` and `gpt-5.6*` models:
     `"pattern": "^(gpt-6(\\.[0-9]+)?(-[a-z0-9]+)?|gpt-5\\.6(-[a-z0-9]+)?)$"`
   - In `loom-role-launch-v1.schema.json`:
     - Update Codex model pattern similarly to permit `gpt-6.1-terra`,
       `gpt-6.1-sol`, and `gpt-6-astra`.
     - Add `antigravity` launch variant to `oneOf` with `model`,
       `subagentName`, `rolePromptPath`, and `rolePromptSha256`.

2. **Update Compatibility Matrix (`plugins/loom/adapters/compatibility/v0.2.0.json`):**
   - Update Codex profile defaults:
     - `Economy`: `gpt-6.1-terra`, effort `low`
     - `Standard`: `gpt-6.1-terra`, effort `medium`
     - `Deep review`: `gpt-6.1-sol`, effort `high`

3. **Add Dynamic Discovery, Caching & Pinning to `loom-launch-role`:**
   - In `plugins/loom/bin/loom-launch-role`:
     - Add optional CLI flags: `--model <id>` and `--effort <low|medium|high>`.
     - When `--model` is supplied, override the profile default while enforcing
       valid effort levels.
     - When client is `antigravity`:
       - If `--model` is unset, check cache `${XDG_CACHE_HOME:-~/.cache}/loom/agy-models.json`
         (valid if age <= 86400s). If expired or missing, query `agy models` (if
         available) and cache the output.
       - Map profile defaults:
         - `Deep review`: `claude-opus-5-5-high` (fallback `gemini-4-argon-high`)
         - `Standard`: `claude-sonnet-5-5-medium` (fallback `gemini-4-argon-medium`)
         - `Economy`: `gemini-3.8-flash-low`
     - When client is `codex`:
       - If `--model` is unset, inspect `~/.codex/config.toml` for `model = "..."`;
         if set and matching supported families, use it as the default base model;
         otherwise use matrix defaults (`gpt-6.1-sol` for Deep review, `gpt-6.1-terra`
         for Standard/Economy).

4. **Add Comprehensive Bats Tests (`plugins/loom/bin/loom-launch-role.bats`):**
   - Add tests for:
     - `codex` launches producing `gpt-6.1-sol` for Deep review and `gpt-6.1-terra`
       for Standard/Economy.
     - `--model` and `--effort` CLI overrides successfully emitted in the launch JSON.
     - Schema validation of the emitted JSON against `loom-role-launch-v1.schema.json`.
     - `antigravity` dynamic model mapping with cached stub `agy models` output.
     - Preserving existing cross-family evaluation rules and error exits.

## Verification

- **Fast inner-loop tests:**
  - `TMPDIR=/private/tmp LOOM_TEST_BASH=/opt/homebrew/bin/bash bats plugins/loom/bin/loom-launch-role.bats`
- **Static checks:**
  - `shfmt -i 4 -d plugins/loom/bin/loom-launch-role`
  - `shellcheck -s bash plugins/loom/bin/loom-launch-role`
  - `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all`
- **Repository gate:**
  - Run via external Orca worker: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft replacing multi-purpose role-governance-guardrails with focused model matrix & discovery slice |

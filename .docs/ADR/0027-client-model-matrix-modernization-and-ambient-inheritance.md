# 0027 — Ambient Model Inheritance, Model Matrix Modernization, and Dogfood Antigravity Adapter

Status: Accepted
Partially supersedes: ADR 0002, ADR 0018
Date: 2026-10-30

## Context

Loom's model selection architecture was established in ADR
[0002](0002-model-selection-by-tier.md) (model selection by tier) and ADR
[0018](0018-shared-core-and-client-adapters.md) (shared core with Claude and Codex
adapters), with exact matrix mappings frozen in `adapters/compatibility/v0.2.0.json`
and spec [10](../spec/10-packaging.md) §Versioned compatibility and capability mapping.

Under that baseline, model selection is strictly static: every model and effort
level is derived exclusively from the tracked compatibility matrix, and spec 10
forbids inheriting ambient session configuration or falling back to unmapped models.

In practice, this static model model creates critical operational failures:

1. **Provider Catalog Evolution & Pinning Failures:**
   The v0.2.0 compatibility matrix pinned Codex to exact model strings (`gpt-5.6*`).
   As OpenAI's ChatGPT subscription backend retired `gpt-5.6` in favor of newer
   families (`gpt-6*`, `gpt-6.1-terra`, `gpt-6.1-sol`), invoking `loom-launch-role codex`
   fails immediately:
   `ERROR: The 'gpt-5.6' model is not supported when using Codex with a ChatGPT account.`
   Rigidly pinning provider minor versions in central distribution files causes
   complete operational lockouts when upstream catalogs move.

2. **Personal Subscription Quota Ceilings:**
   Direct Claude Pro/Team accounts enforce rolling 7-day quota windows (`Usage Limit Reached:
   Your limit will reset in 6 days, 7 hours`). In contrast, internal environments
   such as Antigravity provide access to Anthropic models (Claude Opus/Sonnet 5.5)
   and Google Gemini models (Gemini 4 Argon, 3.8 Flash). While an Antigravity launcher
   adapter was introduced in commit `0dd3db9` to unblock multi-agent development,
   it lacks formal architectural authority, schema validation, and spec alignment.

3. **Ambient Defaults vs Manual Pinning:**
   Developers configure their preferred active model in client settings (e.g.,
   `model = "gpt-6.1-terra"` in `~/.codex/config.toml`). Forcing developers to
   manually synchronize Loom's compatibility matrix with their local ambient account
   defaults creates high operational friction.

## Decision

### 1. Partial Supersession of ADR 0002 and ADR 0018

This ADR **partially supersedes ADR 0002 and ADR 0018 §3**:
- ADR 0002's static tier policy and ADR 0018 §3's prohibition against ambient
  configuration inheritance are relaxed to permit **ambient model inheritance as
  the default**, while preserving explicit pinning as a supported option.
- All other provisions of ADR 0002 and ADR 0018 (role separation, portable core,
  five lifecycle roles) remain fully in effect.

### 2. Model Resolution Precedence

When launching a role via `loom-launch-role`, the effective model and reasoning
effort SHALL be resolved using the following deterministic four-tier precedence:

1. **Explicit CLI Overrides (Highest):** Caller-supplied `--model <id>` and
   `--effort <low|medium|high>` flags.
2. **Repository Configuration:** A checked-in `.docs/loom-models.json` file,
   allowing projects to pin models and effort across roles when strict reproducibility
   is required.
3. **Ambient Client Configuration (Default):**
   - **Codex:** If unpinned, Loom SHALL inspect the ambient client configuration
     (`~/.codex/config.toml`) for an active `model`. If set and conforming to
     supported provider families, Loom SHALL inherit it.
   - **Antigravity:** If unpinned, Loom SHALL query available models via `agy models`
     (cached locally at `${XDG_CACHE_HOME:-~/.cache}/loom/agy-models.json` with a
     24-hour TTL) and map the tier to the latest available model.
   - **Claude:** Resolves through Claude's native floating aliases (`haiku`,
     `sonnet`, `opus`).
4. **Compatibility Matrix Fallback (Lowest):** The versioned compatibility matrix
   table (`adapters/compatibility/v0.3.0.json`) provides verified baseline floors
   when ambient configuration is absent or unparseable.

### 3. Profile Reasoning Effort Policy

Reasoning effort governs the compute allocated to model inference. In the absence
of an explicit `--effort` override or ambient `model_reasoning_effort` setting,
Loom SHALL assign effort based on role profile intensity:

- **Economy** (`researcher`): `low`
- **Standard** (`developer`, `orchestrator`): `medium`
- **Deep review** (`planner`, `plan-evaluator`, `code-evaluator`): `high`

For clients where reasoning effort is embedded in model identifiers (such as
Antigravity's `-high`, `-medium`, `-low` suffixes), Loom SHALL map the resolved
effort level to the corresponding model variant. For Claude (where effort is not
a client-exposed flag), the effort selection is omitted on the wire.

### 4. Dogfood Status of Antigravity Adapter

Following the private dogfood precedent of ADR 0024:
- The Antigravity adapter is recognized as a **private dogfood and development
  runtime adapter**, providing cross-family evaluation redundancy and token-quota
  resilience.
- It participates in Loom's deterministic cross-family evaluation rotation
  (`claude -> codex -> antigravity -> claude`).
- Like the macOS dogfood amendment in ADR 0024, the Antigravity adapter does
  **not** modify the public dual-client (Claude Code + Codex) release obligations
  defined in spec 00 and ADR 0019 for the public v0.2.0 release.

### 5. Spec Amendments and Schema Modernization

1. **Spec Amendments:** A formal planner spec amendment SHALL be scheduled to
   update `.docs/spec/02-roles.md` and `.docs/spec/10-packaging.md` to reflect
   ambient model inheritance, the four-tier resolution precedence, and the
   compatibility matrix `v0.3.0` upgrade.
2. **Schema Modernization:** `loom-compatibility-matrix-v1.schema.json` and
   `loom-role-launch-v1.schema.json` SHALL be updated to admit modern model
   families (including `gpt-6*` patterns) and validate Antigravity role launches.

## Consequences

- **Operational Resilience:** Upstream provider model catalog updates no longer
  cause catastrophic launch failures.
- **Quota Independence:** Workflows can route heavy evaluation passes to Claude
  Opus via Antigravity when direct Anthropic account quotas are exhausted.
- **Reproducibility Preserved:** Projects requiring rigid version lockstep can
  enforce explicit pinning via `.docs/loom-models.json` or `--model`.
- **Trade-offs & Foreclosed Alternatives:**
  - Ambient inheritance introduces potential variation between developer machines;
    mitigated by logging the exact effective model and SHA in role-launch output.
  - Adding Antigravity increases the test matrix for local dogfooding, though it
    remains excluded from public release gate requirements per ADR 0024.
- **Follow-On Work:**
  - Author and approve spec amendments for `.docs/spec/02-roles.md` and `10-packaging.md`.
  - Bump compatibility matrix to `adapters/compatibility/v0.3.0.json`.
  - Update launch schemas and implement caching/pinning in `loom-launch-role`.

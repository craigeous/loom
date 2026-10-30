# 0027 — Client Model Matrix Modernization, Ambient Inheritance, and Antigravity Ratification

Status: Draft
Date: 2026-10-30

## Context

Loom's model selection architecture was established in ADR 0002 (selection by
tier) and ADR 0018 (dual-platform Claude and Codex mapping), with exact values
pinned in `adapters/compatibility/v0.2.0.json` and spec 10 §Versioned compatibility
and capability mapping.

Three fundamental challenges have emerged across production use:

1. **Rigid Model Pinning Failure:**
   The compatibility matrix and schemas pinned Codex to exact model strings
   (`gpt-5.6`, `gpt-5.6-terra`). On modern OpenAI/Codex accounts, `gpt-5.6` is
   no longer supported and fails immediately:
   `ERROR: The 'gpt-5.6' model is not supported when using Codex with a ChatGPT account.`
   Rigidly hardcoding model identifiers in central schemas forces constant breaking
   revisions every time a model provider updates versions.

2. **Ambient Model Inheritance vs Hardcoded Pinning:**
   Developers configure their preferred default models and accounts in their
   ambient client environments (e.g., `model = "gpt-6.1-terra"` in `~/.codex/config.toml`).
   Spec 10 previously forbade inheriting ambient models, requiring every selector
   to be derived strictly from the versioned matrix. In practice, this creates
   unnecessary breakage when provider model catalogs evolve.

3. **Antigravity & Token Quota Ceilings:**
   Direct Claude Pro/Team accounts enforce strict 7-day rolling window quota limits
   (`Usage Limit Reached: Your limit will reset in 6 days, 7 hours`). Antigravity
   provides access to Anthropic models (`claude-opus-5-5-*`, `claude-sonnet-5-5-*`)
   as well as Gemini models (`gemini-4-argon-*`, `gemini-3.8-flash-*`) via `agy models`.
   Antigravity was added as an operational adapter in commit `0dd3db9` but has not
   yet been formally ratified as a first-class client family in Loom's ADR and
   spec architecture.

## Decision

### 1. Ambient Inheritance as Default; Explicit Pinning as Option

Loom SHALL permit ambient model inheritance by default across all client adapters:

- **Codex:** If `--model` is not explicitly supplied by the caller, `loom-launch-role`
  SHALL inspect the active environment or `~/.codex/config.toml` for the ambient
  `model` configuration. If configured and valid, Loom SHALL inherit that ambient
  model (e.g., `gpt-6.1-terra`, `gpt-6.1-sol`, `gpt-6-astra`). If no ambient model
  is detected, Loom SHALL fall back to current family defaults (`gpt-6.1-terra` for
  Standard/Economy, `gpt-6.1-sol` for Deep review).
- **Claude:** Continues to resolve through Claude's floating tier selectors
  (`haiku`, `sonnet`, `opus`), which automatically resolve to the provider's
  latest models without manual revision.
- **Antigravity:** If `--model` is not explicitly supplied, `loom-launch-role`
  SHALL dynamically discover available models from `agy models` (cached locally
  with a 24-hour TTL) and map tier defaults:
  - `Deep review`: `claude-opus-5-5-high` (fallback `gemini-4-argon-high`)
  - `Standard`: `claude-sonnet-5-5-medium` (fallback `gemini-4-argon-medium`)
  - `Economy`: `gemini-3.8-flash-low`
- **Optional Pinning:** Explicit `--model <id>` CLI overrides and repository-level
  pinning via `.docs/loom-models.json` SHALL remain fully supported for users
  and CI environments that demand strict version reproducibility.

### 2. Reasoning Effort Policy

Reasoning effort governs the compute intensity allocated to tasks. Loom SHALL
determine reasoning effort according to role profile intensity by default:

| Profile | Consumers | Default Effort | Rationale |
|---|---|---|---|
| **Economy** | `researcher` | `low` | Fast context gathering and documentation scraping |
| **Standard** | `developer`, `orchestrator` | `medium` | Balanced code implementation and iterative testing |
| **Deep review** | `planner`, `plan-evaluator`, `code-evaluator` | `high` | Rigorous, critical verification and anti-drift inspection |

Callers MAY override default reasoning effort via `--effort <low|medium|high>`.
When launching with clients or models that embed effort levels in the identifier
(such as Antigravity's `-high`, `-medium`, `-low` suffixes), Loom SHALL map
the requested effort to the corresponding model suffix.

### 3. Formal Ratification of Antigravity

Antigravity is formally recognized as a first-class supported client family in
Loom alongside Claude Code and Codex:
- Antigravity participates in the multi-client cross-family evaluation cycle
  (`claude -> codex -> antigravity -> claude`).
- Antigravity launches SHALL validate against updated `loom-role-launch-v1`
  schemas and use verified canonical role prompts (`plugins/loom/roles/*.md`).
- Antigravity provides independent token capacity and model redundancy,
  enabling workflows to switch seamlessly between Anthropic and Gemini architectures
  when individual provider quotas are exhausted.

### 4. Schema and Compatibility Matrix Updates

The JSON schemas governing compatibility and role launching SHALL be updated
to accommodate modern and evolving model families:
- `loom-compatibility-matrix-v1.schema.json` and `loom-role-launch-v1.schema.json`
  SHALL accept `gpt-6*` and open model family patterns rather than closed legacy enums.
- The versioned compatibility matrix SHALL reflect current baseline floors.

## Consequences

- **Resilience:** Upgrades to provider model catalogs will no longer break Loom
  launches or require emergency schema patches.
- **Quota Flexibility:** Developers can route compute-heavy reviews to Claude Opus
  via Antigravity when direct Claude subscriptions reach quota limits.
- **Reproducibility Preserved:** Projects requiring fixed model versions can still
  pin models and effort levels via configuration or CLI arguments.
- **Spec Consistency:** Spec 10 §Versioned compatibility and capability mapping is
  amended to authorize ambient inheritance, dynamic Antigravity discovery, and
  flexible model patterns.

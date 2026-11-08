# Antigravity Client (4 of 5): Model Adapter and v0.3.0 Registration

Status: Plan Review
Target specs: 07-command-surface.md (Model and client surfaces), 10-packaging.md (client floors, compatibility matrix)
Authority: ADR 0032 §6, ADR 0034 §1, §3, §4, §5 (Accepted)
Target size: <= 380 LOC added (launcher + schema + fixtures + Bats; deletions not counted); keep this plan <= 250 lines

## Context

ADR [0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md) admits Antigravity (`agy`)
to the v0.3.0 scope on macOS 14+ Apple silicon at floor `1.4.12`. Runtime research in
[Orca and Antigravity runtime reference](../research/2026-11-08-orca-and-antigravity-runtime-reference.md)
verified CLI behavior at `/Users/craig/.local/bin/agy` (commands: `agy --version`, `agy models`).

Antigravity is a multi-family client runtime capable of running models from Google (`gemini-*`),
Anthropic (`claude-*`), and open-weights providers (`gpt-oss-*`). Per ADR 0034 §3, cross-family
evaluation governance must track the **underlying model provider family**, not solely client names.

**Model Provider Family Invariant (ADR 0034 §3):**
- Provider families:
  - `anthropic`: `claude` CLI client, or `antigravity` model matching `claude-*`.
  - `openai`: `codex` CLI client, or `antigravity` model matching `gpt-6*` or `openai`.
  - `google`: `antigravity` model matching `gemini-*`.
  - `oss`: `antigravity` model matching `gpt-oss-*`.
- Concrete model resolution: Every Antigravity launch resolves to a concrete model ID from the catalog; aliases (`flash`, `inherit`, `pro`) never map directly to a family and must resolve to concrete models or fail closed (`exit 2`).
- Evidence capture & handoff flow:
  - Component: The orchestrator driver (`loom-run`) captures the author launch descriptor stdout (`loom-role-launch/v1`), extracting `.claude.selector`, `.codex.model`, or `.antigravity.model`.
  - Handoff: The driver stores the resolved model in the routing file (`.routes["planner-model"]` / `.routes["developer-model"]`) and passes `--author-client <client> --author-model <model>` to evaluator launches (`plan-evaluator`, `code-evaluator`).
  - Validation: For `claude` author: `authorFamily=anthropic`. For `codex` author: `authorFamily=openai`. For `antigravity` author: author MUST supply concrete `--author-model <id>`. If missing or an unresolved alias, fail closed (`exit 2`) with `author model must be a concrete model identifier, not an alias`.
  - Invariant check: Deterministically resolve evaluator family from concrete model; if `authorFamily == evaluatorFamily`, fail closed (`exit 2`) with `cross-family evaluation violation: evaluator model family ($evaluatorFamily) matches author model family ($authorFamily)`.
- Cross-family rotation rules:
  - Author `claude` (`anthropic`) -> evaluator `codex` (`openai`).
  - Author `codex` (`openai`) -> evaluator `claude` (`anthropic`).
  - Author `antigravity` with Gemini (`google`) -> evaluator `codex` or `claude`.
  - Author `antigravity` with Claude (`anthropic`) -> evaluator `codex` (never `claude`).
  - Author `antigravity` with OpenAI (`openai`) -> evaluator `claude` (never `codex`).

**Registration decision.** Antigravity registration belongs exclusively to **v0.3.0**.
The v0.2.0 baseline file set is mechanically verified byte-identical against tagged release `v0.2.0` (`git show v0.2.0:<path>`):
1. `plugins/loom/adapters/compatibility/v0.2.0.json`
2. `plugins/loom/adapters/fixtures/v0.2.0/metadata/compatibility.json`
3. `plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-manifest.json`
4. `plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-manifest.json`
5. `plugins/loom/adapters/roots/claude-plugin-root-v1.json`
6. `plugins/loom/adapters/roots/codex-skill-source-v1.json`

## Verified Antigravity CLI 1.4.12 Behaviors & Catalog

Documented in `../research/2026-11-08-orca-and-antigravity-runtime-reference.md`:
- `agy --version`: Emits `1.4.12` (exit 0). Below-floor (< 1.4.12) or malformed version fails closed (exit 2).
- `agy models`: Emits tab-separated catalog (Gemini, Claude, OSS). Cached locally for 24h in owner-only `0600` file.

## Steps

### Step 1: Update Schemas & Toolchain Digests
1. Update `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`:
   - Add `antigravity-plugin-root/v1` variant to `oneOf` with exact properties:
     `schema` ("antigravity-plugin-root/v1"), `client` ("antigravity"), `inputMustBeAbsolute` (true),
     `invocationMustBeAbsolute` (true), `canonicalRootRequired` (true), `rolesDirectory` ("roles"),
     `rolesDirectoryMustBeDirectChild` (true), `canonicalRoleMustBeRegularFile` (true),
     `expectedName` ("loom"), `expectedVersion` ("0.3.0"), `helperDirectory` ("bin"),
     `helperDirectoryMustBeDirectChild` (true), `allowedHelpers` (`#/$defs/allowedHelpers`),
     `helperMustBeRegularFile` (true), `helperMustBeExecutable` (true).
2. Update `plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json`:
   - `clientFloors`: add `antigravity: { "type": "string" }`.
   - `profiles[].items.properties`: add `antigravity: { "type": "object", "required": ["model"], "properties": { "model": { "type": "string" } }, "additionalProperties": false }`.
3. Complete launch descriptor contract in `plugins/loom/schemas/loom-role-launch-v1.schema.json`:
   - Top-level `oneOf` with 3 objects (`additionalProperties: false` on every object):
     - Common required fields: `["schema", "client", "role", "profile", "coldId", "cold", "delegation", "permissions", "<client>"]`.
     - Common optional fields: `authorClient` (enum: `["claude", "codex", "antigravity"]`), `authorFamily` (enum: `["anthropic", "openai", "google", "oss"]`), `evaluatorFamily` (enum: `["anthropic", "openai", "google", "oss"]`), `crossFamilyVerified` (const `true`).
     - Variant `claude`: required `["selector", "agentCapability"]`; `selector` enum `["haiku", "sonnet", "opus"]`, `agentCapability` const `false`.
     - Variant `codex`: required `["model", "effort", "sandbox", "webSearch", "argv"]`; `model` pattern `^(gpt-6(\.[0-9]+)?(-[a-z0-9]+)?|gpt-5\.6(-[a-z0-9]+)?)$`, `effort` enum `["low", "medium", "high"]`, `sandbox` const `"read-only"`, `webSearch` const `false`, `argv` array of strings (minItems 1).
     - Variant `antigravity`: required `["subagentName", "model", "enableSubagentTools", "enableWriteTools", "rolePromptPath", "rolePromptSha256"]`; `subagentName` string minLength 1, `model` string minLength 1, `enableSubagentTools` const `false`, `enableWriteTools` const `true`, `rolePromptPath` string minLength 1, `rolePromptSha256` pattern `^[0-9a-f]{64}$`, optional `environment` object with required `LOOM_ROLE` string.
   - Compatibility: `--author-model` CLI flag is additive; emitted `authorFamily` and `evaluatorFamily` are additive top-level properties; existing consumers reading `authorClient` and `crossFamilyVerified` parse without modification.
4. Re-pin schema digests in `scripts/check-toolchain.json`.

### Step 2: v0.3.0 Matrix, Root Descriptor & Release Fixture
1. Update `plugins/loom/adapters/compatibility/v0.3.0.json`:
   - Add `clientFloors.antigravity: "1.4.12"`.
   - Add profile mappings for `antigravity`:
     - `Economy`: `gemini-3.8-flash-low`
     - `Standard`: `gemini-4-argon-medium`
     - `Deep review`: `gemini-4-argon-high`
   - Register root binding: `{ "id": "antigravity-plugin-root/v1", "path": "plugins/loom/adapters/roots/antigravity-plugin-root-v1.json" }`.
2. Create `plugins/loom/adapters/roots/antigravity-plugin-root-v1.json`:
   - Exact descriptor matching schema, with `allowedHelpers: ["loom-coord", "loom-verify-identity", "loom-review", "loom-eval-workspace", "loom-doctor", "loom-profile"]`.
3. Create byte-equal fixture `plugins/loom/adapters/fixtures/v0.3.0/metadata/root-antigravity.json`.

### Step 3: Implement Launcher Model-Family Resolution & Cross-Family Invariants
In `plugins/loom/bin/loom-launch-role`:
1. Add helper `_model_family <client> <model>`:
   - For `claude`: return `anthropic`.
   - For `codex`: return `openai`.
   - For `antigravity`:
     - `claude-*`: return `anthropic`.
     - `gpt-6*` | `gpt-5.6*` | `openai*`: return `openai`.
     - `gemini-*`: return `google`.
     - `gpt-oss-*`: return `oss`.
     - Aliases never pass to `_model_family`; concrete model is required.
     - Unmapped model: return empty / exit 1.
2. In role launch for `plan-evaluator` and `code-evaluator`:
   - Require author client: if absent under cross-family requirement, fail closed (`exit 2`).
   - Resolve `authorFamily`:
     - If `author_client` is `claude`: `authorFamily=anthropic`.
     - If `author_client` is `codex`: `authorFamily=openai`.
     - If `author_client` is `antigravity`: read `--author-model` (or `--routing-file` `.routes["<author-role>-model"]`). If absent or an alias (`inherit`, `flash`, `pro`), fail closed (`exit 2`) with `author model must be a concrete model identifier, not an alias`.
     - `authorFamily=$(_model_family "$author_client" "$author_model")` || `_fail "cannot deterministically resolve author model family: $author_model"`.
   - Resolve `evaluatorFamily`: `_model_family "$client" "$resolved_model"` || `_fail "cannot deterministically resolve evaluator model family: $resolved_model"`.
   - Enforce: `[ "$evaluatorFamily" != "$authorFamily" ] || _fail "cross-family evaluation violation: evaluator model family ($evaluatorFamily) matches author model family ($authorFamily)"`.
   - Emit in launch descriptor: `"authorClient":"$author_client","authorFamily":"$authorFamily","evaluatorFamily":"$evaluatorFamily","crossFamilyVerified":true`.
3. Auto rotation update in `_next_client_in_cycle`:
   - Author `claude` -> `codex`. Author `codex` -> `claude`.
   - Author `antigravity`: if `authorFamily` is `anthropic` -> `codex` (never `claude`); if `authorFamily` is `openai` -> `claude` (never `codex`); if `authorFamily` is `google` -> `codex`.

### Step 4: Repository Validator Updates
In `scripts/validate-repository.mjs`:
1. Add `["plugins/loom/adapters/roots/antigravity-plugin-root-v1.json", "plugins/loom/schemas/loom-installed-root-binding-v1.schema.json"]` to schema table.
2. In root validation:
   - Validate `antigravity-plugin-root-v1.json` deep-equals fixture `root-antigravity.json`.
   - Validate `v0.3.0.json` has `clientFloors.antigravity: "1.4.12"` matching binding floor.
   - Assert mechanical baseline: the 6 files of the v0.2.0 baseline file set are byte-identical to `git show v0.2.0:<path>`.

### Step 5: Test Coverage & Verification
1. `plugins/loom/bin/loom-launch-role.bats`:
   - Model-family extraction across all four families (`anthropic`, `openai`, `google`, `oss`).
   - Cross-family rejection: `antigravity` running Claude model evaluating `claude` author fails closed with family violation.
   - Cross-family acceptance: `antigravity` running Gemini model evaluating `claude` author succeeds.
   - Author model evidence handoff test: run author launch `antigravity planner`, extract emitted `.antigravity.model`, pass as `--author-model` to `codex plan-evaluator`, verify `authorFamily` and `evaluatorFamily` emitted with exit 0.
   - Multi-family author fail-closed: `antigravity` author without `--author-model` fails closed (exit 2).
   - Alias rejection: `--author-model inherit` fails closed (exit 2).
   - Unknown author model fail-closed: `--author-model unknown-model` fails closed (exit 2).
   - Same-family rejection: author Antigravity resolving to Claude model evaluated by Antigravity resolving to Claude model fails closed (exit 2).
   - Dynamic discovery cache: verifies hit, 24h TTL expiration, and atomic 0600 file rewrite.
   - Version refusal: below-floor `agy` (< 1.4.12) or unknown version fails closed (exit 2).
2. `scripts/tests/repository-validation.bats`:
   - Validate `antigravity-plugin-root/v1` schema and reject unknown fields.
   - Validate v0.3.0 matrix `clientFloors.antigravity` drift or omission fails closed.
3. Gate execution:
   - Full gate: `scripts/check` under Bash 3.2.57 and Bash 5.3+.

## Revision Log

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 3 | plan | FAIL | Author model handoff data flow and handoff test unspecified; launch descriptor schema lacked complete 3-variant contract and consumer compatibility definition. Resolved in Round 4 by specifying orchestrator descriptor capture, persistence, and `--author-model` handoff; defining the complete 3-variant `loom-role-launch-v1` schema with closed constraints, required/optional fields, and additive consumer compatibility; and adding an explicit author-to-evaluator handoff test. |
| 2 | plan | FAIL | Author model propagation lacked concrete evidence capture definition; launch schema lacked complete 3-variant contract and consumer compatibility; threat-model overstated cognitive independence; baseline paths not fully specified. Resolved in Round 3 by specifying author descriptor capture and mandatory concrete `--author-model`, rejecting aliases in family extraction, detailing the complete 3-variant `loom-role-launch-v1` schema with additive compatibility, enumerating the exact 6-file v0.2.0 repository paths for git show validation, and narrowing the threat-model claim to provider-family classification separation. |
| 1 | plan | FAIL | Step 3 mapped aliases to Google without establishing concrete model; `--author-family` permitted unverified claims; launch schema shape not detailed for all variants; v0.2.0 baseline and fixture comparisons inconsistent; threat-model overstated cognitive independence. Resolved in Round 2 by requiring concrete model resolution before family extraction, eliminating unverified `--author-family` in favor of mandatory concrete `--author-model`, defining exact launch schema additions across all three variants, specifying the 6-file v0.2.0 baseline verified against `git show v0.2.0:<path>`, and narrowing the threat-model claim strictly to provider-family separation. |
| 0 | plan | FAIL | Author family resolution inferred from profile floor on multi-family Antigravity; `scripts/check` gate omitted; dynamic discovery cache and version refusal tests omitted; launch descriptor schema and `allowedHelpers` unspecified; mechanical baseline for v0.2.0 undefined. Resolved in Round 1 by requiring `--author-model` for multi-family author, adding `scripts/check` under Bash 3.2 and 5.3+, specifying descriptor schemas and `allowedHelpers`, adding cache and version refusal tests, and defining mechanical fixture baseline. |

## Out of Scope & Threat-Model Boundary

- **Out of Scope:** Live E4 proof runs (reserved for Slice 5); editing v0.2.0 files or released tags; executing unstubbed `agy` in automated gates.
- **Threat-Model Boundary:** Consistent with ADR 0022 and ADR 0034 §2, process isolation does not provide kernel-level sandboxing against malicious same-UID processes. The provider-family invariant enforces model provider family classification separation (`anthropic` vs `openai` vs `google` vs `oss`). It does not assert or guarantee independent physical infrastructure, non-overlapping dataset sources, or weight divergence beyond vendor classification boundaries.

## Verification Commands

- Repository gate: `scripts/check`
- Canonical Bash gate: `TMPDIR=/private/tmp scripts/run-bats-under /bin/bash '^3\.2' "$(readlink -f "$(which bats)")" scripts/tests/shell-runtime.bats plugins/loom/bin/loom-launch-role.bats scripts/tests/repository-validation.bats </dev/null`

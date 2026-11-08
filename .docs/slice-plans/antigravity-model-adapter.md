# Antigravity Client (4 of 5): Model Adapter and v0.3.0 Registration

Status: Draft
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
  - `google`: `antigravity` model matching `gemini-*` (and fallbacks `flash`, `inherit`, `pro`).
  - `oss`: `antigravity` model matching `gpt-oss-*`.
- Fail-closed deterministic resolution:
  - Deterministically resolve both author family (`authorFamily`) and evaluator family (`evaluatorFamily`).
  - If `authorFamily` cannot be resolved: fail closed (`exit 2`).
  - If `evaluatorFamily` cannot be resolved: fail closed (`exit 2`).
  - If `authorFamily == evaluatorFamily`: fail closed (`exit 2`).
- Cross-family rotation rules:
  - If author is `claude` (`anthropic`): evaluator routes to `codex` (`openai`) or `antigravity` with Gemini (`google`).
  - If author is `codex` (`openai`): evaluator routes to `claude` (`anthropic`) or `antigravity` with Gemini (`google`).
  - If author is `antigravity` with Gemini (`google`): evaluator routes to `codex` (`openai`) or `claude` (`anthropic`).
  - If author is `antigravity` with Claude (`anthropic`): evaluator routes to `codex` (`openai`), NEVER `claude`.

**Registration decision.** Like `loom-host-hc` and `loom-host-orca`, Antigravity registration
belongs exclusively to **v0.3.0**. The v0.2.0 matrix and fixtures remain byte-unchanged against HEAD.

## Verified Antigravity CLI 1.4.12 Behaviors & Catalog

Documented in `../research/2026-11-08-orca-and-antigravity-runtime-reference.md`:
- `agy --version`: Emits `1.4.12` (exit 0).
- `agy models`: Emits tab-separated available models:
  - Gemini: `gemini-4-argon-medium`, `gemini-4-argon-high`, `gemini-3.8-flash-low`, etc.
  - Claude: `claude-opus-5-5-high`, `claude-sonnet-5-5-medium`, etc.
  - OSS: `gpt-oss-120b-medium`.

## Step-by-Step Implementation Plan

### Step 1: Update Schemas & Toolchain Digests
1. Update `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`:
   - Add `antigravity-plugin-root/v1` variant to `oneOf` with required properties:
     `schema` ("antigravity-plugin-root/v1"), `client` ("antigravity"), `inputMustBeAbsolute` (true),
     `invocationMustBeAbsolute` (true), `canonicalRootRequired` (true), `rolesDirectory` ("roles"),
     `rolesDirectoryMustBeDirectChild` (true), `expectedName` ("loom"), `expectedVersion` ("0.3.0"),
     `helperDirectory` ("bin"), `helperDirectoryMustBeDirectChild` (true), `allowedHelpers`,
     `helperMustBeRegularFile` (true), `helperMustBeExecutable` (true).
2. Update `plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json`:
   - Under `clientFloors`: add `antigravity: { "type": "string" }`.
   - Under `profiles[].items.properties`: add `antigravity: { "type": "object", "required": ["model"], "properties": { "model": { "type": "string" } }, "additionalProperties": false }`.
3. Compute new sha256 digests and update `scripts/check-toolchain.json`.

### Step 2: v0.3.0 Matrix, Root Descriptor & Release Fixture
1. Update `plugins/loom/adapters/compatibility/v0.3.0.json`:
   - Add `clientFloors.antigravity: "1.4.12"`.
   - Add profile mappings for `antigravity`:
     - `Economy`: `gemini-3.8-flash-low`
     - `Standard`: `gemini-4-argon-medium`
     - `Deep review`: `gemini-4-argon-high`
   - Register root binding: `{ "id": "antigravity-plugin-root/v1", "path": "plugins/loom/adapters/roots/antigravity-plugin-root-v1.json" }`.
2. Create `plugins/loom/adapters/roots/antigravity-plugin-root-v1.json`:
   - Conforms to `antigravity-plugin-root/v1` schema with `expectedVersion: "0.3.0"`.
3. Create byte-equal fixture:
   `plugins/loom/adapters/fixtures/v0.3.0/metadata/root-antigravity.json`.

### Step 3: Implement Launcher Model-Family Resolution & Cross-Family Invariants
In `plugins/loom/bin/loom-launch-role`:
1. Add helper `_model_family <client> <model>`:
   - For `claude`: return `anthropic`.
   - For `codex`: return `openai`.
   - For `antigravity`:
     - `claude-*`: return `anthropic`.
     - `gpt-6*` | `gpt-5.6*` | `openai*`: return `openai`.
     - `gemini-*` | `flash` | `inherit` | `pro`: return `google`.
     - `gpt-oss-*`: return `oss`.
     - else return empty / exit 1.
2. In role launch for `plan-evaluator` and `code-evaluator`:
   - Resolve `evaluatorFamily`: `_model_family "$client" "$resolved_model"` || `_fail "cannot deterministically resolve evaluator model family"`.
   - When `author_client` is supplied or routed:
     - Resolve `author_model` (from `--author-model` if provided, else profile floor for author client).
     - Resolve `authorFamily`: `_model_family "$author_client" "$author_model"` || `_fail "cannot deterministically resolve author model family"`.
     - Enforce `[ "$evaluatorFamily" != "$authorFamily" ] || _fail "cross-family evaluation violation: evaluator model family ($evaluatorFamily) matches author model family ($authorFamily)"`.
     - Emit in launch descriptor: `"authorClient":"<author_client>","authorFamily":"<authorFamily>","evaluatorFamily":"<evaluatorFamily>","crossFamilyVerified":true`.
3. Auto rotation update:
   - In `_next_client_in_cycle`:
     - When author is `claude`: default to `codex`.
     - When author is `codex`: default to `claude`.
     - When author is `antigravity`:
       - If author family is `anthropic`: return `codex` (never `claude`).
       - If author family is `openai`: return `claude`.
       - If author family is `google`: default to `codex` (or `claude`).
4. Update `_launch_antigravity` profile floor resolution to bind `v0.3.0.json` profiles when `--release 0.3.0` is specified or default falls through.

### Step 4: Repository Validator Updates
In `scripts/validate-repository.mjs`:
1. In schema validation table:
   - Add `["plugins/loom/adapters/roots/antigravity-plugin-root-v1.json", "plugins/loom/schemas/loom-installed-root-binding-v1.schema.json"]`.
2. In `validateHostBinding` (or dedicated v0.3.0 client root validation):
   - Include `antigravity-plugin-root-v1.json` in root paths check.
   - Validate that `antigravity-plugin-root-v1.json` matches fixture `plugins/loom/adapters/fixtures/v0.3.0/metadata/root-antigravity.json`.
   - Verify `v0.3.0.json` contains valid `clientFloors.antigravity: "1.4.12"` matching schema.
   - Assert that v0.2.0 files (`compatibility/v0.2.0.json`, fixtures/v0.2.0) are completely unchanged.

### Step 5: Test Coverage & Verification
1. `plugins/loom/bin/loom-launch-role.bats`:
   - Test model-family extraction: `claude` is `anthropic`, `codex` is `openai`, `agy gemini-*` is `google`, `agy claude-*` is `anthropic`.
   - Test cross-family rejection: `antigravity` running Claude model evaluating `claude` author fails closed with family violation.
   - Test cross-family acceptance: `antigravity` running Gemini model evaluating `claude` author succeeds with `crossFamilyVerified: true`.
   - Test intra-antigravity rejection: `antigravity` evaluating `antigravity` with same model family fails closed.
   - Test auto rotation: `antigravity` with Claude author routes to `codex`, never `claude`.
   - Test launch descriptor: emitted descriptor contains `authorFamily`, `evaluatorFamily`, and conforms to schema.
2. `scripts/tests/repository-validation.bats`:
   - Test `antigravity-plugin-root/v1` schema validation and reject unknown properties.
   - Test v0.3.0 `clientFloors.antigravity` drift or omission fails closed.
   - Test fixture drift for `root-antigravity.json` fails closed.
3. Gate execution:
   - Full repository check `node scripts/validate-repository.mjs --all`.
   - Bats test suites under Bash 3.2 canary.

## Out of Scope & Threat-Model Boundary

- **Out of Scope:**
  - Live E4 runs against real `agy` backend (reserved for `v0.3.0-live-proof` follow-on slice).
  - Editing v0.2.0 matrices, schemas, or fixtures.
  - Relaxing the ADR 0034 §2 evaluator isolation rule (evaluators always run in clean POSIX scratch spaces).
- **Threat-Model Boundary:**
  - Consistent with ADR 0022 and ADR 0034 §2, process isolation and input filtering do not provide kernel sandboxing against malicious same-UID processes.
  - The model family invariant guarantees cognitive independence across disparate model training/weights families.

## Verification Commands

- Repository validation: `node scripts/validate-repository.mjs --all`
- Targeted Bats verification under Bash 3.2:
  `TMPDIR=/private/tmp scripts/run-bats-under /bin/bash '^3\.2' "$(readlink -f "$(which bats)")" scripts/tests/shell-runtime.bats plugins/loom/bin/loom-launch-role.bats scripts/tests/repository-validation.bats </dev/null`

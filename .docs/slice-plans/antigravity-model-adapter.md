# Antigravity Client (4 of 5): Model Adapter and v0.3.0 Registration

Status: Approved
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
  - Component: The orchestrator driver (`loom-run`) launches roles via `loom-launch-role`. When an author role (`planner`, `developer`, `researcher`) is launched with `--routing-file <path>`, `loom-launch-role` captures the resolved concrete model and persists its role keys into the routing file.
  - Handoff: The orchestrator passes `--routing-file <path>` to evaluator launches (`plan-evaluator`, `code-evaluator`), where `loom-launch-role auto <evaluator-role> --routing-file <path>` extracts author provenance, resolves families, enforces the cross-family invariant, and prints the verified descriptor.
  - Validation: For single-family authors (`claude` -> `anthropic`, `codex` -> `openai`), `--author-model` is optional and defaults to the client's sole family. For multi-family author `antigravity`, author model MUST be supplied via `--author-model <id>` or `.routes["<author-role>-model"]`. If missing or an alias, fail closed (`exit 2`) with `author model must be a concrete model identifier, not an alias`.
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

### Step 1: Update Schemas, Consumer Resolution Paths & Digests
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
     - Common required fields (identical across all 3 variants):
       - `schema`: `{ "const": "loom-role-launch/v1" }`
       - `client`: `{ "const": "<variant-client>" }` (`"claude"`, `"codex"`, or `"antigravity"`)
       - `role`: `{ "enum": ["researcher", "planner", "plan-evaluator", "developer", "code-evaluator"] }`
       - `profile`: `{ "enum": ["Economy", "Standard", "Deep review"] }`
       - `coldId`: `{ "type": "string", "minLength": 1 }`
       - `cold`: `{ "const": true }`
       - `delegation`: `{ "const": false }`
       - `permissions`: `{ "const": "one-level" }`
       - Variant key: `"claude"`, `"codex"`, or `"antigravity"` (required object per variant).
     - Common optional fields (identical across all 3 variants):
       - `authorClient`: `{ "enum": ["claude", "codex", "antigravity"] }`
       - `authorFamily`: `{ "enum": ["anthropic", "openai", "google", "oss"] }`
       - `evaluatorFamily`: `{ "enum": ["anthropic", "openai", "google", "oss"] }`
       - `crossFamilyVerified`: `{ "type": "boolean" }`
     - Variant-specific object shapes:
       - `claude`: `type: "object"`, `additionalProperties: false`, required `["selector", "agentCapability"]`; `selector`: `{ "enum": ["haiku", "sonnet", "opus"] }`, `agentCapability`: `{ "const": false }`.
       - `codex`: `type: "object"`, `additionalProperties: false`, required `["model", "effort", "sandbox", "webSearch", "argv"]`; `model`: `{ "type": "string", "pattern": "^(gpt-6(\\.[0-9]+)?(-[a-z0-9]+)?|gpt-5\\.6(-[a-z0-9]+)?)$" }`, `effort`: `{ "enum": ["low", "medium", "high"] }`, `sandbox`: `{ "const": "read-only" }`, `webSearch`: `{ "const": false }`, `argv`: `{ "type": "array", "minItems": 1, "items": { "type": "string" } }`.
       - `antigravity`: `type: "object"`, `additionalProperties: false`, required `["subagentName", "model", "enableSubagentTools", "enableWriteTools", "rolePromptPath", "rolePromptSha256"]`; `subagentName`: `{ "type": "string", "minLength": 1 }`, `model`: `{ "type": "string", "minLength": 1 }`, `enableSubagentTools`: `{ "type": "boolean" }`, `enableWriteTools`: `{ "type": "boolean" }`, `rolePromptPath`: `{ "type": "string", "minLength": 1 }`, `rolePromptSha256`: `{ "type": "string", "pattern": "^[0-9a-f]{64}$" }`, optional `environment`: `{ "type": "object", "additionalProperties": false, "required": ["LOOM_ROLE"], "properties": { "LOOM_ROLE": { "type": "string", "minLength": 1 } } }`.
   - Consumer identification, schema handling & versioning breakdown:
     1. Test validator (`plugins/loom/bin/loom-launch-role.bats:validate_launch`): The sole consumer that compiles and validates descriptors against the schema, using strict `Ajv2020({ strict: true, allowUnionTypes: true })`. It loads the schema by file path directly from `$REPO_ROOT/plugins/loom/schemas/loom-role-launch-v1.schema.json`. Because it enforces `additionalProperties: false`, updating this file to admit optional `authorFamily` and `evaluatorFamily` is strictly required and sufficient for this consumer to validate v0.3.0 descriptors while continuing to accept legacy v0.2.0 descriptors.
     2. Launcher guard (`plugins/loom/bin/loom-launch-role`): Does not parse or validate descriptor payloads against the JSON schema; it performs a file-presence assertion (`[ -f "$schema_path" ] && [ ! -L "$schema_path" ]`) at `$root/schemas/loom-role-launch-v1.schema.json` before invoking Codex. It emits version identifier `loom-role-launch/v1` with additive optional fields.
     3. Integrity validator (`scripts/validate-repository.mjs`): Verifies JSON syntax and pins the schema file's SHA-256 digest against `scripts/check-toolchain.json`. It does not validate descriptor payloads. Updating `check-toolchain.json` re-pins this integrity check.
     4. Orchestrator session (`plugins/loom/skills/loom-run/SKILL.md`): Consumes launcher stdout directly as parsed JSON (via client runtime or jq) to extract execution properties; it maintains no JSON schema validator or closed schema copy and ignores additive unknown fields.
   - Mechanically verifiable basis for no-duplicate claim:
     - Verified via `git grep -l "loom-role-launch"`: only `plugins/loom/schemas/loom-role-launch-v1.schema.json` defines a launch schema in the repository. No separate closed schemas or duplicate copies exist in-tree; thus updating this file updates 100% of closed-schema validation in Loom.
   - Out-of-tree consumer boundary:
     - External or third-party consumers embedding their own frozen closed copies of `loom-role-launch-v1.schema.json` with `additionalProperties: false` would reject descriptors with added properties until updated. Loom considers `loom-role-launch/v1` an additive non-breaking minor revision under ADR 0032 SemVer rules; out-of-tree consumers must track the canonical schema asset at tag `v0.3.0`.
   - CLI compatibility: `--author-model` is optional; single-family calls default automatically, while multi-family `antigravity` fails closed if model is omitted or an alias.
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
   - For `antigravity`: `claude-*` -> `anthropic`, `gpt-6*` | `gpt-5.6*` | `openai*` -> `openai`, `gemini-*` -> `google`, `gpt-oss-*` -> `oss`. Aliases fail closed; unmapped models return empty / exit 1.
2. In author role launches (`planner`, `developer`, `researcher`):
   - When `--routing-file <path>` is supplied, atomically update the routing file for the specific role without touching other roles' keys:
     - For `planner`: `.routes["planner"] = "$client"` and `.routes["planner-model"] = "$resolved_model"`.
     - For `developer`: `.routes["developer"] = "$client"` and `.routes["developer-model"] = "$resolved_model"`.
     - For `researcher`: `.routes["researcher"] = "$client"` and `.routes["researcher-model"] = "$resolved_model"`.
3. In evaluator role launches (`plan-evaluator`, `code-evaluator`):
   - Require author client: if absent under cross-family requirement, fail closed (`exit 2`).
   - Read author model: from `--author-model <model>`, or if `--routing-file <path>` is supplied, from `.routes["planner-model"]` (for `plan-evaluator`) or `.routes["developer-model"]` (for `code-evaluator`).
   - Resolve `authorFamily`:
     - If `author_client` is `claude`: `authorFamily=anthropic` (defaulting even if `--author-model` omitted).
     - If `author_client` is `codex`: `authorFamily=openai` (defaulting even if `--author-model` omitted).
     - If `author_client` is `antigravity`: if `author_model` is missing or an alias (`inherit`, `flash`, `pro`), fail closed (`exit 2`) with `author model must be a concrete model identifier, not an alias`; else `authorFamily=$(_model_family "$author_client" "$author_model")` || `_fail "cannot deterministically resolve author model family: $author_model"`.
   - Resolve `evaluatorFamily`: `_model_family "$client" "$resolved_model"` || `_fail "cannot deterministically resolve evaluator model family: $resolved_model"`.
   - Enforce invariant: `[ "$evaluatorFamily" != "$authorFamily" ] || _fail "cross-family evaluation violation: evaluator model family ($evaluatorFamily) matches author model family ($authorFamily)"`.
   - Emit in launch descriptor: `"authorClient":"$author_client","authorFamily":"$authorFamily","evaluatorFamily":"$evaluatorFamily","crossFamilyVerified":true`.
4. Auto rotation update in `_next_client_in_cycle`:
   - Author `claude` -> `codex`. Author `codex` -> `claude`.
   - Author `antigravity`: if `authorFamily` is `anthropic` -> `codex` (never `claude`); if `authorFamily` is `openai` -> `claude` (never `codex`); if `authorFamily` is `google` -> `codex`.

### Step 4: Update Orchestrator Workflow Skill
In `plugins/loom/skills/loom-run/SKILL.md`:
1. Under Step 3.d (Driver loop):
   - Document that when dispatching author roles (`planner`, `developer`, `researcher`), `loom-run` passes `--routing-file "$ROUTING_FILE"` to `loom-launch-role` so author client and concrete model are persisted automatically into role-specific keys.
   - When dispatching evaluator roles (`plan-evaluator`, `code-evaluator`), `loom-run` passes `auto <evaluator-role> --routing-file "$ROUTING_FILE"` so `loom-launch-role` reads persisted author provenance and verifies the cross-family invariant.

### Step 5: Repository Validator Updates
In `scripts/validate-repository.mjs`:
1. Add `["plugins/loom/adapters/roots/antigravity-plugin-root-v1.json", "plugins/loom/schemas/loom-installed-root-binding-v1.schema.json"]` to schema table.
2. In root validation:
   - Validate `antigravity-plugin-root-v1.json` deep-equals fixture `root-antigravity.json`.
   - Validate `v0.3.0.json` has `clientFloors.antigravity: "1.4.12"` matching binding floor.
   - Assert mechanical baseline: the 6 files of the v0.2.0 baseline file set are byte-identical to `git show v0.2.0:<path>`.

### Step 6: Test Coverage & Verification
1. `plugins/loom/bin/loom-launch-role.bats`:
   - Model-family extraction across all four families (`anthropic`, `openai`, `google`, `oss`).
   - Backward compatibility: `--author-client claude` without `--author-model` succeeds with `authorFamily: "anthropic"`; `--author-client codex` without `--author-model` succeeds with `authorFamily: "openai"`.
   - Cross-family rejection with CLI flags: `antigravity` running Claude model evaluating `claude` author fails closed (exit 2).
   - Cross-family acceptance with CLI flags: `antigravity` running Gemini model evaluating `claude` author succeeds (exit 0).
   - Production path orchestrator capture, persistence, and evaluator handoff test:
     1. Invoke author launch production path: `loom-launch-role antigravity planner --routing-file "$routing_file"`.
     2. Assert routing-file persistence: verify `$routing_file` on disk contains `.routes["planner"] == "antigravity"` and `.routes["planner-model"] == "gemini-4-argon-medium"`.
     3. Invoke evaluator launch production path: `LOOM_LAUNCH_ROLE_CODEX_BIN="$STUB" loom-launch-role auto plan-evaluator --routing-file "$routing_file"`.
     4. Assert evaluator output: status 0, emitted JSON contains `"authorClient":"antigravity"`, `"authorFamily":"google"`, `"evaluatorFamily":"openai"`, `"crossFamilyVerified":true`.
     5. Routing-file same-family rejection: write routing file with `.routes["planner"] = "antigravity"`, `.routes["planner-model"] = "claude-3-7-sonnet"`, and `.routes["plan-evaluator"] = "claude"`; run `loom-launch-role auto plan-evaluator --routing-file "$routing_file"`; assert exit 2 with `cross-family evaluation violation: evaluator model family (anthropic) matches author model family (anthropic)`.
   - Researcher routing-file persistence isolation test:
     1. Seed routing file with all four planner and developer provenance keys: `.routes["planner"] = "claude"`, `.routes["planner-model"] = "sonnet"`, `.routes["developer"] = "codex"`, `.routes["developer-model"] = "gpt-6.1-terra"`.
     2. Run `loom-launch-role antigravity researcher --routing-file "$routing_file"`.
     3. Assert both researcher keys updated: `.routes["researcher"] == "antigravity"` and `.routes["researcher-model"] == "gemini-4-argon-medium"`.
     4. Assert all four seeded keys remain strictly unchanged: `.routes["planner"] == "claude"`, `.routes["planner-model"] == "sonnet"`, `.routes["developer"] == "codex"`, and `.routes["developer-model"] == "gpt-6.1-terra"`.
   - Multi-family author fail-closed: `antigravity` author without `--author-model` or routing model fails closed (exit 2).
   - Alias rejection: `--author-model inherit` fails closed (exit 2).
   - Unknown author model fail-closed: `--author-model unknown-model` fails closed (exit 2).
   - Dynamic discovery cache: verifies hit, 24h TTL expiration, and atomic 0600 file rewrite.
   - Version refusal: below-floor `agy` (< 1.4.12) or unknown version fails closed (exit 2).
   - Consumer schema validation & compatibility:
     - Strict Ajv 2020 (`additionalProperties: false`) exercises consumer validation path for legacy descriptor omitting `authorFamily`/`evaluatorFamily` (exit 0).
     - Strict Ajv 2020 exercises consumer validation path for v0.3.0 descriptor containing `authorFamily` and `evaluatorFamily` (exit 0).
     - Strict Ajv 2020 rejects descriptor containing undeclared property (exit 1), proving `additionalProperties: false` is strictly enforced.
2. `scripts/tests/repository-validation.bats`:
   - Validate `antigravity-plugin-root/v1` schema and reject unknown fields.
   - Validate v0.3.0 matrix `clientFloors.antigravity` drift or omission fails closed.
3. Gate execution:
   - Full gate: `scripts/check` under Bash 3.2.57 and Bash 5.3+.

## Revision Log

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 7 | plan | FAIL | Consumer schema handling description conflated direct validation with file existence/parsing; researcher isolation test omitted planner/developer model keys. Resolved in Round 8 by breaking down exact schema resolution, versioning, and validation behavior for each of the 4 consumers; establishing mechanically verified in-tree exclusivity (`git grep -l "loom-role-launch"`) and out-of-tree frozen-schema boundary; and seeding/asserting all four planner and developer provenance keys unchanged during researcher routing-file isolation test. |
| 6 | plan | FAIL | Consumer resolution paths not identified to substantiate single canonical schema claim; researcher routing-file persistence behavior ambiguous. Resolved in Round 7 by explicitly enumerating all 4 launch-descriptor consumers and their file resolution paths, establishing why version v1 is backward-compatible with no duplicate schemas, defining isolated researcher routing persistence (.routes["researcher"] and ["researcher-model"]) that cannot overwrite planner/developer keys, and adding an explicit test for researcher routing isolation. |
| 5 | plan | FAIL | Test still performed orchestrator capture manually instead of invoking production path; closed-schema consumer sharing and versioning behavior not established. Resolved in Round 6 by adding Step 4 for `loom-run/SKILL.md` orchestrator workflow, implementing `--routing-file` author-launch capture and persistence in `loom-launch-role`, asserting that all consumers share the canonical schema asset under compatible minor extension `v1`, and adding tests invoking the production author-persistence -> evaluator-handoff path and strict Ajv legacy/v0.3.0 consumer validation. |
| 4 | plan | FAIL | Descriptor types & constraints incomplete across 3 variants and environment object; consumer and CLI compatibility unspecified for omitted --author-model and closed schemas; handoff test bypassed orchestrator routing-file flow. Resolved in Round 5 by defining complete types, enums, patterns, and constraints for all common and variant fields with additionalProperties: false; specifying single-family backward compatibility defaults and schema property updates for closed-schema consumers; and replacing manual extraction test with full orchestrator launch capture, routing-file persistence, and evaluator handoff test. |
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

# Herdr client adapter

Status: Plan Review
Target specs: 00-overview.md, 10-packaging.md; ADRs 0018, 0027, 0029
Target size: <= 180 LOC net code change (excluding tests and metadata)

## Context

Milestone M9 introduces client adapter support for Herdr and its native desktop
application (`/Applications/Herdr.app`, v0.1.10) alongside Claude Code, Codex, and
Antigravity. As researched and cited in
`.docs/research/2026-11-01-herdr-client-adapter-contract.md` and authorized in
`.docs/ADR/0029-herdr-client-adapter-and-native-app-support.md`, Herdr provides an
agent-centric workspace and persistent terminal runtime.

This slice implements the thin Herdr client adapter contracts: plugin and
marketplace discovery manifests, the installed-root binding descriptor,
compatibility matrix integration in `v0.3.0.json`, helper resolution in
`loom-resolve-helper`, and cold lifecycle role launching in `loom-launch-role`.
The core remains completely client-neutral; Herdr specifics are isolated to the
adapter layer.

## Out of Scope & Threat-Model Boundary

Native-app lifecycle event hooks, identity and governance hook bindings, live
window GUI automation, and public distribution publication belong to subsequent M9
slices and future milestones. This slice does not modify shared role contracts,
Claude/Codex/Antigravity adapter behaviors, or claim public platform support. As
defined in spec 00 Non-goals, a private directory is a trust boundary; hostile
local process containment, memory inspection, and symlink swapping inside private
temporary workspaces are not defended by this slice.

## Files to touch

- `plugins/loom/.herdr-plugin/plugin.json` — Herdr plugin discovery manifest.
- `.herdr-plugin/marketplace.json` — repository marketplace registration pointing to `./plugins/loom`.
- `plugins/loom/adapters/roots/herdr-plugin-root-v1.json` — installed-root binding descriptor (`herdr-plugin-root/v1`).
- `plugins/loom/adapters/compatibility/v0.3.0.json` — register Herdr floor (`0.1.10`), root binding, and profile mappings.
- `plugins/loom/bin/loom-resolve-helper` — support `herdr <helper>` via `HERDR_PLUGIN_ROOT`.
- `plugins/loom/bin/loom-launch-role` — support client `herdr` with cold ID and ambient model inheritance.
- `plugins/loom/bin/loom-launch-role.bats` — unit and integration tests for Herdr role launches.
- `plugins/loom/bin/loom-resolve-helper.bats` — fail-closed resolution tests for `herdr`.
- `scripts/validate-repository.mjs` — register Herdr metadata and root binding descriptors for repository validation.

## Steps

1. Create `plugins/loom/.herdr-plugin/plugin.json`:
   ```json
   {
     "name": "loom",
     "version": "0.2.0",
     "description": "Dual-client spec-driven development system",
     "author": "Craig Pfeiffer",
     "skills": "skills"
   }
   ```
   and `.herdr-plugin/marketplace.json`:
   ```json
   {
     "name": "loom",
     "version": "0.2.0",
     "description": "Dual-client spec-driven development system",
     "source": "./plugins/loom"
   }
   ```
2. Create `plugins/loom/adapters/roots/herdr-plugin-root-v1.json` using schema
   `herdr-plugin-root/v1`:
   - client: `herdr`, binding: `HERDR_PLUGIN_ROOT`.
   - inputMustBeAbsolute, invocationMustBeAbsolute, canonicalizeInput, canonicalRootRequired: `true`.
   - manifest: `.herdr-plugin/plugin.json`, manifestMustBeCanonical, manifestMustBeRegularFile: `true`.
   - expectedName: `loom`, expectedVersion: `0.2.0`.
   - helperDirectory: `bin`, helperDirectoryMustBeDirectChild: `true`.
   - allowedHelpers: `["loom-coord", "loom-verify-identity", "loom-review", "loom-eval-workspace", "loom-doctor", "loom-profile"]` (mirroring the Claude root descriptor allowlist).
   - helperMustBeRegularFile, helperMustBeExecutable: `true`.
3. In `plugins/loom/adapters/compatibility/v0.3.0.json`:
   - Add `"herdr": "0.1.10"` to `.clientFloors`.
   - Add `{ "id": "herdr-plugin-root/v1", "path": "plugins/loom/adapters/roots/herdr-plugin-root-v1.json" }` to `.rootBindings`.
   - Under `.profiles[]`, add `"herdr": { "profile": "<profile>" }` for `Economy`, `Standard`, and `Deep review`.
4. In `plugins/loom/bin/loom-resolve-helper`:
   - Add `herdr)` case resolving via `HERDR_PLUGIN_ROOT` using the identical
     validation rules as `claude`: fail closed if unset, relative, nonexistent, not a
     directory, manifest missing/malformed/mismatched, or helper not in allowlist.
5. In `plugins/loom/bin/loom-launch-role`:
   - Support `herdr` client: validate role against matrix, resolve capability profile,
     generate fresh cold session identifier (`coldId`), set `delegation: false`,
     `permissions: "one-level"`, export `LOOM_ROLE=<role>`, and emit normalized
     JSON payload (`{"schema":"loom-role-launch/v1","client":"herdr","role":"<role>","profile":"<profile>",...}`).
6. Update `scripts/validate-repository.mjs`:
   - Register `herdr-plugin-root-v1.json` and `.herdr-plugin/plugin.json` in adapter
     validation schemas and allowlists so `validate-repository.mjs --all` passes.
7. Add automated Bats tests:
   - In `plugins/loom/bin/loom-resolve-helper.bats`: test valid `HERDR_PLUGIN_ROOT`
     resolution, missing env, relative path rejection, manifest mismatch, symlink
     escape rejection, and helper allowlist enforcement.
   - In `plugins/loom/bin/loom-launch-role.bats`: test `herdr` launches for all five
     roles with correct profiles, non-delegation, and cold ID freshness.

## Verification

- Run targeted Bats tests:
  ```sh
  LOOM_TEST_BASH=/opt/homebrew/bin/bash bats plugins/loom/bin/loom-resolve-helper.bats plugins/loom/bin/loom-launch-role.bats
  ```
- Run full repository validation:
  ```sh
  node scripts/validate-repository.mjs --root . --all
  ```
- Affirmative contract checks:
  ```sh
  jq -e '.clientFloors.herdr == "0.1.10"' plugins/loom/adapters/compatibility/v0.3.0.json
  jq -e '.rootBindings[] | select(.id == "herdr-plugin-root/v1")' plugins/loom/adapters/compatibility/v0.3.0.json
  plugins/loom/bin/loom-launch-role herdr researcher | jq -e '.client == "herdr" and .role == "researcher" and .profile == "Economy"'
  plugins/loom/bin/loom-launch-role herdr developer | jq -e '.client == "herdr" and .role == "developer" and .profile == "Standard"'
  plugins/loom/bin/loom-launch-role herdr planner | jq -e '.client == "herdr" and .role == "planner" and .profile == "Deep review"'
  ```
- Negative assertion:
  ```sh
  HERDR_PLUGIN_ROOT="/invalid/path" plugins/loom/bin/loom-resolve-helper herdr loom-doctor || [ $? -ne 0 ]
  ```
- Run full repository gate:
  ```sh
  scripts/check
  ```

## Notes

All Herdr contract values and schemas are grounded in primary research note
`.docs/research/2026-11-01-herdr-client-adapter-contract.md` and authorized in
`.docs/ADR/0029-herdr-client-adapter-and-native-app-support.md`.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft; Herdr contract evidence identified as blocking. |
| 1 | Pinned exact contract values from primary research; resolved authority gap via ADR 0029; removed deferral step; established definite file scope, matrix paths, and Bats test locations. |

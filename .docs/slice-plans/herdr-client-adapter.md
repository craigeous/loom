# Herdr client adapter

Status: Plan Review
Target specs: 00-overview.md, 10-packaging.md; ADRs 0018, 0027, 0029
Target size: <= 180 LOC net code change (excluding tests and metadata)

## Context

Milestone M9 introduces client adapter support for Herdr and its native desktop
application (`/Applications/Herdr.app`, v0.1.10) alongside Claude Code, Codex, and
Antigravity. As researched and cited in
`.docs/research/2026-11-01-herdr-client-adapter-contract.md` (Approved) and
authorized in `.docs/ADR/0029-herdr-client-adapter-and-native-app-support.md`
(Accepted), Herdr provides an agent-centric workspace and persistent terminal runtime.

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
2. Create `plugins/loom/adapters/roots/herdr-plugin-root-v1.json`:
   ```json
   {
     "schema": "loom-installed-root-binding-v1",
     "id": "herdr-plugin-root/v1",
     "client": "herdr",
     "binding": "HERDR_PLUGIN_ROOT",
     "inputMustBeAbsolute": true,
     "invocationMustBeAbsolute": true,
     "canonicalizeInput": true,
     "canonicalRootRequired": true,
     "manifest": ".herdr-plugin/plugin.json",
     "manifestMustBeCanonical": true,
     "manifestMustBeRegularFile": true,
     "expectedName": "loom",
     "expectedVersion": "0.2.0",
     "helperDirectory": "bin",
     "helperDirectoryMustBeDirectChild": true,
     "allowedHelpers": ["loom-coord", "loom-verify-identity", "loom-review", "loom-eval-workspace", "loom-doctor", "loom-profile"],
     "helperMustBeRegularFile": true,
     "helperMustBeExecutable": true
   }
   ```
3. In `plugins/loom/adapters/compatibility/v0.3.0.json`:
   - Set `.clientFloors.herdr` to `"0.1.10"`.
   - Add `{ "id": "herdr-plugin-root/v1", "path": "plugins/loom/adapters/roots/herdr-plugin-root-v1.json" }` to `.rootBindings`.
   - In `.profiles[]`:
     - Profile `"Economy"`: add `"herdr": { "profile": "Economy" }`.
     - Profile `"Standard"`: add `"herdr": { "profile": "Standard" }`.
     - Profile `"Deep review"`: add `"herdr": { "profile": "Deep review" }`.
4. In `plugins/loom/bin/loom-resolve-helper`:
   - Add `herdr)` case resolving via `HERDR_PLUGIN_ROOT` using the identical
     validation rules as `claude`: fail closed if unset, relative, nonexistent, not a
     directory, manifest missing/malformed/mismatched, or helper not in allowlist.
5. In `plugins/loom/bin/loom-launch-role`:
   - Support `herdr` client: validate role against matrix, resolve capability profile,
     generate fresh cold session identifier (`coldId`), set `delegation: false`,
     `permissions: "one-level"`, export `LOOM_ROLE=<role>`, and emit normalized JSON:
     ```json
     {"schema":"loom-role-launch/v1","client":"herdr","role":"<role>","profile":"<profile>","coldId":"<coldId>","cold":true,"delegation":false,"permissions":"one-level","herdr":{"profile":"<profile>"}}
     ```
     The launcher emits the normalized launch descriptor and does not spawn a live desktop window without an execution request.
6. In `scripts/validate-repository.mjs`:
   - In `validateSchemas()`: add `["plugins/loom/adapters/roots/herdr-plugin-root-v1.json", "plugins/loom/schemas/loom-installed-root-binding-v1.schema.json"]` to `schemaBindings`.
   - In `checkMatrixRootBindings()`: add `"plugins/loom/adapters/roots/herdr-plugin-root-v1.json"` to the roots allowlist array.
7. Add automated Bats tests:
   - In `plugins/loom/bin/loom-resolve-helper.bats`: test valid `HERDR_PLUGIN_ROOT`
     resolution, missing env, relative path rejection, manifest mismatch, symlink
     escape rejection, and helper allowlist enforcement.
   - In `plugins/loom/bin/loom-launch-role.bats`: test `herdr` launches for all five
     roles with correct profiles, non-delegation, and cold ID freshness.
   - Assert all existing Claude, Codex, and Antigravity tests pass without regression.

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
- Negative assertion (must exit non-zero and print error):
  ```sh
  ! HERDR_PLUGIN_ROOT="/invalid/path" plugins/loom/bin/loom-resolve-helper herdr loom-doctor
  ```
- Run full repository gate:
  ```sh
  scripts/check
  ```

## Notes

All Herdr contract values and schemas are grounded in approved research note
`.docs/research/2026-11-01-herdr-client-adapter-contract.md` and authorized in
accepted `.docs/ADR/0029-herdr-client-adapter-and-native-app-support.md`.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft; Herdr contract evidence identified as blocking. |
| 1 | Pinned contract values from primary research; resolved authority gap via ADR 0029; removed deferral step; established definite file scope and Bats locations. |
| 2 | Grounded in Accepted ADR 0029 and Approved research note; eliminated placeholders in Steps 3 and 5 with exact JSON payloads; specified exact validator edits in Step 6; corrected descriptor schema/id fields in Step 2; made negative oracle fail-closed (`! cmd`). |

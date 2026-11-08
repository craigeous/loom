# Orca Client (3 of 5): Host Adapter `loom-host-orca` and v0.3.0 Registration

Status: Plan Review
Target specs: 07-command-surface.md (Host surfaces), 10-packaging.md (host floors)
Authority: ADR 0032 §6, ADR 0034 §1, §2, §5 (Accepted)
Target size: <= 380 LOC added (helper + Bats + registration; deletions not counted); keep this plan <= 250 lines

## Context

ADR [0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md) admits Orca to the
v0.3.0 scope on macOS 14+ Apple silicon at floor `1.4.250`. Runtime research in
[Orca and Antigravity runtime reference](../research/2026-11-08-orca-and-antigravity-runtime-reference.md)
verified CLI behavior at `/Applications/Orca.app/Contents/Resources/bin/orca` (commands:
`orca terminal create`, `show`, `read`, `wait`, `close`, `list`).

Like `loom-host-hc` (landed `a84ddf3`), `loom-host-orca` is a host adapter that observes
and cleans up host terminal sessions but never launches roles directly until the
owner-recorded live probes pass. Evaluator roles run in independent, sanitized `0700` POSIX
scratch workspaces outside the host terminal tree (ADR 0034 §2; spec 05).

**Registration decision (owner, binding).** `loom-host-orca` is registered under the
**v0.3.0** matrix alongside `loom-host-hc`. The v0.2.0 release evidence stays untouched:
frozen fixtures under `plugins/loom/adapters/fixtures/v0.2.0/`, `v0.2.0.json`, and the
installed-root bindings are **not edited**. `loom-host-orca` is **not** added to
`ALLOWED_HELPERS` or any root `allowedHelpers`. It is a *host helper*: a regular
executable directly under `bin/loom-host-orca`.

**v0.3.0 fixture layout.** This slice adds `plugins/loom/adapters/fixtures/v0.3.0/metadata/host-orca.json`,
the release-evidence copy of the host descriptor for the v0.3.0 release, byte-equal to
the live descriptor `plugins/loom/adapters/hosts/orca-host-v1.json`.

## Out of Scope & Threat-Model Boundary

- **No role launch.** `launch` refuses unconditionally (`exit 2`): it reads no input, has
  no override variable, and never invokes `orca` (ADR 0034 §1, §2).
- No GUI control, tab switching, focus stealing, remote pairing, or config writes.
- `orca` does not enforce blind evaluation or delegation limits (ADR 0034 §2; spec 05,
  spec 08). The helper is an observation and cleanup convenience, not a security boundary.
- **Matrix registration.** `loom-compatibility-matrix-v1.schema.json` gains an optional
  `orca` property under `hostFloors` (`floor: "1.4.250"`, `helper: "loom-host-orca"`).
  `v0.2.0.json` has no `hostFloors` and validates unchanged. `v0.3.0.json` gains `hostFloors.orca`.
  The matrix schema SHA-256 in `scripts/check-toolchain.json` is re-pinned.
- **Host binding schema.** `plugins/loom/schemas/loom-host-binding-v1.schema.json` is updated
  with `oneOf` to accept both `hc-host/v1` and `orca-host/v1`.
- Validator scope: v0.3.0 checks read only v0.3.0 files. They never compare v0.2.0 frozen
  fixtures or installed roots with v0.3.0 content.

## Steps

1. **`plugins/loom/bin/loom-host-orca`** (new, mode 755, Bash 3.2). Binary:
   `${LOOM_ORCA_BIN:-orca}` (PATH lookup; tests stub PATH). Every `<handle>` must match
   `^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$` (no leading `-`, length 1..64), validated before any
   `orca` call. Exit codes: 0 ok, 1 usage, 2 fail-closed, 4 degraded wait. Subcommands:
   - `launch ...`: exit 2, `unsupported: role launch on orca requires the owner-recorded probes (ADR 0034 sections 1 and 2)`. Unknown subcommand: exit 1.
   - `status <handle>`: `orca terminal show --terminal <handle> --json`. If exit is 1 or
     output contains `terminal_handle_stale`, prints `not_found` and exits 2. If exit is 0,
     prints compact JSON: `{"handle","title","connected","exitCause","worktreePath"}`
     (`exitCause` from `exitCause.kind`, absent fields `null`).
   - `wait <handle> --timeout <1..3600>`: converts seconds to ms (`timeout_ms=$((timeout * 1000))`),
     runs `orca terminal wait --terminal <handle> --for exit --timeout-ms <timeout_ms> --json`.
     Mandatory `--timeout <1..3600>`. Orca exit 0 prints `returned: read the committed artifact`
     and exits 0; any nonzero exit prints `degraded: wait did not return (orca exit <rc>); not completion`
     and exits 4. Neither is completion; the artifact `Status:` is.
   - `read <handle> [--lines <1..500>]` / `events <handle> [--lines <1..500>]`:
     `orca terminal read --terminal <handle> --limit <lines> --json`. Default lines: 500.
     Pipes tail lines, truncated after N lines; exit status 0.
   - `end <handle>`: `orca terminal close --terminal <handle> --tab --json`. Verifies cleanup:
     `orca terminal show --terminal <handle> --json` must return exit 1 (`terminal_handle_stale`)
     or `operator_close`, else exit 2.
2. **`plugins/loom/adapters/hosts/orca-host-v1.json`** (new; binding, schema `loom-host-binding-v1`):
   `{ "schema":"loom-host-binding-v1", "id":"orca-host/v1", "host":"orca", "controlCli":"orca", "floor":"1.4.250", "helper":"loom-host-orca", "helperPath":"bin/loom-host-orca", "helperMustBeRegularFile":true, "helperMustBeExecutable":true, "helperDirectoryMustBeDirectChild":true, "reachableVerbs":["show","wait","read","close"], "launch":"unsupported" }`.
3. **`plugins/loom/schemas/loom-host-binding-v1.schema.json`** (touched):
   Accepts either `hc-host/v1` or `orca-host/v1` using `oneOf`.
4. **Matrix registration**:
   Add optional `orca` under `hostFloors` in `plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json`:
   `orca: { type: "object", additionalProperties: false, required: ["floor", "helper"], properties: { floor: { const: "1.4.250" }, helper: { const: "loom-host-orca" } } }`.
   Add `hostFloors.orca` to `plugins/loom/adapters/compatibility/v0.3.0.json`.
   Re-pin `sha256` of `loom-compatibility-matrix-v1.schema.json` in `scripts/check-toolchain.json`.
5. **`plugins/loom/adapters/fixtures/v0.3.0/metadata/host-orca.json`** (new):
   Byte-for-byte copy of step 2's file.
6. **`scripts/validate-repository.mjs`** (touched):
   Update `validateHostBinding(ajv)` to validate both `hc` and `orca` host bindings:
   - Validate both `hc-host-v1.json` and `orca-host-v1.json` against `loom-host-binding-v1.schema.json`.
   - Validate `v0.3.0.json` against matrix schema, requiring both `hostFloors.hc` and `hostFloors.orca`
     to match their respective live bindings' `floor` and `helper`.
   - Verify `plugins/loom/adapters/hosts/` holds exactly `hc-host-v1.json` and `orca-host-v1.json`.
   - Verify each live host binding and its v0.3.0 fixture are deep-equal.
   - Verify both `loom-host-hc` and `loom-host-orca` exist as regular, executable files.
   - Verify neither helper appears in `ALLOWED_HELPERS` of `loom-resolve-helper` nor any root `allowedHelpers`.
7. **`plugins/loom/bin/loom-host-orca.bats`** (new):
   Offline Bats tests using a stubbed `$BATS_TEST_TMPDIR/bin/orca` verifying:
   - `launch` exits 2 unconditionally without invoking `orca`.
   - Unknown subcommand exits 1 with empty stub log.
   - Bad handle formats (`-x`, 65 chars, spaces, newlines, empty) refused before invoking `orca`.
   - `status` JSON shape extraction, stale handle exit 1 -> `not_found` on stdout and exit 2.
   - `wait` requires `--timeout` (and rejects 0, 3601, `abc`), converts to ms, exit 0 prints `returned`,
     nonzero exits map to exit 4 `degraded` and never contain `complete`.
   - `read` / `events` parses tail lines and truncates after specified or default lines.
   - `end` invokes `terminal close --terminal <handle> --tab --json`, accepts stale or operator_close on show,
     fails closed if show still reports connected.
   - Across all subcommands, only `terminal` with subcommands `show`, `wait`, `read`, `close` ever appear in stub log.
8. **`scripts/tests/repository-validation.bats`**:
   Update and expand host binding test cases to cover both `hc` and `orca` bindings, fixtures, helpers,
   and matrix entries; assert v0.2.0 fixtures and root bindings remain byte-unchanged against HEAD.
9. **Docs (finalize pass)**:
   `CLAUDE.md` Map `bin/` list gains `loom-host-orca`. Update `.docs/slice-plans/README.md`.

## Verification

- Iteration: `shfmt -i 4 -d -ln bash`, `shellcheck -s bash` and `bash -n` on
  `plugins/loom/bin/loom-host-orca`; `node scripts/validate-repository.mjs --all`;
  `TMPDIR=/private/tmp bats plugins/loom/bin/loom-host-orca.bats scripts/tests/repository-validation.bats`.
- Acceptance:
  (1) `launch` exits 2 for every input without invoking `orca`;
  (2) a wait that does not return is exit 4 `degraded`, never completion;
  (3) `git diff --stat HEAD -- plugins/loom/adapters/fixtures/v0.2.0 plugins/loom/adapters/compatibility/v0.2.0.json plugins/loom/adapters/roots plugins/loom/schemas/loom-installed-root-binding-v1.schema.json plugins/loom/bin/loom-resolve-helper` is empty;
  (4) `scripts/check-toolchain.json` differs only in the matrix schema's `sha256`;
  (5) validator reports binding drift when either host binding or its fixture is edited, and
      `jq -e '.hostFloors.orca.floor=="1.4.250"' plugins/loom/adapters/compatibility/v0.3.0.json` prints `true`.
- Full gate on candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft for Slice 3: `loom-host-orca` host adapter and v0.3.0 matrix registration beside `hc` |

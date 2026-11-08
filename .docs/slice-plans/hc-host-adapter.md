# Herdr `hc` Client (2 of 4): Host Adapter `loom-host-hc` and v0.3.0 Registration

Status: Implemented
Un-shelved: 2026-11-08 per ADR 0034 §5 (Accepted) — requirements below unchanged; review history kept.
Target specs: 07-command-surface.md (Host surfaces), 10-packaging.md (host floor, no Herdr root)
Authority: ADR 0031 §3, §5, §6, §7 (Accepted)
Target size: <= 380 LOC added (helper + Bats + registration; deletions not counted); keep this plan <= 250 lines

## Context

ADR [0031](../ADR/0031-herdr-as-an-hc-driven-client.md) makes `hc` the only Herdr
integration surface and requires a host adapter that observes and cleans up `hc`
terminals but never launches a role until the owner-recorded probes pass. Nothing
`hc`-related exists in the tree. Slice 1 (`hc-guard-deny-policy`) denies `hc` to role
sessions; the orchestrator is the only caller of this helper.

**Registration decision (owner, binding).** `loom-host-hc` is registered under the
**v0.3.0** matrix. The v0.2.0 release evidence stays untouched: the unreleased
dual-client (Claude and Codex) release, its frozen fixtures under
`plugins/loom/adapters/fixtures/v0.2.0/`, `v0.2.0.json`, and the installed-root
bindings `claude-plugin-root-v1.json` / `codex-skill-source-v1.json` (whose
`allowedHelpers` list is deep-compared with those fixtures and pinned by schema
`const`) are **not edited**. Therefore `loom-host-hc` is **not** added to
`ALLOWED_HELPERS`, the root `allowedHelpers`, or `loom-resolve-helper`. It is a *host
helper*: a regular executable file directly under the already-validated Claude plugin
root's `bin/`, invoked by absolute path `<root>/bin/loom-host-hc`.

**v0.3.0 fixture layout (checked against the tree): none exists** (only
`adapters/fixtures/v0.2.0/{metadata,dogfood}`). This slice defines
`plugins/loom/adapters/fixtures/v0.3.0/metadata/` with one file, `host-hc.json`,
the release-evidence copy of the host binding for the v0.3.0 release (frozen at that
release; byte-equal to the live binding until then). No `compatibility.json`
fixture for v0.3.0 is added here (the release slice owns it).

Observed in the earlier developer pass, now requirements: `hc get --json` carries
`exit_code` (output field `exitCode` is filled from it); `hc ls --all --json` rows
carry no `name`, so cleanup is verified by `hc get <name>` returning not_found.

## Out of Scope & Threat-Model Boundary

- **No role launch.** `launch` refuses unconditionally (exit 2): it reads no input, has
  no override variable and never invokes `hc` (ADR 0031 §6; spec 07 requires the
  probes first). Codex and evaluator roles on `hc` stay unsupported (ADR 0031 §5).
- No `herdr-app do`, config writes, mods, GUI control, templates, machines, remote runs.
- The probe script is slice 3; Herdr plugin retirement (manifests, `herdr` branches,
  the v0.3.0 `herdr` keys, 24 hook fixtures) is slice 4. This slice adds registration
  beside the existing Herdr keys and edits no Herdr key.
- `hc` does not enforce blind review or delegation limits (spec 08; `00-overview.md`
  Non-goals). The helper is an observation convenience, not a boundary.
- **Open blocker (retained, not resolved here):** Blind review through `hc` is an **unresolved owner decision** (ADR 0031 §5 and Consequences): hc evaluator use is blocked pending a follow-up ADR (isolation or explicit degraded blindness); this helper does not enforce blind review and no evaluator role runs on `hc`.
- **Matrix registration (owner decision; this slice owns it for all four plans).** One
  minimal, backward-compatible schema change: `loom-compatibility-matrix-v1.schema.json`
  gains an **optional** `hostFloors` property (`additionalProperties:false`; sole key
  `hc`, an object `{floor: const "0.1.16", helper: const "loom-host-hc"}`); it is not
  added to `required`, so the frozen `v0.2.0.json` still validates unchanged. `v0.3.0.json`
  gains `"hostFloors":{"hc":{"floor":"0.1.16","helper":"loom-host-hc"}}` (spec 10: the matrix
  records `hc` as a host with floor `0.1.16`; herdr-app is not floored). There is no
  `hostBindings` key. The schema's `sha256` in `scripts/check-toolchain.json` is re-pinned.
  Slice 4 later edits `v0.3.0.json` only to remove Herdr keys and keeps `hostFloors`.
- Validator scope: v0.3.0 checks read only v0.3.0 files. They never compare the v0.2.0
  frozen fixtures or the three installed roots with v0.3.0 content.

## Steps

1. **`plugins/loom/bin/loom-host-hc`** (new, mode 755, Bash 3.2). Binary:
   `${LOOM_HC_BIN:-hc}` (PATH lookup; tests put a stub on PATH). Every `<name>` must
   match `^[a-z0-9][a-z0-9_-]{0,31}$` (no leading `-`), checked before any `hc` call.
   No other verb or `hc` subcommand is reachable. Exit codes: 0 ok, 1 usage, 2
   fail-closed, 4 degraded wait. Subcommands:
   - `launch ...`: exit 2, `unsupported: role launch on hc requires the owner-recorded
     probes (ADR 0031 section 6)`. Any unknown subcommand: exit 1.
   - `status <name>`: `hc get <name> --json`; prints compact
     `{"name","state","status","reported","exitCode"}` (`exitCode` from `exit_code`,
     absent fields `null`); read-only; hc exit 3 prints `not_found` and exits 2.
   - `wait <name> --timeout <1..3600>`: runs `hc wait <name> --timeout <S>`; `--timeout`
     mandatory. hc exit 0 prints `returned: read the committed artifact` and exits 0;
     any nonzero exit prints `degraded: wait did not return (hc exit <n>); not
     completion` and exits 4 (timeout exit code undocumented, so all nonzero are
     degraded). Neither is completion; the artifact `Status:` is.
   - `events <name> --lines <1..500>`: `hc events --terminal <name>` truncated after N
     lines (pipe closed); exit status is the truncation, not hc's.
   - `end <name>`: `hc kill <name>` (hc exit 11 "finished" accepted), then `hc rm
     <name>`, then `hc get <name> --json` must exit 3 (not_found), else exit 2.
2. **`plugins/loom/adapters/hosts/hc-host-v1.json`** (new; binding, schema
   `loom-host-binding-v1`): `{ "schema":"loom-host-binding-v1","id":"hc-host/v1",
   "host":"herdr","controlCli":"hc","floor":"0.1.16","helper":"loom-host-hc",
   "helperPath":"bin/loom-host-hc","helperMustBeRegularFile":true,
   "helperMustBeExecutable":true,"helperDirectoryMustBeDirectChild":true,
   "reachableVerbs":["get","wait","events","kill","rm"],"launch":"unsupported" }`.
3. **`plugins/loom/schemas/loom-host-binding-v1.schema.json`** (new): draft 2020-12,
   `additionalProperties:false`, every key above required, `launch` const
   `"unsupported"`, `reachableVerbs` const the five verbs. The installed-root binding
   schema is **not modified** (its pinned digest stays valid).
4. **Matrix registration**: add the optional `hostFloors` property to
   `plugins/loom/schemas/loom-compatibility-matrix-v1.schema.json`, add the `hostFloors`
   entry to `plugins/loom/adapters/compatibility/v0.3.0.json` (see the Registration
   bullet), and re-pin the schema `sha256` in `scripts/check-toolchain.json` (change
   nothing else there).
5. **`plugins/loom/adapters/fixtures/v0.3.0/metadata/host-hc.json`** (new): a byte-for-byte
   copy of step 2's file.
6. **`scripts/validate-repository.mjs`** (touched): add `validateHostBinding()` called beside the
   metadata checks: (a) validate the live binding against its schema through the
   existing Ajv path (add the schema to the loaded set and `schemaBindings`), and
   validate `v0.3.0.json` against the matrix schema, requiring `hostFloors.hc.floor`
   to equal the binding's `floor` and `helper` to equal its `helper`;
   (b) the `hosts/` directory holds exactly that one binding file and `floor` is `0.1.16`; (c) the live binding and the v0.3.0 fixture are
   deep-equal; (d) `bin/loom-host-hc` exists as a regular, executable file; (e)
   `loom-host-hc` appears in neither `ALLOWED_HELPERS` of `loom-resolve-helper` nor any
   root `allowedHelpers`. Report each failure with the existing `report()` helper. It
   reads `v0.3.0.json` and does not touch `expectedRoots`; the existing v0.2.0
   matrix check is unchanged.
7. **`plugins/loom/bin/loom-host-hc.bats`** (new). Each test builds
   `$BATS_TEST_TMPDIR/bin/hc`, a stub appending `"$@"` one arg per line to a log,
   printing canned JSON per verb and exiting per `STUB_*`; `PATH` is prefixed. Tests:
   `launch` exits 2 for every input shape, with `LOOM_HC_UNVERIFIED=1` and `LOOM_HC_BIN`
   set, stub log empty; unknown subcommand exit 1; bad names (`-x`, `A`, 33 chars,
   `a b`, empty) refused with an empty stub log; `status` JSON shape, `exit_code` →
   `exitCode`, only `get --json` in the log, exit 3 → exit 2; `wait` requires
   `--timeout` (and rejects 0, 3601, `abc`), exit 0 prints "returned", every nonzero hc
   exit (1, 124, 3) maps to exit 4 "degraded" and the output never contains
   "complete"; `events` truncates after N lines; `end` order is `kill` then `rm` then
   `get`, accepts kill exit 11, exits 2 if `get` still succeeds; across all tests only
   `get wait events kill rm` ever appear in a stub log.
8. **`scripts/tests/repository-validation.bats`**: add cases for step 6 (a)–(e): a
   mutated copy of the repo fixture (including a wrong or missing `hostFloors`) fails each check; the real tree passes; v0.2.0
   fixtures and root bindings are asserted byte-unchanged against `git show HEAD:`
   in the same test (regression proof that registration touched none of them).
9. **Docs (finalize pass)**: `CLAUDE.md` Map `bin/` list gains `loom-host-hc` (one
   clause: observation/cleanup helper for `hc`, launch unsupported; stays <= ~100
   lines). `.docs/slice-plans/README.md` index. Status docs on `main` by the
   orchestrator.

## Verification

- Iteration: `shfmt -i 4 -d -ln bash`, `shellcheck -s bash` and `bash -n` on
  `plugins/loom/bin/loom-host-hc`; `node scripts/validate-repository.mjs --all`;
  `TMPDIR=/private/tmp bats plugins/loom/bin/loom-host-hc.bats scripts/tests/repository-validation.bats`.
- Acceptance: (1) `launch` exits 2 for every input without invoking `hc`; (2) a wait
  that does not return is exit 4 `degraded`, never completion; (3) `git diff --stat
  HEAD -- plugins/loom/adapters/fixtures/v0.2.0 plugins/loom/adapters/compatibility/v0.2.0.json
  plugins/loom/adapters/roots plugins/loom/schemas/loom-installed-root-binding-v1.schema.json
  plugins/loom/bin/loom-resolve-helper` is empty, and `jq -e '.hostFloors|not' plugins/loom/adapters/compatibility/v0.2.0.json`
  prints `true`; (4) `scripts/check-toolchain.json` differs only in the matrix schema's `sha256`; (5) validator reports
  binding drift when the binding or its fixture is edited, and `jq -e '.hostFloors.hc.floor=="0.1.16"'
  plugins/loom/adapters/compatibility/v0.3.0.json` prints `true`.
- Full gate once on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
  Only the known unrelated `INT during a mutation yields exit 130` dogfood race may
  be recorded and rerun once (owner-declared out of scope); any other failure blocks.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 2 | Plan-eval round 2 + owner decision: restored v0.3.0 matrix registration via one optional `hostFloors` schema key (no `hostBindings`), sha re-pinned, v0.2.0 untouched; this slice owns it |
| 1 | Plan-eval round 1: dropped matrix `hostFloors`/`hostBindings` (schema forbids them); binding stands alone, no schema change; blind-review open blocker retained |
| 0 | Split from `herdr-hc-client` (owner decision): host adapter and v0.3.0-only registration; v0.2.0 fixtures, roots and `ALLOWED_HELPERS` untouched; v0.3.0 fixture layout defined; name grammar, `exit_code`, not_found cleanup check from the developer pass |

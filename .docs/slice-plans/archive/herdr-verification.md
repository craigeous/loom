# Herdr Verification

Status: Archived
Target specs: 00-overview.md, 08-playbook.md, 10-packaging.md
Target size: <= 180 LOC net code change (excluding test fixtures)

## Context

M9 slice 3 adds reproducible offline smoke verification of the existing Herdr
adapter and native-app hook contract. The Herdr marketplace and plugin manifests,
installed-root binding, role launcher, and shared hooks already exist. The launcher
emits a descriptor; it does not start Herdr. A fixture host can exercise Loom's
side of installation, discovery, launch and hook execution without asserting that
an actual Herdr binary or native application has run.

## Out of Scope & Threat-Model Boundary

No new client adapter, protocol, spec amendment, live client installation, network
access, release certification, or claim of real Herdr/native-app execution is in
scope. Per spec 00 Non-goals, this is not a hostile-code sandbox or defense against
malicious local filesystem mutation; temporary installed copies and stubs are
trusted. Live client integration remains separate evidence for the M9 milestone.

## Steps

1. Add `scripts/tests/herdr-verification.bats`. In a private temporary directory,
   copy the marketplace and `plugins/loom` into a clean install layout, resolve the
   marketplace `source`, and discover the plugin manifest, skills directory, and
   hook manifest from their declared paths. Assert manifest name/version and that
   discovered paths remain within the copied installation. Run all subsequent
   product commands from the installed copy, not the checkout, with an isolated
   HOME and without Herdr or a network service. Treat the same fixture host as the
   native-app hook-process simulation; do not label it a real native-app test.
2. In that suite, exercise `loom-resolve-helper herdr loom-coord` with the copied
   absolute `HERDR_PLUGIN_ROOT`; assert the physical installed helper path, then
   reject unset/relative root, invalid manifest and a missing helper. Invoke
   installed `loom-launch-role herdr` for each of the five roles; parse each JSON
   descriptor and assert client, role, matrix-derived profile, cold launch,
   delegation false and one-level permissions. Reject explicit model/effort
   overrides. Check shared role and workflow skill files are discoverable from the
   manifest's skills directory, including `loom-run` and all five role skills.
3. Drive the actual commands declared in the copied `hooks/hooks.json` with only
   `HERDR_PLUGIN_ROOT` set, feeding the existing Herdr wire fixtures for both
   events and all allow/block/malformed outcomes. Compare exit status, stdout and
   stderr byte-for-byte with the fixture files. Exercise the declared identity and
   role-governance PreToolUse commands with recognized identity mutation and
   evaluator git mutation respectively, asserting Herdr block wire; assert a
   permitted command succeeds. Use isolated temporary git state where required for
   PreCompact. Verify competing valid client roots fail closed. Never contact a
   service or invoke an actual Herdr executable.
4. Ensure the new tracked Bats file is discovered by `scripts/check`'s existing
   `git ls-files` Bats enumeration; change `scripts/check` only if necessary to
   make that integration explicit. Keep product behavior unchanged; if a defect
   prevents these tests from passing, report it for a separately scoped fix rather
   than weakening assertions. Fixture additions, if needed, belong under
   `scripts/tests/fixtures/` and must be deterministic and local.

## Verification

Run from repository root after staging the new test so gate discovery sees it:

```sh
bats scripts/tests/herdr-verification.bats
bats plugins/loom/bin/loom-resolve-helper.bats plugins/loom/bin/loom-launch-role.bats
bats plugins/loom/hooks/git-identity-guard.bats plugins/loom/hooks/role-governance-guard.bats plugins/loom/hooks/precompact-write-ahead-backstop.bats
scripts/check
```

The targeted suite must pass with network unavailable and no Herdr binary installed;
`scripts/check` must report the new tests in its discovered Bats suite and pass.
The gate may provision its pinned tools separately; the compatibility tests themselves
must require no network. Acceptance matrix:

| Surface | Offline evidence | Required result |
|---|---|---|
| Install/discovery | marketplace source, manifest, skills and hooks in copied tree | all resolve within the installed copy; invalid roots fail closed |
| Roles/workflows | five role descriptors and shared skill discovery | expected profiles and cold, one-level, non-delegating governance; override rejected |
| Native-app hook simulation | declared commands, two events, three wire outcomes | exact fixture bytes and exit codes; ambiguous roots fail closed |
| Identity/governance | actual declared PreToolUse guards | identity and evaluator mutation blocked, permitted command allowed |
| Regression/gate | existing resolver, launcher and hook suites; `scripts/check` | all pass; new suite included |

These establish Loom-side compatibility in a deterministic fixture, not that an
actual Herdr client installs components or executes workflows. Live installation,
role/workflow execution, uniform identity and governance in both real Herdr and
its native application remain to be demonstrated before claiming M9's live gate.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

# Loom Doctor Foundation

Status: Plan Review
Target specs: 06-init-modes.md, 08-playbook.md, 10-packaging.md
Target size: <= 450 LOC net change excluding tests and schemas

## Context

The improvement plan's M6 calls for read-only environment and repository diagnostics
through `loom doctor` and stable JSON. Specs 06, 08, and 10 define the supported
runtime, detection, and broader doctor contract. This foundation establishes a
small, testable diagnostic surface; a successful foundation report must not be
presented as proof of all supported-mode or release checks in spec 08.

## Out of Scope & Threat-Model Boundary

This slice does not mutate or repair the repository, install dependencies, claim
release conformance, or implement the full spec 08 diagnostic inventory. Client
version and manifest/catalog loading, hook trust, instruction parity, profile mapping,
remote landing configuration, and optional egress-sandbox diagnostics remain future
work; report them as unchecked, never as passing. Per `.docs/spec/00-overview.md`
## Non-goals, OS-level hostile-code containment and cross-clone claim exclusion
without an adapter are outside scope; diagnostics do not replace owner judgment.

## Steps

1. Add executable Bash `plugins/loom/bin/loom-doctor`, using `set -u` and Bash 3.2
   compatible syntax. Accept no argument or `--json`; reject other arguments.
   Read state only. Collect host OS/architecture and shell, required `git`, `bash`,
   `jq`, `node`, and `shasum` availability, Bash/Git/jq minimum versions from
   spec 06, Git identity and tracked/untracked cleanliness, initialization mode
   and evidence per spec 06, coordination schema and stale claims, review-protocol
   finder availability, and evaluation-protocol helper availability. Missing or
   invalid required capabilities and unsupported host/runtime are errors; dirty
   trees and stale claims are warnings; inability to determine a required check is
   an error. Report each check with a stable identifier, status, and evidence;
   report explicitly unchecked spec 08 capabilities. Human and JSON output must
   derive from the same results. Exit 0 for pass or warnings, 1 for any error,
   and 2 for invalid invocation. Do not treat an unverified client as supported.
2. Add `plugins/loom/schemas/loom-doctor-report-v1.schema.json`, a JSON Schema
   Draft 2020-12 contract for `--json`: versioned report, ordered check records,
   status (`pass`, `warning`, `error`, `unchecked`), evidence, and overall result.
   Specify required fields and reject unexpected properties; keep output stable.
3. Update `plugins/loom/bin/loom-resolve-helper` to register `loom-doctor` in
   `ALLOWED_HELPERS`, preserving installed-root resolution and existing behavior.
4. Add `plugins/loom/commands/doctor.md` as a thin `/loom:doctor` adapter that
   invokes the shared helper and presents its diagnostics without claiming support
   for unchecked capabilities.
5. Add `plugins/loom/skills/loom-doctor/SKILL.md` as the thin Codex skill adapter,
   resolving the same helper through the installed skill-source binding and
   preserving human and `--json` semantics.
6. Add `plugins/loom/bin/loom-doctor.bats` with isolated fixtures covering every
   check, supported and unsupported host/runtime, missing tools and minimum versions,
   identity, clean and dirty repositories, each init mode, valid/invalid coordination
   schema and stale claims, missing finders/helper, human and schema-valid JSON,
   warnings versus errors, exit codes, and invalid arguments. Stub dependencies and
   avoid mutating the developer's repository or client configuration.
7. Add `plugins/loom/bin/loom` as an executable Bash CLI entry point dispatching
   `loom doctor` and `loom doctor --json` to the adjacent shared helper, forwarding
   exit status and rejecting unsupported commands. Test both entry points in Bats.
   Keep client adapters thin and do not assert installation or release compatibility
   beyond the evidence actually collected.

## Verification

- `TMPDIR=/private/tmp bats plugins/loom/bin/loom-doctor.bats` exercises all new
  diagnostics, classifications, output forms, dispatch, and exit codes.
- `scripts/check` is the required repository gate and regression proof.
- `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all`
  validates repository structure and applicable schemas.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

# Loom Doctor Foundation

Status: Approved
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

1. Add executable Bash `plugins/loom/bin/loom-doctor`, using `set -u` and Bash
   3.2 compatible syntax. Accept no argument or `--json`; reject other arguments.
   Read state only. Emit ordered records with the following fixed identifiers,
   status and evidence; an indeterminate required probe is an error.

   | Check ID | Probe and status mapping |
   |---|---|
   | `host_and_os` | OS, architecture and shell: pass for spec 10 supported host/runtime; otherwise error. |
   | `required_tools` | Bash >= 3.2, Git >= 2.34, jq >= 1.6, Node.js >= 18 and either `shasum -a 256` or `sha256sum`: pass when usable, otherwise error. Node and SHA-256 are foundation protocol dependencies, not additional spec 06 runtime floors. |
   | `git_identity` | Effective Git name and email: pass when both nonempty, otherwise error. |
   | `repo_cleanliness` | Git tracked and untracked status: pass if clean, warning if dirty, error if unavailable. |
   | `init_mode` | Apply `skills/loom-playbook/references/init-detection.md` classifier and report mode and evidence: pass if determinable, otherwise error. |
   | `coordination` | Read `refs/loom/schema` and claim blobs directly without invoking mutating `loom-coord`; absent schema with no claims passes, schema `2` and fresh claims pass, incompatible/malformed state errors. A claim is stale when its numeric lease timestamp is at least `LOOM_LEASE_TTL` seconds old (default 3600; normalize as `loom-coord` does); stale claims warn, unreadable timestamps error, never declare them stale. |
   | `review_protocol` | Check executable `plugins/loom/bin/loom-review` and readable `plugins/loom/finders/review-{correctness,tests,security}-v1.md`: pass if present, otherwise error. |
   | `eval_protocol` | Check executable `plugins/loom/bin/loom-eval-workspace`: pass if present, otherwise error. |
   | `client_adapter` | Client version, manifest/catalog loading, instruction parity and profile mapping are unchecked; report no client support conclusion. |
   | `hook_trust` | Hook trust is unchecked. |
   | `egress_sandbox` | Egress sandbox and remote landing configuration are unchecked. |

   Human and JSON output derive from the same records and explicitly label each
   unchecked item. Exit 0 for pass or warnings, 1 for any error, and 2 for invalid
   invocation; unchecked is never a pass or a client-support claim.
2. Add `plugins/loom/schemas/loom-doctor-report-v1.schema.json`, a JSON Schema
   Draft 2020-12 contract for `--json`: versioned report, ordered check records
   using the IDs above, status (`pass`, `warning`, `error`, `unchecked`), evidence,
   and overall result. Specify required fields and reject unexpected properties.
3. Register `loom-doctor` consistently, preserving installed-root behavior:
   - `plugins/loom/bin/loom-resolve-helper`: add to `ALLOWED_HELPERS`.
   - `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`: extend the `allowedHelpers` const array.
   - `plugins/loom/adapters/roots/claude-plugin-root-v1.json`: extend `allowedHelpers`.
   - `plugins/loom/adapters/roots/codex-skill-source-v1.json`: extend `allowedHelpers`.
   - `plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-root.json`: extend `allowedHelpers`.
   - `plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-root.json`: extend `allowedHelpers`.
   - `scripts/validate-repository.mjs`: extend both `expectedRoots` `allowedHelpers` arrays.
   - `plugins/loom/bin/loom-resolve-helper.bats`: test resolving `loom-doctor`.
   - `scripts/tests/repository-validation.bats`: update fixture allowlist check.

   Explicitly update the release-owned v0.2.0 root fixtures with the binding change;
   the validator pins them to the live root metadata. This is a fixture change, not
   a claim of a new release or alteration of other historical fixture fields.
4. Add `plugins/loom/commands/doctor.md` with description frontmatter, a thin
   adapter of at most 20 lines routing to `skills/loom-doctor/SKILL.md`. Add
   `.agents/skills/loom-doctor/SKILL.md` with name and description frontmatter,
   a thin Antigravity adapter of at most 20 lines routing to the same shared skill.
   Add `doctor` to `workflows` in `plugins/loom/adapters/compatibility/v0.3.0.json`.
   The validator's thin-adapter routes and frontmatter schemas apply; existing
   plugin manifests and catalogs identify the distribution and need no entry or
   count update for this discovered command and skill.
5. Add `plugins/loom/skills/loom-doctor/SKILL.md` with `name: loom-doctor` and
   description frontmatter. Route to `plugins/loom/bin/loom-doctor` via
   `loom-resolve-helper` using the installed client binding, preserving human and
   `--json` semantics without claiming support for unchecked capabilities.
6. Add `plugins/loom/bin/loom-doctor.bats` with isolated fixtures and a proportional
   matrix: at least one pass, warning, error, and unchecked case; cover supported
   and unsupported runtime, missing tools and versions, identity, cleanliness,
   each init mode, coordination state, missing protocol assets, both output forms,
   schema-valid JSON, exit codes, and invalid arguments. Assert human output
   explicitly contains the `unchecked` label for deferred capabilities. Stub
   dependencies and avoid mutation of the developer's repository or configuration.
7. Add `plugins/loom/bin/loom` as an executable Bash CLI entry point dispatching
   `loom doctor` and `loom doctor --json` to the adjacent shared helper, forwarding
   exit status and rejecting unsupported commands. Test both entry points in Bats.
   Keep client adapters thin and do not assert installation or release compatibility
   beyond the evidence actually collected.

## Verification

- `TMPDIR=/private/tmp bats plugins/loom/bin/loom-doctor.bats` exercises all new
  diagnostics, classifications, output forms, dispatch, and exit codes.
- `shfmt -i 4 -d plugins/loom/bin/loom-doctor plugins/loom/bin/loom` and
  `shellcheck -s bash plugins/loom/bin/loom-doctor plugins/loom/bin/loom` provide fast shell checks.
- `scripts/check` is the required repository gate and regression proof.
- `node scripts/validate-repository.mjs --root . --all`
  validates repository structure and applicable schemas.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Defined diagnostic probes and statuses, complete helper registration and adapters, proportional tests, and portable verification. |

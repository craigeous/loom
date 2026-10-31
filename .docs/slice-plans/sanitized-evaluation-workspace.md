# Sanitized Evaluation Workspace

Status: Approved
Target specs: 04-orchestrator.md § Evaluation orchestration; 05-blind-evaluation.md § Controlled-input independent evaluation
Target size: <= 600 LOC net change excluding tests/schemas (keep this plan document <= 250 lines)

## Context

ADR 0022 and spec 05 require independent cold-agent evaluation with controlled inputs:
a fresh, evidence-complete export with immutable judgment inputs and a deterministic
code gate rerun. M5's `sanitized-evaluation-workspace` supplies the exporter and runner;
prior gate evidence cannot substitute for a rerun. This slice builds a reusable helper,
its schemas, registration, and tests, without claiming that the helper alone establishes
the client adapter or recorder boundary. If implementation exceeds the LOC budget, split
the gate runner into a separately planned slice rather than silently exceeding it.

## Out of Scope & Threat-Model Boundary

- No evaluator launch, client permissions, network confinement, delegation controls,
  verdict recording, lifecycle transition, spec amendment, or retirement of bootstrap
  authority. Those integrations and the evidence collector are separate work; callers
  must not claim end-to-end conformance from this helper alone.
- No hostile host administrator, compromised client/provider, statistical independence,
  cryptographic anonymity, or OS-level hostile-code containment (spec 00 Non-goals).
  The run and its parent are private to the trusted operator; concurrent hostile inode
  replacement and monkeypatched tools are outside this slice. Read-only modes and hashes
  detect accidental changes, not writes by an owner deliberately changing permissions.
- No network access or dependency downloads by the helper. Research captures and
  verified offline dependencies are supplied by trusted preparation; missing required
  captures or an unavailable offline gate is infrastructure-blocked, never PASS.

## Steps

Conventions: Bash 3.2+, Git 2.34+, jq 1.6+; `set -euo pipefail`, canonical JSON
`jq -S -c`, SHA-256 via `shasum -a 256` or `sha256sum`.

| Exit | Outcome and `status` mapping |
|---|---|
| 0 | Successful command, valid run, `prepared`, or `rerun-passed` |
| 1 | Usage error or invalid flags; no run status implied |
| 2 | Invalid input, rejected run, verification failure, `invalid`, or `rerun-failed` |
| 3 | `status` on an in-flight or partial run (incomplete); no terminal status implied |
| 4 | `infrastructure-blocked`: unavailable gate, missing Git objects or required captures, or interrupted execution |

A nonzero gate exit produces `rerun-failed`; interruption or inability to execute it
produces `infrastructure-blocked`. These states never imply a merits verdict.
Reject unknown options, protocol versions, duplicate paths and extra inputs.
Never evaluate shell text supplied by an evaluator. All paths in manifests are normalized
relative paths; reject absolute paths, `..`, control bytes, links, special files, and
collisions. Check file types and link counts on traversal; no symlink or hardlink is
followed, including in inputs and cleanup. Build runs atomically in a private sibling
staging directory; on failure remove only that staging directory.

1. **Contracts** — add `plugins/loom/schemas/loom-eval-workspace-manifest-v1.schema.json`
   and `plugins/loom/schemas/loom-eval-gate-rerun-v1.schema.json` (draft 2020-12,
   `additionalProperties: false`). Manifest protocol `loom-eval-workspace/v1` binds
   run ID, evaluation type, UTC `created_at`, reviewed full commit and tree IDs, optional
   base and evidence SHA/tree, normalized per-file path, origin/role, mode and SHA-256,
   explicit policy exclusions, diff hash when applicable, pinned gate command argv,
   environment, tool versions and offline dependency inventory for code, and its own
   SHA-256 over canonical JSON with the hash field omitted. The rerun schema binds the
   run ID and manifest hash, command/environment digest, tool versions, start/end UTC,
   completion state and exit status, stdout/stderr hashes, starting and ending execution
   inventories, and post-run source verification. Define required conditional fields for
   each type; validate schema and cross-field invariants, rejecting unknown versions.
2. **Prepare** — add executable `plugins/loom/bin/loom-eval-workspace`, with `prepare`,
   `verify`, `gate-rerun`, `status`, and `clean`. `prepare` accepts explicit evaluation
   type, full immutable SHA(s), approved artifact/authority/rubric paths, and for code
   base/head, gate evidence, valid local-review findings (or explicit docs-only status),
   pinned gate argv/environment/tool versions and offline dependencies. Require assembled
   findings and validate them with `plugins/loom/bin/loom-review validate` before
   inclusion; reject bootstrap or unassembled findings. Resolve commit
   objects locally, require base ancestor of head, and materialize tracked inputs from
   exact objects, never the live checkout. External evidence must be regular, supplied
   explicitly, validated and copied; reject missing, mutable, unresolvable, or unapproved
   input. For re-review require prior verdict and exact revision diff. For planning
   mechanical evidence, require one full `evidence_sha` and tree ID when needed, and
   export its complete tracked tree subject only to recorded exclusions. Research inputs
   require complete, fresh captured citations and their locator, retrieval, status,
   content-type, tool, freshness and hash provenance; fail closed if unavailable.
3. **Run layout and export** — default to a private `0700` root under
   `${TMPDIR:-/tmp}/loom-eval-${REPO_HASH}/<run_id>/`, strictly outside the managed
   repository, worktree and Git common directory; reject the default if it fails that
   containment check. `--out <dir>` selects a new absolute directory, strictly outside
   the managed checkout and Git directory (including common directory). Resolve physical
   paths and reject overlap in either direction. Require
   unique safe run IDs, private `0700` run roots, no pre-existing destination, and no
   symlinked or escaping path components. Export `source/` from exact `head_sha` objects
   (or evidence snapshot when required), checking every path, type, mode and hash against
   the Git tree; reject gitlinks and unsafe objects rather than silently omit them.
   Generate exact binary/full-index base-to-head `diff.patch` and `diff_sha256` for code.
   Place approved plan, relevant specs/ADRs, gate evidence, `review-findings.md`/JSON,
   rubric and other type-specific inputs in `inputs/`, and grant unique writable `output/`
   and private `scratch/`. Manifest inventories and hashes every supplied file, including
   diff and dependencies, with origin and policy exclusions; omit `.git`, identity/author
   metadata, status/roadmap/handoff history except when itself authority or artifact,
   transcripts, unrelated evaluations, scratch, credentials and client session stores.
   Normalize identity-bearing filesystem metadata and make source and inputs read-only.
4. **Verify and status** — `verify` validates the manifest and its self-hash, expected
   layout, file types, permissions, complete inventories and all hashes; compare Git
   object/tree and diff bindings against local objects, failing closed if unavailable.
   Reject extras, missing files, altered modes, links or paths outside the run. Verify
   independently supplied evidence provenance and recorded dependency hashes; no
   unverified fallback. `status` is read-only and reports `prepared`, `invalid`, `infrastructure-blocked`, `rerun-passed`, or
   `rerun-failed` with the exit mapping above only after checking the current run; stale evidence cannot make a changed run
   valid. Neither command writes a verdict or advances lifecycle state.
5. **Gate rerun** — `gate-rerun` is code-only and takes a run identifier, never an
   evaluator-supplied command, source, environment or dependency override. Verify inputs,
   create a private disposable execution copy, and compare its initial inventory and
   hashes to source before invoking the pinned argv with the pinned environment and
   prepared offline dependencies. Redirect home/config, cache, temp and declared build
   outputs to that copy or private scratch. Record command/environment digest, tool
   versions, UTC times, exit, stdout/stderr hashes and output inventory in schema-valid
   `gate-rerun.json`, bound to the run and manifest. Reverify both immutable source and the managed checkout tree against their
   pre-run inventories after every attempt and delete the execution copy on success, gate failure, or interruption;
   failed verification or incomplete execution is invalid/infrastructure-blocked, never
   a successful rerun. Preserve separate evidence for repeated invocations without
   overwriting earlier results. This is a bounded runner, not an OS sandbox.
6. **Clean** — `clean` removes only a recognized run with matching protocol and safe
   paths, under the default root or an explicitly supplied `--out` run. Reject symlinked
   roots, traversal, foreign directories, and malformed manifests; restore owner write
   permission only within the validated run before removal. Never delete the repository
   or arbitrary parents. `status` and `verify` must not mutate inputs.
7. **Registration** — add the helper to `plugins/loom/bin/loom-resolve-helper`, both
   adapter root JSONs and their fixture copies, installed-root binding schema, and the
   helper allowlists in `scripts/validate-repository.mjs`; update allowlist order mutation
   and resolver tests. Register and validate both new schemas in repository validation.

## Verification

Developer iteration: `bats plugins/loom/bin/loom-eval-workspace.bats` and the resolver
and repository-validation Bats suites; run `shfmt -i 4 -d` and `shellcheck -s bash` on
the helper. Final gate: `scripts/check` and
`node scripts/validate-repository.mjs --root "$PWD" --all`.

The new Bats suite uses disposable repositories and proves:

- Exact object export, diff, inventories, hashes, canonical manifest and schema validity;
  base-not-ancestor rejection, and binary, rename and mode metadata in the diff;
  source is read-only, output/scratch are private and writable, and seeded identity,
  history, transcript, credentials and unrelated-evaluation canaries are absent.
- Plan/research evidence and re-review bindings; complete evidence snapshot at declared
  SHA; required citation capture freshness/provenance; code review findings or explicit
  docs-only status, including rejection of unassembled or invalid findings by the named
  validator. Missing evidence, wrong SHA/tree/diff, invalid schema, duplicate or
  extra paths, altered source/input/mode, unavailable objects and unknown versions fail
  closed, including after a previously successful verification.
- Rejection of symlinks, hardlinks, devices, sockets, gitlinks, escaping paths, unsafe
  output roots and cleanup targets; no partial run on prepare failure.
- A gate writing beside source and to home, cache, temp and build paths runs in a
  verified copy with pinned offline inputs, leaves source and checkout hashes unchanged,
  records bound result hashes/inventories, and removes its copy on success and failure.
  Tampered dependencies, changed source, unavailable gate, nonzero exit, interrupted
  execution and attempted command/environment substitution never report a valid rerun;
  `gate-rerun` rejects non-code runs. Test every exit/status mapping, including partial
  runs and infrastructure-blocked cases.
- Independent runs do not share writable paths; status detects stale evidence; clean
  removes only the selected recognized run. Resolver and validator tests cover both
  adapter metadata copies, schema registration and allowlist drift.

## Notes

- Adapter confinement, cited-source collection and recording remain required before a
  production evaluation can claim the complete ADR 0022 boundary.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Address Round 0 findings: external run roots, status/exit contract, findings validation, rerun verification and coverage |

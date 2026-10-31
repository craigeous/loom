# Evaluation Gate Runner

Status: Implemented
Target specs: 04-orchestrator.md, 05-blind-evaluation.md; ADR 0022
Target size: <= 500 LOC net change excluding tests/schemas

## Context

`loom-eval-workspace` exports and verifies a controlled, immutable evaluation run;
code runs already pin gate argv, environment, tool versions and offline dependencies.
The landed workspace slice deferred execution and shipped the rerun evidence schema.
This slice supplies the deterministic rerun and its status evidence, enabling a code
evaluator to obtain the required independent gate result on the verified snapshot.
Prior developer evidence is comparison material, never a substitute for the rerun.

## Out of Scope & Threat-Model Boundary

No evaluator launch, verdict recording, lifecycle advancement, new spec or ADR, or
network sandbox is included. The later `evaluation-output-recorder` slice owns verdict
recording. This is a bounded runner, not a hostile-code sandbox: the private `0700`
run and scratch boundary is trusted; hostile local inode swapping and helper
monkeypatching are outside the threat model (spec 00 non-goals). A gate requiring
network or unavailable dependencies is infrastructure-blocked, not a reason to change
its checks or reuse prior evidence.

## Steps

1. **`plugins/loom/bin/loom-eval-workspace`** — Add `gate-rerun <run-dir|run-id>
   [--repo <path>]`, using existing run resolution, containment and `do_verify` /
   `verify_rc`. Accept no gate command, environment, source or dependency overrides;
   reject non-code runs and malformed options. Verify the complete current manifest,
   self-hash, source, dependencies, permissions and Git object bindings before work.
   Update the helper header to describe the implemented runner. When `REPO_OK=1`,
   inventory tracked index paths via `git ls-files -s` and untracked non-ignored paths,
   including actual path types, modes and content hashes; exclude ignored files and
   `.git` internals. When `REPO_OK=0`, there is no checkout inventory or comparison;
   retain all run/source verification. Inability to inventory is infrastructure-blocked.
2. **Execution boundary** — Create a unique private disposable execution tree outside
   the checkout and Git common directory. Copy the verified source without links or
   special files, preserve executable modes, and compare its initial path/type/mode/
   content-hash inventory to the immutable source before running. Make only the copy
   writable. Invoke the manifest's exact argv as an argument vector, without shell
   evaluation or word splitting, from the copy. Start from an empty environment with
   only the pinned variables plus runner-owned redirects; provide the verified prepared
   offline dependencies and redirect home/config, caches, temp and declared build
   outputs to the copy or private scratch. Map `HOME` to scratch/home;
   `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` to
   scratch/xdg/{config,cache,data,state}; `TMPDIR`, `TMP`, `TEMP` to scratch/tmp;
   `CARGO_HOME` to scratch/cargo, `CARGO_TARGET_DIR` to scratch/build/cargo,
   `GOCACHE` to scratch/cache/go, `GOPATH` to scratch/go, `npm_config_cache` to
   scratch/cache/npm, `PIP_CACHE_DIR` to scratch/cache/pip; `LOOM_EVAL_DEPS` to
   read-only `inputs/deps`, `LOOM_EVAL_BUILD` to scratch/build and
   `LOOM_EVAL_SCRATCH` to scratch. Create these private directories as needed.
   Never inherit credentials or ambient environment. For each declared tool resolve
   `name` only on the pinned `PATH` under the empty pinned environment, run the resolved
   tool as `name --version 2>&1` in that environment, record the observed first non-empty
   line, and require the pinned version as a whole token on that line. Missing tools,
   probe failure, version mismatch or unavailable dependencies block the attempt (4).
3. **Evidence and cleanup** — For each attempt allocate a unique monotonic sequence
   under runner-owned `reruns/attempt-<seq>/` within the run, retaining earlier
   evidence without overwrite. Add `reruns` to the top-level allowlists in `do_verify`
   and `cmd_clean`. Preserve `stdout.log` and `stderr.log` in each attempt. Capture UTC
   start/end, process completion and exit status, stdout/stderr byte counts and SHA-256,
   canonical start/end inventories (file count and SHA-256) and sorted added/modified/
   deleted paths, command/environment digest, tool versions, run ID and exact manifest
   hash. Reverify immutable source and the checkout against pre-run inventories after
   every attempt, including failures and interruptions. Write `gate-rerun.json` in the
   attempt's own directory atomically only after validating it with
   `plugins/loom/schemas/loom-eval-gate-rerun-v1.schema.json` (Draft 2020-12,
   using the existing schema-validation dependencies). Refactor `validate_manifest_schema`
   into reusable `validate_json_schema <schema> <file>` for both schemas. Encode completion,
   source verification and result consistently with that schema. Incomplete execution,
   failed verification, evidence write/validation failure or interruption cannot pass;
   classify changed inputs as invalid and unavailable infrastructure as blocked. A
   pre-execution tool/dependency block records `completion: "blocked"`, null exit status,
   empty stream files and copy-only start/end inventories when available, or leaves an
   incomplete attempt if a valid record cannot be written; the command exits 4. Use
   traps and safe containment checks: terminate the gate process group with SIGTERM, wait,
   then SIGKILL remaining processes and wait before recording evidence and removing the
   execution tree on catchable interruption. Never delete the run, repository or arbitrary
   parent. A hard kill that
   prevents cleanup must leave an incomplete attempt, never a passing result.
4. **Status and exit contract** — Extend read-only `status` to verify the current run
   first, then validate the latest attempt against `loom-eval-gate-rerun-v1.schema.json`,
   its run/manifest/command digest binding, contiguous monotonic attempt sequences,
   and stream bytes and SHA-256 recomputed from both retained logs. Only intact, current
   evidence can report `rerun-passed` or `rerun-failed`. A latest attempt without a
   completed record (including killed or in-progress) is `incomplete` (3), blocked is
   `infrastructure-blocked` (4), and corrupt, stale, changed or invalid evidence is
   `invalid` (2); never fall back to `prepared` or an earlier pass. `verify` remains
   read-only and does not treat rerun evidence as a verdict. For both commands use 0
   for pass, 1 strictly for usage errors, 2 for rerun-failed or invalid, 3 for incomplete
   status, and 4 for infrastructure-blocked. Catchable interruption exits 4; a hard kill
   leaves an incomplete attempt. Neither operation advances lifecycle state.
5. **`plugins/loom/bin/loom-eval-workspace.bats`** — Add isolated repository fixtures
   covering the boundary and evidence contract below; update usage/status assertions as
   needed. Reuse existing helper/schema registration, adding repository validator checks
   only if needed to validate the already shipped rerun schema. Keep shared policy
   portable under Bash 3.2+, Git 2.34+ and jq 1.6+.

## Verification

Developer iteration: `bats plugins/loom/bin/loom-eval-workspace.bats`, plus
`shfmt -i 4 -d plugins/loom/bin/loom-eval-workspace` and
`shellcheck -s bash plugins/loom/bin/loom-eval-workspace`. Final gate: `scripts/check`
and `node scripts/validate-repository.mjs --root "$PWD" --all`.

Tests must exercise exact argv including spaces and metacharacters, empty-environment
isolation and reserved redirects; a gate writing beside source and into home, config,
cache, temp and build paths must complete in the copy without changing source or
checkout. Cover pinned dependencies and tools, non-code and override rejection,
missing/mismatched tools, invalid manifests and changed source/checkout, copy inventory
mismatch, passing and nonzero gates, interruptions, evidence schema and hash validation,
corrupt/stale/cross-run evidence, repeat attempts without overwrite, and cleanup on each
outcome. Assert all exit/status mappings, retained stream byte/hash checks, sequence continuity,
blocked and incomplete attempts, and that prior evidence cannot mask a changed run.
Run existing exporter tests unchanged as regression coverage.

## Notes

Verification evidence: `TMPDIR=/private/tmp scripts/check` exited 0 (752 Bats tests, 0 failures, including
17 new `gate-rerun` tests in `loom-eval-workspace.bats`, covering no-checkout and bare repository runs; existing exporter tests unchanged);
`node scripts/validate-repository.mjs --root "$PWD" --all` passed; `shfmt -i 4 -d` and
`shellcheck -s bash` clean on the helper. ADR 0021 local-review findings generated and assembled at `.docs/evaluations/evaluation-gate-runner-review-findings.md`.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Resolve Round 0 findings on exits, evidence, tool probes, redirects, inventory, interruption and schema validation. |

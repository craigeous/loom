# Evaluation Gate Runner

Status: Plan Review
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
   Capture a deterministic inventory of the managed checkout, including untracked
   files and modes, before execution; inability to inventory is infrastructure-blocked.
2. **Execution boundary** — Create a unique private disposable execution tree outside
   the checkout and Git common directory. Copy the verified source without links or
   special files, preserve executable modes, and compare its initial path/type/mode/
   content-hash inventory to the immutable source before running. Make only the copy
   writable. Invoke the manifest's exact argv as an argument vector, without shell
   evaluation or word splitting, from the copy. Start from an empty environment with
   only the pinned variables plus runner-owned redirects; provide the verified prepared
   offline dependencies and redirect home/config, caches, temp and declared build
   outputs to the copy or private scratch using the existing reserved environment names.
   Never inherit credentials or ambient environment. Capture actual declared tool
   versions and compare with the pinned versions before execution; unavailable or
   mismatched tools/dependencies block the attempt rather than silently substituting.
3. **Evidence and cleanup** — For each attempt allocate a unique monotonic sequence
   under private scratch, retaining earlier evidence without overwrite. Capture UTC
   start/end, process completion and exit status, stdout/stderr byte counts and SHA-256,
   canonical start/end inventories (file count and SHA-256) and sorted added/modified/
   deleted paths, command/environment digest, tool versions, run ID and exact manifest
   hash. Reverify immutable source and the checkout against pre-run inventories after
   every attempt, including failures and interruptions. Write `gate-rerun.json` in the
   attempt's own directory atomically only after validating it with
   `plugins/loom/schemas/loom-eval-gate-rerun-v1.schema.json` (Draft 2020-12 and
   formats, using the existing schema-validation dependencies). Encode completion,
   source verification and result consistently with that schema. Incomplete execution,
   failed verification, evidence write/validation failure or interruption cannot pass;
   classify changed inputs as invalid and unavailable infrastructure/interruption as
   infrastructure-blocked. Use traps and safe containment checks to remove the execution
   tree on success, failure and catchable interruption, after recording evidence when
   possible; never delete the run, repository or arbitrary parent. A hard kill that
   prevents cleanup must leave an incomplete attempt, never a passing result.
4. **Status and exit contract** — Extend read-only `status` to verify the current run
   first, then validate the latest attempt's schema, run/manifest/command digest binding
   and evidence integrity before reporting `rerun-passed` or `rerun-failed`. Missing,
   partial, corrupt or stale evidence cannot yield either status. Preserve existing
   `prepared`, `incomplete`, `invalid` and `infrastructure-blocked` distinctions;
   `verify` remains read-only and does not treat rerun evidence as a verdict. For
   `gate-rerun` and completed rerun status use 0 for passed, 1 for completed nonzero
   gate, 2 for invalid input/evidence or changed source/checkout, and 4 for unavailable
   infrastructure or interrupted execution. Preserve existing usage-error and incomplete
   status behavior. Neither operation advances lifecycle state.
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
outcome. Assert exit/status mappings and that prior evidence cannot mask a changed run.
Run existing exporter tests unchanged as regression coverage.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

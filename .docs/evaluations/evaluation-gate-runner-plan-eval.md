# Evaluation: evaluation-gate-runner Slice Plan

Status: Evaluated
Verdict: PASS
Round: 1
Reviewed against: Round 0 findings (below, superseded); revision diff `464e6d9..3cca633`; ADR 0022 §2–§5; spec 04 § Evaluation orchestration; spec 05 § Unconditional gate rerun, § Verdict, § Mechanical conformance; `plan-eval-rubric.md`; `severity.md`; archived `sanitized-evaluation-workspace.md`; `plugins/loom/schemas/loom-eval-gate-rerun-v1.schema.json`; `plugins/loom/bin/loom-eval-workspace` at `3cca633`

## Summary

Round 1 applies the non-expansion rule. I checked only whether the Round 0 findings
are resolved in the revision diff, and whether the revision introduced any regression.
The revision resolves all three majors and all six minors with local edits to the plan
text. Both nits are also addressed. It adds no new blocker or major, so the plan passes.

## Round 0 finding resolution

| Finding | Status | Evidence in revision |
|---|---|---|
| M1: exit code 1 means two things | Resolved | Step 4 now reserves 1 strictly for usage errors. It maps rerun-failed and invalid to 2, which matches the landed workspace table, and lets `status` tell them apart. It maps incomplete to 3 and infrastructure-blocked to 4. Verification asserts all exit/status mappings. |
| M2: evidence location and integrity | Resolved | Attempts live in the runner-owned `reruns/attempt-<seq>/`, outside `output/`/`scratch/`. `reruns` is added to the `do_verify` and `cmd_clean` top-level allowlists (the current allowlists are at `loom-eval-workspace:404-408` and `:1044`). `stdout.log`/`stderr.log` are retained. `status` recomputes stream bytes/SHA-256 and checks that attempt sequences are contiguous and monotonic. |
| M3: tool-version check has no method | Resolved | Step 2 defines a single probe: resolve `name` only on the pinned `PATH` under the empty pinned environment, then run `name --version 2>&1`. It records the first non-empty line and requires the pinned version as a whole token. A missing tool, a failed probe or a mismatch blocks the attempt (4). |
| m1: status for non-pass/fail latest attempt | Resolved | No completed record means `incomplete` (3). Blocked means `infrastructure-blocked` (4). Corrupt, stale or changed evidence means `invalid` (2). Status never falls back to `prepared` or to an earlier pass. |
| m2: pre-execution block vs schema | Resolved | The runner writes a `completion: "blocked"` record with null exit status, empty stream files and copy-only inventories. If no valid record can be written, it leaves an incomplete attempt. Either way it exits 4. |
| m3: reserved redirects not listed | Resolved | Step 2 lists exactly where each redirect points: `HOME`, `XDG_*`, `TMPDIR`/`TMP`/`TEMP`, the Cargo/Go/npm/pip names, `LOOM_EVAL_DEPS` (read-only `inputs/deps`), `LOOM_EVAL_BUILD` and `LOOM_EVAL_SCRATCH`. |
| m4: checkout inventory scope | Resolved | With `REPO_OK=1`, the inventory covers `git ls-files -s` plus untracked non-ignored paths, with types, modes and hashes. It excludes ignored files and `.git` internals. With `REPO_OK=0`, there is no checkout comparison and run/source verification still applies. |
| m5: interruption doesn't handle the gate child | Resolved | On interruption the runner sends SIGTERM to the gate process group and waits, then sends SIGKILL to anything left and waits again. Only after that does it record evidence and remove the tree. |
| m6: schema-validation refactor unstated | Resolved | Step 3 refactors `validate_manifest_schema` into `validate_json_schema <schema> <file>`. |
| Nit: "formats" | Resolved | The reference to "formats" is removed. |
| Nit: stale header comment | Resolved | Step 1 updates the helper header. |

## Findings

### Blocker

- None.

### Major

- None.

### Minor

- None.

### Nit

- **Nit — The redirect paths don't name a root.** Step 2's redirect targets are written as
  `scratch/...` without saying whether that is the run's evaluator `scratch/` or a
  private scratch inside the disposable execution tree. The text around it ("to the copy
  or private scratch", execution tree removed afterwards) suggests the execution tree.
  The developer should root the redirects there, so that gate caches neither persist
  into nor read from the evaluator's `scratch/`. This is non-blocking.
- **Nit — Exit 2 covers two outcomes.** Exit 2 now covers both rerun-failed and invalid.
  Tests should assert the `status` string as well as the exit code, so the two stay
  distinguishable.

## Verdict rationale

Under `severity.md`, a plan with no unaddressed `[BLOCKER]` or `[MAJOR]` passes.
M1–M3 and m1–m6 are each resolved with specific, testable plan text. The revision adds
no new ambiguity of major severity. The two remaining nits are advisory.

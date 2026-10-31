# Evaluation Output Recorder

Status: Plan Review
Target specs: 03-artifact-lifecycle.md, 04-orchestrator.md, 05-blind-evaluation.md; ADR 0022, ADR 0023
Target size: <= 350 LOC net change excluding tests and schemas (keep this plan <= 200 lines)

## Context

The sanitized workspace and gate runner prepare and verify controlled evaluation inputs
and reruns; evaluators still need a deterministic way to record their output without
checkout write access. This slice adds the schema and recorder, connects orchestration
to it, and specifies settlement of the recorder's bootstrap retirement. Invalid
output is infrastructure-blocked, not a merits FAIL and cannot advance a lifecycle.

## Out of Scope & Threat-Model Boundary

No evaluator launch isolation, exporter, gate command, remote publication mechanism,
or spec/ADR amendment is introduced here. Spec 00's non-goals exclude OS-level
hostile-code containment, cryptographic anonymity, remote attestation, and proof of
independent model reasoning. The private workspace and checkout are trusted against
hostile concurrent inode swaps or helper monkeypatching; nevertheless reject links,
path escapes, malformed outputs and unverified evidence at the recording boundary.
The ADR 0023 exception remains restricted to its eligible repository and state; no
production failure or stale checkpoint revives retired bootstrap components.

## Steps

1. **`plugins/loom/schemas/loom-eval-verdict-v1.schema.json`**: define strict Draft
   2020-12 `loom-eval-verdict/v1`, rejecting extra properties and requiring a single
   complete verdict: run ID, manifest SHA-256, evaluation type, artifact path,
   reviewed head (and base for code), PASS/FAIL, nonnegative round, authority
   bindings, severity-tagged findings, required changes for FAIL, residual notes,
   and for code the local-review adjudications and gate-rerun reference. Require
   nonempty required changes for FAIL and bind field types, hashes and relative paths.
   Preserve evaluator judgment verbatim; do not infer PASS from an empty findings list.
2. **`plugins/loom/bin/loom-eval-workspace`**: add `record <run-dir|run-id> [--repo
   <path>]`, usage and dispatch; require a usable managed checkout and run `do_verify`
   successfully before examining output. Require exactly one regular, non-symlink
   `output/verdict.json` and no other output entries; validate it with the existing Ajv
   `validate_json_schema` path. Compare every echoed run/type/manifest, artifact,
   revision and authority binding to the verified manifest; reject missing, duplicate,
   malformed, truncated, cross-run or mismatched data. Require exactly one manifest
   artifact for unambiguous destination and reject ambiguous multi-artifact runs.
3. **Same helper**: refactor the existing `rerun_status` checks into a reusable,
   non-exiting validator retaining its status behavior. For code require a completed,
   schema-valid latest attempt bound to run, manifest and command, with matching log
   hashes and contiguous attempt sequence; reject blocked, interrupted, invalid or
   incomplete attempts. Bind the verdict reference to that attempt. A PASS requires
   `rerun-passed`; a FAIL may record a completed `rerun-failed` or `rerun-passed`.
   Prior developer gate evidence never substitutes for a rerun.
4. **Same helper**: derive `.docs/evaluations/<artifact-name>-eval.md` from the sole
   manifest artifact's repository-relative basename, stripping its final `.md`;
   reject non-Markdown, unsafe components, traversal, links or special files in the
   destination and its existing ancestors. Render a deterministic identity-neutral
   Markdown report from the validated fields without changing merits. Write a private
   temporary file in the destination directory and atomically publish it; identical
   existing bytes are an idempotent success, differing existing bytes fail closed.
   Never overwrite another verdict. Emit JSON containing status, run ID, verdict,
   report path and report SHA-256 on stdout; diagnostics go to stderr.
5. **Same helper and orchestration guidance**: validate the applicable spec-03 legal
   status transition before recording; apply it only for a valid recorded verdict,
   preserving owner-claimed gates and the ADR 0023 ratification exception. Make
   interruption/retry safe: an existing matching report can complete a pending legal
   transition, while conflicting report or state blocks without advancing. Specify
   the transition and recovery ordering in the guidance; orchestrator commits the
   report and status under the uniform identity, evaluator never commits or mutates
   the checkout. A recording failure consumes no round and causes no status advance.
6. **`plugins/loom/skills/loom-run/SKILL.md` and
   `plugins/loom/skills/loom-playbook/references/orchestration.md`**: instruct root to
   invoke `record`, inspect its JSON, commit the valid report and status, and retain
   recovery evidence. Retire root-copy once its component is retired, without
   retroactively claiming production conformance for degraded bootstrap evidence.
   During settlement of this slice, after fresh verification of its published result,
   freshly read the configured target and prove each recorded result SHA for
   `local-review-orchestration`, `sanitized-evaluation-workspace`, and this slice is an
   ancestor. Record the first such target as `full_sunset.sha`; the terminal successor
   retires all components and full sunset and empties `allowed_slices`. Unavailable or
   unverifiable target blocks settlement; never force-push or reopen bootstrap.
7. **`plugins/loom/bin/loom-eval-workspace.bats`**: exercise plan/research/code valid
   records, FAIL and PASS, schema errors, missing/duplicate/cross-run and hash mismatch,
   changed inputs, completed/failed/incomplete/blocked reruns and latest-attempt
   mismatch, traversal and symlink destinations, conflicting outputs, idempotent retry,
   legal transition and interrupted recovery. Assert no report or status advance on
   failure and preserve existing verify/status/gate-rerun regressions.

## Verification

Run `bats plugins/loom/bin/loom-eval-workspace.bats` for targeted iteration and
`scripts/check` as the required full gate. Run
`node scripts/validate-repository.mjs --root /Users/craig/git/loom --all` for
repository validation. The new Bats cases prove recording, binding, confinement,
rerun and retry behavior; existing workspace tests must pass unchanged as regression
proof. Review settlement guidance against ADR 0023 and specs 03/04/05, including the
fresh target ancestry and terminal-state requirements.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

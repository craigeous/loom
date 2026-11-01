# Workflow Benchmark

Status: Plan Review
Target specs: 00-overview.md, 04-orchestrator.md
Target size: <= 250 LOC net script code; tests and protocol documentation separate

## Context

M8 needs evidence about workflow cost and defects before choosing workflow profiles
or history policy. This slice supplies an owner-operated paired benchmark harness
and measurement protocol. A 250-line script budget covers three small commands and
jq validation; Bats fixtures and protocol prose are outside that code budget.

## Out of Scope & Threat-Model Boundary

Do not change specs, role contracts, approval gates, publication, workflow profiles,
or target-branch history policy. Do not run a production benchmark or publish a
result during implementation. Per spec 00 Non-goals, this is not OS-level
hostile-code containment, remote attestation, or proof of independent model reasoning;
use disposable, trusted local workspaces and synthetic fixtures, not secrets or
untrusted code. Results are observations, not release conformance or statistical
proof of defect absence.

## Files to touch

- `scripts/workflow-benchmark.sh` — new executable harness.
- `scripts/tests/workflow-benchmark.bats` — new automated tests.
- `docs/workflow-benchmark.md` — new operator protocol (create `docs/` if needed).

`scripts/check` discovers tracked `.sh` and `.bats` files, so no registration change
is planned. Do not change `CLAUDE.md`, status documents, or other paths. Stop and
escalate to the orchestrator if the budget or listed paths cannot satisfy this
contract, a required measure cannot be represented, or a gate failure requires a
specification or out-of-scope change; do not silently weaken requirements.

## Steps

1. Implement `scripts/workflow-benchmark.sh` in Bash 3.2+ using jq 1.6+ and the
   repository runtime floor Git 2.34+; no Node runtime dependency. Provide exactly
   `init <output-dir>`, `validate <output-dir>`, and `summarize <output-dir>`.
   `init` refuses any existing output directory, creates `manifest.json` and ten
   `records/<workload>--<mode>.json` files, and never overwrites. Manifest has exactly
   `schemaVersion: "loom-workflow-benchmark/v1"` and `records`, an array of those
   ten relative paths. Workloads are `doc-fix`, `localized-bug`, `feature`, `security`,
   `architecture`; modes are `loom`, `single-agent`. No agent launch, checkout
   mutation, service contact, or automatic token measurement is performed.
2. Each record has exactly these top-level keys and types (all keys required):
   - `workload`, `mode`: allowed strings above; filename must match both.
   - `timestamps`: object with `start`, `end` UTC ISO 8601 strings or null, and
     `interruptions`: array of objects with nonempty `description` and nonnegative
     numeric `seconds`. Complete records require ordered, valid start and end.
   - `wallClockSeconds`, `agentCount`, `tokenInput`, `tokenOutput`,
     `estimatedCostUsd`, `commits`, `reviewRounds`, `defectsIntroduced`,
     `defectsCaught`, `humanInterventions`: nonnegative numbers or null; counts
     are integers. Null means unknown, never inferred zero.
   - `status`: `incomplete`, `success`, or `failure`; only success and failure are
     complete. An initialized record is incomplete, timestamps null, interruptions
     empty, all metrics null, and all supporting fields below empty.
   - `unknownReasons`: object mapping every null metric to a nonempty reason for
     complete records; no reason is required for blank incomplete templates.
   - `provenance`: object with nonempty `task`, `startingCommit`, `acceptanceCriteria`,
     `testCommands`, `seededDefects`, `detectionProcedure`, `client`, `model`,
     `reasoning`, `host`, `pricingSource`, `pricingDate`, `executionOrder` strings
     for complete records; explain nonapplicability rather than omit a field.
   - `evidence`: object with arrays `commitIds`, `testOutcomes`, `paths`, `defects`,
     `interventions`, `deviations`. Complete records require at least one nonempty
     test outcome and evidence path; other arrays may be empty when observed.
     Defect entries describe cause, detection method and stage; intervention entries
     describe the action. Arrays contain nonempty strings.
3. Document the format and exact commands in `docs/workflow-benchmark.md`. Before
   either run, define each workload's task, starting commit, acceptance criteria,
   tests, seeded defects and independent detection procedure. Use equivalent isolated
   copies of the same commit and task; alternate first mode across workloads. Loom
   follows its existing gates; the single-agent baseline uses one agent with the same
   task, tools, criteria and tests without Loom role orchestration. Do not relax safety
   or owner gates. Record deviations, interruptions, model and pricing provenance.
   Measure wall time from assignment to accepted completion including waits; count
   distinct invocations including root and review workers. A review round is one
   complete review and response cycle; an intervention is human action beyond initial
   assignment. A defect is a reproducible criteria violation or seeded fault,
   deduplicated by underlying cause. Apply the same independent post-run checks to
   both outputs; preserve unknowns and evidence without credentials or transcripts.
4. `validate` checks manifest shape and paths, exactly one record for each pair,
   exact record keys and types above, nonnegative values and integer counts, timestamp
   validity and order, complete-record provenance, unknown reasons and evidence.
   Incomplete records are valid but excluded from comparisons. `summarize` validates
   first and prints each pair's raw numeric values and Loom-minus-single-agent delta;
   display `unknown` for each metric if either value is null or either record is
   incomplete. Do not aggregate unmatched runs or claim causation or significance.
   Retain source records as the audit trail.
5. Add Bats tests using temporary fixtures. Test the documented init, validate and
   summarize commands end to end, including all ten files and unknown incomplete
   comparisons, and the success and rejection oracles below. All verification is
   automated; no manual walkthrough is required.

## Verification

- `bats scripts/tests/workflow-benchmark.bats` and `scripts/check` must pass; the
  latter runs shfmt, shellcheck, Bash syntax and tracked Bats tests.
- Exit 0 for successful init, valid complete and incomplete datasets and summary.
  Assert ten distinct pairs and no overwrite; init on an existing directory exits 1,
  stderr includes `exists`, and its prior contents remain unchanged.
- Invalid command or argument count exits 2 with `usage` on stderr. Missing manifest
  or record exits 1 with `missing`; malformed JSON or wrong schema/keys/types exits 1
  with `invalid`; duplicate pair exits 1 with `duplicate` and the pair named.
- Negative measurements, noninteger counts, invalid or reversed timestamps, and
  disallowed workload/mode/status each exit 1 with `invalid` and the field named.
  Missing required provenance, evidence, or null-metric reason exits 1 with respectively
  `provenance`, `evidence`, or `unknown reason` on stderr. Test each rejection for
  both `validate` and `summarize`, which must not emit a comparison on failure.
- For a complete pair with wall-clock values Loom 120 and single-agent 90, assert
  raw values and delta 30; reverse values yield -30. A null metric with a reason or
  an incomplete member yields `unknown` for the affected comparison, never zero.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Use portable Bash/jq, scope the code budget, specify records, paths, stop rules and automated test oracles. |

# Workflow benchmark protocol

An owner-operated, paired comparison of Loom against a single-agent baseline on
five workloads. The harness `scripts/workflow-benchmark.sh` only creates, validates
and summarizes records. It launches no agent, mutates no checkout, contacts no
service and measures no tokens; the operator records all measurements by hand.

Use disposable, trusted local workspaces and synthetic fixtures, never secrets or
untrusted code. Results are observations, not release conformance, causal claims
or statistical proof of defect absence.

Requirements: Bash 3.2+, jq 1.6+, Git 2.34+.

## Commands

```sh
scripts/workflow-benchmark.sh init <output-dir>       # refuses an existing directory
scripts/workflow-benchmark.sh validate <output-dir>
scripts/workflow-benchmark.sh summarize <output-dir>  # validates first
```

Exit codes: 0 success; 2 `usage` (bad command or argument count); 1 for a
data problem, with one of these tokens on stderr: `exists`, `missing`, `invalid`
(malformed JSON, wrong keys/types/values, negative or noninteger measurements,
bad or reversed timestamps; the field is named), `duplicate` (pair named),
`provenance`, `evidence`, `unknown reason`.

## Layout

`init` writes `manifest.json` and ten `records/<workload>--<mode>.json` templates.
Workloads: `doc-fix`, `localized-bug`, `feature`, `security`, `architecture`.
Modes: `loom`, `single-agent`. The manifest is exactly:

```json
{"schemaVersion": "loom-workflow-benchmark/v1", "records": ["records/doc-fix--loom.json", "..."]}
```

## Before either run

For each workload define, and fix before starting: the task, starting commit,
acceptance criteria, tests, seeded defects, and an independent detection procedure.
Run both modes on equivalent isolated copies of the same commit and task, and
alternate which mode goes first across workloads. Loom follows its existing gates;
the baseline is one agent with the same task, tools, criteria and tests, without
Loom role orchestration. Do not relax safety or owner gates. Record deviations,
interruptions, and model and pricing provenance. Apply the same independent
post-run checks to both outputs. Keep unknowns as `null`; never record credentials
or transcripts.

## Record schema

Every record has exactly these top-level keys:

| Key | Type |
|---|---|
| `workload`, `mode` | allowed strings; must match the filename |
| `timestamps` | `{start, end, interruptions}`; `start`/`end` are UTC ISO 8601 (`2026-01-01T00:00:00Z`) or null; `interruptions` is a list of `{description, seconds}` with nonempty description and `seconds >= 0` |
| `wallClockSeconds`, `estimatedCostUsd` | nonnegative number or null |
| `agentCount`, `tokenInput`, `tokenOutput`, `commits`, `reviewRounds`, `defectsIntroduced`, `defectsCaught`, `humanInterventions` | nonnegative integer or null |
| `status` | `incomplete`, `success` or `failure`; the last two are complete |
| `unknownReasons` | object: metric name to nonempty reason |
| `provenance` | object of strings: `task`, `startingCommit`, `acceptanceCriteria`, `testCommands`, `seededDefects`, `detectionProcedure`, `client`, `model`, `reasoning`, `host`, `pricingSource`, `pricingDate`, `executionOrder` |
| `evidence` | object of string arrays: `commitIds`, `testOutcomes`, `paths`, `defects`, `interventions`, `deviations` |

A fresh template is `incomplete`, with null timestamps and metrics and empty
supporting fields. A complete record needs ordered, valid `start` and `end`; a
nonempty value for every `provenance` field (explain nonapplicability rather than
omit); at least one `testOutcomes` entry and one `paths` entry; and a reason in
`unknownReasons` for every null metric. Defect entries describe cause, detection
method and stage; intervention entries describe the action.

## Measures

- **Wall time**: assignment to accepted completion, including waits.
- **Agent count**: distinct invocations, including the root and review workers.
- **Review round**: one complete review and response cycle.
- **Intervention**: human action beyond the initial assignment.
- **Defect**: a reproducible criteria violation or seeded fault, deduplicated by
  underlying cause.

## Summary

`summarize` prints, per workload and metric, the raw `loom` and `single-agent`
values and `delta` = Loom minus single-agent. `unknown` is shown for a null value,
and as the delta whenever either value is null or either record is `incomplete`;
unknown is never treated as zero. Unmatched runs are not aggregated. Keep the
source records as the audit trail.

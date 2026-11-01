# Workflow Benchmark

Status: Plan Review
Target specs: 00-overview.md, 04-orchestrator.md
Target size: <= 180 LOC net change (excluding generated run data)

## Context

M8 needs evidence about workflow cost and defects before choosing workflow profiles
or history policy. This slice supplies a repeatable, owner-operated benchmark
harness and measurement protocol for paired Loom and single-agent runs. It does
not assert that one workflow is better before measurements exist.

## Out of Scope & Threat-Model Boundary

Do not change specs, role contracts, approval gates, publication, workflow profiles,
or target-branch history policy. Do not run a production benchmark or publish a
result as part of implementation. Per spec 00 Non-goals, this is not OS-level
hostile-code containment, remote attestation, or proof of independent model reasoning;
use disposable, trusted local workspaces and synthetic fixtures, not secrets or
untrusted code. Benchmark results are observations, not release conformance or
statistical proof of defect absence.

## Steps

1. Add `scripts/workflow-benchmark.mjs`, a dependency-free Node harness with
   `init <output-dir>`, `validate <output-dir>`, and `summarize <output-dir>`.
   `init` creates a versioned JSON manifest and ten empty run records, one per
   workload and mode, without overwriting existing files. The five workload IDs are
   `doc-fix`, `localized-bug`, `feature`, `security`, and `architecture`; modes are
   `loom` and `single-agent`. The harness never launches agents, changes a checkout,
   contacts a service, or measures token usage itself. Fail with a nonzero exit and
   actionable error on malformed arguments, missing files, duplicate pairs, invalid
   records, or an existing output directory at initialization.
2. Add `docs/workflow-benchmark.md` documenting the operator protocol and JSON
   schema. Before either run, define each workload's task, starting commit, acceptance
   criteria, test commands, seeded defects and independent defect-detection procedure;
   use equivalent isolated copies of the same commit and task for each pair. Record
   client, model, reasoning settings, host, pricing source/date and execution order;
   alternate which mode runs first across workloads. Loom follows its existing gates;
   the single-agent baseline uses one agent with the same task, tools, acceptance
   criteria and tests, without Loom role orchestration. Do not relax safety or owner
   gates. Record deviations and interruptions; mark incomplete runs rather than
   silently substituting estimates or zeroes.
3. Each run record identifies workload, mode, start/end UTC timestamps and elapsed
   wall-clock seconds from task assignment to accepted completion, including waits;
   record interruptions and their durations separately. Record distinct agent
   invocation count (including root and review workers), input/output tokens and
   estimated currency cost with rate/source or `null` and a reason, created commit
   count, review rounds, human intervention count and description, defects introduced,
   and defects caught before completion. Define a defect as a reproducible violation
   of the predeclared criteria or a seeded fault; deduplicate by underlying cause and
   record detection method and stage. Apply the same independent post-run checks to
   both outputs to identify remaining defects; record unknown where observation is
   impossible, and never infer zero from missing evidence. Record success/failure,
   relevant commit IDs, test outcomes, and evidence paths without credentials or
   private transcripts. Define a review round as one complete review and associated
   response cycle, and an intervention as a human action beyond initial assignment;
   use these definitions for both modes, including zero when observed.
4. `validate` checks the schema, exactly one record per pair, allowed values,
   nonnegative numeric measurements, timestamps and ordering, required provenance,
   explicit unknown reasons, and completion/evidence fields. Incomplete records are
   valid only when explicitly marked incomplete and excluded from comparisons.
   `summarize` validates first, then prints each pair's raw values and Loom-minus-
   baseline deltas for comparable numeric metrics; show `unknown` if either value is
   missing or either run incomplete. Do not aggregate unmatched runs or claim causal
   or statistical significance. Preserve the source records as the audit trail.
5. Add `scripts/tests/workflow-benchmark.bats` covering initialization, all five
   pairs, valid complete and incomplete records, malformed or duplicate data,
   missing evidence and unknown reasons, no-overwrite behavior, and paired deltas
   including unknown values. Use temporary fixtures only. Document exact commands
   for initializing, filling, validating, and summarizing a run in the protocol.

## Verification

- Fast targeted check: `bats scripts/tests/workflow-benchmark.bats`.
- Repository gate: `scripts/check`.
- The targeted tests prove schema rejection, no-overwrite behavior, incomplete and
  unknown handling, and correct paired comparisons; the full gate guards regressions.
- Manually follow the documented commands with a temporary output directory and
  verify the ten blank records are produced and incomplete results are not compared.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

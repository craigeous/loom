# Plan evaluation — workflow-benchmark

Artifact: .docs/slice-plans/workflow-benchmark.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: fbac2cd
Round: 0
Verdict: PASS

## Summary

The revision (diff `1267b87..fbac2cd`) resolves both Round 0 MAJOR findings and all four MINOR findings. This is a non-expansion re-review under severity.md (re-review resolving Round 0 FAIL; counting rule keeps Round 0): I checked prior findings against the revision diff and raised no new BLOCKER or MAJOR. The plan is 124 lines, under the 250-line budget, with `Target size:`, `## Out of Scope & Threat-Model Boundary`, in-place edits, and a `## Revision Log` row for Round 1.

Read scope was limited to the plan, the prior evaluation, the rubric, improvement-plan lines 805-835, and the revision diff. I did not open specs 00 or 04 in full beyond locating the Non-goals heading. The Round 0 review found them consistent and the revision does not change that.

## Findings

### Round 0 findings: resolution

1. **[MAJOR] Node runtime outside the declared floors — RESOLVED.** Step 1 now specifies `scripts/workflow-benchmark.sh` in Bash 3.2+ with jq 1.6+ and Git 2.34+, with "no Node runtime dependency". The Files to touch section notes that `scripts/check` discovers tracked `.sh` and `.bats` files, so shfmt, shellcheck and syntax stages cover the harness.
2. **[MAJOR] LOC budget not credible — RESOLVED.** The budget is now `<= 250 LOC net script code`, with Bats tests and protocol prose explicitly outside it. Context explains the scope as three small commands plus jq validation, and the stop-and-escalate clause fires if the budget cannot satisfy the contract. This is the "raise with a justified number" option the finding offered. Residual observation, not a finding: 250 lines is tight for the validation surface. Excluding tests from the budget is acceptable here, and the escalation clause covers the overshoot case.
3. **[MINOR] Schema deferred to docs — RESOLVED.** Step 1 fixes the manifest as `schemaVersion: "loom-workflow-benchmark/v1"` plus `records`. Step 2 lists every record key with its type, allowed values, null semantics, completeness rules, and the provenance and evidence sub-keys.
4. **[MINOR] Oracles by topic — RESOLVED.** Verification gives concrete exit codes and stderr tokens per rejection class: usage exits 2, missing/invalid/duplicate exit 1, and the existing directory case exits 1 with `exists`. It also gives the worked delta (120 vs 90 gives 30; reversed gives -30) and `unknown` for null or incomplete.
5. **[MINOR] Stop rules and path footprint — RESOLVED.** The new "Files to touch" section lists three paths, says `docs/` is created if needed, says no registration change is needed, and forbids touching `CLAUDE.md` and status docs. It adds an explicit stop-and-escalate clause.
6. **[MINOR] Manual verification — RESOLVED.** Step 5 and Verification now state that all verification is automated, including end-to-end init, validate and summarize with a ten-file assertion and `unknown` for incomplete pairs. The manual walkthrough is removed.

## Checked against the revision diff (no new issues)

- The revision keeps the M8 measurement list intact: wall-clock, agents, tokens/cost, commits, review rounds, defects introduced and caught, interventions. Five workloads and a single-agent baseline per workload are still required.
- Threat-model boundary is unchanged and still cites spec 00 Non-goals.
- The changes were made in place and logged. No competing "Operative contract" or "Resolving Round N" section was added.
- Verification still names the fast check (`bats scripts/tests/workflow-benchmark.bats`) and the gate (`scripts/check`).

## Non-blocking notes

- The developer should keep the jq validation compact. If the 250-line script budget is exceeded, the plan's stop-and-escalate clause applies rather than trimming checks.

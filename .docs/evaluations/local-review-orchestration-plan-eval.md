# Evaluation: local-review-orchestration (slice-plan)

Verdict: FAIL
Round: 0
Reviewed against: ADR 0021, ADR 0022, specs 02/04/05, repository-improvement-plan.md (lines 595-635), plan-eval-rubric.md, severity.md, evaluation template; spot-checks of the five target operational files and the `loom-review` helper usage text

## Findings

- [MAJOR] Step 1 specifies a nonexistent flag: `loom-review assemble <run-dir|run-id> --output .docs/evaluations/<slice>-review-findings.md`. The helper's usage and arg parser accept only `--out` (`plugins/loom/bin/loom-review` usage block and the `--repo | --out)` case). A developer following the plan verbatim would write operational docs whose command fails with a usage error. The plan's own Verification section promises to check signatures against the helper, but the step text itself is already wrong (the improvement plan's `--run`/`--output` shape is also stale relative to the shipped helper). Also, `prepare` prints the run directory path, not a bare run ID (`printf '%s\n' "$final"`), so "use the returned run ID" is imprecise.
- [MAJOR] Step 1 does not say how the three finders are launched. It says to "launch three separate cold, non-delegating Loom-owned finders" with manifest-pinned prompts, but names no launch mechanism or helper (e.g. `loom-launch-role` or a per-client adapter step) for either Claude or Codex, and `loom-launch-role` has no finder support. The plan also excludes launch adapters from scope. An independent reader cannot execute or write this step without guessing, which is the executability gap the rubric calls the most common BLOCKER. Required: state the launch path the operational docs should point to (or state explicitly that adapter-specific launch is deferred and what the docs say in the interim, without reintroducing a hidden-command dependency).
- [MINOR] Header lists `05-evaluation.md`; the actual spec is `05-blind-evaluation.md`. Fix the filename.
- [MINOR] The mechanical-verification bullet names no concrete command. The rubric expects an `rg -U` invocation for wrapped-token invariants. Give the pattern and file list (e.g. `rg -U -n -i '/code-review|/security-review|command-unavailable|origin/HEAD|\bPR\b|GitHub' <five files>`) and the expected disposition of the remaining matches. Note that review-findings.md and code-eval-rubric.md currently cite historical ADR 0010/0011 links, so state which historical mentions are permitted.
- [MINOR] Step 4 says to "retain any separately authorized bootstrap procedure". The files do reference ADR 0023 `loom-repository-bootstrap/v1`. Name the exact retained references (code-eval-rubric.md, orchestration.md) so the developer does not delete or expand them.
- [MINOR] Step 3 leaves the "Illustrative skeleton" and the per-command status table to be "replaced" without listing the sections. The current review-findings.md also says "Orchestration still uses the legacy commands above until the `local-review-orchestration` slice rewires it" (around line 172); list that sentence explicitly for removal.

## Required changes (for FAIL)

1. Change `--output` to `--out` in step 1 (or document the flag the helper actually accepts) and describe `prepare` output accurately as the run directory (run ID derivable from it).
2. Specify, in step 1, the finder launch mechanism the orchestration docs must reference for each client, or explicitly scope and word the deferral so the instructions remain executable and carry no external-command dependency.
3. (Recommended with the above) fix the spec filename, give the concrete `rg -U` verification command, and enumerate the retained bootstrap/ADR-historical references.

## Notes

Strengths: the plan is well-scoped to documentation, traces cleanly to ADR 0021 (exact SHAs, three required finders, whole-run invalidation, docs-only skip, ADR 0017 pause/checkpoint, evaluator-owned verdict) and ADR 0022 (controlled inputs, mandatory gate rerun, no network-sandbox overclaim). It has the required `Target size`, the `Out of Scope & Threat-Model Boundary` section, a Revision Log, and is under 250 lines (99). It meets the improvement plan's acceptance criteria (no-remote clone, provenance, no GitHub/PR/network, evaluator adjudicates every finding). Both MAJORs are narrow fixes; no re-scoping is needed.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | Initial review: wrong `assemble` flag and unspecified finder launch path (MAJOR); minor filename/verification nits. |

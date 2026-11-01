# Plan evaluation — workflow-profiles

Artifact: .docs/slice-plans/workflow-profiles.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: e69a4c1
Round: 0
Verdict: PASS

## Summary

Re-review of the in-place revision (diff `cd77a32..e69a4c1`) under the non-expansion
rule: only the three MAJOR and four MINOR findings from the prior evaluation (commit
cd77a32, FAIL) were checked, plus regressions introduced by the diff. All three MAJORs
are resolved. The plan is 107 lines (under 250), keeps `Target size:`, the
`## Out of Scope & Threat-Model Boundary` section and a compact `## Revision Log`, and
was revised in place with no competing sections. Two residual MINOR points remain and
are advisory. No new BLOCKER or MAJOR was introduced.

## Findings

Prior findings:

1. **[MAJOR] Duplicate-key rejection — RESOLVED.** The revision takes the prior
   evaluation's second option: duplicate-key rejection is dropped. Step 1 now states
   that duplicates follow jq last-key-wins behavior, and Step 4 tests that behavior
   rather than rejection. The plan is now executable with jq 1.6+.

2. **[MAJOR] Checkpoint persistence — RESOLVED (residual MINOR below).** Step 3 now
   names the recorded fields (`profile`, `risk` ∈ low/normal/high/null) and puts them
   in untracked per-session state under `.git/loom/`, which is consistent with spec 04
   (high-frequency restart state is per-session, untracked, under the common Git
   directory). It also states resume semantics: read the recorded values, and a
   changed selection requires explicit owner instruction and re-resolution before
   dispatch. This is now testable through the documentation oracle.

3. **[MAJOR] Documentation tests lack oracles — RESOLVED.** Step 4 names the heading
   (`grep -Fxq '## Workflow Profiles'`), the exact `grep -Fq` literals, and a negative
   `grep -Eiq` pattern rejecting "skip … stage/gate/review/evaluation" wording. It
   applies these to both `orchestration.md` and `loom-run/SKILL.md`, and Verification
   repeats this. This meets the "verified mechanically" rubric item.

4. **[MINOR] Strict checkpoints and spec 00 non-goal — RESOLVED.** Strict pauses are
   now "advisory human pauses … not new spec gates or implied owner approval". Context
   now says the configuration records an owner choice and is not a frozen policy
   prescribing reduced workflows before benchmark evidence exists, which addresses the
   spec 00 non-goal.

5. **[MINOR] Helper packaging — PARTIALLY RESOLVED.** Step 3 now instructs
   `chmod +x`, invocation by the resolved absolute installed path, and verifying
   packaging, resolution and inventories, updating any required metadata or fixtures.
   `## Files to touch` still lists none of these. Acceptable because the developer is
   told to verify against the tree and the stop rule covers the rest.

6. **[MINOR] Proportionality — RESOLVED.** `Target size:` now says "<= 250 LOC net
   script/code change; tests and docs separate", and Step 4 asks for table-driven
   cases.

7. **[MINOR] Edge cases and stop rules — RESOLVED.** Exit codes 0/1/2 are given.
   Symlinks are rejected via `[ -f "$file" ] && [ ! -L "$file" ]`. An explicit
   stop-and-escalate instruction was added to the out-of-scope section.
   `scripts/validate-repository.mjs` exists in the tree.

Residual, advisory (do not affect the verdict):

8. **[MINOR] Checkpoint location is still offered as alternatives.** Step 3 says
   `.git/loom/session-<id>/checkpoint` "or" `.git/loom/run.json` "or pass them via
   orchestrator options". An implementer must pick one, and `run.json` looks invented
   rather than taken from spec 04. Pin to the per-session checkpoint and drop the other
   two. The oracle literals mean the tests pass either way, so this does not block.

9. **[MINOR] Negative-grep scope is unspecified.** Step 4 says to reject the pattern
   "in that section", but does not say how the section is extracted (for example
   `sed -n '/^## Workflow Profiles$/,/^## /p'`). The developer should choose and
   document a section-bounded extraction in the Bats helper.

## Required changes for PASS

None. Findings 8 and 9 may be addressed during implementation.

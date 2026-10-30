# Role Governance Guard Code Evaluation

Verdict: FAIL
Round: 0
Reviewed: c3f1c86..2cd3339

## Must Fix

1. **[MAJOR] Landing exception bypasses other runners.** `plugins/loom/hooks/role-governance-guard.sh:126` uses `elif` after detecting `scripts/check`; with `LOOM_ALLOW_ORCHESTRATOR_GATE=1`, `scripts/check && bats tests` exits 0, allowing both commands. The plan permits only the landing gate, not other test runners. Independently evaluate all commands and add a combined-command test.
2. **[MAJOR] Ordinary Git global options bypass evaluator enforcement.** `plugins/loom/hooks/role-governance-guard.sh:133` treats an option as a single word, so `git -C /tmp commit -m x` exits 0 for `code-evaluator`: the option's argument prevents matching the mutation. This is a normal Git invocation, not hostile shell evasion, and defeats the required evaluator mutation guard. Handle value-taking global options and test them.
3. **[MAJOR] Quoted executable words bypass the guard.** `plugins/loom/hooks/role-governance-guard.sh:115` deletes quoted segments instead of dequoting command words. For example, `'bats' tests` exits 0 for the orchestrator, and `git 'commit' -m x` similarly escapes evaluator enforcement. Preserve quoted leading words while ignoring quoted arguments and add coverage.

## Verification

Reviewed the complete diff and plan steps against specs 02, 04, and 08 and the code evaluation rubric. Hook ordering jq check passed, fixture count remains 48, and launcher includes both role environment declarations. The test suite exercises the documented basic cases but misses the combinations above. No local review findings artifact was supplied. Repository gate rerun result is recorded below.

Gate rerun: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` completed with “All checks passed” (541 Bats cases); recorded implementation evidence agrees with this run.

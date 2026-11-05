# Evaluation: herdr-surface-retirement

Verdict: PASS
Round: 3
Commit: fd93361
Reviewed against: `.docs/slice-plans/herdr-surface-retirement.md`, ADR 0031 §7, specs 07 (Host surfaces), 08 (hook wire) and 10 (no Herdr root), the code-eval rubric, `severity.md`, and `.docs/evaluations/herdr-surface-retirement-review-findings.md`. Diff: `origin/main` (0048036) to fd93361 (implementation commits 7591c90, 8e2fe2b, 1b46726, cb5e46d, fd93361).

## Summary

PASS (code review; BLOCKER: 0, MAJOR: 0, MINOR: 1). The diff retires every ADR 0031 §7 Herdr plugin surface the plan names, adds no capability, and leaves the v0.2.0 evidence and the Claude and Codex bindings and fixtures byte-identical. The gate was rerun on the candidate and is green. Round stays 3: this is the first code-phase verdict, the running count for this artifact is 3 (plan-phase FAILs at rounds 1 and 2, PASS at round 3), and a PASS does not increment it.

## Required changes

None.

## Findings

- [MINOR] (adjudicated TST-1, confirmed) `plugins/loom/schemas/loom-role-launch-v1.schema.json:18,44,73`: no Bats test fails if `herdr` is put back into an `authorClient` enum. The schema test at `plugins/loom/bin/loom-launch-role.bats:802` validates emitted descriptors against the schema, which only checks that they conform. The new grep test in `repository-validation.bats` matches only `HERDR_PLUGIN_ROOT|herdr-plugin`. The plan's Step 8 does not require such a test, and acceptance check 1 (`rg -i herdr plugins/loom/schemas`) catches it at review time. A later slice could widen the repository-validation grep to case-insensitive `herdr` across the schemas. This does not block.

## Review-findings adjudication

- Aggregate `ran-with-findings` (loom-local-review/v1, head fd93361). The correctness and security finders were clean. This review agrees: hook client selection keeps the rule of exactly one valid root and otherwise fails closed. After the change, `n == 1` with Codex invalid can only mean Claude, so dropping `claude_ok` is sound. The `claude | *)` adapter arm and the `hooks.json` fallback `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}` are correct, and a lone `HERDR_PLUGIN_ROOT` now fails closed in all three hooks, as tested.
- TST-1 (proposed NIT, conf 0.35): confirmed. Recorded above as [MINOR] (non-blocking). Severity is mapped under `severity.md` as test-coverage hygiene beyond what the plan requires.

## Mechanical checks

- Gate: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` on fd93361 exited 0 with "All checks passed", plan `1..901`, and 0 `not ok`. No dogfood rerun was needed.
- Bats count 931 to 901 (-30), reconciled from the per-file `@test` counts in `origin/main..HEAD`: `herdr-verification.bats` -16 (deleted), `loom-resolve-helper.bats` -7, `git-identity-guard.bats` -7, `loom-launch-role.bats` -3, `precompact-write-ahead-backstop.bats` -3, `role-governance-guard.bats` +1, `repository-validation.bats` +5. Every removed test either covered Herdr only or is covered elsewhere, as mapped in the 8e2fe2b commit body. Spot checks confirmed that the covering tests exist: role-governance "evaluators block git mutation" and "code-evaluator allows read-only inspection", identity BLOCK B01 and ALLOW A01, the Claude/Codex ambiguous-root tests in all three hook suites (role-governance newly ported), the `claude:` resolver negatives, and the ported skills and `hooks.json` checks. No Claude or Codex test was weakened.
- Acceptance 1: the `rg -i herdr` scope search returns nothing (rc 1).
- Acceptance 2: the `HERDR_PLUGIN_ROOT|herdr-plugin` search returns nothing (rc 1), and none of the Step 1 paths exists.
- Acceptance 3: `hook-wire-v1` has the directories `claude` and `codex`, 12 `.exit` files and 48 files. `git diff origin/main..HEAD` on the claude and codex fixture directories is empty.
- Acceptance 4: `git diff --stat` on the v0.2.0 matrix, the v0.2.0 fixtures and the Claude/Codex root bindings is empty.
- Acceptance 5: the jq matrix check prints `true` (exit 0), and `node scripts/validate-repository.mjs --all` passes. No slice 2 code file is present.
- Re-pin: the sha256 of `loom-installed-root-binding-v1.schema.json` is `d3c508a7…512c` and matches `scripts/check-toolchain.json`. Nothing else in that file changed.
- Scope: `scripts/validation/relative-link-allowlist.txt` and the `.docs/` Herdr history are untouched. The `CLAUDE.md` hook line (12 cases / 48 files, both clients) matches Step 9 and stays a one-line pointer. The `.docs/slice-plans/README.md` index and the status docs are left for the finalize pass and the orchestrator, as Step 9 directs.

## Prior Rounds Summary

Plan phase: round 1 FAIL (3e04b23), round 2 FAIL (b52467b), round 3 PASS (1c7b0ef). The retire-first plan revision records are archived under `.docs/slice-plans/archive/evaluations-retire-first/`.

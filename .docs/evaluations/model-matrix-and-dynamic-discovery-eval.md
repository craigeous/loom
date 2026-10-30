# Code Evaluation: model-matrix-and-dynamic-discovery

Verdict: PASS
Round: 1

Reviewed commit: `77d6898` (diff against its parent), against the implemented slice plan, specs 08 and 10, accepted ADR 0027, and the code evaluation rubric and severity policy. No review-findings artifact was supplied or found.

## Round 0 Must Fix (resolved)

- [BLOCKER] ADR 0027 §3 requires ambient `model_reasoning_effort` to be honored absent an override. The Codex path in `plugins/loom/bin/loom-launch-role` reads only the ambient model and takes effort directly from the matrix when the flag and repository value are absent (lines 509–514). For example, a planner configured with ambient `high` is launched with `medium`. Parse and validate the ambient effort at the correct precedence, with a test that differs from the profile default. The existing ambient test sets `low` for an Economy role, so cannot detect this defect.
- [BLOCKER] Explicit empty `--model` and `--effort` values are treated as absent (lines 379–393, 490–491), contrary to the plan's fail-closed validation. Running the launcher by absolute path with `antigravity developer --model ''` returned exit 0 and a discovered model. Track whether each flag was supplied and validate its value even when empty; cover both flags.
- [BLOCKER] The new Antigravity schema variant forbids additional top-level properties but omits `authorClient` and `crossFamilyVerified`, which the launcher emits on cross-family evaluator launches. Consequently such emitted launches cannot validate against the schema. Add the emitted fields to the variant and validate actual cross-family output using a JSON Schema validator. The added schema test at lines 783–795 checks required/key sets only, not JSON Schema validation, so it does not satisfy the plan's validation step.

## Verification

The repository gate was rerun in this worker; its result is recorded below. The new tests cover cached discovery, precedence, and several negative cases, but the schema check is not a schema validation and the ambient effort test does not distinguish inheritance from the profile default.

`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: passed, 523 Bats tests; output ended `All checks passed`.

## Round 1 re-evaluation

Reviewed `git diff 77d6898..642157d` against the three frozen Round 0 blockers. Ambient Codex effort now precedes the matrix default and is validated; the regression test uses an effort different from the planner default. Explicit empty model and effort flags now fail validation, with tests for both. The launch schema admits the emitted cross-family fields and actual cross-family outputs are checked with a JSON Schema validator, including a negative control. All three blockers are resolved.

`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: passed, 527 Bats tests; output ended `All checks passed`.

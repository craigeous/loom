# Herdr client adapter code evaluation

Artifact: .docs/slice-plans/herdr-client-adapter.md
Reviewed against: plugins/loom/skills/loom-playbook/references/code-eval-rubric.md
Commit: e358af7
Round: 0
Verdict: FAIL

## Summary

The revision resolves the prior major launcher-verification finding and the minor metadata-coverage finding, but the mandatory full gate fails in repository-validation fixture tests. The supplied review-findings document explicitly disclaims a conforming, isolated local review; it is not valid evidence for landing.

## Findings

- [BLOCKER] `scripts/check` exits 1 at the Bats stage. Numerous `scripts/tests/repository-validation.bats` cases fail, including the valid metadata fixture (test 717), conforming packaging fixture (858), and valid docs-state fixture (869). The revision adds unconditional Herdr metadata reads in `validateHerdrMetadata` without updating the existing validator fixtures; update the fixtures and any affected assertions for the new required inputs and rerun the full gate. A red gate is an automatic blocker under the rubric.

## Prior findings and review adjudication

- R1 / prior MAJOR: resolved. The `2f52d69..e358af7` diff changes all three prescribed launcher commands to absolute paths; all three passed on rerun.
- R2 / prior MINOR: resolved for the reported gap. The revision reads and validates both Herdr discovery files and adds them to claim surfaces; live repository validation passes. The full gate regression above remains.
- The supplied R1 and R2 claims are confirmed to that extent. The artifact expressly says no cold finders ran and it is not `loom-local-review/v1`; it cannot substitute for the required validated review package or establish landing readiness.

## Verification

- `node scripts/validate-repository.mjs --root . --all`: passed, snapshot checks only.
- Specified Bash 5 targeted Bats: 140/140 passed.
- Matrix floor and root binding checks, all three absolute-path launcher checks, and the invalid-root negative assertion passed.
- `scripts/check`: failed in Bats (exit 1), with numerous repository-validation fixture failures. Formatting, lint, and syntax stages completed before Bats.

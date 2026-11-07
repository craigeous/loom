# Code Evaluation: release-conformance-and-evidence-schema

Artifact: [release-conformance-and-evidence-schema](../slice-plans/archive/release-conformance-and-evidence-schema.md)
Commit: 8845343
Round: 2
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [spec-10-07-release-evidence-amendment](../slice-plans/spec-10-07-release-evidence-amendment.md), [spec 10](../spec/10-packaging.md), [spec 07](../spec/07-command-surface.md), and [code-eval rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md).

## Summary

The implementation conflicts with the approved correction-record invariant and omits required plan verification and scope controls. The sibling amendment passed cold plan evaluation; its added spec lines match the implementation. The review is round 2 following plan evaluation, not a re-review of a previous code evaluation. Repository `--all` validation passes. The requested HEAD gate `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` passed, including all 937 Bats tests and all remaining checks; it selected Homebrew Bash 5.3.9, not the macOS Bash 3.2 floor.

## Findings

- [BLOCKER] Spec 10 requires repository validation of correction record names, predecessor hashes, an unbroken chain, and unchanged candidate (`.docs/spec/10-packaging.md:297`–305). `scripts/validate-repository.mjs:384` validates only `v0.2.0.json`; line 1046 rejects every correction as an unexpected nested path, and the schema has no `supersedes` property. Thus a spec-permitted correction cannot pass, and the required chain validation is absent. The implementation plan instead explicitly permits only the original path, so resolve that conflict through the planner and cold plan evaluation before implementing and testing the approved behavior.
- [BLOCKER] The plan's 300 net LOC limit and explicit required split are exceeded: the complete diff is +697/−88, net +609 lines, and even excluding both spec files remains over 300. CI lane retirement remains in this slice rather than the required sibling. Resolve the plan's size/split requirement through the prescribed workflow.
- [MAJOR] The required valid-fixture `--all` test does not assert success (`scripts/tests/repository-validation.bats:2837`); it only checks absence of one diagnostic. A different validation error can make `--all` fail while the test passes. Assert exit 0 for a valid fixture in a fully valid test root. This confirms advisory TST-2.
- [MAJOR] The plan requires the developer to record the Bash 5.x candidate gate version and result in `progress.md`; no such record exists in the implementation commit. Supply the candidate-bound run and required record; a later HEAD rerun alone does not establish the required evidence at 8845343.
- [MINOR] Advisory TST-1 is confirmed: record-versus-matrix checks lack focused negative tests. The fixed per-harness schema already checks client, floor, entry and binding, but matrix drift should also be tested so these semantic checks cannot silently disappear.

Advisory findings adjudicated: COR-3 is rejected because the sibling amendment was approved through cold plan evaluation and its Context authorizes landing its matching normative text with the implementation. COR-2 is rejected: the approved amendment's verification procedure explicitly requires file-only tar members and gives a construction example; directory members are outside that archive procedure. COR-1 is rejected: the matrix is independently required and validated in metadata mode, and `readJson` reports a missing required path, so absence does not silently pass validation. TST-2 and TST-1 are addressed above.

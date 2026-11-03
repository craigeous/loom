Verdict: FAIL
Round: 1

## Required changes

- [BLOCKER] `.docs/slice-plans/dogfood-int-race.md:68`–77: The runnable Bats commands omit the required `LOOM_TEST_BASH` and `LOOM_EXPECTED_BASH_VERSION` environment variables. In a clean environment the exact targeted command fails in `setup_file`, before exercising the test; the neighbor command has the same defect. Specify a concrete supported interpreter and matching version, or use `scripts/run-bats-under` with its required arguments, for all repeat, mutation and neighbor checks. Evidence: `TMPDIR=/private/tmp bats --filter 'INT during a mutation yields exit 130' scripts/tests/macos-dual-client-dogfood.bats` exits 1 at `scripts/tests/macos-dual-client-dogfood.bats:17` with `LOOM_TEST_BASH is required`.
- [BLOCKER] `.docs/slice-plans/dogfood-int-race.md:29,64`: Requiring the entire existing Bats file to be shfmt-clean conflicts with changing only the INT test. `shfmt -i 4 -d scripts/tests/macos-dual-client-dogfood.bats` exits 1 and reports pre-existing differences outside that test, including lines 516 and 529. Scope formatting verification to the changed code or otherwise reconcile the restriction.

## Mechanical checks

- `git show f6e51e0 -- .docs/slice-plans/dogfood-int-race.md` confirms the reviewed artifact. `git show f6e51e0:.docs/slice-plans/dogfood-int-race.md | wc -l` reports 88; status is Plan Review and target is <=15 net LOC.
- `rg -n 'INT during a mutation|kill -INT|status.*130|READY_FILE|CONTINUE_FILE' scripts/tests/macos-dual-client-dogfood.bats` identifies the exact test at line 378, the existing 130 assertion, and the stub handshake. The plan names it approximately at line 389. The proposed ready-file poll is bounded at 200 iterations; the stub itself has a 10-second deadline. The proposed assertion remains 130.
- Plan lines 68–78 specify 20 repeats, a signal-removal mutation and the exact gate `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`; the standalone commands need correction above. The mutation procedure states the expected failure but does not give a complete executable mutation command.
- Read ADR 0024, ADR 0033 and the Herdr retirement plan: no accepted ADR requirement is violated by the scoped test fix. The gate was not run because this is a plan review and no implementation exists.

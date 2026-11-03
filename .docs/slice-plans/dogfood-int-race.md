# Deflake the Dogfood INT Test: Replace the Fixed Sleep with a Readiness Signal

Status: Plan Review
Target specs: none (test-only change); gate per 08-playbook.md
Authority: ADR 0033 (Accepted order: `herdr-surface-retirement` lands first, then `dogfood-retirement`); owner decision to fix this race in its own slice before the Herdr retirement gate runs
Target size: <= 15 LOC net change in one file (`scripts/tests/macos-dual-client-dogfood.bats`); keep this plan <= 250 lines

## Context

`scripts/tests/macos-dual-client-dogfood.bats`, test "INT during a mutation yields exit
130" (about line 389), starts `__mutation` in the background with
`LOOM_DOGFOOD_STUB_SLEEP=3`, runs `sleep 0.5`, then `kill -INT "$pid"` and asserts the
exit status is 130. The `0.5` is a guess that the harness has installed its INT trap
(`scripts/macos-dual-client-dogfood:1795`) and is inside a foreground step. On a loaded
host the signal can land first, so the status is not 130 and `herdr-surface-retirement`'s
gate fails spuriously. This slice removes the timing dependency.

The stub (`make_stub_client`, line 49–56) already supports a handshake used by other
tests: with `LOOM_DOGFOOD_STUB_READY_FILE` and `LOOM_DOGFOOD_STUB_CONTINUE_FILE` set it
creates the ready file, then blocks (bounded, 10 s) until the continue file exists. The
stub is a child of the harness, so the ready file exists only after the harness trap is
installed and a foreground mutation step is running: exactly the state the test needs.

## Out of Scope & Threat-Model Boundary

- Only the one INT test changes. The TERM test (line ~397) has the same `sleep 0.5`
  pattern but is **not** in this slice (owner scoped it to the INT race); record it in
  `## Notes` as a follow-up if its flake is observed.
- No change to the harness, the stub, the expected exit code (130), or any other test.
  The test is neither weakened nor deleted: it still sends a real SIGINT to a live
  mutation and requires exactly 130.
- Test-only; no spec or ADR text changes. Non-goals per `.docs/spec/00-overview.md`
  `## Non-goals` apply (no hostile-local-process hardening of the test harness).

## Steps

1. In the INT test, drop `LOOM_DOGFOOD_STUB_SLEEP=3` and set the handshake instead:

   ```bash
   ready_file="$STUB_DIR/int.ready"
   continue_file="$STUB_DIR/int.continue"
   set -m
   LOOM_DOGFOOD_STUB_READY_FILE="$ready_file" LOOM_DOGFOOD_STUB_CONTINUE_FILE="$continue_file" \
       "$LOOM_TEST_BASH" "$HARNESS" __mutation "$RUN_ROOT" claude-install claude install &
   pid=$!
   set +m
   for _ in $(seq 1 200); do
       [ -f "$ready_file" ] && break
       sleep 0.05
   done
   [ -f "$ready_file" ]        # bounded: 10 s, then the test fails loudly
   kill -INT "$pid"
   : >"$continue_file"         # let the stub finish so the deferred trap runs promptly
   status=0
   wait "$pid" || status=$?
   [ "$status" -eq 130 ]
   ```

   Rationale for creating `continue_file` after the kill: the harness defers the trap
   until the foreground step ends (`macos-dual-client-dogfood:1789`); without it the
   stub would wait its full 10 s.
2. Delete the `sleep 0.5` in the INT test only. Leave the `set -m`/`set +m` job-control
   comment and block as is.
3. Run `shfmt -i 4 -d` and `shellcheck -s bash` on the file; keep both clean.

## Verification

- Targeted repeat (20 runs, all must pass):
  `for i in $(seq 1 20); do TMPDIR=/private/tmp bats --filter 'INT during a mutation yields exit 130' scripts/tests/macos-dual-client-dogfood.bats || exit 1; done`
- Load check: repeat the 20-run loop once while a CPU-bound background load is running
  (e.g. `yes >/dev/null` x4, then kill); all 20 must pass.
- Mutation check (developer runs, then reverts; record both outputs in the handoff):
  delete the line `kill -INT "$pid"` in the INT test. The harness then runs to completion
  and returns 0 (or the stub waits for the continue file and exits normally), so
  `[ "$status" -eq 130 ]` must FAIL. Confirm the filtered run fails with that
  assertion, restore the line, and confirm it passes again.
- Neighbor regression: `TMPDIR=/private/tmp bats --filter 'TERM during a mutation' scripts/tests/macos-dual-client-dogfood.bats` still passes unchanged.
- Gate on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.

## Notes

(none)

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

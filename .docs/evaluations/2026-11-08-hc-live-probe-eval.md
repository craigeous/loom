# Code Evaluation: hc-live-probe

Artifact: [hc-live-probe](../slice-plans/hc-live-probe.md)
Commit: f3c6c71
Round: 4
Verdict: FAIL
Reviewed against: [ADR 0031](../ADR/0031-herdr-as-an-hc-driven-client.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [hc-live-probe slice plan](../slice-plans/hc-live-probe.md), [spec 07](../spec/07-command-surface.md), [spec 08](../spec/08-playbook.md), and [code-eval rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md).

## Summary

Round 3's collision issue is resolved: P1 failures abort before launch, and cleanup only iterates over names added to LAUNCHED. P4, P5 and both P6 checks now require successful command exits. P2 requires exit 0 and rejects first_message, but the new address validation still accepts multiline non-address output. Cleanup now records commands and results and handles an INT during a running probe, but the prior cleanup-interruption and exact-argv coverage findings remain unresolved. The local review reported ran-clean, with no candidate findings to adjudicate.

The requested Bash 3.2 runtime canary and slice tests passed (20/20); shfmt and shellcheck passed. The script and tests total 257 lines, within the 260-line budget. These passing checks do not resolve the findings below. No live hc run was performed.

## Findings

1. **MAJOR — P2 accepts output that is not a single address.** In `scripts/hc-live-probe:120,137`, grep matches any individual line, so a successful command producing `t1` followed by `error diagnostic` passes the address check. `_cmd` combines stdout and stderr, so extra diagnostic lines can be accepted as evidence. Require the complete output to be exactly one valid address, and test multiline output for both launches.

2. **MAJOR — Cleanup remains interruptible and the required exact argv test is absent.** `scripts/hc-live-probe:65` resets INT and TERM to their default dispositions before cleanup; a signal during kill, rm, or get can terminate the probe with remaining terminals and no final result. In `scripts/tests/hc-live-probe.bats:54-61`, the exact sequence test compares only verbs and two partial substrings; it does not check full argument boundaries, both model selectors, names, timeouts, prompts, or cleanup arguments. Protect cleanup from repeated signals (`trap '' INT TERM`) while retaining an interrupted verdict, and add deterministic tests for cleanup interruption and full ordered argv.

3. **MAJOR — Blocked get failures are no longer recognized.** The new exit-zero short circuits at `scripts/hc-live-probe:128,146` prevent `_check_get_json` from executing for exit 9, making its explicit blocked detection at line 98 unreachable for that exit. Detect blocked independently of the success requirement, while still requiring exit 0 for P4/P6 success, and cover a blocked nonzero get in the stub tests.

## Prior Rounds Summary

Round 3 code evaluation failed on terminal cleanup scope after absence failure, validation of command exit codes before judging evidence, and cleanup/signal test coverage. The collision and exit-code checks were addressed in commit f3c6c71; address validation and cleanup/sequence coverage remain incomplete, and the revised get checks introduce a blocked-classification regression.

# Code Evaluation: hc-live-probe

Artifact: [hc-live-probe](../slice-plans/hc-live-probe.md)
Commit: 9a6dfb2
Round: 3
Verdict: FAIL
Reviewed against: [ADR 0031](../ADR/0031-herdr-as-an-hc-driven-client.md), [ADR 0034](../ADR/0034-admit-antigravity-orca-and-herdr-to-v0.3-scope.md), [hc-live-probe slice plan](../slice-plans/hc-live-probe.md), [spec 07](../spec/07-command-surface.md), [spec 08](../spec/08-playbook.md), and [code-eval rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md).

## Summary

The implementation follows the intended command outline, uses the specified model and prompts, inspects `status.state`, writes ordinary command output and exit codes to evidence, and has normal-path P1–P7 checks and BLOCKED handling. It does not establish all criteria reliably, and cleanup can affect pre-existing terminals. These findings block a PASS. The local review is recorded as `ran-clean`; independent inspection found the issues below despite that result.

The script and tests add 162 and 95 lines respectively, totaling 257, within the 260 LOC budget. The requested shfmt and shellcheck commands passed. The six offline Bats tests use a stub and passed under Bash 3.2.57; they do not require a network or daemon. The requested gate rerun passed all 269 tests under Bash 3.2.57 (exit 0). No live probe was run; a generic probe result would not establish role support or release conformance.

## Findings

1. **HIGH — Existing terminals can be killed and removed after the absence check fails.** `scripts/hc-live-probe:97-104` records P1 failure but still sets `LAUNCHED=1` and attempts both runs; lines 137–146 then kill and remove both names regardless of whether they were already present or successfully created by this invocation. The EXIT trap likewise cleans both names. A name collision or failed/ambiguous `get` can therefore destroy an unrelated terminal. Stop before launching when absence is not established, and restrict cleanup to terminals safely attributable to this invocation, including interrupted launches.

2. **MAJOR — Failed or non-address output can produce false evidence of success.** `_cmd` combines stderr and stdout (lines 68–76); P2 accepts any nonempty output as an address (lines 104–105, 120–122), while P4–P6 judge output without requiring successful `get` or `read` exits (lines 111–117, 128–133). For example, a failing read that emits `42` or `TOOL_ABSENT` on stderr can satisfy the relevant criterion, and arbitrary successful run output is accepted as an address. Validate command success and the actual address shape before judging evidence, keeping diagnostics distinct from data.

3. **MAJOR — Cleanup and signal coverage do not meet the plan.** The normal cleanup marks itself complete before attempting cleanup, and the trap silently discards all cleanup results and evidence (lines 48–64, 137–146); interruption during cleanup can leave terminals without a retry or P7 evidence. The signal test sends INT to the stub's own process, not the probe, and merely finds kill/rm in its log, which normal cleanup also produces. The supposed exact-sequence test checks a permissive token allowlist, not order or both full invocations. Add assertions for actual probe interruption, cleanup outcomes and exact argv sequence, as well as collision and failed-command cases.

## Prior Rounds Summary

Rounds 1-3 plan evaluations refined criteria P1-P7, status.state usage, and matrix ownership. This is Round 3 of the artifact evaluation sequence.

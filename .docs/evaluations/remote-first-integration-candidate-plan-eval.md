# Evaluation: remote-first-integration-candidate (slice-plan)

Verdict: FAIL
Round: 0
Reviewed against: ADR 0020; repository-improvement-plan.md (slice `remote-first-integration-candidate`); specs 00-overview (Non-goals), 03-artifact-lifecycle, 04-orchestrator; plan-eval-rubric.md; severity.md; `loom-coord` lock_acquire / lock_verify_self / lock_release_if_self and subcommands (lock-acquire, lock-verify, lock-release, release-claim); templates/evaluation.md

## Findings

- [MAJOR] Durable state interfaces are unspecified — Steps 3, 5, 6. The plan requires a "durable coordinator-state receipt", "durable candidate state" and recovery that reconstructs the receipt, but never names where each lives, its format, or how the receipt is written atomically. It also never says who supplies the "applicable integrated gate" command or the review-evidence format that Step 1 calls "explicit inputs". Two independent implementers could choose incompatible locations and formats, and Step 6 recovery and the receipt-field tests cannot be written without them.
- [MINOR] Exit codes are incomplete — Step 1 lists 0/1/3/5/10 only. Retry exhaustion (Step 4), "stop for owner action" (Step 6), and a lock lost after push (Step 5) have no stated code. 3 for exhaustion and 10 for the others are the natural mapping; state it.
- [MINOR] Size budget looks optimistic — `Target size: <= 200 LOC net` for a helper covering fetch, worktree, manifest, gate, locking, push, verify, receipt, recovery and cleanup, plus a bats suite with about 20 scenarios in Verification. Confirm whether the bats file counts toward the budget, and trim Verification to the cases that guard distinct failure modes.
- [MINOR] Step 5 verifies lock ownership before `release-claim`, but does not say what happens if ownership is lost between a verified push and the receipt. Step 6 recovery presumably covers it; say so in one clause.

## Required changes (for FAIL)

1. In Steps 1/3/5, name the durable location and format for the candidate state and the receipt. Reuse the existing per-session coordinator-state directory and the write-temp-then-rename idiom. Also name how the gate command and review evidence are supplied, for example as explicit input flags or a file path. Keep it to a sentence or two each.

## Notes

Verified, with no defects found:
- **Structure and size:** The plan follows the slice-plan template, with Target size, an explicit Out of Scope & Threat-Model Boundary, a Revision Log, and 92 lines (well under 250).
- **Scope:** Single-purpose, remote-direct only. No spec or ADR edits.
- **Threat model:** The boundary matches spec 00 Non-goals.
- **Fail-closed behavior:** The plan requires an absolute-path invocation, pre-mutation validation, and claim preservation on every nonzero exit.
- **Lock semantics:** The plan uses `lock-acquire`, `lock-verify` before each mutation, and release only if owned. This matches `lock_acquire` (0/3/10), `lock_verify_self` (0/5/10) and `lock_release_if_self`.
- **Landing flow:** The plan re-fetches under the lock and rebuilds on movement. It uses a non-force push with independent remote verification, and writes the receipt before `release-claim`.
- **Recovery:** The plan recovers without republishing, and treats the mirror update as non-authoritative. All of this is consistent with ADR 0020 §1–3 and the improvement plan.
- **Verification:** Named commands and tests cover the acceptance criteria.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | First review; one MAJOR (state/receipt/input interfaces unspecified), three MINORs. |

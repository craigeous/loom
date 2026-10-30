# Remote-first Integration Candidate

Status: Plan Review
Target specs: 00-overview.md, 03-artifact-lifecycle.md, 04-orchestrator.md; ADR 0020
Target size: <= 250 LOC for the `loom-land` implementation, excluding the test suite (keep this plan document <= 250 lines)

## Context

ADR 0020 makes the configured remote target the landing authority. This slice
constructs and publishes one reviewed slice against that target without importing
local main. Final tracked evidence is prospective until remote verification and a
receipt establish Landed; failed or unverifiable publication retains the claim.

## Out of Scope & Threat-Model Boundary

Only remote-direct is supported; PR and queue adapters, cross-clone claim exclusion,
changes to frozen specs, and workflow wiring are separate work. The remote push
prevents overwrites across clones but does not prevent duplicate work. As in spec
00 Non-goals, this is not a hostile-code sandbox: private coordinator state and
trusted local executables are assumed; hostile inode swaps and helper monkeypatching
are outside the boundary. Never force-push or silently switch modes.

## Steps

1. Add executable `plugins/loom/bin/loom-land`, Bash 3.2 compatible with
   `set -euo pipefail`; require invocation by absolute path. Define and validate
   explicit inputs for repository, configured remote, full `refs/heads/...` target,
   remote-direct mode, slice and session IDs, immutable slice head, finalization
   inputs, `--gate <cmd>` (default `scripts/check`), and `--evidence <path>`
   (a JSON manifest containing review evidence hashes). Reject malformed inputs, unsupported modes,
   missing tools or evidence, and non-ready slices before mutation. Document its
   invocation and exit codes in its usage: 0 verified success, 1 usage error,
   3 contention or retry exhaustion, 5 ownership failure, 10 operational or
   unverifiable failure (including stop for owner action); every
   nonzero result preserves claim and recovery evidence.
2. Fetch the configured target into an isolated ref and resolve its exact commit.
   Create a uniquely named disposable branch and worktree at that SHA, integrating
   only the specified slice head. Fail on conflicts; never consult local main. In
   that worktree prepare the slice candidate manifest and final tracked plan,
   evaluation, archive, index and living-status changes, then commit them. The
   tracked manifest binds slice/session, remote/ref/mode, slice head and initial
   base and evidence inputs; do not embed its own candidate SHA in its commit.
3. Run the applicable integrated gate and review/evaluation checks against the
   exact committed candidate, recording candidate SHA and evidence hashes outside
   the candidate. Reject a dirty or changed candidate after checks. Build, finalize
   and check outside the lock. Write candidate state as JSON at `<git-dir>/loom/session-<sid>/candidate.json`,
   atomically via a temporary file and `mv`; include the candidate SHA, inputs and
   evidence hashes needed for recovery. Preserve it on failure; do not mistake candidate Landed text for publication.
4. Use `loom-coord lock-acquire` for the session, then `lock-verify` before each
   protected mutation and `lock-release` on every exit only if owned. Re-fetch
   and compare the exact target under the lock. If moved, release it, discard the
   disposable candidate and rebuild from the new base, repeating all affected
   gate and review checks. Bound retries and return recoverable failure on exhaustion.
   A lost or expired lock stops publication; never release another session's lock.
5. Under the lock push the candidate SHA to the full target ref with ordinary
   non-force push; verify independently with a fresh remote ref read that equals
   the candidate SHA. A rejected push or uncertain verification is not success.
   After verification write a JSON receipt at
   `<git-dir>/loom/session-<sid>/publication-receipt.json` atomically via a
   temporary file and `mv`,
   binding slice/session, remote/ref/mode, slice head, initial and final bases,
   candidate/result SHA, gate and review hashes, helper/protocol version, push and
   verification outcomes. Lock loss between verified push and receipt enters Step 6
   recovery without republishing. Verify lock ownership and use `release-claim` only after
   the receipt; then release lock and idempotently clean the disposable worktree
   and branch. A clean local mirror may fast-forward after success; its failure
   does not change publication outcome.
6. Recovery must inspect durable candidate state and fresh remote truth: if a
   prior push may have succeeded, verify the candidate is contained in the target,
   reconstruct the receipt and finish claim release/cleanup without republishing;
   if containment or evidence cannot be proved, stop for owner action. Preserve
   candidate and claim on network, protection, gate, review or receipt failure.
   Handle interruption at each post-push boundary without falsely reporting Landed.
7. Add `plugins/loom/bin/loom-land.bats` with isolated bare remotes and temporary
   clones/worktrees. Exercise the contract and failures below, including controlled
   races and injected failures; do not use a real remote.

## Verification

Run `bats plugins/loom/bin/loom-land.bats` for targeted iteration and `scripts/check`
for the full repository gate. Tests prove dirty/ahead/stale local main and unrelated
local commits cannot enter the candidate; final evidence and code arrive together;
absolute-path and input/mode validation fail closed; conflicts, gate/review failure,
lock contention/loss, target movement and non-fast-forward race preserve the claim.
Prove rebuild and recheck on movement, no force push, independent verification,
receipt fields and ordering, failure after push followed by recovery without a second
push, idempotent cleanup, and mirror-update failure after verified success. Exercise
same-clone and separate-clone races and Bash 3.2 compatibility through the full gate.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Specify durable JSON state, inputs, exit codes, size budget and post-push recovery. |

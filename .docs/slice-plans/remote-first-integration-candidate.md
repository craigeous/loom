# Remote-first Integration Candidate

Status: In Progress
Target specs: 00-overview.md, 03-artifact-lifecycle.md, 04-orchestrator.md; ADR 0020
Target size: <= 250 LOC for the `loom-land` implementation, excluding the test suite (keep this plan document <= 250 lines)

## Context

ADR 0020 makes the configured remote target the landing authority. This slice
constructs and publishes one reviewed slice against that target without importing
local main. Final tracked evidence is prospective until remote verification and a
receipt establish Landed; failed or unverifiable publication retains the claim. Candidate
review is bound to the exact commit SHA before publication.

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
   remote-direct mode, slice and session IDs, immutable slice head, `--gate <cmd>` (default `scripts/check`), and `--evidence <path>`
   (the JSON evidence object specified in Notes), and `--candidate-only`. Evidence is
   required for publication, but not candidate-only preparation. Validate its schema,
   candidate SHA, nonempty gate
   matching the effective `--gate`, and both 64-character hexadecimal SHA-256 fields. Reject malformed inputs, unsupported modes,
   missing tools or required evidence before mutation. Require `--head` to resolve to a
   commit with `git rev-parse --verify --quiet "<head>^{commit}"` and the calling
   session to hold the active slice claim, verified by `loom-coord verify-claim
   --session <sid> --slice <slice>` (or the claim ref). For publication also require
   valid `loom-evidence/v1` evidence whose `candidateSha` matches the candidate.
   Document its
   invocation and exit codes in its usage: 0 verified success, 1 usage error,
   3 contention or retry exhaustion, 5 ownership failure, 10 operational or
   unverifiable failure (including stop for owner action); every
   nonzero result preserves claim and recovery evidence.
2. Fetch the configured target into an isolated ref and resolve its exact commit.
   Create a uniquely named disposable branch and worktree at that SHA, integrating
   only the specified slice head. Fail on conflicts; never consult local main. Code and slice-level documentation already committed at `--head` (including
   prepared evaluations and archived plans) enter by the standard git merge. Do
   not invent transformations for plans, evaluations, archives, indexes or living
   status: any such changes must already be committed on the slice branch. Commit
   `.loom/candidate-manifest.json` binding slice/session, remote/ref/mode, slice
   head and base commit; do not embed its own candidate SHA or evidence hashes, which
   are supplied after review. Preserve and reuse the exact candidate commit on the
   subsequent invocation when its inputs and fetched base still match candidate state.
3. Run the specified gate against the exact committed candidate, recording candidate
   SHA and any supplied evidence hashes outside the candidate. For publication, validate
   `evidence.candidateSha` equals the exact candidate SHA; mismatch fails closed.
   `--candidate-only` builds the worktree, runs the gate, outputs the candidate SHA,
   writes candidate state and returns without publication or requiring evidence. The hashes are opaque
   caller-supplied bindings: their syntax is validated, but they do not prove review
   content or authorize an invented review command. Reject a dirty or changed candidate after checks. Build, finalize
   and check outside the lock. Write candidate state as JSON at `<git-dir>/loom/session-<sid>/candidate.json`,
   atomically via a temporary file and `mv`; include the candidate SHA, inputs and
   evidence hashes needed for recovery. Preserve it on failure; do not mistake candidate Landed text for publication.
4. Use `loom-coord lock-acquire` for the session, then `lock-verify` before each
   protected mutation and `lock-release` on every exit only if owned. Re-fetch
   and compare the exact target under the lock. If moved, rebuild from the new base
   and rerun `--gate` against the rebuilt candidate. A merge conflict exits 3;
   a gate failure exits 10, preserving candidate state. Write the rebuilt candidate
   state to `candidate.json`. If its SHA differs from `evidence.candidateSha`, release
   the lock and exit 3: `contention: target moved, candidate rebuilt at <new_candidate_sha>; fresh review evidence bound to <new_candidate_sha> is required before publication`.
   The caller reviews that SHA, updates evidence with that SHA, and re-invokes the
   helper; reuse the recorded candidate if its inputs and base still match. Bound retries
   and return recoverable failure on exhaustion.
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
Prove candidate-only preparation, exact SHA reuse and evidence mismatch rejection;
prove movement triggers rebuild, gate and exit 3 until newly bound evidence is supplied.
Prove no force push, independent verification,
receipt fields and ordering, failure after push followed by recovery without a second
push, idempotent cleanup, and mirror-update failure after verified success. Exercise
same-clone and separate-clone races and Bash 3.2 compatibility through the full gate.

## Notes

**Implementation question:** What authoritative input and status establish that a
slice is ready before mutation, particularly for `--candidate-only` before the
candidate-specific review? Step 1 requires rejecting non-ready slices but defines
no readiness lookup or check.

**Resolved (Round 4):** Candidate-only readiness requires a valid `--head` commit
object and the calling session's active claim for `--slice`, checked via
`loom-coord verify-claim --session <sid> --slice <slice>` or the claim ref.
Remote-direct publication additionally requires supplied `loom-evidence/v1`
evidence whose `candidateSha` matches the candidate SHA. `loom-land` does not
inspect arbitrary markdown status strings; readiness is defined by commit validity,
claim ownership and evidence matching.

**Implementation question:** How can the helper establish that evidence supplied
after a target move is fresh and applies to the rebuilt candidate? The evidence
schema contains only opaque hashes and the gate command, while the candidate SHA
is created inside the invocation. Please specify the candidate-specific review
handoff and how a subsequent invocation binds that evidence before publication.

**Resolved (Round 3):** `--candidate-only` creates and gates the candidate, prints
its SHA and records `candidate.json` for external review. Publication validates
`evidence.candidateSha` against that exact candidate. On target movement, rebuild
and gate, record the new state, release the lock and exit 3 if the SHA differs; the
orchestrator or caller reviews the new SHA, updates evidence and re-invokes. The
helper is non-interactive and cannot conduct role review autonomously. Candidate
state enables exact commit reuse; evidence stays outside the commit to avoid a
self-referential SHA. The binding identifies the candidate but does not prove that
the opaque review actually occurred.

**Resolved (Round 2):** The explicit finalization input is the committed slice
`--head`: code and slice-level docs, including any prepared evaluations, archived
plans, index and living-status edits, are incorporated by standard git merge. No
generic document transformation is authorized. The tracked candidate manifest binds
the slice/session, remote/ref/mode, slice head and base commit; evidence hashes are recorded outside the candidate.

`--evidence <path>` accepts this JSON object (SHA-256 values are 64 hex digits):

```json
{
  "schema": "loom-evidence/v1",
  "candidateSha": "<sha1>",
  "gate": "<cmd>",
  "gateEvidenceSha256": "<hex>",
  "reviewEvidenceSha256": "<hex>"
}
```

Validate the schema, fields, candidate SHA equality, hash syntax and gate equality with the effective
`--gate`; the file supplies hashes, not review artifacts or a review command, so
hash contents and review execution cannot be independently verified from this
interface. On target movement rebuild from the new base and rerun the gate; conflict
exits 3 and gate failure exits 10 with candidate state preserved. A rebuilt candidate
needs fresh external candidate-specific review evidence before publication; the
caller must supply it, and old hashes alone cannot establish that review occurred.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Specify durable JSON state, inputs, exit codes, size budget and post-push recovery. |
| 2 | Clarify merge inputs, evidence schema and rebuild verification boundaries. |
| 3 / Clarification | Bind evidence to candidate SHA and specify candidate-only and target-movement review handoff. |
| 4 / Clarification | Define readiness by commit validity, claim ownership and candidate-bound publication evidence. |

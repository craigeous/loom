# 04 — Orchestrator

Status: Approved

## Authority

ADRs [0001](../ADR/0001-plugin-architecture-and-orchestrator.md),
[0008](../ADR/0008-parallel-docs-coordination-worktree-per-slice.md),
[0012](../ADR/0012-thin-orchestrator-sonnet-default-bounded-return.md) through
[0018](../ADR/0018-shared-core-and-client-adapters.md), and
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md) through
[0022](../ADR/0022-controlled-input-independent-evaluation.md).

## Identity and adapter boundary

The orchestrator is the owner's top-level interactive session running Loom's run
workflow. It is not a lifecycle role. Claude Code invokes it explicitly as
`/loom:run`; Codex invokes it explicitly as `$loom-run`. Both load the same shared
orchestration contract.

Only this root session delegates. The Claude adapter launches thin native role
agents; the Codex adapter launches generic cold subagents loaded with shared role
contracts. Both enforce non-delegating children. Auxiliary review workers are also
launched by the root but never enter lifecycle-role status routing.

The shared orchestrator uses the Standard capability profile. Claude maps that to
`sonnet`; Codex uses the tested model/reasoning mapping in its compatibility matrix.

## Driver loop

```text
start(scope, claimed_gates, client_adapter)
  validate supported host/client and adapter readiness
  classify/init the repository when needed
  establish or recover session and claims
  loop:
    state := scan statuses + exact commits + coordination refs + receipts
    action := deterministic dispatch within scope
    checkpoint next action before any large/in-window operation
    pause if owner gate or escalation requires it
    launch one cold role, auxiliary finder set, or deterministic helper step
    validate bounded return and committed/recorded handoff
    rescan from files and exact state
  stop at scope boundary with recoverable handoff
```

Files, Git objects, protocol manifests, refs, and remote receipts are truth. Role
conversation is not. Status scans do not ingest artifact bodies; the actor receiving
the path reads its own allowed content.

## Thin-orchestrator invariant

- Pass paths and run identifiers, never artifact/diff bodies.
- Accept only the bounded return contract from lifecycle roles.
- Route on validated status plus one signal, not critique prose.
- Review workers write distinct run outputs; their findings do not enter the
  orchestrator conversation.
- Deterministic helpers export, validate, assemble, record, and publish data; the
  orchestrator does not improvise protocol transforms.
- Before a large operation, write the next action to per-session state. Near the
  configured context threshold (operational default about 60%), restart cold from
  that state. Repeating the same unadvanced action triggers starvation escalation.

The owner-facing `status/handoff.md` is updated only through serialized candidate
finalization; high-frequency restart state is per-session and untracked under the
common Git directory.

## Scope and owner gates

The owner declares a boundary such as research, ADR, plan, implement, one slice, or a
larger roadmap range, and claims either all approval gates or named gates. The
orchestrator chains only within that boundary. It pauses at claimed gates, the scope
boundary, round/starvation/infrastructure escalation, unsupported publication mode,
or an authority-changing ambiguity.

One-off workflows use the same shared contracts but perform one pass and stop; they
must not bypass export, review, recorder, or landing rules applicable to that pass.

## Local review orchestration

For each code-bearing `Implemented` slice, the orchestrator runs the repository-owned
`loom-local-review/v1` protocol through `loom-review` against full `base_sha` and
`head_sha`:

1. Resolve the installed helper through the active adapter and invoke its absolute
   path; `prepare` rejects dirty/ambiguous targets and exports a `.git`-free immutable
   source snapshot plus hashed manifest.
2. Launch cold non-delegating correctness, tests, and security workers against that
   same run. Each has read-only common inputs, its own writable output, no credentials,
   and no network-specific client tools.
3. `validate` recalculates all hashes, source inventory, prompt/protocol versions,
   exact SHAs/diff, finder completeness, and diff-intersecting locations.
4. Only a valid complete run may be `assemble`d into the identity-neutral
   `.docs/evaluations/<slice>-review-findings.md` companion.
5. Preserve the validated evidence through evaluation and publication; `clean` is
   allowed only when required recovery evidence is safely retained.

Preparation, workers, validation, and assembly are network-silent and require no
remote, PR, or external review command. A missing/failed/invalid finder invalidates
the aggregate, never means clean, and blocks evaluation/landing until corrected or
infrastructure is restored. Pure-docs changes record `skipped: docs-only` without a
protocol run. Superseded mechanisms remain documented only in the ADR history.

## Evaluation orchestration

For every plan/research or code evaluation:

1. A deterministic exporter creates a fresh directory outside the managed repository,
   copies only the type-specific allowlist, strips forbidden metadata, rejects unsafe
   links/special files, applies read-only permissions, and writes a manifest hashing
   every input and origin.
2. Current-tree evidence, when required, is a complete sanitized tracked snapshot at
   one `evidence_sha`. Research source evidence is captured before launch with locator,
   retrieval/freshness/provenance, and content hash.
3. The active adapter launches a cold evaluator with only export path, evaluation
   type, and bounded task instruction. Delegation and network-specific tools are
   denied; evaluator writes are confined to output/scratch.
4. A code evaluator must invoke the deterministic gate runner. The runner verifies
   judgment-source hashes, creates and verifies a private writable execution copy,
   runs the pinned gate/environment with prepared offline dependencies, records full
   result evidence, re-verifies immutable source, and discards the copy even on fail.
5. A deterministic recorder rejects missing, duplicate, malformed, truncated,
   cross-run, or hash-mismatched output. It copies one valid verdict to the expected
   `.docs/evaluations/` path and applies the legal status transition; the orchestrator
   commits it author-neutrally.

Prior developer gate evidence never substitutes for the unconditional evaluator gate
rerun. Inability to rerun is invalid/infrastructure-blocked, not “unsupported.” The
orchestrator never grants an evaluator write access to the repository or asks it to
commit.

## Parallel and multi-session work

Each claimed slice uses a session-owned branch/worktree. Independent slices may run
concurrently only when their source and uniquely named artifact path sets are disjoint;
overlapping or dependent slices are sequenced.

Same-clone coordination uses validated state plus Git-ref CAS in the common ref store:

- `refs/loom/lock` protects only short shared coordination/publication sections;
- `refs/loom/claims/<slice>` is the per-slice claim;
- exact-SHA create/value/delete `git update-ref` CAS is required;
- lease freshness is the only cross-session liveness signal;
- a detached session-identity-checked renewer refreshes held leases;
- stale steals are freshness-gated value CAS; release is owner-verified delete CAS;
- every shared-state mutation verifies current lock ownership immediately first; and
- identifiers and computed paths are validated and contained under `.git/loom`.

Role work, review, evaluation, candidate construction, merging, and gates happen
outside the publish lock. Claim acquisition does not write tracked local or remote
target state. Final living docs/index changes exist only in the candidate.

These refs coordinate sessions sharing one common Git directory. They do not exclude
duplicate work across clones. Only a configured remote-claim/provider adapter may make
that stronger claim.

## Remote-first landing

Every initialized repository configures a remote name, full target ref, and one mode:

| Mode | Publication boundary | Support condition |
|---|---|---|
| `remote-direct` | non-force fast-forward target update | required first implementation; unprotected target |
| `pr-per-slice` | provider-confirmed merge of one candidate | only with a conforming configured provider adapter |
| `merge-queue` | queue-confirmed merge result | only with a conforming configured provider adapter |

Mode is never inferred or silently changed. Network loss, credentials, protection, or
adapter failure preserves `Ready to Publish` and its claim.

The landing helper:

1. Fetches the configured target and resolves the exact base SHA.
2. Creates a disposable integration branch/worktree at that SHA; local `main` is not
   consulted as authority.
3. Integrates only the current slice and deterministic finalization artifacts.
4. Runs the integrated gate and all review/evaluation checks affected by integration.
5. Re-fetches immediately before publication. If the target moved, it rebuilds from
   the new SHA and reruns affected checks.
6. Publishes without force using the configured mode while holding the same-clone lock
   only for final compare, publication, fresh verification, and receipt update.
7. Independently reads the remote, verifies the exact result, records the receipt,
   releases the claim, and performs idempotent cleanup.

The receipt binds slice/session, remote/full target ref, mode, slice head, initial and
final bases, candidate/result SHA, gate/review/evaluation evidence hashes,
helper/protocol/product versions, and publication/verification outcome.

A successful command response is not proof. `Landed` exists only after remote
verification and a matching receipt. Local `main` may be fast-forwarded afterward when
clean; failure to do so has no lifecycle effect. Loom never force-pushes.

## Human checkpoints and recovery

On any pause the orchestrator persists the exact pending action, evidence locations,
claim/candidate state, and resume command. Infrastructure failure is detected on
failure, not predicted: it consumes no merits round and stops blind retries. A crash
after remote publication is recovered by fresh remote verification and idempotent
receipt/cleanup; if the exact published result cannot be proven, the owner decides.

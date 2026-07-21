# 04 — Orchestrator

Status: Approved

## Authority

ADRs [0001](../ADR/0001-plugin-architecture-and-orchestrator.md),
[0008](../ADR/0008-parallel-docs-coordination-worktree-per-slice.md),
[0012](../ADR/0012-thin-orchestrator-sonnet-default-bounded-return.md) through
[0018](../ADR/0018-shared-core-and-client-adapters.md), and
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md) through
[0023](../ADR/0023-repository-self-hosting-bootstrap-transition.md).

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

## Repository self-hosting bootstrap orchestration (non-release exception)

The production orchestration sections below remain Loom's v1 contract. ADR 0023 adds
one temporary, non-release bridge for this repository only. Released Loom and every
Loom-managed project always use the production local-review, controlled-input
evaluation, recorder, and landing paths; they cannot select, advertise, or consume
`loom-repository-bootstrap/v1`.

### Eligibility and exact evidence

Before any bootstrap action, including checkpoint resume, the root freshly reads and
validates the protected remote transition branch described below and the configured
target. The state must list the exact separately planned slice and its needed component
as available. The closed set is M0 `ci-baseline` and
`client-floor-adapter-smoke`; M1 `coord-identifier-boundaries`,
`coord-lock-ownership`, and `coord-schema-cas`; M2
`remote-first-integration-candidate` and `coordination-state-separation`; M3
`identity-guard-contract` and `precompact-per-session`; M4 `local-review-helper`,
`local-review-agents`, `local-review-orchestration`, and
`local-review-defect-battery`; and M5 `sanitized-evaluation-workspace` and
`evaluation-output-recorder`. Only ADR 0023's degraded cold ratification evaluation
and a plan evaluation solely authorizing one listed slice receive analogous plan
eligibility. No other artifact, slice, milestone, repository, or workflow is eligible.

### Bootstrap planning-artifact evaluation

Planning-artifact evaluation is a separate path from bootstrap code review and code
evaluation. The path is type-complete for a research note at `Research Review` or an
ADR, spec amendment, or slice-plan at `Plan Review`, but type support does not widen
ADR 0023's closed eligibility: this transition admits only ADR 0023's one-time degraded
ratification and a slice-plan whose sole purpose is to authorize exactly one listed
slice. Research, another ADR, and every spec amendment remain ineligible.

Except for ADR 0023's necessarily pre-acceptance ratification, each new or resumed
planning run first performs the same fresh transition-ref history, protection, phase,
allowlist, component-retirement, and configured-target containment checks required for
code-bearing bootstrap work. The ratification instead binds the proposed ADR commit
and blob, produces the mandatory degraded verdict, and leaves acceptance to the
explicit owner gate; after acceptance, transition-state initialization binds that
accepted ADR commit and blob before any other bootstrap use. A current publication
intent, missing/unverifiable state, absent eligible slice, or terminal sunset blocks a
planning run.

For an eligible planning artifact, the root creates a fresh package outside the
managed checkout and records in its manifest:

1. One normalized repository-relative artifact path, artifact type and review status,
   the full reviewed commit object ID, the artifact's Git blob object ID at that commit,
   and SHA-256 of the supplied artifact bytes.
2. Every type-specific authority and applicable rubric/severity file by normalized
   path, authority role, Git blob object ID, and SHA-256. If the rubric requires
   current-tree evidence, the package also binds one full `evidence_sha`, its tree ID,
   and the complete sanitized tracked-path inventory and hashes. A re-review binds the
   prior verdict and exact artifact-revision diff as additional hashed inputs.
3. A unique run ID, package-manifest SHA-256, creation time, client/launch mechanism,
   evidence mode, and the freshly validated transition-state tip when one exists.

The root materializes only those allowlisted inputs from the recorded objects, makes
them read-only, re-verifies the manifest immediately before launch, and supplies no
producer transcript, producer reasoning, credentials, status history, unrelated
evaluation, or original Git identity/history. It launches one fresh cold,
non-delegating plan evaluator distinct from the artifact author/producer and root. The evaluator
receives only the package path, evaluation type, and bounded instruction; it has no
managed-checkout write path and may write only to its unique confined output and
scratch directories. This planning path has no developer gate, auxiliary code
finders, local-review companion, code evaluator, or gate rerun.

The plan evaluator writes exactly one identity-neutral verdict in its confined output
that echoes the run ID, manifest hash,
artifact path, reviewed commit and blob IDs, all authority/rubric/evidence bindings,
PASS/FAIL, round, findings, and required changes for FAIL. It never commits or changes
status. The root re-verifies input immutability and output confinement, then
mechanically validates eligibility, state tip, schema, uniqueness, completeness, and
every echoed binding. While the `evaluation-recorder` component remains available, the root
copies the one valid verdict to the expected evaluation path, applies only the legal
spec-03 status transition, and commits the verdict and status author-neutrally without
changing the verdict's merits. Retirement of `evaluation-workspace` makes the
production exporter mandatory; retirement of `evaluation-recorder` makes the
production recorder mandatory and reaches the terminal full sunset. Neither may fall
back to this path. ADR 0023's ratification remains at `Plan Review` after evaluator
PASS until the explicit owner acceptance is recorded.

Every planning verdict records:

```text
Evidence mode: loom-repository-bootstrap/v1
Conformance: degraded ADR 0023 bootstrap planning evaluation
Isolation: not established under ADR 0022
```

The ADR 0023 ratification verdict also records
`bootstrap-ratification: degraded`. Missing, duplicate, truncated, malformed,
cross-run, hash-mismatched, out-of-confinement, unrecordable, or otherwise invalid
input/output is infrastructure-blocked, never PASS or a merits FAIL; it causes no
status advance or round consumption. A retry may reuse only hash-identical inputs;
otherwise the root creates a wholly new run.

### Code-bearing evidence, auxiliary review, evaluation, and recording

The existing code-bearing bootstrap path is unchanged. Before launching an auxiliary
code-review worker or code evaluator for an eligible code-bearing slice, the root
SHALL:

1. Resolve full existing `base_sha` and `head_sha` commit objects, prove ancestry,
   record `head_sha^{tree}`, and reject a dirty handoff.
2. Export committed `head_sha` source to a fresh temporary root outside the checkout;
   record the exact full-index binary/mode/rename diff and ordered changed paths.
3. Hash the source inventory, diff, approved plan, authority, rubric, and every gate
   evidence file. Record the exact gate command, available tool versions, creation
   time, client/launch mechanism, and bootstrap evidence mode.
4. Run the developer gate against source verified as `head_sha`; preserve command,
   environment summary, timing, exit, stdout/stderr hashes, and output location.
5. Exclude producer transcripts/reasoning, credentials, unrelated evaluations, status
   history, and original Git identities/history. Necessary synthetic Git metadata is
   identity-free and explicitly marked synthetic.

The root re-verifies inventory immediately before each cold launch and after each gate.
A changed head, nonzero or incomplete gate, source mismatch, or unrecorded output
invalidates the run; evidence never carries across a base/head pair.

The root launches exactly three separate cold, non-delegating auxiliary workers for
correctness, tests, and security. They receive the same hash-bound package without
producer context and use separate scratch/output paths with no source, checkout,
authority, gate-evidence, or peer-output write access. Each echoes the base/head and
manifest hash and returns parseable, diff-intersecting findings with stable run-local
ID, confidence, proposed severity, location, claim, evidence, and suggested
verification.

The root mechanically validates completeness, bindings, inventories, and locations,
then records an identity-neutral companion with only
`bootstrap-ran-with-findings`, `bootstrap-ran-clean`, or `bootstrap-invalid`. Clean
requires three valid workers and zero findings. Any missing, failed, timed-out,
truncated, malformed, duplicate, hash-mismatched, or source-mutating output makes the
aggregate invalid; partial findings remain diagnostics only.

After a complete review, the root launches a fresh cold code evaluator distinct from
the developer, workers, and root. It receives only the exact package, validated
bootstrap findings, rubric, and bounded instruction, cannot delegate, independently
checks plan/spec conformance and adjudicates every finding, and obtains the same gate
rerun against a fresh writable copy whose starting inventory matches `head_sha`.
Developer gate evidence is comparison material, not a substitute. An unavailable or
incomplete rerun invalidates the evaluation.

The evaluator writes one bound verdict to its scratch output and never commits or
changes status. The root validates run ID, exact SHAs, manifest hash, round,
adjudications, gate evidence, and output uniqueness, copies it without changing its
merits, and commits the companion and verdict under the configured uniform identity.
Only the independent evaluator supplies PASS/FAIL. Until the recorder component
retires, this root-copy operation is explicitly not deterministic recorder
conformance.

Every artifact prominently records:

```text
Evidence mode: loom-repository-bootstrap/v1
Conformance: degraded bootstrap; not loom-local-review/v1
Isolation: not established under ADR 0022
```

The orchestrator never labels bootstrap output isolated, sanitized-evaluation/v1,
controlled-input-conformant, or release/adapter conformance, and never feeds it into a
production-v1 consumer as production evidence.

### Protected transition state, publication, and recovery

Eligibility is latched only by `refs/heads/loom/bootstrap-transition`, an ordinary
branch on the configured remote, separate from the target and protected against
deletion and non-fast-forward updates. Protection must be freshly verified before a
create-only root push. The canonical JSON root binds the accepted ADR commit/blob,
`loom-repository-bootstrap-state/v1` schema and unique program ID, improvement-plan
blob, configured remote/full target/`remote-direct` mode, transition ref, exact
allowlist, component retirement slices, empty result/evidence maps, sequence zero,
phase `active`, and `full_sunset: not-reached`. A missing or unexpected root blocks
bootstrap.

Each ordinary-push successor has the prior verified tip as its sole parent, increments
the sequence, repeats immutable fields, and carries cumulative state. History
validation permits only slice removal, immutable result addition, component movement
`available -> closing -> retired`, and full-sunset movement
`not-reached -> closing -> retired`. Every push is freshly fetched and checked by exact
object ID. Each result binds the verified target result and slice head, initial/final
bases, gate/review/evaluation hashes, receipt hash, and intent-state SHA; retirement
records its slice and result SHA. Writers that lose a fast-forward race inspect the
winner and recover its matching intent or restart from fresh state; they never retry
stale state or candidate commits.

Every eligible publication, including later production-helper publications while the
program remains active, uses this envelope: prepare and check the final candidate;
append and freshly verify a `publication-intent` phase bound to slice, session/claim,
final base, candidate input/result, evidence hashes, and intended removals/retirements;
publish and freshly verify the configured target; write the ADR-0020 receipt; append
and freshly verify settlement returning to `active` or terminal `retired`; then release
the claim and clean up. A current intent blocks every other new or resumed bootstrap
action. An abort successor is permitted only after proving no target publication
occurred; it retains the intent/abort record and cannot undo results or retirements.
Recovery freshly reads both refs and either publishes only the exact recorded
candidate, reconstructs the receipt and settles a verified result, completes cleanup
for an existing settlement, or stops for owner recovery when containment is uncertain.

For only M0, M1, and `remote-first-integration-candidate`, while
`bootstrap-landing` remains available, the root may replace the not-yet-built landing
helper with ADR 0023's repository-only `remote-direct` procedure. It fetches the exact
remote base into a temporary ref; builds a disposable candidate containing only the
slice and deterministic prospective finalization; runs the integrated gate, auxiliary
review, and independent evaluation against exact candidate SHAs; adds only declared
evidence/finalization; reruns the exact publish-candidate gate; and re-fetches before
publication. Target movement discards and rebuilds the candidate with affected checks
rerun. Publication uses an explicit non-force `<sha>:<full-target-ref>` refspec and is
successful only after a fresh read proves the target and checked tree exactly match.
It never falls back to PR, merge queue, a protected target, force, or another mode.

Settlement of `remote-first-integration-candidate` retires bootstrap landing;
`local-review-orchestration` retires auxiliary bootstrap review;
`sanitized-evaluation-workspace` retires bootstrap export and gate rerun; and
`evaluation-output-recorder` retires root-copy recording. Retirements govern every
new and resumed run regardless of its base. A stale run must rebuild/rebase from a
fresh target containing every retired component's result SHA and rerun the integrated
gate and all affected review/evaluation. A rewind or unavailable qualifying base
blocks; an older checkpoint never reopens a retired path.

Settlement of `evaluation-output-recorder` derives the full-sunset SHA from a fresh
target proven to contain the results for `local-review-orchestration`,
`sanitized-evaluation-workspace`, and `evaluation-output-recorder`. Its terminal state
retires all components and empties the allowlist. Bootstrap is then forbidden for all
runs. Production failure does not revive it; only a new accepted ADR and new
program/ref could authorize another transition.

At every preparation, review, gate, evaluation, recording, state, or publication
failure, the root fails closed: it never records clean/PASS or advances without valid
evidence; retains the exact commits and safe diagnostics; keeps `Implemented`, or
`Ready to Publish` after a valid PASS, unless a merits revision returns to
`In Progress`; checkpoints the exact resume action; preserves the claim during
incomplete intent/publication/settlement; and stops spawning. Infrastructure blocks
consume no merits round and are never retried blindly. A stage may resume only with
hash-identical inputs; otherwise the root starts a new run. A docs-only skip, missing
command, partial finder set, manual finding summary, owner assertion, or prior slice's
evidence never substitutes for a required bootstrap stage.

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

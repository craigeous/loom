# 0023 — Repository Self-Hosting Bootstrap Transition

Status: Accepted
Date: 2026-07-21

## Context

Accepted ADRs [0021](0021-loom-owned-local-review-protocol.md) and
[0022](0022-controlled-input-independent-evaluation.md), as incorporated into
Approved specs [03](../spec/03-artifact-lifecycle.md),
[04](../spec/04-orchestrator.md), and
[05](../spec/05-blind-evaluation.md), require every code-bearing slice to complete a
valid `loom-local-review/v1` run and controlled-input evaluation through the
repository-owned exporter, gate runner, and recorder before it can advance beyond
`Implemented`.

Those components do not yet exist. The
[repository improvement plan](../repository-improvement-plan.md) deliberately puts a
reproducible baseline, coordinator safety, remote publication, and hook safety before
the local-review pipeline and evaluation workspace. Its current authority snapshot is
Git blob `316ae4bc964fb422134151478b6369e1f9b4cfa5`. The Approved
[`ci-baseline`](../slice-plans/ci-baseline.md) plan, Git blob
`2f8d375691d4dc7e27914aad243963bc27c6d048`, is the first code-bearing M0 slice and
explicitly does not implement the later review or evaluation machinery. Therefore the
first slice, the intervening safety slices, and the review/evaluation machinery's own
first implementations cannot satisfy the prerequisites needed to evaluate the code
that creates those prerequisites.

Pretending that existing prompt-scoped review is `loom-local-review/v1`, or that an
evaluator launched against an orchestrator-prepared directory has passed ADR 0022's
isolation conformance, would erase the distinction those ADRs were written to create.
Stopping all code work would instead make the approved ordering impossible to execute.

In scope is one temporary self-hosting transition for this Loom repository's named
improvement-program slices, including the minimum planning evaluations needed to
authorize them. It defines exact-revision evidence, cold auxiliary review, independent
evaluation, recording, a closed bootstrap publication path until the landing helper
can land itself, failure handling, remote-latched progressive retirement, and a hard
sunset. It does not change behavior shipped to or promised for a Loom-managed project,
waive configured-remote publication authority, establish a reusable workflow profile,
or authorize unrelated repository work.

## Decision

### 1. Authorize one repository-only bootstrap evidence mode

Until the sunset in section 6, the root orchestrator MAY use
`loom-repository-bootstrap/v1` only for this repository and only for these
code-bearing improvement slices:

- M0: `ci-baseline` and its required `client-floor-adapter-smoke` follow-up;
- M1: `coord-identifier-boundaries`, `coord-lock-ownership`, and
  `coord-schema-cas`;
- M2: `remote-first-integration-candidate` and
  `coordination-state-separation`;
- M3: `identity-guard-contract` and `precompact-per-session`;
- M4: `local-review-helper`, `local-review-agents`,
  `local-review-orchestration`, and `local-review-defect-battery`; and
- M5: `sanitized-evaluation-workspace` and `evaluation-output-recorder`.

The same mode MAY be used for a cold plan evaluation of ADR 0023 itself and for a
slice-plan whose sole purpose is to authorize one of the listed code-bearing slices.
It is not available for research, a different ADR/spec amendment, M6 or later work,
maintenance outside the program, another repository, or a managed project. A slice ID
that is missing, renamed, combined, or not represented by its own approved plan is not
implicitly eligible; changing this closed list requires another accepted ADR.

ADR 0023 cannot authorize its own acceptance retroactively. Its Plan Review must
receive a distinct cold plan-evaluator assessment prepared with the controls below and
explicitly labeled `bootstrap-ratification: degraded`. Acceptance then requires an
explicit owner decision under spec 03's existing owner-gate authority. If either is
absent, this ADR remains in Plan Review and the exception never starts.

This mode is transition evidence, not a product protocol. Nothing created under it may
be reused as release conformance, managed-project evidence, or proof that either client
adapter implements the production boundary.

### 2. Bind every bootstrap run to exact committed inputs and gate evidence

Before launching any reviewer or evaluator, the root orchestrator SHALL:

1. Resolve and record full, existing commit object IDs for `base_sha` and `head_sha`,
   verify that `base_sha` is an ancestor of `head_sha`, record `head_sha^{tree}`, and
   reject a dirty implementation handoff. Symbolic refs, the current checkout, a PR,
   and a floating remote ref are not review inputs.
2. Materialize source from the committed `head_sha`, not from the working tree, into a
   fresh temporary root outside the managed checkout. Capture the exact
   `base_sha..head_sha` diff with full-index, binary, mode, and rename information and
   an ordered changed-path inventory.
3. Record SHA-256 for the source inventory, diff, approved plan, relevant specs/ADRs,
   rubric, and every gate-evidence file. The manifest also records the exact gate
   command, tool versions available, creation time, client/launch mechanism, and
   `evidence_mode: "loom-repository-bootstrap/v1"`.
4. Run the developer gate against source verified to match `head_sha` and preserve the
   command, environment summary, start/end time, exit status, stdout/stderr hashes, and
   output location. A nonzero, interrupted, unrecorded, or source-mismatched gate is a
   failed bootstrap run.
5. Exclude producer transcripts, producer reasoning, credentials, unrelated
   evaluations, status history, and original Git author/committer history from the
   evidence package. Any minimal Git metadata synthesized only to execute a Git-aware
   gate is marked synthetic and contains no original identity or history.

The orchestrator verifies the inventory immediately before each cold launch and after
each gate execution. Any change to the committed head requires a new run and new
evidence; findings or verdicts from a prior base/head pair cannot be carried forward.

For a plan evaluation, the analogous package binds the exact artifact commit,
authority/rubric blobs, and any current-tree evidence SHA needed by the plan rubric.

### 3. Perform complete cold auxiliary review without claiming the v1 protocol

For each eligible code-bearing slice, the root orchestrator launches three separate,
cold, non-delegating auxiliary workers for correctness, tests, and security. They all
receive the same hash-bound bootstrap package, no producer conversation or reasoning,
and distinct writable scratch/output locations. They cannot edit the source, approved
plan, gate evidence, another worker's output, or the managed checkout.

Each worker must echo the exact base/head and manifest hash and return structured
findings with a stable run-local ID, confidence, proposed severity, changed file and
line/range, claim, concrete evidence, and suggested verification. A finding must
intersect the exact diff. Proposed severity is advisory.

The orchestrator mechanically checks required-worker completeness, echoed hashes,
output parseability, source inventory, and diff intersection, then records an
identity-neutral companion artifact. The artifact uses the aggregate states
`bootstrap-ran-with-findings`, `bootstrap-ran-clean`, or `bootstrap-invalid`. Clean is
permitted only when all three workers completed and validated with zero findings. A
missing, failed, timed-out, truncated, malformed, hash-mismatched, duplicate, or
source-mutating worker makes the aggregate `bootstrap-invalid`; partial findings may be
retained only as diagnostics.

The artifact MUST prominently record:

```text
Evidence mode: loom-repository-bootstrap/v1
Conformance: degraded bootstrap; not loom-local-review/v1
Isolation: not established under ADR 0022
```

It MUST NOT contain `protocol: loom-local-review/v1`, use the unqualified production
states `ran-clean` or `ran-with-findings`, call itself a valid local-review/v1 run, or
be passed to an evaluator as one. Existing generic agent launch and filesystem/shell
capabilities are auxiliary bootstrap mechanisms only; external hidden review commands
are not reinstated.

### 4. Preserve a distinct evaluator and evaluator-owned verdict

After a complete bootstrap review, the root launches a fresh cold code-evaluator
invocation that is distinct from the developer, all auxiliary workers, and the root
orchestrator. It receives only the exact package, validated bootstrap findings,
applicable rubric, and bounded instruction. It receives no producer transcript,
producer reasoning, or prior role conversation and may not delegate.

The evaluator independently checks plan/spec conformance, adjudicates every advisory
finding, and obtains a rerun of the same declared gate against a fresh writable copy
whose starting inventory matches the immutable `head_sha` export. The rerun records
the command/environment digest, tool versions, timing, exit status, stdout/stderr
hashes, and ending inventory. An unavailable or incomplete rerun invalidates the
evaluation; prior developer gate evidence is comparison material, not a substitute.

The evaluator writes one verdict to its scratch output, echoing the run ID, exact
base/head, manifest hash, PASS/FAIL, round, adjudications, severity findings, and gate
rerun reference. It never commits or changes lifecycle state. The root validates those
bindings and copies the verdict without changing its merits, then commits the companion
and verdict under the repository's configured uniform identity. The committed artifacts
and messages identify evidence mode and exact revisions but contain no producer,
reviewer, model-persona, or tool authorship attribution.

Only that independent code-evaluator verdict may supply PASS or FAIL. The root,
auxiliary workers, developer, and owner cannot turn invalid bootstrap evidence into an
evaluator PASS. A valid FAIL returns the slice to `In Progress`; a valid PASS may
advance it to `Ready to Publish`. ADR 0020/specs 03–04 publication authority, fresh
remote verification, and receipt requirements still apply before `Landed`; section 7
temporarily replaces only their unavailable helper implementation boundary.

Cold plan evaluations use the same separation: a plan evaluator distinct from the
planner writes its own verdict to scratch, and the root records it without merits
changes. These plan verdicts carry the same degraded-bootstrap provenance and do not
claim ADR 0022 conformance.

### 5. State precisely which production guarantees remain unproved

Bootstrap evidence preserves exact committed revisions, three-way advisory review,
cold producing/evaluating role separation, gate and rerun evidence, author-neutral
handoffs, independent evaluator verdict authority, and fail-closed handling. It does
not establish any of these production v1 guarantees:

- the released `loom-review` prepare/validate/assemble schemas, canonical hashing,
  prompt versions/hashes, helper provenance, network-silent execution, or adapter
  conformance of ADR 0021;
- deterministic construction of the complete evaluation allowlist, enforced
  read-only permissions, denial of all undeclared filesystem/process access, canary
  isolation, credential absence, or client-equivalent capability confinement;
- the deterministic bounded gate runner's output redirection, offline dependency
  preparation, mutation containment, cleanup, and conformance fixtures; or
- schema-valid deterministic recording, cross-run rejection, output confinement, and
  recorder-owned lifecycle transition under ADR 0022/spec 05.

Prompt instructions and temporary-directory permissions are useful controls, but are
not represented as a proven isolation boundary. No bootstrap verdict or findings file
may be labeled `isolated`, `sanitized-evaluation/v1`, `controlled-input-conformant`, or
otherwise abbreviated to imply those unproved guarantees. User-facing material must
continue to distinguish this degraded repository bootstrap from Loom's production
claim.

### 6. Latch eligibility and retirement on an append-only remote state ref

The original improvement-plan milestone order remains unchanged. Safety and remote
publication work are not moved behind self-hosting machinery. Bootstrap eligibility is
not inferred from a chosen run base, local status, local receipts, or the current target
branch. It is granted only by a valid state history on the configured remote at
`refs/heads/loom/bootstrap-transition` (the **transition ref**).

The transition ref is an ordinary branch, separate from the configured target branch.
Before this exception is used after ADR acceptance, the repository owner SHALL
configure the remote to reject deletion and non-fast-forward updates of that ref. If
that protection cannot be established and freshly verified, bootstrap is unavailable.
The initializer then creates, with a create-only ordinary push, one root commit whose
sole payload is canonical UTF-8 JSON with:

- `schema: "loom-repository-bootstrap-state/v1"`, a unique program ID, this accepted
  ADR's commit and blob IDs, and improvement-plan blob
  `316ae4bc964fb422134151478b6369e1f9b4cfa5`;
- the configured remote name, full target ref, required `remote-direct` mode, and
  transition ref;
- sequence `0`, no predecessor, phase `active`, and the exact initial allowed slice set
  from section 1;
- immutable component entries for `bootstrap-landing`, `local-review`,
  `evaluation-workspace`, and `evaluation-recorder`, initially `available` and bound
  respectively to `remote-first-integration-candidate`,
  `local-review-orchestration`, `sanitized-evaluation-workspace`, and
  `evaluation-output-recorder`; and
- empty result/evidence maps and `full_sunset: {"state":"not-reached"}`.

Missing state does not mean “not yet retired”: it blocks the exception. A create race
is resolved by freshly reading and validating the winning root; an unexpected root is
invalid, not replaceable. The initialization commit and every successor are pushed
without force and freshly fetched back by exact object ID before they have authority.
No command in this ADR deletes, force-updates, or recreates the transition ref.

Each successor has exactly one parent equal to the previously verified transition tip,
increments the sequence by one, repeats the immutable program/configuration fields,
and contains the complete cumulative state. Validation walks the entire history to the
root and permits only these monotonic changes:

- remove, never add, a slice from `allowed_slices`;
- add one immutable slice result containing its verified configured-target result SHA,
  slice head, initial/final target bases, gate/review/evaluation evidence hashes,
  receipt hash, and publication-intent state SHA;
- move a component only `available -> closing -> retired`, recording its retirement
  slice and result SHA; and
- move full sunset only `not-reached -> closing -> retired`, with its derived SHA.

A publication-intent successor records the exact slice, session/claim, final remote
base, candidate-input and publish-result SHAs, evidence hashes, and intended removals
or retirements, and changes phase to `publication-intent`. While that phase is current,
all new and resumed bootstrap review, evaluation, recording, and landing runs are
blocked. Only recovery of that exact hash-bound publication may proceed. Its settlement
successor records the verified result and removals/retirements and returns to `active`,
or to terminal `retired` at full sunset. If no target publication occurred, an abort
successor may return to `active`, but it retains the intent and abort record and cannot
undo an earlier result or retirement. This prepare-intent, publish-target, settle-state
ordering deliberately does not assume atomic publication of two remote refs.

That envelope applies to every section-1 slice, including publications performed by
the production landing helper after its own retirement boundary: prepare and check the
final candidate; append and freshly verify its transition intent; publish and freshly
verify the configured target; write the ADR-0020 receipt; append and freshly verify
settlement; then release the claim and clean up. A helper may implement those steps,
but may not reorder or collapse the two remote updates. Concurrent state writers start
from the same verified tip; only one ordinary fast-forward push can win. A loser
freshly reads the winner and either recovers the matching intent or restarts from the
new state and target. It never retries its old state commit or target candidate.

At the start of every new run and before resuming any checkpoint, the orchestrator
performs a network read of the transition ref into a new temporary ref, verifies the
advertised and fetched object IDs agree, validates the complete state history, and
freshly reads the configured target. It also compares the observed state tip with every
tip bound into the current run, claim, candidate manifest, or recoverable receipt. A
missing, unreadable, unprotected, malformed, wrong-program, divergent, deleted,
rewound, or non-fast-forward transition ref; unavailable remote; or target that no
longer contains every recorded result SHA blocks all bootstrap use and recovery. It
never selects an older valid-looking state. Remote enforcement supplies the durable
append-only latch, so deletion of all local checkpoints or receipts loses recovery
convenience but cannot restore a removed permission.

Settlement of these verified configured-target results retires the corresponding
component for **every** later new or resumed run, independent of its selected base:

- `remote-first-integration-candidate` retires `bootstrap-landing`;
- `local-review-orchestration` retires the section 3 bootstrap review;
- `sanitized-evaluation-workspace` retires bootstrap export and gate rerun; and
- `evaluation-output-recorder` retires root-copy recording.

Once state retires a component, every run base must contain that component's recorded
result SHA. A stale run is invalidated and rebuilt/rebased from a fresh configured
remote target that contains all required result SHAs; its integrated gate and every
review/evaluation check affected by the new base are rerun. If the target was rewound,
is unavailable, or cannot supply such a base, the run blocks. Choosing a pre-result
base, resuming an old checkpoint, deleting a receipt, or deleting local transition
state can therefore never reopen bootstrap.

The **full sunset SHA** is derived during settlement of
`evaluation-output-recorder`: after fresh verification of that published result, read
the configured target once more and require
`git merge-base --is-ancestor <result_sha> <target_sha>` for the recorded results of
`local-review-orchestration`, `sanitized-evaluation-workspace`, and
`evaluation-output-recorder`. The first target SHA verified by that settlement to
contain all three is recorded as `full_sunset.sha`; the final successor sets every
component and `full_sunset.state` to `retired`, empties `allowed_slices`, and is
terminal. Bootstrap is then forbidden for all runs, including stale-base and resumed
runs. Production failure is an infrastructure block, not revival grounds. Revival
requires a new accepted ADR and a new program/ref; no target rewind, state-file edit,
local configuration change, owner flag, or receipt deletion can mutate this terminal
history.

### 7. Bootstrap remote-direct landing only until the landing helper lands

ADR 0020's remote authority remains the success boundary, but its not-yet-implemented
landing-helper requirement is temporarily replaced for exactly these slices:
`ci-baseline`, `client-floor-adapter-smoke`, `coord-identifier-boundaries`,
`coord-lock-ownership`, `coord-schema-cas`, and
`remote-first-integration-candidate`. The procedure is repository-only,
`remote-direct` only, and available only while the freshly validated transition state
lists the slice and `bootstrap-landing` is `available`. It is not `loom-land/v1`, a
supported managed-project path, provider-adapter conformance, or release conformance.
It does not support PR, merge-queue, protected-target fallback, another repository, or
any later slice.

The root orchestrator, while retaining the slice claim, SHALL perform this closed
procedure:

1. Freshly validate the transition state and fetch the configured full target ref by
   name into a new temporary ref. Record its exact commit as `initial_base`; never read
   local `main` for authority or candidate content.
2. Resolve the reviewed slice head and its exact evidence, create a disposable branch
   and worktree at `initial_base`, integrate only that slice, and deterministically add
   the prospective `Landed`/`Archived` finalization required by specs 03/04. Record an
   inventory proving that no unrelated local-main or other-slice commit entered the
   candidate.
3. Run the integrated gate against the resulting candidate input. Run sections 3 and
   4 again against its exact base/input SHAs and bind their outputs to that integrated
   tree. Add only those generated evidence and final status/index files to form the
   publish candidate, prove that this last delta is confined to the declared
   finalization paths, and run the integrated gate once more against the exact publish
   candidate. Any other delta restarts integrated review/evaluation.
4. Immediately re-fetch the configured target. If it differs from `initial_base`,
   discard the candidate, rebuild from the new exact base, and repeat step 3. A conflict,
   ambiguous affected-check determination, or evidence mismatch fails closed.
5. Append and freshly verify a `publication-intent` transition-state commit bound to
   the final base, candidate-input SHA, publish-candidate SHA, claim, and all integrated
   evidence hashes. This makes other bootstrap work stop before the target update.
6. Push the publish-candidate SHA with an explicit `<sha>:<full-target-ref>` refspec
   through the configured remote, without `+`, `--force`, `--force-with-lease`, mirror
   mode, deletion, or a changed destination. A non-fast-forward, protection,
   credential, or network failure is not retried blindly and never selects another
   mode.
7. Perform a new remote read, fetch the advertised object, and verify the configured
   target equals the exact publish-candidate SHA and its tree equals the checked tree.
   Push exit alone is insufficient. Write a bound untracked receipt in common-Git-dir
   recovery state containing the program/state-intent SHA, slice/session/claim, remote
   and full target ref, mode `remote-direct`, slice head, initial/final bases,
   candidate-input and result SHAs, gate/review/evaluation hashes, timestamps, and
   publication/verification outcomes.
8. Append and freshly verify the settlement transition commit, removing the slice from
   `allowed_slices` and recording the result and receipt hash. For
   `remote-first-integration-candidate`, also retire `bootstrap-landing`. Only then
   release the owner-verified claim and perform idempotent local cleanup. Updating local
   `main` is optional cache maintenance and has no authority.

The transition ref and target ref are intentionally updated in separate ordered
operations. Crash recovery begins with fresh reads of both. Before the intent exists,
the disposable candidate may be discarded and rebuilt. With an intent and the target
still at its recorded base, recovery may publish only the exact recorded candidate; if
that object was lost before publication, append an abort only after proving the target
does not contain it, then rebuild under a new intent. If the target equals or contains
the recorded result, validate its tree/evidence, reconstruct a missing receipt, and
settle without republishing. If the receipt exists but settlement does not, validate
the receipt and settle. If settlement exists but local receipt/cleanup was deleted,
reconstruct the receipt from the cumulative remote state plus fresh target containment,
then clean up. Any target that neither remains at the recorded base nor contains the
result, any rewritten transition history, or any uncertain containment stops for owner
recovery without releasing the claim or reopening bootstrap.

After the verified settlement of `remote-first-integration-candidate`, every later
publication uses the production landing helper required by ADR 0020/specs 03–04. An
unavailable or defective helper is infrastructure-blocked and cannot fall back to this
procedure.

### 8. Fail closed and recover without changing the reviewed target

At any bootstrap preparation, auxiliary review, gate, evaluation, recording,
publication, or transition-state failure, the orchestrator SHALL:

1. mark the run invalid, never clean/PASS, and make no unauthorized advancing
   lifecycle transition;
2. leave the slice at `Implemented`, or at `Ready to Publish` after a valid PASS (return
   it to `In Progress` only for a merits revision), retain the exact committed
   base/head and all safe diagnostic evidence, and checkpoint the failed step and
   resume action;
3. preserve the claim whenever publication or transition settlement is incomplete,
   stop spawning, and classify infrastructure failures under ADR 0017 without
   consuming a merits round or retrying blindly; and
4. after repair, rerun the failed stage only when its inputs remain hash-identical,
   otherwise start a completely new run for the new committed head. A current
   publication intent may be recovered only by section 7's exact procedure.

If bootstrap cannot be launched at all, the owner may restore the existing client,
filesystem, gate dependency, remote/state-ref protection, or orchestrator capability
and resume from the checkpoint, or abandon the slice. No docs-only skip,
command-unavailable state, partial finder set, manual finding summary, owner assertion,
or earlier slice's evidence substitutes for the required run. Once remote state has
retired a component, recovery uses its production implementation or pauses for a new
authority decision; it never falls back to this bridge.

## Consequences

- The improvement program can self-host honestly without reordering M0–M5 or claiming
  that future helpers already exist. Early safety work still precedes the machinery it
  will eventually use.
- **Temporarily and narrowly supersedes ADR 0021 sections 1 and 3** only where they
  require a valid `loom-local-review/v1` run as the entry to code evaluation for the
  closed repository/program slice list. Exact commits, complete required review,
  false-clean prohibition, advisory findings, and evaluator verdict authority remain.
- **Temporarily and narrowly supersedes ADR 0022 sections 2, 3, and 5** only where they
  require the not-yet-implemented exporter, gate runner, recorder, and adapter
  conformance for ADR 0023 ratification and the closed repository/program slice list.
  Cold separation, no self-approval, exact evidence, honest trust claims, and invalid
  output handling remain.
- **Temporarily and narrowly supersedes ADR 0020 section 2 and specs 03/04** only where
  they require the not-yet-landed deterministic landing helper. Section 7 preserves
  the configured remote as authority, exact candidate construction, integrated
  evidence, non-force publication, fresh verification, bound untracked receipt, and
  recovery, and disappears when `remote-first-integration-candidate` is settled.
- Approved specs 03–05 are read through exactly those temporary exceptions for eligible
  runs before each remote-latched retirement boundary. No other lifecycle,
  orchestration, evaluation, or publication rule is superseded. ADR 0017's
  infrastructure handling, ADR 0003's neutral handoffs, and ADR 0020's remote
  publication authority remain fully in force.
- Production components must accept and test only production evidence. Bootstrap
  artifacts remain auditable historical records but are never upgraded, relabeled, or
  counted as v1 conformance after the sunset.
- The price of preserving program order is explicit degraded provenance, a protected
  append-only transition ref, and some manual orchestration. The benefit is a hard
  one-way transition: each settled remote result removes its corresponding exception,
  stale bases must move forward, and the final state eliminates the bridge entirely.

# 0023 — Repository Self-Hosting Bootstrap Transition

Status: Draft
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
evaluation, recording, failure handling, progressive retirement, and a hard sunset.
It does not change behavior shipped to or promised for a Loom-managed project, waive
publication authority, establish a reusable workflow profile, or authorize unrelated
repository work.

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
advance it to `Ready to Publish`. This ADR does not weaken ADR 0020 or specs 03/04:
publication, remote verification, and receipt requirements still apply before
`Landed`.

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

### 6. Retire the bridge monotonically and mechanically

The original improvement-plan milestone order remains unchanged. Safety and remote
publication work are not moved behind self-hosting machinery. Instead the exception
shrinks as each production component is remotely landed:

- For a run whose `base_sha` contains the verified remote result of
  `local-review-orchestration`, production `loom-local-review/v1` is mandatory; the
  bootstrap review in section 3 is no longer available.
- For a run whose `base_sha` contains the verified remote result of
  `sanitized-evaluation-workspace`, its production exporter and gate runner are
  mandatory; prompt-scoped bootstrap preparation/rerun is no longer available.
- For a run whose `base_sha` contains the verified remote result of
  `evaluation-output-recorder`, its production recorder is mandatory; root-copy
  bootstrap recording is no longer available.

At the start of each run the orchestrator freshly reads the configured remote target.
Absence there of a transition slice's published `Archived` plan and PASS evidence means
that component has not landed. Their presence triggers ADR 0020 receipt recovery and
fresh verification of its exact result SHA. The boundary contains the run base only
when `git merge-base --is-ancestor <result_sha> <base_sha>` succeeds. An ambiguous,
unverifiable, or contradictory tracked state, receipt, or remote result fails closed;
deleting local recovery state cannot make the older bootstrap path available.

The **full sunset SHA** is the first verified configured-remote target commit that
contains the verified results of all three slices: `local-review-orchestration`,
`sanitized-evaluation-workspace`, and `evaluation-output-recorder`. Bootstrap mode is
forbidden for every run whose base is that SHA or a descendant. This predicate is
mechanical, has no date extension or owner-discretion flag, and lets each transition
component use bootstrap only for its own pre-landing evaluation. At and after the full
sunset, ADRs 0021/0022 and specs 03–05 apply without exception. An unavailable or
defective production component is then an infrastructure block, not grounds to revive
bootstrap mode. Revival requires a new accepted ADR; editing a plan, status file,
receipt, or local configuration cannot do it.

### 7. Fail closed and recover without changing the reviewed target

At any bootstrap preparation, auxiliary review, gate, evaluation, recording, or
sunset-check failure, the orchestrator SHALL:

1. mark the run invalid, never clean/PASS, and make no advancing lifecycle transition;
2. leave the slice at `Implemented` (or return it to `In Progress` only for a merits
   revision), retain the exact committed base/head and all safe diagnostic evidence,
   and checkpoint the failed step and resume action;
3. stop spawning and classify infrastructure failures under ADR 0017 without consuming
   a merits round or retrying blindly; and
4. after repair, rerun the failed stage only when its inputs remain hash-identical,
   otherwise start a completely new run for the new committed head.

If bootstrap cannot be launched at all, the owner may restore the existing client,
filesystem, gate dependency, or orchestrator capability and resume from the checkpoint,
or abandon the slice. No docs-only skip, command-unavailable state, partial finder set,
manual finding summary, owner assertion, or earlier slice's evidence substitutes for
the required run. If the sunset predicate has fired, recovery uses production v1 or
pauses for a new authority decision; it never falls back to this bridge.

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
- Approved specs 03–05 are read through exactly those temporary exceptions for eligible
  runs before each mechanical retirement boundary. No other lifecycle, orchestration,
  evaluation, or publication rule is superseded. ADR 0017's infrastructure handling,
  ADR 0003's neutral handoffs, and ADR 0020's remote authority remain fully in force.
- Production components must accept and test only production evidence. Bootstrap
  artifacts remain auditable historical records but are never upgraded, relabeled, or
  counted as v1 conformance after the sunset.
- The price of preserving program order is explicit degraded provenance and some
  manual orchestration. The benefit is a hard one-way transition: each landed
  self-hosting component removes its corresponding exception, and the final landing
  eliminates the bridge entirely.

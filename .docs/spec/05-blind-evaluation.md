# 05 — Controlled-Input Independent Evaluation

Status: Approved

## Authority

ADRs [0003](../ADR/0003-cold-handoffs-commit-per-handoff.md) and
[0004](../ADR/0004-blind-evaluation-role-separation.md), as corrected and extended
by [0021](../ADR/0021-loom-owned-local-review-protocol.md) and
[0022](../ADR/0022-controlled-input-independent-evaluation.md), with the temporary
repository-only transition in
[0023](../ADR/0023-repository-self-hosting-bootstrap-transition.md).

## The claim

Loom provides **independent cold-agent evaluation with controlled inputs**.

- **Independent:** a fresh invocation distinct from the producer has no authority to
  approve its own output.
- **Cold:** no producer transcript or conversational state is intentionally supplied.
- **Controlled inputs:** Loom constructs a hashed allowlisted workspace and bounded
  task prompt.

This does not mean a different vendor/base model, statistical independence,
cryptographic anonymity, impartiality, or a hostile-code sandbox. “Blind evaluation”
may name this historical file or a lifecycle phase only when immediately qualified by
the boundary above.

## Fresh per-run workspace

Every evaluation runs in a new exported directory outside the managed repository.
Common inputs are:

- the artifact under review;
- upstream authority;
- applicable rubric and severity rules; and
- a machine-readable manifest with origin and SHA-256 for every supplied file.

Re-review additionally receives the prior verdict and exact artifact revision diff.
Input data is immutable/read-only. Each evaluator receives separate writable output
and scratch directories and no write path into the managed checkout or another run.

Exports reject symlinks, hardlinks, sockets, devices, escaping paths, missing inputs,
unexpected extras, mutable inputs, and unsupported manifest/schema versions.

## Plan and research inputs

The artifact's upstream authority is type-specific:

- research note: deterministically captured cited sources;
- ADR: approved research/problem statement plus accepted prior authority;
- spec: accepted ADRs it derives from;
- slice-plan: target approved specs and relevant accepted ADRs.

When the claim under review depends on current repository state, the exporter supplies
a complete sanitized tracked snapshot at one full `evidence_sha`, less only declared
policy exclusions, with tree ID and per-path inventory/hashes. Approved mechanical
reads may operate on that snapshot. Tools requiring writes use a verified disposable
copy and private scratch. The live checkout is never consulted.

Before research evaluation, the evidence collector resolves local citations at exact
repository/content revisions and retrieves external citations. Each capture records
requested/final locator, UTC retrieval time, redirect/status, content type, collector
version, freshness rule, and content hash. Required missing, stale, truncated,
authentication-dependent, or unresolvable evidence invalidates/blocks the run; the
evaluator cannot replace it with recollection.

## Code inputs

Code evaluation receives only:

- source at exact reviewed `head_sha` and its tree/inventory hashes;
- the exact `base_sha..head_sha` diff, including rename/binary/mode metadata;
- approved slice-plan and relevant specs/ADRs;
- developer gate evidence;
- one valid assembled `loom-local-review/v1` artifact, or explicit docs-only status;
- rubric/severity rules; and
- the evaluation manifest.

The evaluator independently adjudicates every advisory local-review finding. It may
confirm, reject with reason, or adjust proposed severity under the canonical rubric.
Finders never determine PASS/FAIL.

## Degraded repository bootstrap evaluation (non-release exception)

The production controlled-input claim and construction requirements in this spec are
unchanged. ADR 0023 permits a temporary `loom-repository-bootstrap/v1` substitute only
inside this Loom repository while it builds the exporter, runner, and recorder. It is
never available to released Loom, a Loom-managed project, another repository, or as
release/client-adapter conformance.

Eligibility is closed to M0 `ci-baseline` and `client-floor-adapter-smoke`; M1
`coord-identifier-boundaries`, `coord-lock-ownership`, and `coord-schema-cas`; M2
`remote-first-integration-candidate` and `coordination-state-separation`; M3
`identity-guard-contract` and `precompact-per-session`; M4 `local-review-helper`,
`local-review-agents`, `local-review-orchestration`, and
`local-review-defect-battery`; and M5 `sanitized-evaluation-workspace` and
`evaluation-output-recorder`. The only planning uses are ADR 0023's degraded cold
ratification and a slice-plan solely authorizing one listed slice. A renamed, combined,
unlisted, M6-or-later, research, maintenance, or other planning artifact is ineligible.
The ADR 0023 ratification verdict additionally records
`bootstrap-ratification: degraded` and requires the existing explicit owner gate; it
does not retroactively authorize its own evaluation.

### Planning-artifact path

Bootstrap planning evaluation is distinct from the code-bearing path below. Its
package shape covers a research note at `Research Review` and an ADR, spec amendment,
or slice-plan at `Plan Review`, while ADR 0023's closed allowlist still determines
whether a run may start. Under this transition, only ADR 0023's degraded ratification
and a slice-plan solely authorizing one listed slice are eligible; type coverage does
not admit research, another ADR, or a spec amendment.

Except for ADR 0023's one-time pre-acceptance ratification, every new or resumed plan
run freshly validates the protected remote transition history, current tip and phase,
configured-target containment, eligible slice entry, and progressive component state.
The ratification binds the proposed ADR commit/blob and cannot itself initialize the
post-acceptance state; its valid degraded verdict plus explicit owner acceptance are
preconditions to the transition root, which then binds the accepted ADR commit/blob.
A current publication intent or missing, unprotected, divergent, rewound, malformed,
wrong-program, unavailable, or terminal transition state fails closed.

The root prepares a fresh planning package outside the managed checkout. Its manifest
binds the normalized repository-relative artifact path; artifact type and review
status; full reviewed commit object ID; the artifact's Git blob object ID at that
commit and SHA-256 of its bytes; and each type-specific authority, rubric, and severity
input by normalized path, authority role, Git blob object ID, and SHA-256. When the
plan rubric requires current repository facts, it additionally binds one full
`evidence_sha`, its tree ID, and a complete sanitized tracked-path inventory and
hashes. Re-review also binds the prior verdict and exact artifact-revision diff. The
manifest records a unique run ID, its own SHA-256, creation time, launch mechanism,
evidence mode, and the validated transition-state tip when one exists.

Only those recorded objects are materialized as read-only inputs. Producer transcripts
and reasoning, credentials, status history, unrelated evaluations, and original Git
identity/history are excluded. After verifying the inventory, the root launches one
fresh cold, non-delegating plan evaluator distinct from the artifact author/producer
and the root orchestrator. It receives only the package path, evaluation type, and bounded
instruction, has no managed-checkout write path, and may write only to a unique
confined output directory and private scratch. No developer gate, correctness/test/
security finder, local-review companion, code evaluator, or code gate rerun participates
in this path.

The plan evaluator writes exactly one identity-neutral verdict in its confined output
and echoes the run ID, manifest hash,
artifact path, reviewed commit/blob IDs, authority/rubric/evidence hashes, PASS/FAIL,
round, severity findings, and required changes for FAIL. It never writes `.docs/`,
commits, or changes lifecycle state. The root re-verifies immutable inputs and output
confinement, then mechanically validates eligibility, transition-state binding,
schema, uniqueness, completeness, and every echoed hash. It copies a valid verdict to
the expected evaluation path without changing the merits, applies only the legal
spec-03 status transition, and commits the verdict/status author-neutrally. ADR 0023's
ratification PASS remains owner-gated in `Plan Review`. Root-copy is permitted only
while `evaluation-recorder` remains available. Retirement of `evaluation-workspace`
makes the production exporter mandatory; retirement of `evaluation-recorder` makes
the production recorder mandatory and reaches the terminal full sunset. Neither may
fall back to this path.

Every bootstrap planning verdict prominently records:

```text
Evidence mode: loom-repository-bootstrap/v1
Conformance: degraded ADR 0023 bootstrap planning evaluation
Isolation: not established under ADR 0022
```

ADR 0023's ratification verdict also records
`bootstrap-ratification: degraded`. Missing or invalid authority/evidence, mutation,
missing/duplicate/truncated/malformed/cross-run/hash-mismatched output, escape from
output confinement, or recording failure is invalid/infrastructure-blocked—not PASS,
clean, or a merits FAIL—and cannot advance status or consume a round. Only
hash-identical inputs may resume; changed inputs require a wholly new run.

### Code-bearing path

The code-bearing bootstrap package binds full ancestor `base_sha` and committed
`head_sha`, `head_sha^{tree}`, exact full-index binary/mode/rename diff, ordered source
inventory, approved plan and authority, rubric, and SHA-256 for every input. It records the exact
developer gate command, environment/tool versions, timing, exit, stdout/stderr hashes,
and output after running against source verified to match `head_sha`. The package is
materialized outside the managed checkout from the commit, never the worktree, and
excludes producer transcripts/reasoning, credentials, unrelated evaluation and status
history, and original Git identity/history. A changed head requires a new package and
new evidence.

Before evaluation, three separate cold, non-delegating auxiliary workers for
correctness, tests, and security inspect that same immutable package using distinct
writable output/scratch locations. Each echoes exact revisions and manifest hash and
returns structured diff-intersecting advisory findings. The root validates all three;
missing, failed, timed-out, truncated, malformed, duplicate, hash-mismatched, or
source-mutating output makes the review `bootstrap-invalid`, never clean. Valid
aggregate states are only `bootstrap-ran-with-findings` and
`bootstrap-ran-clean`.

The code evaluator is a new cold invocation distinct from the developer, all three
workers, and the root orchestrator. It receives only the exact package, validated
bootstrap findings, rubric, and bounded instruction; receives no producer conversation
or reasoning; cannot delegate; independently checks plan/spec conformance and
adjudicates every finding; and obtains a rerun of the same gate against a fresh writable
copy whose starting inventory matches `head_sha`. The rerun records its
command/environment digest, tool versions, timing, exit, stdout/stderr hashes, and
ending inventory. Prior developer evidence cannot substitute; an unavailable or
incomplete rerun invalidates the evaluation.

The evaluator writes one verdict in scratch, echoing run ID, exact base/head, manifest
hash, PASS/FAIL, round, adjudications, severity findings, and gate-rerun reference. It
never writes the repository, commits, or changes lifecycle state. The root validates
the bindings and copies the verdict without merits changes under the uniform neutral
identity. Only this independent evaluator may supply PASS or FAIL. Missing, malformed,
duplicate, truncated, cross-run, hash-mismatched, or unrecordable output cannot advance
the lifecycle.

Every bootstrap findings file and verdict prominently records:

```text
Evidence mode: loom-repository-bootstrap/v1
Conformance: degraded bootstrap; not loom-local-review/v1
Isolation: not established under ADR 0022
```

It never claims `protocol: loom-local-review/v1`, `isolated`,
`sanitized-evaluation/v1`, `controlled-input-conformant`, unqualified production
review states, or deterministic recorder/adapter conformance. Prompt restrictions and
temporary-directory permissions are controls, not proof of the production isolation
boundary. Bootstrap artifacts remain degraded historical evidence and are never
upgraded or relabeled as v1.

The protected append-only transition history at
`refs/heads/loom/bootstrap-transition` is the only authority for use and retirement.
Each run and resume freshly validates its exact remote history and target containment.
Settlement of `local-review-orchestration` permanently requires production local
review; settlement of `sanitized-evaluation-workspace` permanently requires the
production export and gate-runner path; settlement of `evaluation-output-recorder`
permanently requires deterministic recording. Any stale run must rebuild/rebase onto a
fresh target containing those result SHAs and rerun affected checks. Missing,
unprotected, divergent, rewound, malformed, or unverifiable state/target fails closed.

When a hash-bound publication intent is current, no new or resumed bootstrap review,
evaluation, or recording may start; only exact intent recovery may proceed. The full
sunset is terminal once fresh target ancestry proves the results for
`local-review-orchestration`, `sanitized-evaluation-workspace`, and
`evaluation-output-recorder`, the transition state retires every component, and the
allowlist becomes empty. Stale state, local edits, missing receipts, owner assertion,
or production failure cannot revive the exception; that requires a new accepted ADR
and program/ref.

Any failed package, worker, gate, evaluator, recording, transition-state, or recovery
step is invalid/infrastructure-blocked, not clean or PASS. Safe diagnostics and exact
input bindings are retained, no unauthorized status advance occurs, incomplete
publication/settlement keeps its claim, and retry is permitted only for hash-identical
inputs. Otherwise a wholly new evaluation run is required.

## Unconditional gate rerun

Every code evaluator must rerun the declared gate through a bounded deterministic
runner:

1. Verify immutable judgment source against the input manifest.
2. Create a private disposable writable execution copy with identical source bytes.
3. Verify the starting copy's inventory and hashes.
4. Run the pinned gate command/environment/tool versions with build products, caches,
   temporary files, home/config paths, and declared outputs redirected to the copy or
   private scratch.
5. Record command/environment digest, start/end UTC times, tool versions, exit status,
   stdout/stderr hashes, and output inventory.
6. Re-verify immutable judgment source and managed checkout remain unchanged.
7. Discard the execution copy after evidence is recorded, pass or fail.

Prepared offline dependencies must allow the same gate checks when the normal build
would download inputs. The evaluator cannot choose different source, command,
environment, or dependencies. Prior gate evidence is comparison material only.
Inability to complete the rerun makes the evaluation invalid/infrastructure-blocked;
there is no `unsupported` substitute.

## Explicit exclusions

The export excludes `.git`, commit/author metadata, producer identity and role labels,
status/roadmap/handoff history unless itself under review, role transcripts,
orchestrator conversation, unrelated evaluations, uncommitted scratch state, client
session stores, credentials, and undeclared external caches.

The evaluator receives no network-specific client connectors/tools and cannot
delegate. Credentials are absent. Shell egress may remain a host residual unless a
release separately proves an OS sandbox; omission of network tools is not described as
an outbound-network sandbox.

## Deterministic construction and recording

The repository-owned exporter/evidence collector resolves revisions, captures
authorized evidence, normalizes identity-bearing metadata, applies permissions, and
writes the manifest before launch. The orchestrator supplies only export path,
evaluation type, and bounded instruction.

The evaluator writes exactly one schema-valid verdict to its output directory. A
deterministic recorder validates schema, evaluation type, run/input hashes, output
uniqueness/completeness, and legal transition before copying it to
`.docs/evaluations/<artifact-name>-eval.md`. The orchestrator commits it with the
uniform author-neutral identity. The evaluator never writes `.docs/`, status, or Git.

Missing, duplicate, truncated, malformed, mismatched, or cross-run output is not a
verdict and cannot advance the lifecycle.

## Verdict

A verdict records at least protocol/schema version, run ID and input-manifest hash,
reviewed exact revisions, PASS/FAIL, round, authority used, severity-tagged findings,
required changes for FAIL, local-review adjudication for code, gate-rerun evidence
reference, and residual notes. The canonical severity rubric alone maps confirmed
findings to PASS/FAIL.

## Trust boundary

The trusted computing base is Loom's exporter, evidence collector, schema validators,
gate runner, deterministic recorder, client launch adapter and permissions, host
OS/filesystem, and selected client/model service. The evaluator is trusted for
judgment, not repository mutation.

Loom does not defend against a malicious host administrator, compromised client/model
provider, undisclosed service-side context, authorship inference from writing style,
shell egress without a proven OS sandbox, or arbitrary hostile-code escape.

## Mechanical conformance

Each client adapter must pass canary tests proving forbidden identity/history/
transcript data and decoy checkout state are unavailable; `.git` and credentials are
absent; inputs reject mutation; current-tree queries bind to `evidence_sha`; external
captures expose provenance without evaluator network access; output is confined;
delegation/network-specific tools are denied; and the recorder rejects another run's
output.

Gate-runner fixtures must write beside source and into cache/temp/home/build paths and
prove all writes remain private, recorded, and discarded while judgment source and
managed checkout hashes remain unchanged. `loom doctor` reports required adapter
file/delegation/rerun enforcement separately from optional OS egress-sandbox support.

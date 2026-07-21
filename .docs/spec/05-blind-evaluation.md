# 05 — Controlled-Input Independent Evaluation

Status: Approved

## Authority

ADRs [0003](../ADR/0003-cold-handoffs-commit-per-handoff.md) and
[0004](../ADR/0004-blind-evaluation-role-separation.md), as corrected and extended
by [0021](../ADR/0021-loom-owned-local-review-protocol.md) and
[0022](../ADR/0022-controlled-input-independent-evaluation.md).

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

# 0022 — Controlled-Input Independent Evaluation and Its Isolation Boundary

Status: Draft
Date: 2026-07-21

## Context

ADR [0004](0004-blind-evaluation-role-separation.md) says blind evaluation is
enforced by prompt inputs and that cold anonymous agents make self-favoring
“impossible.” Approved specs 02 and 05 repeat that agents are blind “by
construction.” The current evaluator nevertheless runs against the real checkout, can
inspect `.git` and unrelated files, and writes directly into the repository. Prompt
selection and role labels are procedural controls, not a security boundary, and a cold
invocation can still use the same underlying client/model family as the author.

The [repository improvement plan](../repository-improvement-plan.md) requires an
accurate trust claim immediately and then a materially isolated, sanitized evaluation
workspace. ADR 0018 requires equivalent boundaries through separate Claude and Codex
launch adapters; ADR 0021 supplies versioned local-review input for code evaluation.

In scope are the claim Loom may make, trusted boundary, evaluator inputs and
permissions, output recording, role separation, and verification obligations. OS-level
hostile-code containment, cryptographic anonymity, statistical independence between
models, and remote attestation are out of scope and are not claimed.

## Decision

### 1. The claim is “independent cold-agent evaluation with controlled inputs”

Loom SHALL use that exact claim, not “blind evaluation,” “impartial by construction,”
“anonymous evaluator,” or “self-favoring is impossible,” in user-facing descriptions
unless the narrower term is immediately qualified by this boundary.

“Independent” means a fresh evaluator invocation, distinct from the producing role,
that receives no producer conversation and has no authority to approve its own output.
It does not mean a different human, vendor, base model, or statistically independent
reasoning process. “Cold” means no prior role transcript or conversational state is
intentionally supplied. “Controlled inputs” means Loom constructs an allowlisted
workspace and prompt; it does not mean the platform supplies a cryptographically sealed
or non-observable environment.

The existing no-self-approval policy remains mandatory: a producing invocation is never
routed as evaluator for its own artifact, and the orchestrator never supplies producer
reasoning. This is valuable separation of duties, not proof of impartiality.

### 2. The evaluator sees only a sanitized, per-run workspace

Every plan/research or code evaluation SHALL execute in a fresh exported directory,
outside the working repository, containing only inputs allowed for that evaluation
type. Common allowed inputs are the artifact under review, its upstream authority,
the applicable rubric/severity rules, and a machine-readable evaluation manifest that
hashes every supplied file. Re-review additionally allows the prior verdict and the
exact revision diff.

Code evaluation additionally allows source at the exact reviewed `head_sha`, the exact
base/head diff, approved slice-plan, relevant specs/ADRs, gate evidence, and a valid
ADR-0021 local-review artifact. Plan/research evaluation receives only the artifact,
its cited/upstream authority, rubric, and the re-review inputs just named; it does not
receive unrelated source/history by default.

The export SHALL exclude `.git`, commit and author metadata, status/roadmap/handoff
history unless itself the artifact or authority under review, role transcripts,
orchestrator conversation, unrelated evaluations, uncommitted developer scratch data,
client session stores, and credentials. Symlinks, hardlinks, sockets, devices, and paths
escaping the export root are rejected. Source and authority inputs are read-only. Each
evaluator receives one separate writable output directory and no write path into the
real checkout or another evaluator's run.

The evaluator may rerun the declared gate only when all build/cache/temp writes can be
redirected to a separate declared scratch directory. Network-specific client
tools/connectors are not granted and
credentials are absent. A gate that requires network must use pre-recorded evidence or
be explicitly classified unsupported rather than quietly widening the boundary. Shell
process egress is a stated residual host capability unless a release separately proves
an OS sandbox; this ADR does not call tool omission an outbound-network sandbox. The
client adapter SHALL deny delegation by evaluator children and grant only the
file/process capabilities needed inside the export.

### 3. Deterministic components construct and record; the evaluator only evaluates

A repository-owned exporter resolves exact commits/artifacts, copies the allowlist,
normalizes identity-bearing metadata, applies permissions, and writes the hashed input
manifest before evaluator launch. It fails closed on missing, mutable, extra, or
unresolvable input. The orchestrator supplies only the export path, evaluation type,
and bounded task instruction to the cold evaluator.

The evaluator writes one schema-valid verdict into its output directory. It does not
write `.docs/evaluations`, commit, change status, or mutate the managed repository. A
deterministic recorder validates the output schema and run/input hashes, copies it to
the correct `.docs/evaluations/` path, and the orchestrator commits it under the uniform
identity. Invalid, missing, duplicate, truncated, or mismatched output is not a verdict
and cannot advance lifecycle state.

### 4. The trust boundary and residual limitations are explicit

The trusted computing base is the Loom exporter, manifest/schema validator, client
launch adapter and permission configuration, deterministic recorder, host OS/filesystem,
and the selected client/model service. The evaluator is trusted for judgment but not
for repository mutation. Author-neutral commit conventions reduce identity leakage in
normal artifacts but are not relied on as the workspace boundary because `.git` is
absent.

This design materially isolates evaluation from accidental repository context and
writes. It does **not** defend against a malicious host administrator, a compromised
client/model provider, undisclosed service-side context, covert inference of authorship
from writing style, shell-level network egress where no OS sandbox is configured, or
arbitrary untrusted code escaping the host process boundary. It does not prove evaluator
impartiality. Therefore even after implementation Loom retains the controlled-input
independent-evaluation wording; “strong isolated blind evaluation” would require a
later ADR specifying and testing a stronger sandbox and attestation threat model.

### 5. The claim is mechanically verified per adapter

Conformance tests SHALL seed forbidden identity/history/transcript canaries outside and
inside a decoy real checkout, launch each supported client adapter, and prove they are
unreadable from the evaluator workspace. Tests SHALL also prove input hashes and
read-only files reject mutation, output is confined, child delegation and
network-specific client tools are denied, `.git` and credentials are absent, and the
recorder rejects an output from another run. `loom doctor` reports whether the active
adapter can enforce the required permissions and separately reports OS egress-sandbox
availability; inability to enforce the required file/delegation boundary is an error,
not a weaker silent mode.

## Consequences

- **Partially supersedes ADR 0004.** Preserved: controlled allowlisted inputs, no
  producer reasoning intentionally supplied, separate producing/evaluating invocations,
  structured verdicts, and no self-approval. Replaced: claims that prompt control alone
  enforces blindness, cold anonymity makes self-favoring impossible, or the current
  checkout/commit-metadata discipline forms a sufficient isolation boundary.
- ADR 0003's author-neutral commit convention remains defense in depth and protects
  ordinary handoffs, but evaluator isolation no longer depends on exposing or scrubbing
  real Git history.
- ADR 0010/0011's advisory-findings rule remains only as preserved and superseded by
  ADR 0021; the sanitized code-evaluation workspace receives a valid Loom-owned review
  artifact, never raw external-command state.
- Specs 00, 01, 02, 03, 04, and 05 and evaluator/playbook language require a later
  planner-authored amendment. Exporter, recorder, schemas, adapter permissions, and
  canary tests are separate implementation slices. No spec or code changes occur here.
- Evaluation becomes more reproducible and less able to leak or mutate, while the
  residual trust in host, client, and model is stated instead of hidden behind stronger
  language.

# 03 — Artifact Lifecycle & Status State Machine

Status: Approved

## Authority

ADRs [0003](../ADR/0003-cold-handoffs-commit-per-handoff.md),
[0005](../ADR/0005-specs-frozen-after-approval.md),
[0013](../ADR/0013-starvation-loop-guards-cold-restart.md),
[0017](../ADR/0017-infrastructure-blocked-escalation.md),
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md),
[0021](../ADR/0021-loom-owned-local-review-protocol.md), and
[0022](../ADR/0022-controlled-input-independent-evaluation.md), with the temporary
repository-only transition authorized by
[0023](../ADR/0023-repository-self-hosting-bootstrap-transition.md).

Status is a dispatcher, not proof by itself. The orchestrator combines artifact
status with commits, validated review/evaluation evidence, coordination state, and
remote publication receipts.

## Legal statuses

| Status | Meaning | Next actor |
|---|---|---|
| `Draft` | authoring/revision | researcher or planner |
| `Research Review` | research ready for source evaluation | plan evaluator |
| `Plan Review` | ADR/spec/plan ready for evaluation | plan evaluator |
| `Accepted` | ADR accepted and immutable | none; later ADR may supersede it |
| `Approved` | planning artifact accepted | developer for a slice |
| `Living` | operational artifact maintained in place outside gated review | deterministic finalizer |
| `In Progress` | slice implementation/revision active | developer |
| `Implemented` | developer gate green; exact committed head awaits review/evaluation | orchestrator |
| `Ready to Publish` | code evaluation passed; claim and evidence retained pending publication | orchestrator via landing helper |
| `Landed` | configured remote result independently verified and receipt recorded | orchestrator via deterministic cleanup |
| `Archived` | completed/abandoned plan stored under `archive/` | none |
| `Needs Clarification` | prior transition paused on a recorded question | authoritative clarifier |
| `Abandoned` | deliberately stopped and retained for history | none |

Only these exact tokens are valid. `Accepted` is reserved for ADRs; approved research,
specs, and plans use `Approved`. Review finder states and evaluation validity are
protocol fields, not artifact statuses.

## Research and planning

```text
Research: Draft -> Research Review -> Approved
                         | FAIL
                         v
                       Draft

ADR:       Draft -> Plan Review -> Accepted
                              | FAIL
                              v
                            Draft

Spec/plan: Draft -> Plan Review -> Approved
                               | FAIL
                               v
                             Draft
```

An accepted ADR is immutable. An approved spec is frozen and can re-enter the
planning cycle only through a planner-authored amendment. Research or evaluation
whose required captured evidence is unavailable is invalid/infrastructure-blocked,
not a merits FAIL and not round-counted.

## Code-bearing slice

```text
Approved -> In Progress -> Implemented
                              |
                              v
                 valid local-review/v1 run
                              |
                              v
                 isolated code evaluation
                       | FAIL      | PASS
                       v           v
                 In Progress  Ready to Publish
                                      |
                    build/rebuild one checked candidate containing
                    prospective Landed text and the plan already at
                    archive/<name> with prospective Archived status
                                      |
                    atomic configured-mode remote publication
                                      |
                    fresh verification against remote authority
                                      |
                    record local untracked receipt
                                      |
                                      v
                    Landed slice + published Archived plan authoritative
                                      |
                         release claim; idempotent local cleanup
```

For a pure-documentation slice the review companion records `skipped: docs-only` and
the code evaluator still runs when the slice requires code-evaluation authority. For
an applicable code slice, only a valid complete `loom-local-review/v1` run may enter
code evaluation. There is no command-unavailable terminal skip.

The diagram and rule above are the production v1 contract. The following exception
exists only to let this repository build that contract and is never available to a
Loom-managed project or released Loom workflow.

## Repository self-hosting bootstrap transition (non-release exception)

ADR 0023 temporarily permits `loom-repository-bootstrap/v1` for this Loom repository
and only for the following separately planned improvement-program slices:

| Milestone | Eligible slice IDs |
|---|---|
| M0 | `ci-baseline`; `client-floor-adapter-smoke` |
| M1 | `coord-identifier-boundaries`; `coord-lock-ownership`; `coord-schema-cas` |
| M2 | `remote-first-integration-candidate`; `coordination-state-separation` |
| M3 | `identity-guard-contract`; `precompact-per-session` |
| M4 | `local-review-helper`; `local-review-agents`; `local-review-orchestration`; `local-review-defect-battery` |
| M5 | `sanitized-evaluation-workspace`; `evaluation-output-recorder` |

The mode may also support the degraded cold ratification evaluation for ADR 0023 and
a slice-plan whose sole purpose is to authorize one listed slice. It does not apply to
research, another ADR/spec amendment, a renamed or combined slice, M6 or later work,
unlisted maintenance, another repository, or a managed project. The list is closed;
only another accepted ADR may change it. Bootstrap evidence is historical transition
evidence and can never become release, adapter, local-review/v1, or controlled-input
conformance evidence.

For an eligible code-bearing slice, and only while the corresponding transition-state
components remain available, the production review/evaluation arrows above may
temporarily be satisfied by all of the following, without changing the legal status
tokens or PASS/FAIL authority:

1. A clean committed `head_sha`, ancestor `base_sha`, `head_sha^{tree}`, exact
   full-index binary/mode/rename diff, ordered path inventory, hash-bound authority,
   and a recorded successful developer gate run against verified `head_sha` source.
2. Three separate cold, non-delegating auxiliary workers for correctness, tests, and
   security against the same immutable package, each with independent writable output.
   Missing, failed, malformed, hash-mismatched, duplicate, truncated, or source-mutating
   output invalidates the aggregate and never means clean.
3. A fresh cold code evaluator, distinct from the developer, workers, and root
   orchestrator, which adjudicates every advisory finding and reruns the declared gate
   against a fresh copy matching the committed source. Only its valid bound verdict
   supplies PASS or FAIL.
4. Companion and verdict artifacts that prominently identify
   `loom-repository-bootstrap/v1`, `degraded bootstrap; not loom-local-review/v1`, and
   `isolation not established under ADR 0022`. Unqualified production review states,
   `isolated`, `controlled-input-conformant`, and equivalent v1 claims are forbidden.

A valid bootstrap FAIL returns the slice to `In Progress`; a valid PASS may advance it
to `Ready to Publish`. Invalid or incomplete evidence cannot advance status. The
orchestrator retains exact inputs and safe diagnostics, checkpoints the failed step,
keeps the claim whenever publication or settlement is incomplete, and handles
infrastructure failure without a merits round or blind retry. It reruns a failed stage
only when all inputs remain hash-identical; otherwise it starts a new run.

Bootstrap eligibility and retirement come only from a freshly fetched, fully
validated history at the protected ordinary remote branch
`refs/heads/loom/bootstrap-transition`, never from local status, a selected base, or a
receipt. The branch rejects deletion and non-fast-forward updates. Its create-only
root and each single-parent, sequence-incrementing successor carry complete cumulative
state. Allowed slices can only be removed, results can only be added, components can
only move `available -> closing -> retired`, and full sunset can only move
`not-reached -> closing -> retired`.

Every eligible publication first appends and freshly verifies a hash-bound
`publication-intent`, which blocks all other new or resumed bootstrap work; it then
publishes and freshly verifies the configured target, records the receipt, and appends
and freshly verifies settlement before claim release and cleanup. If the target did
not change, an append-only abort may retain the intent and resume `active`; otherwise
recovery must reconcile that exact intent and the freshly read target. Missing,
unprotected, divergent, rewound, malformed, or unverifiable transition state, or a
target that no longer contains every settled result, blocks the exception.

Only M0, M1, and `remote-first-integration-candidate` may use ADR 0023's repository-only
`remote-direct` landing procedure. It never supports a protected-target fallback, PR,
merge queue, force update, another repository, or managed-project publication. After
settlement of `remote-first-integration-candidate`, every publication uses the
production landing helper and its failure is infrastructure-blocked.

Settlement retires bootstrap capabilities monotonically for every new or resumed run:

| Settled slice | Bootstrap capability permanently retired |
|---|---|
| `remote-first-integration-candidate` | bootstrap landing |
| `local-review-orchestration` | auxiliary bootstrap review |
| `sanitized-evaluation-workspace` | bootstrap export and gate rerun |
| `evaluation-output-recorder` | root-copy recording |

A run based before any retirement result is stale and must be rebuilt/rebased from a
fresh configured-target base containing every required result SHA; affected integrated
gates, review, and evaluation run again. During settlement of
`evaluation-output-recorder`, fresh target ancestry must prove that the target contains
the recorded results for `local-review-orchestration`,
`sanitized-evaluation-workspace`, and `evaluation-output-recorder`. The first such
target SHA becomes the full-sunset SHA; the terminal successor retires every component
and empties the allowlist. No stale checkpoint, target rewind, missing receipt, local
edit, owner flag, or production failure revives bootstrap. Revival requires a new
accepted ADR and a new program/ref.

### `Implemented`

`Implemented` binds one full committed `head_sha`, its review base, and green
developer gate evidence. The orchestrator prepares review from those exact commits.
Dirty state, symbolic refs, PR metadata, remote branches, or a current checkout do not
define the review target.

### `Ready to Publish`

A PASS recorded for the reviewed slice changes the active plan to
`Ready to Publish`. The slice claim remains held. This is a durable recovery state:
network failure, remote movement, provider delay, unavailable configured mode, branch
protection, or unverifiable publication preserves candidate evidence and the claim.
None of these conditions permits a `Landed` assertion or silent mode fallback.

### Candidate finalization and integrated evidence

The root orchestrator owns dispatch and recovery for landing and invokes the
deterministic landing helper; neither publication nor cleanup belongs to a lifecycle
role. The helper fetches the configured remote target, creates a disposable integration
worktree at its exact SHA, integrates only the slice, and prepares in the candidate:

- the slice change and final plan/evaluation evidence;
- archived plan and slice-index transition;
- progress, handoff, and roadmap changes;
- canonical project-instructions and both generated instruction adapters when the
  curated digest changed; and
- tracked finalization metadata required by spec 04. The pre-publication candidate
  manifest is local untracked recovery state, not another candidate artifact.

It runs the integrated gate against the exact candidate. Any review/evaluation whose
judgment could be affected by integration is rerun against the candidate. Immediately
before publication it re-fetches the target. Movement invalidates the candidate base:
rebuild from the new SHA and rerun all affected checks; never force-push or trust local
`main`.

The candidate may contain prospective `Landed`/`Archived` text so the final status and
code arrive in one target update. That text has no operational authority while local.
Until remote verification, the recoverable source state remains `Ready to Publish`.
The plan move into `slice-plans/archive/`, its `Archived` token, and related index
changes are all candidate contents. Fresh verification makes that already-published
archive state authoritative; no second tracked finalization commit is permitted.

The ordering is strict: build and check the atomic candidate with final tracked
`Landed`/`Archived` state; publish it atomically through the configured mode; verify
the candidate/result by a fresh read of the configured remote authority; write or
reconstruct the untracked common-Git-dir receipt; then release the claim and perform
idempotent local cleanup. No producing or evaluating role performs those steps, and
no receipt or cleanup change is added to the candidate.

### `Landed` and cleanup

`Landed` means the explicitly configured mode completed, a fresh remote read proves
the target contains the exact result SHA, and a publication receipt bound to slice,
candidate, evidence, mode, and target has been recorded only in the local untracked
coordinator/recovery state defined by spec [01](01-concepts.md). A local merge, green
test, provider response, push exit, or local status line is insufficient.

The receipt is written after verification and requires no target update. Only verified
publication plus that receipt releases the claim and begins idempotent local cleanup;
the published archived plan already exists before cleanup starts. Cleanup never edits
tracked lifecycle state. If the remote update succeeded before a crash, recovery
verifies containment, reconstructs
the receipt, and completes cleanup without republishing. If containment cannot be
proved, recovery pauses for the owner. Updating a clean local target branch afterward
is optional cache maintenance and cannot change landing truth.

## Review-run validity

Every required finder is one of `pending`, `ran-with-findings`, `ran-clean`, `failed`,
or `invalid`. The aggregate is `ran-with-findings` if at least one valid finder has
findings and otherwise `ran-clean` only when every required finder completed validly
and cleanly. Any pending, failed, invalid, missing, duplicate, truncated, malformed,
hash-mismatched, modified-source, or unknown-version result makes the whole run
`invalid`. Partial findings may be retained for diagnostics but cannot be assembled as
completed evidence or presented to the evaluator.

Infrastructure failures are checkpointed and paused under ADR 0017. Retry is allowed
only when classified safely retryable and does not turn missing work into clean.

## Evaluation-run validity

An evaluation is valid only when the exporter manifest, allowlisted input hashes,
permissions, required evidence, and output schema/run hashes validate. Code evaluation
also requires a completed gate rerun in a verified disposable writable copy. Missing,
duplicate, truncated, mismatched, cross-run, mutated-input, or unrecordable output is
not a verdict and cannot transition status.

The deterministic recorder installs a valid verdict under `.docs/evaluations/`, makes
the allowed status transition, and the orchestrator commits the handoff. The evaluator
itself never mutates the checkout.

## Dispatch rules

| Observed validated state | Dispatch |
|---|---|
| `Research Review` or `Plan Review` | export and launch plan evaluator |
| Approved slice-plan | developer |
| `Implemented`, docs-only | export and launch code evaluator with explicit skip companion |
| `Implemented`, code-bearing, no valid review | prepare/launch/validate/assemble local review |
| `Implemented`, valid review | export and launch code evaluator |
| `Ready to Publish` | orchestrator invokes helper to build/check, publish, verify, receipt, then clean up |
| remotely verified result with incomplete receipt/cleanup | orchestrator invokes helper to recover receipt, then clean up |
| `Needs Clarification` | recorded authoritative clarifier |
| rejected `Draft`/`In Progress` within scope | producing role |

Dispatch never derives landing, claims, or current authority from local `main`.

## Clarification sub-flow

The orchestrator persists the status that preceded `Needs Clarification`. A cold
authorized role answers under `## Notes`; the recorder/orchestrator commits the
answer, restores the prior status, and resumes. A clarification is not an evaluator
backchannel and does not supply producer conversation to an evaluator.

## Approval gates

Evaluator approval advances by default. At kickoff the owner may claim `all` gates or
named gates. The orchestrator pauses before crossing a claimed gate and surfaces the
artifact path and verdict. Owner override is explicit authority and is recorded; it is
never inferred from silence.

## Round limit

A round is one merits FAIL followed by revision. The first review begins at round 0;
each merits FAIL increments the artifact's single lifetime counter, and a resolving
PASS retains that round number. Plan and code review share the same counter for a
slice. PASS, invalid runs, infrastructure blocks, publication retries, and
clarifications do not increment it.

At the fifth FAIL the loop pauses. The owner receives the artifact/status, ordered
per-round phase and findings, recurring-versus-new classification, and concrete
choices: materially redirect (which may reset to 0), abandon, explicitly override, or
adjust authority/rubric. “Keep trying” without materially new direction does not reset
the counter.

## Other escalations

- **Starvation:** a cold restart re-derives the same action without a new advancing
  commit/checkpoint. Stop and summarize rather than repeat.
- **Infrastructure blocked:** spend/usage/quota, 429, transient 5xx,
  classifier-unavailable, missing required captured evidence/dependencies, unsupported
  required adapter capability, or partial workflow infrastructure failure. Do not
  treat it as PASS/FAIL/clean, do not consume a round, and do not retry blindly.

Every escalation writes the per-session checkpoint before pausing and states the
specific block, location/artifact status, preserved evidence, and exact resume action.
### ADR 0024 dogfood slice eligibility

After verified M0 settlement, the protected bootstrap state may admit exactly
`macos-dogfood-program-amendment` and `macos-dual-client-dogfood` while those names
remain in `allowed_slices` and required components remain available. The first is a
planner-owned documentation/spec set judged by a cold plan evaluator; no developer
edits frozen specs and code finders are `skipped: docs-only`. The second is
code-bearing and requires all three cold finders plus a distinct code evaluator.

Each slice independently follows Approved/Implemented-or-planning PASS, integrated
candidate, final exact gate, `publication-intent`, non-force remote-direct update,
fresh target verification, untracked receipt, settlement/removal, and only then claim
release. A local status token never establishes `Landed`. These are degraded bootstrap
records, not `loom-local-review/v1`, ADR-0022 isolation, or release conformance.

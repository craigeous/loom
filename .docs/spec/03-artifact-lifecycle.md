# 03 — Artifact Lifecycle & Status State Machine

Status: Draft

## Authority

ADRs [0003](../ADR/0003-cold-handoffs-commit-per-handoff.md),
[0005](../ADR/0005-specs-frozen-after-approval.md),
[0013](../ADR/0013-starvation-loop-guards-cold-restart.md),
[0017](../ADR/0017-infrastructure-blocked-escalation.md),
[0020](../ADR/0020-remote-publication-is-the-landing-authority.md),
[0021](../ADR/0021-loom-owned-local-review-protocol.md), and
[0022](../ADR/0022-controlled-input-independent-evaluation.md).

Status is a dispatcher, not proof by itself. The orchestrator combines artifact
status with commits, validated review/evaluation evidence, coordination state, and
remote publication receipts.

## Legal statuses

| Status | Meaning | Next actor |
|---|---|---|
| `Draft` | authoring/revision | researcher or planner |
| `Research Review` | research ready for source evaluation | plan evaluator |
| `Plan Review` | ADR/spec/plan ready for evaluation | plan evaluator |
| `Approved` | planning artifact accepted | developer for a slice |
| `In Progress` | slice implementation/revision active | developer |
| `Implemented` | developer gate green; exact committed head awaits review/evaluation | orchestrator |
| `Ready to Publish` | code evaluation passed; claim and evidence retained pending publication | orchestrator/publisher |
| `Landed` | configured remote result independently verified and receipt recorded | deterministic cleanup |
| `Archived` | completed/abandoned plan stored under `archive/` | none |
| `Needs Clarification` | prior transition paused on a recorded question | authoritative clarifier |
| `Abandoned` | deliberately stopped and retained for history | none |

Only these exact tokens are valid. Review finder states and evaluation validity are
protocol fields, not artifact statuses.

## Research and planning

```text
Research: Draft -> Research Review -> Approved
                         | FAIL
                         v
                       Draft

ADR/spec/plan: Draft -> Plan Review -> Approved
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
                    candidate rebuild / integrated checks as needed
                                      |
                    configured remote publication + verification
                                      |
                                      v
                                   Landed
                                      |
                              local cleanup complete
                                      v
                                   Archived
```

For a pure-documentation slice the review companion records `skipped: docs-only` and
the code evaluator still runs when the slice requires code-evaluation authority. For
an applicable code slice, only a valid complete `loom-local-review/v1` run may enter
code evaluation. There is no command-unavailable terminal skip.

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

The landing flow fetches the configured remote target, creates a disposable
integration worktree at its exact SHA, integrates only the slice, and prepares in the
candidate:

- the slice change and final plan/evaluation evidence;
- archived plan and slice-index transition;
- progress, handoff, and roadmap changes;
- canonical project-instructions and both generated instruction adapters when the
  curated digest changed; and
- candidate/publication metadata required by spec 04.

It runs the integrated gate against the exact candidate. Any review/evaluation whose
judgment could be affected by integration is rerun against the candidate. Immediately
before publication it re-fetches the target. Movement invalidates the candidate base:
rebuild from the new SHA and rerun all affected checks; never force-push or trust local
`main`.

The candidate may contain prospective `Landed`/`Archived` text so the final status and
code arrive in one target update. That text has no operational authority while local.
Until remote verification, the recoverable source state remains `Ready to Publish`.

### `Landed` and cleanup

`Landed` means the explicitly configured mode completed, a fresh remote read proves
the target contains the exact result SHA, and a publication receipt bound to slice,
candidate, evidence, mode, and target has been recorded. A local merge, green test,
provider response, push exit, or local status line is insufficient.

Only verified publication releases the claim and begins idempotent cleanup. If the
remote update succeeded before a crash, recovery verifies containment, reconstructs
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
| `Ready to Publish` | build/rebuild, check, publish, verify, receipt |
| remotely verified result with incomplete receipt/cleanup | recover receipt and cleanup |
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

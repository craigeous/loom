# 0017 — Infrastructure-Blocked Escalation, Degraded-Review Honesty, and Incremental-Commit Discipline

Status: Approved
Date: 2026-07-03

## Context

loom's escalation machinery so far recognizes exactly two ways a loop can go wrong,
both **content**-driven: the **5-FAIL round-limit escalation** ([spec 03](../spec/03-artifact-lifecycle.md)
§"Round limits" → *Escalation contract (pause + summary)*), which bounds thrashing on
one artifact, and the **starvation-loop escalation** ([ADR 0013](0013-starvation-loop-guards-cold-restart.md)
rule 3), which converts a no-progress cold-restart into one owner escalation. Both
assume the roles and tools *ran* — they adjudicate the **work product**.

A long `/loom:run` thread exposed a third failure mode that neither covers: an
**account-level infrastructure block**, where a role or tool does not fail *on the
merits* but is **killed by a limit outside loom's control**. Observed in one session:

- The monthly **spend/usage limit** killed a developer sub-agent mid-work; it returned
  a **bare error string**, not an artifact.
- A `/code-review` workflow had **all of its finder sub-agents crash on the same
  limit**, yet the workflow still returned a **"no findings survived verification"**
  summary — a **false-clean** that is indistinguishable, at the surface, from a genuine
  `ran-clean`.
- The per-response **32k output-token cap** crashed developer agents mid-edit **twice**,
  each time abandoning large uncommitted work-in-progress.

loom currently has **no rule** distinguishing an infrastructure block from (a) a normal
blind-eval FAIL, (b) a dead/uncooperative agent, or (c) a genuinely clean result.
The concrete risks: mistaking a limit-killed review for `ran-clean` and feeding a
**false-clean** to the blind code-evaluator (defeating the ADR 0010/[0011](0011-correct-automated-review-command-to-code-review.md)
review faithfulness invariant); **burning a round-limit count** on a failure that is
not the artifact's fault; **retry-looping** straight back into the same limit; and
**losing large uncommitted WIP** when an agent is killed mid-edit.

**In scope:** a new escalation *type* for infrastructure blocks, a degraded-review
honesty rule extending the review-findings faithfulness invariant, and a developer
incremental-commit discipline that shrinks the blast radius of a mid-work kill.
**Out of scope:** the frozen-spec amendments and the playbook wiring these decisions
imply — deferred to a later pure-docs slice (see Consequences). Preserves
ADR [0001](0001-plugin-architecture-and-orchestrator.md) (orchestrator-only spawn),
[0003](0003-cold-handoffs-commit-per-handoff.md), [0012](0012-thin-orchestrator-sonnet-default-bounded-return.md)
(bounded role return), and 0013.

## Decision

Three parts.

### 1. Infrastructure-blocked escalation — a new escalation type

When a role return, or a tool/workflow result, matches an **infrastructure-failure
signature**, the orchestrator MUST treat it as an infrastructure block, **not** as a
valid result. The signature is any of:

- an account **spend / usage / quota limit** reached;
- a **rate-limit / HTTP 429**;
- a **5xx** / transient upstream error;
- a **safety-classifier-unavailable** error (a review or guard command whose classifier
  could not run); or
- a **partial workflow failure** — a multi-agent workflow (e.g. `/code-review`) whose
  **sub-agents crashed on one of the above limits**, even if the workflow returns a
  plausible-looking summary.

On matching that signature the orchestrator MUST:

1. **Not treat it as a valid result.** It is not a normal FAIL, not `ran-clean`, and
   not a genuine finding set. The orchestrator does **not** count a round-limit FAIL
   against the artifact (spec 03 §"Round limits"), and does **not** fabricate or
   attribute findings from it.
2. **Stop spawning / halt the loop** rather than retry-looping into the same limit.
   A blind retry re-hits the block and wastes budget; the block clears by **owner
   action** (e.g. raising the limit), not by re-attempting.
3. **Write-ahead checkpoint** the current state to `status/handoff.md` per
   [ADR 0013](0013-starvation-loop-guards-cold-restart.md) rule 1, so that a resume
   once unblocked is **lossless** and picks up the exact pending action.
4. **Surface a pause + summary** to the owner naming (a) the **specific block** hit
   (which limit / signature), (b) **where** it fired (which role or command, which
   artifact + `Status:`), and (c) **how to resume** (e.g. raise the monthly limit in
   account settings, wait out a 429, then resume `/loom:run`).

This is a **sibling** to the spec-03 5-FAIL round-limit escalation and to ADR 0013's
starvation-loop escalation: **same pause + summary shape** (a checkpointed pause with a
decision-ready owner summary), **different trigger**. It is explicitly **NOT
round-counted** — an infrastructure block reflects account state, not the artifact's
quality, so it must never move the `Round:` counter toward the 5-FAIL threshold.

### 2. Degraded-review honesty — extends the review faithfulness invariant

A `/code-review` or `/security-review` run whose **finder or verify sub-agents FAILED
on an infrastructure limit is INVALID**, not clean. Extending the faithfulness
invariant of [ADR 0010](0010-orchestrator-run-automated-review-in-code-eval.md)/[0011](0011-correct-automated-review-command-to-code-review.md)
and [`review-findings.md`](../../plugins/loom/skills/loom-playbook/references/review-findings.md)
(*Findings come from real command output*), the orchestrator MUST:

- **not record `ran-clean`** for such a run — "no findings" from a run whose finders
  **never executed** is a false-clean, not a clean review;
- **not feed it to the blind code-evaluator** as review input; and
- **re-run** the command once unblocked, or record it as a **non-run** (the honest
  degraded state) until it can be re-run.

A degraded run is an instance of the Part 1 infrastructure block, so it triggers the
same pause + summary; it is never silently down-graded to a passing review. The four
`review-findings.md` status tokens (`ran-with-findings` / `ran-clean` /
`skipped: docs-only` / `skipped: command-unavailable`) remain the only honest terminal
states; an infra-degraded run is **not** any of them until re-run or recorded as a
non-run.

### 3. Incremental-commit developer discipline — blast-radius reduction

Developer (and other file-mutating) agents SHOULD **commit each gate-green or coherent
sub-step** rather than accumulating one big final commit, so that a mid-work kill (an
output-cap crash, a limit) leaves **committed progress** on the branch instead of
throwaway uncommitted WIP. This also directly mitigates the **32k output-token cap**:
prefer **small, targeted `Edit`s and terse returns** over emitting a whole file through
a single `Write`, which is the operation most likely to blow the per-response cap
mid-edit. This discipline is consistent with — and reinforced by — ADR 0003
(commit-per-handoff) and the ADR 0012 bounded-return contract; it tightens *intra*-role
commit granularity without changing the handoff boundary.

### Scope guard — detect-on-failure, not predict

loom **cannot proactively poll** billing, rate, session, or usage limits: it is a
plugin with **no interface to account limit state**. The only budget it can observe is
the **per-conversation context window** (ADR 0012/0013 self-restart; Sonnet
context-awareness). Therefore this decision is **detect-on-failure + graceful-pause
only** — it reacts to a block that has *already* fired. It is **not** prediction or
prevention, and it is an **orchestration rule, not a hook** (hooks are event-driven on
tool use, not budget timers, and cannot see account state either).

## Consequences

- loom gains a **third escalation type** alongside the round-limit (spec 03) and
  starvation-loop (ADR 0013) escalations, all sharing the pause + summary shape. An
  infrastructure block now produces one clean, checkpointed owner escalation instead of
  a false-clean, a mis-counted round, or a retry loop.
- The blind code-evaluator is **protected from false-clean review input**: a
  limit-degraded `/code-review`/`/security-review` can no longer masquerade as
  `ran-clean`.
- A mid-work agent kill costs **at most the current sub-step**, not a whole slice's
  uncommitted work, and the output-cap crash class is reduced by small-edit discipline.
- **Deferred to a later pure-docs slice** (frozen artifacts — ADR 0005 — change only
  via a planning cycle; **no code**):
  - the **spec amendment(s)** — spec 04 (orchestrator: add the infrastructure-blocked
    escalation to *Human checkpoints* and the *Thin-orchestrator invariant* neighborhood)
    and/or spec 03 (note the infra escalation as a sibling that is **not** round-counted,
    beside the *Escalation contract*);
  - the **playbook wiring** — `references/orchestration.md` (the escalation section +
    the *Actually invoke — never simulate* neighborhood), `agents/developer.md` plus the
    developer guidance for incremental commits, and a degraded-review note in
    `references/review-findings.md`.
- **Builds on** ADR 0013 (write-ahead checkpoint + escalation machinery — this adds a
  new trigger to the same shape), 0010/0011 (review faithfulness invariant — this
  extends it), 0012 (bounded role return), 0003 (commit-per-handoff), and 0001
  (orchestrator-only spawn). **Supersedes none.**
- **Bounded by design:** because loom cannot see account state, an infrastructure block
  can only ever be caught **on failure**; loom will always take at least one hit before
  it can pause. Reducing that first-hit cost is exactly what Part 3's incremental-commit
  discipline addresses.

# 03 — Artifact Lifecycle & Status State Machine

Status: Plan Review

Status is loom's dispatcher. Each gated artifact carries a `Status:` line; the
orchestrator reads it (and git state) to decide which role to spawn next. **Every
role pass ends in a commit** (ADR 0003), so status transitions are paired with
commits the next role can diff against.

## Statuses

| Status               | Meaning                                      | Next actor            |
|----------------------|----------------------------------------------|-----------------------|
| `Draft`              | Author is writing / revising                 | author (researcher/planner) |
| `Research Review`    | Research note ready for source check         | plan evaluator        |
| `Plan Review`        | Planning artifact ready for blind review     | plan evaluator        |
| `Approved`           | Artifact accepted                            | developer (if a slice)|
| `In Progress`        | Developer implementing                       | developer             |
| `Implemented`        | Gate green; awaiting code review             | code evaluator        |
| `Landed`             | Code approved; finalize pass underway        | developer (finalize)  |
| `Archived`           | Plan moved to `archive/`; history            | —                     |
| `Needs Clarification`| Blocked on a question in `## Notes`          | clarifying role       |
| `Abandoned`          | Dropped; kept for history                    | —                     |

## Research lifecycle

```
Draft ──▶ Research Review ──approve──▶ Approved (usable by planner)
   ▲             │
   └───reject────┘   (eval: sources missing or don't support claims)
```

Research approval is a light gate: citations present, sources exist and support
the summary.

## ADR / Spec lifecycle (no implementation)

```
Draft ──▶ Plan Review ──approve──▶ Approved
   ▲           │
   └──reject───┘   (eval notes written; planner revises)
```

- An **accepted ADR** is immutable. To change it, write a new ADR that supersedes
  it.
- An **approved spec is frozen** (ADR 0005). It changes only by re-entering this
  cycle in a new planning phase — never as a side effect of a slice landing, and
  never by a developer.

## Slice-plan lifecycle (the full loop)

```
Draft ──▶ Plan Review ──approve──▶ Approved ──▶ In Progress ──▶ Implemented
  ▲            │                                    ▲                │
  └──reject────┘                                    │                │ PASS
   (planner revises)                                │                ▼
                                                    │          Landed ──▶ Archived
                                                    │                │
                                       FAIL (eval notes)─────────────┘
```

`Implemented` is the awaiting-review status: the code evaluator holds the slice
under **code review** (a phase, not a status) and writes a verdict. On **PASS** it
sets `Landed`; on **FAIL** it sets `In Progress` with eval notes and the developer
fixes. The full string is therefore `… Implemented → (code review) → Landed →
Archived`, where *code review* names the evaluator's pass over an `Implemented`
artifact rather than a distinct `Status:`.

On **code-eval PASS** (the slice is `Landed`), the developer runs a **finalize
pass** (cold):
1. Update `status/progress.md` and `status/handoff.md` (and `roadmap.md` if a
   milestone closed).
2. Update the relevant `CLAUDE.md` **only when the landed slice changed something
   in the curated-digest scope** — i.e. it introduced or altered a durable
   convention, a repo-layout fact, a gate definition, or a "read-first" pointer.
   The change reflected into `CLAUDE.md` is the stable, agent-facing form of what
   landed; **per-slice history stays in `progress.md`** and the other living docs,
   never in `CLAUDE.md`. If the slice changed nothing in that scope, **no
   `CLAUDE.md` edit is made.** This applies to loom's own root `CLAUDE.md` and, in
   a managed project, to that project's `CLAUDE.md`. The curated-digest boundary is
   defined authoritatively in [08](08-playbook.md) (*Evolving the playbook*), whose
   *Shape and Concision Discipline* governs how the edit is written (point-don't-restate
   pointers, the size bound, the two-zone shape); the finalize pass applies it here.
3. `git mv` the plan into `slice-plans/archive/`, set status `Archived`, commit.

**No spec edit happens at landing.** The slice-plan and the living docs record
what was built; the spec only ever changes through a planning cycle. If
implementation showed the spec to be wrong, the developer stops and the orchestrator
opens a planning task instead of patching the spec.

The `CLAUDE.md` update in step 2 does **not** weaken this rule or ADR 0005.
`CLAUDE.md` is a **derived, non-spec digest** — a curated reflection of conventions
already decided in the specs and playbook — not an authoritative artifact. Updating
it at finalize is therefore in the same category as updating the living docs, not in
the category of spec authorship. The frozen artifacts (`.docs/spec/` and
`.docs/ADR/`) remain untouched at landing; the developer still **never** edits them.
On any conflict, the specs win and `CLAUDE.md` is corrected to match — it can never
become a competing source of truth.

> **Why this differs from the prototype:** ballboy folded slice outcomes back into
> its specs at landing. loom instead **freezes specs** (ADR 0005) and treats the
> spec as *intended design*, not *current state*. Divergence is surfaced as
> explicit planning work rather than silent spec drift.

## Clarification sub-flow

```
<prior status> ──role asks in ## Notes, sets──▶ Needs Clarification
                                                   │
                  orchestrator spawns clarifying role (cold)
                                                   │
                  answer written in ## Notes, commit
                                                   ▼
                  orchestrator restores the prior status, resumes the loop
```

The orchestrator records the status the artifact held when it became `Needs
Clarification` and restores that status once the clarifying role (usually the
planner) has answered in `## Notes` ([02](02-roles.md) — Clarification between
roles). The loop then resumes from the restored status via the dispatch rules
below.

## Dispatch rules (status → role)

| When it sees…                          | It spawns…       |
|----------------------------------------|------------------|
| `Research Review`                      | plan evaluator   |
| `Plan Review`                          | plan evaluator   |
| `Approved` slice-plan                  | developer        |
| `Implemented`                          | code evaluator   |
| `Landed`                               | developer (finalize) |
| `Needs Clarification`                  | clarifying role  |
| `Draft` (after a reject, within scope) | author           |

Approval authority: by default **evaluator approval advances the loop**. The owner
declares claimed gates at kickoff — `all` or a named list ([04](04-orchestrator.md));
at a claimed gate, the orchestrator pauses for owner sign-off before proceeding.

## Round limits

A **round** is one **reject→revise cycle**: a FAIL verdict followed by the
author's revision. The round counter exists to bound thrashing — after a fixed
number of FAILs on one artifact, the orchestrator escalates rather than looping
indefinitely.

### Counting rule

- **A FAIL opens (increments) a round.** When an evaluator returns FAIL, the
  round counter for that artifact goes up by one, and the author revises.
- **A PASS does not increment the counter.** A PASS that follows a FAIL is the
  **resolving review** of the round that FAIL opened; it closes that round
  rather than starting a new one. A PASS never carries a higher round number
  just for being the next eval pass.
- The **first** evaluation of a fresh artifact (no prior FAIL) is round 0 / not
  yet counted; only a FAIL moves the count to round 1. Round 0 is the
  initial clean-review state and **carries no FAIL findings**, so the counted
  rounds — and the escalation summary's per-round findings history — run 1..N. Concretely: a slice that
  is reviewed, FAILs once, is revised, and then PASSes is **1 round** — not
  three eval passes counted separately. (This corrects an earlier de-facto
  practice that numbered every eval pass sequentially, e.g. R1 FAIL → R2 PASS →
  R3 PASS; under this rule that same history is one round, resolved.)
- Each eval pass is still recorded in the eval file with its verdict; the
  `Round:` value written on a PASS that resolves a FAIL is the **same** number as
  the FAIL it resolves (the round is closed, not advanced).

So an independent orchestrator or evaluator counts identically every time:
`Round:` equals the number of FAILs the artifact has accumulated, and a
resolving PASS shares the FAIL's round number.

### Counter scope

- There is **one counter per artifact**, recorded as `Round:` in that artifact's
  **single eval file** (`.docs/evaluations/<artifact-name>-eval.md`).
- The counter **spans the artifact's entire life across both review phases** — a
  slice-plan that goes through plan review and then code review uses **one** eval
  file and **one** counter. Plan-review FAILs and code-review FAILs accumulate
  toward the **same** limit. It is **not** a fresh counter per phase: e.g. two
  plan-review FAILs plus three code-review FAILs is round 5 and triggers
  escalation, even though neither phase alone reached 5.

### Threshold

After **5** rounds (i.e. the 5th FAIL) for a given artifact, the orchestrator
**stops and escalates** to the owner instead of dispatching another revision.

### Reset rule

The counter **does not reset on its own** — not when the artifact PASSes a phase,
not when it crosses from plan review into code review, not on time. It only ever
moves forward as FAILs accumulate, for the life of that artifact.

The **one** way it resets is **owner-driven at an escalation**: when the
orchestrator escalates and the owner intervenes with **materially new direction**
(e.g. a redefined goal, a changed rubric, a new scope boundary for the artifact),
the orchestrator **may reset the counter to 0** as part of applying that
redirection — because the artifact is now being judged against a changed target,
the prior FAILs no longer represent failures against the current bar. An owner
who merely says "keep trying" without new direction does **not** reset the
counter; the next FAIL would re-trigger escalation. The orchestrator records the
reset and its cause in the eval file.

### Escalation contract (pause + summary)

This is the canonical definition of the round-limit escalation; spec
[04](04-orchestrator.md) ("Human checkpoints") points here. When the threshold is
reached the orchestrator **pauses the loop** and presents the owner a summary
that is sufficient to decide without re-reading the whole history. The summary
**must** contain:

1. **The stuck artifact and its current status** — which artifact, its path, and
   the `Status:` it now holds (e.g. a slice-plan back at `Draft` after a
   plan-review FAIL, or at `In Progress` after a code-review FAIL).
2. **Per-round findings history** — for each of the counted rounds (1..N; round
   0 carries no findings), the FAIL's verdict and the substantive findings that
   drove it (and the phase — plan vs. code — each FAIL occurred in), in order.
3. **A recurring-vs-new classification** — the orchestrator states whether the
   findings are **recurring** (the same defect surviving one or more revisions =
   **thrashing**) or **new each round** (each FAIL raises a different issue =
   genuine churn / a moving target). This tells the owner whether the artifact is
   stuck on one unsolved problem or accumulating distinct problems.
4. **Concrete owner options** — at minimum:
   - **Give new direction** — redefine the goal/scope/rubric (may reset the
     counter, per the reset rule above) and resume.
   - **Abandon the artifact** — set `Abandoned`; stop work on it.
   - **Override and accept** — owner overrides the evaluator and accepts the
     artifact as-is, advancing the loop (an owner authority, distinct from
     evaluator approval).
   - **Adjust authority or rubric** — change which gates are owner-claimed, or
     correct the rubric the evaluator is applying, then resume.

The orchestrator ensures `status/handoff.md` reflects the paused state and the
pending owner decision (consistent with the Human-checkpoints rule in
[04](04-orchestrator.md)).

## Infrastructure-blocked escalation (a sibling — not round-counted)

The round-limit escalation above is one of **three** escalation types loom
recognizes, all sharing the same **pause + summary** shape but firing on different
triggers. The other two are ADR 0013's **starvation-loop escalation** (a cold
restart that re-derives the same action with no new commit since — a no-progress
wedge) and the **infrastructure-blocked escalation** defined here
([ADR 0017](../ADR/0017-infrastructure-blocked-escalation.md)). Because this trigger
reflects **account state, not the artifact's quality**, it lives beside the
round-limit contract but is explicitly **not** round-counted.

An **infrastructure block** is a role return, or a tool/workflow result, that
matches an **infrastructure-failure signature** — any of:

- an account **spend / usage / quota limit** reached;
- a **rate-limit / HTTP 429**;
- a **5xx** / transient upstream error;
- a **safety-classifier-unavailable** error (a review or guard command whose
  classifier could not run); or
- a **partial workflow failure** — a multi-agent workflow (e.g. `/code-review`)
  whose sub-agents crashed on one of the above limits, even if the workflow returns
  a plausible-looking summary.

Such a result is **not a valid outcome**: it is not a blind-eval FAIL, not a
`ran-clean` review, and not a genuine finding set — the role or tool was killed by a
limit outside loom's control rather than failing on the merits. On matching the
signature the orchestrator MUST:

1. **Not consume a round.** An infrastructure block **never** increments the
   `Round:` counter toward the 5-FAIL threshold and never counts as a FAIL against
   the artifact — it is not the artifact's fault. It also does not fabricate or
   attribute any findings from the failed result.
2. **Halt rather than retry-loop.** A blind retry re-hits the same limit and wastes
   budget; the block clears by **owner action** (e.g. raising the limit, waiting out
   a 429), not by re-attempting.
3. **Write-ahead checkpoint** the current state to `status/handoff.md`
   ([ADR 0013](../ADR/0013-starvation-loop-guards-cold-restart.md) rule 1) so a
   resume once unblocked is lossless and picks up the exact pending action.
4. **Pause + summarize to the owner**, naming (a) the **specific block** hit (which
   limit / signature), (b) **where** it fired (which role or command, which artifact
   + `Status:`), and (c) **how to resume** (e.g. raise the monthly limit, wait out a
   429, then resume `/loom:run`).

This escalation is **detect-on-failure only**: loom is a plugin with **no interface
to account limit state** and **cannot poll or predict** a limit — it reacts to a
block that has *already* fired, so it always takes at least one hit before it can
pause. It is an orchestration rule, not a hook. See spec [04](04-orchestrator.md)
(*Human checkpoints* and *Automated review before a slice lands* — the degraded-review
case) for the orchestrator-side handling.

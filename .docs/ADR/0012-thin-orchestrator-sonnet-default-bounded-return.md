# 0012 — Thin Orchestrator: `sonnet` Default + Bounded Role-Return Contract

Status: Accepted
Date: 2026-06-11

## Context

ADR 0002 pinned each **role** to a model tier but deliberately left the
**orchestrator** (the main session running `/loom:run`, ADR 0001) untiered — its
model was whatever the interactive session happened to be. We now want the
orchestrator to default to the **`sonnet`** tier: orchestration is reliable
instruction-following, tool/role selection, and status routing — squarely Sonnet's
strength — not the judgment-heavy work (`opus`) that planning and blind evaluation
require.

The concern with a non-`opus` orchestrator is context budget: a default `sonnet`
window is smaller than an `opus` one, so a long session risks filling the
orchestrator's context. Raising the orchestrator's window is a **config lever**
(the owner can give it more, or run it on `opus`), but it is the wrong primary
answer. loom's architecture (ADR 0001/0003 — cold roles, files-and-git are truth)
is *designed* so the heavy material lives in sub-agents and in `.docs/`, never in
the orchestrator's window. A correctly-built orchestrator's context should grow
with the **number of artifacts in flight**, not with the **size of the work
product** — roughly flat across loop iterations, regardless of which tier backs it.

An audit of the shipped playbook found the dispatcher already lean (it routes off
`Status:` lines + git, never artifact bodies), but one channel was never
constrained: **the agent's final message is returned verbatim into the
orchestrator's context** (the Task-tool return). Nothing bounded it, so a chatty
role could inflate the orchestrator's window every iteration — context scaling with
steps, the exact failure this ADR closes.

In scope: the orchestrator's default tier; the invariant that keeps it thin; the
role-return contract; the treatment of the one inherently orchestrator-heavy step;
and loom's answer to context pressure. Out of scope: role tiers (ADR 0002 stands)
and the automated-review decision itself (ADR 0010/0011 stand — this ADR only marks
its run step *write-and-forget*).

## Decision

1. **The orchestrator defaults to the `sonnet` tier.** Set `model: sonnet` in
   `/loom:run`'s frontmatter (slash commands accept the tier enum per ADR 0002).
   This **extends ADR 0002's tier table** with an orchestrator row; it does not
   supersede it. `opus` remains reserved for the planner and both evaluators, where
   judgment quality moves the outcome. The owner may override (more window, or
   `opus`) — a lever, not a hard limit.

2. **Thin-orchestrator invariant.** The orchestrator's context must scale with the
   number of in-flight artifacts, not the size of the work product. Four rules
   enforce it:
   - **Pass references, never bodies.** The orchestrator hands each role `.docs/`
     **paths**; the cold role reads the artifact in its own isolated window. The
     orchestrator never inlines a plan, diff, research note, or eval **body** into
     its own context.
   - **Bounded role-return contract.** A role's final message to the orchestrator
     is a small, fixed schema only: the **new `Status:`**, the **artifact path(s)**
     it wrote, a **≤~150-token summary**, and the **one branch-relevant signal**
     (verdict / gate result / blocker / clarification question). Roles **must not
     echo their full output** — no pasted diffs, eval prose, research bodies, or
     file dumps. The body lives in `.docs/` for the next cold role to read directly.
   - **Route on the signal, not the prose.** The orchestrator branches off the
     `Status:` line plus the returned signal — never by reading the critique or
     diff body. (The owner-claimed-gate pause is the one place an artifact is
     surfaced, and only to the **owner**, terminal for that turn.)
   - **Re-scan the digest, not the bodies.** Each loop turn re-scans `Status:`
     lines + git (the `/loom:status` view), not artifact bodies.

3. **The automated-review step is write-and-forget.** Running `/code-review` +
   `/security-review` (ADR 0010/0011) is the one step that *must* execute in the
   orchestrator's own window, because sub-agents cannot spawn (ADR 0001). The
   orchestrator captures the output, writes the `-review-findings.md` artifact, and
   then **drops it** — it does not reason over, summarize, or branch on the findings
   text. The blind code-evaluator adjudicates them from the file.

4. **Context pressure is answered by a cold self-restart, not a lossy summary.**
   Because `.docs/` + git are truth, when the orchestrator's window grows large it
   **checkpoints to `status/handoff.md` and re-bootstraps** from the status digest,
   continuing the loop with a fresh window. This is a *perfect* reset (no signal
   lost — the durable state was never in the window) and is loom's answer to
   context limits in place of any numeric auto-compact threshold. Sonnet's
   context-awareness lets the orchestrator trigger this before degrading.

## Consequences

- A correctly-thin orchestrator stays roughly flat in context across iterations, so
  the default `sonnet` window comfortably drives long, multi-slice sessions; the
  cost/capability profile improves (orchestration no longer consumes `opus`).
- The bounded-return contract is now a **role obligation** (spec 02) and an
  **orchestrator expectation** (spec 04); a role that dumps its body is a defect,
  not a style nit.
- "If the orchestrator's context grows with the work rather than staying flat,
  that's the bug" becomes a checkable invariant, independent of model choice.
- Builds on ADR 0001 (spawn model), 0003 (cold handoffs / files-are-truth),
  0004 (blind routing), and 0010/0011 (the review step it marks write-and-forget).
  **Extends — does not supersede — ADR 0002** (adds the orchestrator tier row).
- Specs 02 (Roles) and 04 (Orchestrator) are updated to carry the return contract
  and the thin-orchestrator invariant; `CLAUDE.md` and the playbook
  (`orchestration.md`, `run.md`, the five agents) are wired to match.

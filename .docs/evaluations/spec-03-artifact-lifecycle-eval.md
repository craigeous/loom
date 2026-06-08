# Evaluation: 03 — Artifact Lifecycle & Status State Machine

Verdict: FAIL
Round: 1
Reviewed against: ADR 0003 (commit-per-handoff), ADR 0005 (frozen specs);
references/status-machine.md, references/orchestration.md, SKILL.md;
agents/{researcher,planner,plan-evaluator,developer,code-evaluator}.md;
sibling specs 01-concepts, 02-roles, 05-blind-evaluation; severity.md +
plan-eval-rubric.md.

## Findings

- [BLOCKER] `Code Review` is declared as a first-class **Status** that no part of
  the built system actually sets or dispatches on — Statuses table, line 20
  (`| Code Review | Code under blind review | code evaluator |`) and the
  slice-plan diagram, lines 53–62. The authoritative `status-machine.md` does
  **not** list `Code Review` in its status table (lines 8–19) nor its dispatch
  table (lines 23–31); `Code Review` appears there only as a phase label inside a
  lifecycle *string* (line 50). No agent ever persists `Status: Code Review`: the
  developer sets `Implemented` and exits (developer.md step 5), the orchestrator
  dispatches the code evaluator off `Implemented` (status-machine.md dispatch
  table; orchestration), and the code evaluator transitions `Implemented → Landed`
  (PASS) or `Implemented → In Progress` (FAIL) directly (code-evaluator.md step 5;
  spec 02-roles lines 115–117). Promoting `Code Review` to a status makes the
  authoritative state machine carry a status that is unreachable (nobody writes it)
  and unconsumed (no dispatch row), contradicting both the reference and Approved
  spec 02. Because this spec *is* the canonical status set the whole loop runs on,
  this is a state-machine fidelity/consistency defect, not a nit. Fix:
  `Implemented` is the awaiting-review status; "Code Review" should be described as
  the phase during which the evaluator holds an `Implemented` artifact, not as a
  distinct `Status:` row. (Equivalently, if the design intends a real `Code Review`
  status, that is a change to the built system and must go through the agents +
  status-machine.md first — a spec may not unilaterally introduce a status no role
  sets.)

- [BLOCKER] Internal contradiction between the Statuses table and the Dispatch
  rules table within this same spec. Line 20 declares the next actor for
  `Code Review` is the code evaluator, but the Dispatch rules (lines 93–101) have
  **no `Code Review` row** and instead route the code evaluator off `Implemented`
  (line 98). The spec therefore names a status whose handler is absent from its own
  dispatch table. An orchestrator implementer reading this spec cannot determine
  who, if anyone, sets `Code Review` or what spawns on it. (Resolving the first
  BLOCKER resolves this one.)

- [MAJOR] The slice-plan diagram's FAIL edge is mis-anchored relative to the built
  system. Lines 53–62 route "reject (eval notes)" out of the `Code Review` node
  back into the line feeding `In Progress`. The actual contract is `Implemented`
  (artifact under review) `→ In Progress` on FAIL, set by the code evaluator
  (code-evaluator.md step 5; spec 02-roles line 116; status-machine.md line 51:
  "FAIL edges back to `Draft` (plan) or `In Progress` (code)"). With `Code Review`
  removed as a status, the FAIL/PASS edges must originate from `Implemented`. As
  drawn, the diagram implies a transition out of a status that is never entered.

- [MINOR] The clarification sub-flow's restore mechanic (lines 82–88: "status
  restored, prior status resumes") is not grounded in any agent or reference. The
  agents only describe *setting* `Needs Clarification` with a `## Notes` question
  (developer.md step 3; planner.md "Clarify"); none describes who records the prior
  status or how it is restored. State which status is restored and which actor
  restores it (presumably the clarifying role on commit, or the orchestrator), or
  cross-reference 04-orchestrator, so the "resumes" step is executable rather than
  implied.

- [MINOR] `Implemented` meaning (line 19, "Developer done; gate green; awaiting
  review") reads fine on its own, but once `Code Review` is removed as a status
  this row carries the "awaiting code review" semantics in full and should match
  status-machine.md line 15 ("Gate green; awaiting code review") verbatim to avoid
  re-introducing the two-status ambiguity.

## Required changes (for FAIL)

1. Remove `Code Review` from the **Statuses** table (line 20). Treat "Code Review"
   only as the descriptive phase during which an `Implemented` artifact is under
   blind review; make `Implemented` the explicit "awaiting code review" status,
   matching status-machine.md and spec 02-roles.
2. Redraw the slice-plan lifecycle diagram (lines 53–62) so PASS and FAIL edges
   originate from `Implemented`: `Implemented → Landed → Archived` on PASS and
   `Implemented → In Progress` on FAIL. Remove the `Code Review` node.
3. Reconcile the prose at lines 64 ("On **approve at Code Review**…") so it reads
   as "on code-eval PASS" / "on approval of the `Implemented` slice," consistent
   with the status set after the edit. (The finalize-pass content itself is correct
   and matches developer.md and ADR 0005 — keep it.)
4. Confirm the Statuses table and the Dispatch rules table list the same set of
   actor-bearing statuses with no orphan (a status with a next actor but no
   dispatch row, or vice versa).
5. Ground or cross-reference the clarification restore step (which prior status,
   which actor restores it).

## Notes

What is correct and should be preserved: the ADR-0003 framing (status transitions
paired with commits, lines 5–8); the ADR-0005 landing model — no spec edit at
landing, divergence surfaced as planning work, the ballboy contrast (lines 45–49,
64–77) — which matches ADR 0005 faithfully; the research and ADR/spec sublifecycles
(lines 26–49); the dispatch rows for `Research Review`, `Plan Review`, `Approved`
slice-plan, `Implemented`, `Landed`, `Needs Clarification`, and post-reject `Draft`
(all match status-machine.md and orchestration.md); the round-limit (5 → pause +
summary) and claimed-gates authority model (lines 103–111) match status-machine.md
and orchestration.md; no stale bare `/loom` or "skill" usage was found. The single
load-bearing defect is the promotion of `Code Review` from a phase label to a
status, which fractures the authoritative state machine; everything downstream of
that (findings 2 and the MAJOR diagram edge) flows from it.

---

# Round 2 re-review

Verdict: PASS
Round: 2
Reviewed against the same authority set, focusing on the commit `05fef29` diff
versus the Round 1 findings: references/status-machine.md (status + dispatch
tables, lifecycle strings), agents/code-evaluator.md, agents/developer.md,
Approved spec 02-roles.

## Resolution of prior findings (cite: `git show 05fef29`)

- [BLOCKER] `Code Review` as a first-class Status — **RESOLVED.** The diff removes
  the `| Code Review | … |` row from the Statuses table; the `Implemented` row now
  reads "Gate green; awaiting code review → code evaluator", matching
  status-machine.md line 15 verbatim. No status exists that no role sets.

- [BLOCKER] Statuses↔Dispatch contradiction on the code evaluator's trigger —
  **RESOLVED.** Neither table now carries `Code Review`. The actor-bearing
  statuses and the dispatch rows form the same set with no orphan, and the
  dispatch table is row-for-row identical to status-machine.md lines 23–31. The
  code evaluator is dispatched off `Implemented` in both tables and in
  code-evaluator.md ("When to invoke: a slice is at `Implemented`").

- [MAJOR] Slice-plan diagram edges anchored on the phantom `Code Review` node —
  **RESOLVED.** The redrawn diagram (current lines 52–60) originates PASS from
  `Implemented → Landed → Archived` and FAIL from `Implemented → In Progress`, with
  no `Code Review` node. This matches status-machine.md line 51 ("FAIL edges back
  to `Draft` (plan) or `In Progress` (code)") and code-evaluator.md step 5
  (`Landed` on PASS, `In Progress` on FAIL). The follow-on prose (current lines
  62–67) names "code review" as a phase over an `Implemented` artifact, not a
  `Status:`, and line 69 now reads "On **code-eval PASS**" (was "approve at Code
  Review").

- [MINOR] Ungrounded "prior status resumes" mechanic — **RESOLVED.** Current lines
  96–101 state the orchestrator records the held status and restores it after the
  clarifying role answers, cross-referencing 02-roles, which matches 02-roles line
  126 ("then restores the prior status").

- [MINOR] `Implemented` row wording — **RESOLVED.** Now verbatim with
  status-machine.md line 15 ("Gate green; awaiting code review").

## Notes

The spec's parenthesized phase label `… Implemented → (code review) → Landed →
Archived` is consistent with — and more precise than — status-machine.md's
lifecycle string (line 50), which itself uses `Code Review` only as a stage label
inside a string, never in its status or dispatch tables. No new findings. The
status machine is internally consistent (Statuses table, Dispatch table, and all
three lifecycle diagrams agree) and matches status-machine.md, code-evaluator.md,
developer.md, and Approved spec 02-roles.

<!--
Rules (full definitions in references/severity.md):
- Any unresolved [BLOCKER], or any unaddressed [MAJOR] ⇒ Verdict: FAIL.
- PASS means no blockers and no unaddressed majors; [MINOR]s don't block.
- Use the literal Verdict: PASS / FAIL regardless of how the request was phrased.
- On a re-review, confirm each prior BLOCKER/MAJOR was resolved (cite the diff).
-->

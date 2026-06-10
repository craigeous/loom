# Evaluation: 0010 — Orchestrator-Run Automated Review Feeds the Blind Code-Evaluator

Verdict: PASS
Round: 0
Reviewed against: `.docs/research/2026-06-10-review-security-review-in-code-eval.md` (Approved); ADR 0001 (orchestrator-only spawning), ADR 0004 (blind contract), ADR 0002 (tiers/cost), ADR 0003 (committed author-neutral handoffs), ADR 0008 (per-slice coordination files); spec 03 (`Implemented → code review → Landed`); spec 02 (roles — code-evaluator inputs); spec 04 (orchestrator driver loop); `references/plan-eval-rubric.md`; `references/severity.md`.

## Findings

- [MINOR] §2 fixes the findings-artifact path as a *proposed* convention
  (`.docs/evaluations/<slice-name>-review-findings.md`) while also delegating the
  exact filename to the follow-on slice. This is internally consistent (the ADR
  fixes only "committed, evaluator-readable, identity-neutral, per-slice file") but
  the word "proposed" on a path that sits in the same evaluations namespace as the
  eval file could read as half-decided. Non-load-bearing; the binding decision
  (committed identity-neutral input artifact) is unambiguous.
- [MINOR] §5 and §7 both have the orchestrator write a findings artifact recording a
  *skip* (docs-only vs unavailable), and §7 says the evaluator "distinguishes" the
  two reasons — but the ADR does not fix that the skip-reason field is machine- or
  evaluator-distinguishable beyond "the artifact says which." This is correctly
  deferred to the follow-on format slice; flagged only so the follow-on planner
  preserves the two distinct skip reasons explicitly.

## Required changes (for FAIL)

None. No BLOCKER or MAJOR findings.

## Notes

Checked the points the review specifically required, against the cited authorities:

- **Traceable / decisive (rubric "ADRs").** The ADR cites the Approved research note
  and the owner problem, and every in-scope design point is actually decided: who
  runs the commands (orchestrator, §1), when (`Implemented`, before land, §1), the
  handoff path (committed identity-neutral findings artifact as an additional
  evaluator input, §2), blindness invariant (§3), advisory-not-auto-FAIL with the
  evaluator owning the verdict (§4), the docs-only skip-with-a-note (§5), cost (§6),
  degradation on unavailability (§7), and the gate relationship (§8, gate unchanged).
  A reader could implement it; the only deferred items are explicitly named as
  playbook/spec follow-ons.

- **One-spawner invariant (ADR 0001).** Confirmed not weakened. The decision keeps
  spawning with the orchestrator and explicitly forbids the code-evaluator (a
  sub-agent) from running the commands (§1, lines 64-69; Alternatives §1; Consequences
  "Builds on"). The reasoning matches ADR 0001 (only the main session spawns) and the
  research note's "nested-spawn blocker" (§"The nested-spawn blocker"). The
  code-evaluator is never asked to run a spawning command.

- **Blind contract (ADR 0004).** Soundly preserved. The mechanism is local-diff-mode
  only, never PR/`--comment`/`--fix` (§1, §3), on a diff that is already author-neutral
  (ADR 0003/0004), with an identity-scrubbed findings artifact and no GitHub
  round-trip. This matches the research note's blind-contract section (PR mode leaks
  identity; local mode does not) and ADR 0004's controlled-inputs rule. I found no
  path where author identity could leak into the evaluator.

- **Verdict authority (spec 03 / severity.md).** §4 states the findings are advisory
  input the evaluator must adjudicate (confirm/reject, map confirmed findings to
  `severity.md`, discard false positives with a recorded reason), and that
  `severity.md` remains the single source of verdict authority — not an oracle or
  auto-FAIL. Consistent with spec 03's `Implemented → (code review) → Landed` phase
  and with the existing code-evaluator loop in spec 02 (lines 107-117). No new
  `Status:` value is introduced (Consequences), so it fits the existing lifecycle.

- **Honesty about the UNVERIFIED point.** Verified against the research note's
  labeling: the note marks the built-ins' internal spawn behavior UNVERIFIED
  (§"Do these commands spawn sub-agents?", Open questions) and says the recommendation
  does not depend on resolving it. The ADR matches exactly (Context constraint 1,
  §1 lines 66-69, Alternatives §1, "Honest note", Notes) — it never claims the
  built-ins spawn and states the decision is safe regardless. No overclaim.

- **Scope discipline.** The ADR edits no spec and no index; spec 04/02 amendments and
  the playbook bodies are listed as Consequences/Out-of-scope, deferred to follow-on
  planning per ADR 0005 (Context "Out of scope", Consequences). It correctly states
  it builds on ADR 0001/0004/0002/0003/0008 and supersedes no ADR.

- **Alternatives recorded.** All three research-note paths are present with
  chosen/rejected rationale: (1) orchestrator-run — CHOSEN with why-it-wins;
  (2) loom-native non-spawning — rejected (narrower, duplicate maintenance);
  (3) amend ADR 0001 — rejected (erodes one-spawner invariant). Matches the research
  note's three viable paths and "Not recommended" labeling for path (3).

Mechanical checks: confirmed no prior eval file for this ADR (fresh → Round 0);
confirmed spec 02 = roles (code-evaluator Reads list, lines 107-109) and spec 04 =
orchestrator, matching the ADR's citations; confirmed the code-evaluator frontmatter
is `tools: Read, Grep, Glob, Bash, Write, Edit` (no `Agent` tool), exactly as the ADR
and research note state; confirmed spec 03 defines `Implemented → (code review) →
Landed` as a phase, not a new status, matching the ADR's "no status-machine change."

Status left at `Plan Review` — this is an owner-gated ADR; the verdict is advisory to
the owner's sign-off, not a status flip by the evaluator.

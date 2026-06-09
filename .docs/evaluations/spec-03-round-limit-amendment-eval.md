# Evaluation: 03 — Artifact Lifecycle, `## Round limits` amendment

Verdict: PASS
Round: 1
Reviewed against: the round-limit/escalation requirement (FAIL-only counting,
threshold 5, per-artifact cross-phase single-counter scope, reset rule,
escalation pause+summary contract); ADR 0005 (specs frozen → re-enter Plan
Review); the rest of spec 03 for internal consistency (lifecycle diagrams' FAIL
edges); spec 04 "Human checkpoints" pointer; spec 09 Q6; plan-eval-rubric.md +
severity.md. Mechanical checks via `git show 5de67fd` and `rg`.

## Findings

- [MINOR] Counting rule, lines 134 and 161: the section uses "round 0 / not yet
  counted" for the pre-FAIL state and elsewhere refers to "for each of the
  rounds" (line 191). Round 0 is, by the rule's own arithmetic, not a
  reject→revise cycle and produces no FAIL findings, so the per-round history in
  the escalation summary spans rounds 1..5 only. The text is not wrong, but a
  reader could momentarily wonder whether "round 0" appears in the findings
  history. A half-sentence noting that round 0 carries no findings (it is the
  initial clean review state) would remove the only residual ambiguity. Does not
  block.

## Required changes (for FAIL)

None. (The single MINOR above is optional polish.)

## Notes

The amendment encodes all five requirement points faithfully and completely, and
the arithmetic is coherent end-to-end:

- **Faithfulness of the counting rule (scrutinized).** Lines 128–146 state a FAIL
  increments the counter and a PASS does not; a resolving PASS shares the FAIL's
  round number ("the round is closed, not advanced"). No wording reads as a PASS
  incrementing, and no wording implies a per-phase reset — the closing sentence
  ("`Round:` equals the number of FAILs the artifact has accumulated") is an
  unambiguous, independently-computable invariant. This correctly supersedes the
  earlier sequential-numbering practice (explicitly called out, lines 137–139).

- **Round-0 formalization (scrutinized for off-by-one).** Round 0 = fresh artifact,
  no prior FAIL; FAIL #n ⇒ round n; the 5th FAIL ⇒ round 5 ⇒ escalate (lines 134,
  161). The threshold prose "After **5** rounds (i.e. the 5th FAIL)" is consistent
  with both the round-0 start and the requirement's threshold of 5. No off-by-one.

- **Threshold (point 2).** Unchanged at 5 (line 161); consistent with spec 09 Q6
  ("Default 5") and the frozen prior text.

- **Counter scope (point 3).** Lines 148–157 fix one counter per artifact in its
  single eval file, spanning both review phases, with the worked example "two
  plan-review FAILs plus three code-review FAILs is round 5" — exactly the
  cross-phase accumulation required, and explicitly *not* a fresh per-phase
  counter.

- **Reset rule (point 4).** Lines 164–178 define it: no self-reset (not on PASS,
  not on phase crossing, not on time); the sole reset is owner-driven at an
  escalation when the owner gives materially-new direction, with "keep trying"
  explicitly *not* resetting, and the reset + cause recorded in the eval file.
  Sound and unambiguous.

- **Escalation contract (point 5).** Lines 180–211 supply all four required
  elements — (1) stuck artifact + path + current Status, (2) per-round findings
  history with phase, (3) recurring-vs-new (thrashing vs. churn) classification,
  (4) concrete owner options — and are genuinely actionable.

- **ADR 0005 conformance.** Status correctly flipped Approved → Plan Review (the
  spec re-enters the planning cycle to change a frozen spec). The eval does not
  touch the Status line.

- **Internal consistency.** `git show 5de67fd --stat` confirms the change is
  confined to the `## Round limits` section plus the Status line — the lifecycle
  diagrams are untouched, so the FAIL edges (plan FAIL → `Draft`, code FAIL →
  `In Progress`) remain intact and are correctly referenced by escalation-summary
  item 1.

- **Spec 04 pointer.** Spec 04 "Human checkpoints" (line 109) says "escalation =
  pause + summary, see [03]"; the amendment makes spec 03 the canonical, fuller
  definition and explicitly back-references 04. The pointer's accuracy is
  preserved and spec 04 needed no change.

- **No over-reach.** The owner options ("Abandon" → existing `Abandoned` status;
  "Override and accept" / "Adjust authority or rubric" → elaborations of the
  owner's existing claimed-gate / sign-off authority in spec 04 and spec 03 lines
  116–117) introduce no new lifecycle rule, status, or threshold. The amendment
  defines round-limit/escalation only.

<!--
Rules (full definitions in references/severity.md):
- Any unresolved [BLOCKER], or any unaddressed [MAJOR] ⇒ Verdict: FAIL.
- PASS means no blockers and no unaddressed majors; [MINOR]s don't block.
- Use the literal Verdict: PASS / FAIL regardless of how the request was phrased.
-->

---

# Evaluation: spec-03 round-limit amendment (confirming re-review)

Verdict: PASS
Round: 0 (no FAIL — confirming review)
Reviewed against: the Round-1 MINOR (round 0 carries no findings; the per-round
findings history should span the counted rounds 1..N, not round 0); the fold diff
`git show df72df0` (and `--stat`); the `## Round limits` section of spec 03.

## MINOR resolution

The single Round-1 MINOR is **resolved**. The fold (`df72df0`, 6 insertions / 4
deletions, confined to one file) makes exactly two edits, both in the
`## Round limits` section:

- The round-0 bullet now states "Round 0 is the initial clean-review state and
  **carries no FAIL findings**, so the counted rounds — and the escalation
  summary's per-round findings history — run 1..N." This is the half-sentence the
  Round-1 MINOR asked for.
- Escalation-summary item 2 changed "for each of the rounds" → "for each of the
  counted rounds (1..N; round 0 carries no findings)", removing the residual
  ambiguity flagged at line 191.

## No regression / no scope creep

`git show --stat df72df0` confirms a single file, +6/−4, inside the `## Round
limits` section only. The substantive rules are untouched: the counting rule (a
FAIL increments, a PASS does not), the per-artifact cross-phase single-counter
scope, the threshold of 5, the reset rule (owner-driven only, on materially-new
direction), and the four escalation-summary elements / owner options all read as
in the Round-1-approved version. No lifecycle diagram, status, or threshold
changed. The spec's `Status:` line was not modified by this review.

## Round-counting note

Per the rule the amendment itself defines (a round is a FAIL→revise cycle; a PASS
opens no new round), this artifact has had no FAIL — Round 1 was a PASS with an
advisory MINOR, and this fold is polish, not a revision of a FAIL. Recorded as a
confirming re-review at round 0, demonstrating the rule under approval. (The
playbook/agent prompts do not yet encode this; that is a separate follow-up.)

# Evaluation: ADR 0017 spec amendment (specs 03 + 04)

Verdict: PASS
Round: 0
Reviewed against: .docs/ADR/0017-infrastructure-blocked-escalation.md (Approved/immutable);
.docs/spec/03 existing "Round limits" contract; plugins/loom/skills/loom-playbook/references/review-findings.md
four-token contract (+ ADR 0010/0011 faithfulness invariant); ADR 0013 (write-ahead/escalation);
ADR 0005 (amendment discipline).

## Findings

- [MINOR] Semantic stretch of `skipped: command-unavailable`. `review-findings.md`
  glosses that token as "Built-in **not available** in this environment (ADR 0010 §7)"
  — i.e. the command is absent/uninstalled. The amendment reuses it for a *present but
  limit-killed, non-re-runnable* run ("the command effectively could not complete in
  this environment"). This is a coherent extension, not a contradiction: both cases are
  "the command did not run to completion → skipped, non-run", and the amendment is
  explicit that it **reuses** the four-token set rather than adding a token — which is
  exactly what ADR 0017 Decision 2 mandates ("record it as a non-run … the four tokens
  remain the only honest terminal states"). Non-blocking; noted only because the
  reference's token gloss could optionally be broadened in the playbook-wiring slice so
  the two meanings are co-located. No change required for approval.

## Verification performed

- **Faithfulness (spec 03 new §"Infrastructure-blocked escalation").** Mechanically
  confirmed the section is purely additive (`git diff` shows only an append after the
  round-limit *Escalation contract*, plus the `Status:` flip). It states, faithfully to
  ADR 0017 Decision 1: the full infra-signature set (spend/usage/quota, 429, 5xx,
  safety-classifier-unavailable, partial-workflow false-clean); "not a valid outcome"
  (not a FAIL, not `ran-clean`, not a genuine finding set); (1) no round consumed / no
  fabricated findings; (2) halt-not-retry; (3) write-ahead checkpoint to `handoff.md`
  (ADR 0013 rule 1); (4) pause+summary naming block/where/how-to-resume; and
  detect-on-failure-only ("no interface to account limit state", "orchestration rule,
  not a hook"). Framed correctly as a **sibling** — "three escalation types … same
  pause+summary shape … explicitly not round-counted."

- **Faithfulness (spec 04).** Human-checkpoints gains the infra-block trigger with the
  correct "same pause+summary shape but **not** round-counted" qualifier and a summary
  paragraph accurate to ADR 0017 (detect-on-failure, no valid-result treatment, no
  round consumed, halt, write-ahead, pause+summarize). The degraded-review rule in
  *Automated review before a slice lands* matches ADR 0017 Decision 2: INVALID / never
  `ran-clean` / never fed to the blind evaluator / re-run once unblocked; correctly cast
  as an instance of the infra escalation extending the ADR 0010/0011 faithfulness
  invariant.

- **MINOR 1 resolution (token reuse) — sound.** The amendment maps a limit-killed,
  non-re-runnable review to the **existing** `skipped: command-unavailable` and states
  "**never** as `ran-clean`" and "reuses the four-token contract … rather than adding a
  token." `rg` confirms no new token string is introduced and the four-token set in
  `review-findings.md` is unchanged. Coherent and non-contradictory (see MINOR above).

- **MINOR 2 resolution (false-clean detection) — sound.** The "False-clean detection —
  how" bullet is concrete and actionable: inspect the workflow result for a specific
  sub-agent/finder failure indicator (non-empty failures list; error signature in the
  infra set; **finder count of 0 with failures present**) before trusting "no findings",
  and treat any such result as a degraded/INVALID run. Not merely asserted — it names
  the checkable indicators.

- **No regression (mechanical).** `git diff HEAD~1` on spec 03 confirms the 5-FAIL
  *Round limits* contract (counting rule, counter scope, threshold, reset rule,
  escalation contract) is byte-for-byte unchanged — the only line matching
  "5-FAIL threshold" is inside the new section. Spec 04's pre-existing content is intact;
  changes are confined to two additive blocks. The amendment commit (`bde65f3`) touches
  **only** the two spec files — no ADR was edited (immutability / ADR 0005 preserved).
  All cross-link targets resolve (ADR 0017/0013/0010/0011/0005 and `review-findings.md`
  all present at the referenced relative paths). No internal contradiction found.

## Notes

Faithful, minimally-scoped fold with no collateral disturbance. Both MINOR resolutions
called out in the review brief are soundly and coherently addressed. Approving.

# Evaluation: ADR 0017 — Infrastructure-Blocked Escalation, Degraded-Review Honesty, and Incremental-Commit Discipline

Verdict: PASS
Round: 0
Reviewed against: ADR 0013 (write-ahead + pause+summary escalation machinery), spec 03 §"Round limits" (round-counting + Escalation contract), ADR 0010/0011 + `review-findings.md` (review faithfulness invariant + the four status tokens), ADR 0012 (bounded return), ADR 0005 (frozen-spec deferral), ADR 0003 (commit-per-handoff), ADR 0001 (orchestrator-only spawn), ADR README descriptor.

## Findings

- [MINOR] Degraded-review terminal-token encoding is left slightly self-tensioned. Part 2 asserts an infra-degraded run is "not any of" the four `review-findings.md` tokens, yet says the honest resolution is to "re-run … or record it as a **non-run**" — and the only existing non-run terminal states *are* two of those four tokens (`skipped: docs-only` / `skipped: command-unavailable`). The ADR does not state whether a limit-killed review reuses `skipped: command-unavailable` (semantically "built-in not available", which does not match "ran but finders crashed") or requires a new token. This is honestly deferred (Consequences lists "a degraded-review note in `references/review-findings.md`" as follow-on playbook wiring), and the load-bearing invariant — never `ran-clean`, never fed to the evaluator — is unambiguous, so it does not block. Recommend the follow-on wiring slice pick reuse-vs-new-token explicitly.
- [MINOR] The false-clean detection *mechanism* is asserted but not spelled out. Part 1 signature bullet 5 requires the orchestrator to treat a workflow as an infra block when "sub-agents crashed on one of the above limits, even if the workflow returns a plausible-looking summary" — yet the Context itself notes this false-clean is "indistinguishable, at the surface, from a genuine `ran-clean`." How the orchestrator *learns* the finders crashed (e.g. correlating with an account-limit signature it has already observed in-environment, or the workflow surfacing per-agent errors) is not named. Acceptable at ADR granularity — the directive (treat such a run as invalid) is decisive and the mechanism is implementation/playbook detail — but the follow-on wiring should make the crash-observability path concrete so the rule is actionable, not aspirational.

## Required changes (for FAIL)

None — PASS.

## Notes

Verified mechanically:
- **Authority citations resolve.** All cross-links exist (spec 03, spec 04, ADRs 0001/0003/0005/0010/0011/0012/0013, `review-findings.md`); the `../../plugins/…` relative path from `.docs/ADR/` resolves.
- **ADR 0013 rule citations are accurate.** Rule 1 = "Write-ahead checkpoint" (ADR 0017 §Part 1 step 3 cites rule 1 correctly); rule 3 = "Forward-progress guard"/escalate (ADR 0017 Context cites it as the starvation-loop escalation correctly).
- **Spec 04 section names exist** ("Thin-orchestrator invariant", "Human checkpoints"); `orchestration.md` "Actually invoke … never simulate" exists.
- **README descriptor present and accurate** (`.docs/ADR/README.md:34`).
- **Structure** conforms (Context / Decision / Consequences).

Substantive judgment:
- **Sibling-not-replacement framing is correct.** The new escalation is presented as a third escalation *type* sharing the pause+summary shape with the spec-03 round-limit and ADR 0013 starvation-loop escalations, "different trigger" — not a replacement. Consistent with both authorities.
- **"Not round-counted" is consistent with spec 03.** Spec 03 increments `Round:` only on a FAIL *verdict*; an infra block is not a FAIL verdict, so it must not move the counter. The ADR states this correctly and gives the right reason (block reflects account state, not artifact quality).
- **Degraded-review rule extends, does not contradict, the faithfulness invariant.** The "never `ran-clean` for a limit-killed run, never feed to the blind evaluator, re-run or record as non-run" directive is airtight on the load-bearing invariant and is a proper extension of ADR 0010/0011 + `review-findings.md` (*Findings come from real command output*). The four tokens are preserved as the only honest terminal states.
- **No retry-loop hazard.** Halt-not-retry + write-ahead checkpoint + resume-on-owner-action avoids both hammering the same limit and wedging forever; resume is well-defined (write-ahead → owner raises limit → resume `/loom:run`).
- **Incremental-commit discipline correctly scoped as a SHOULD** (intra-role granularity), consistent with ADR 0003 and ADR 0012, not a hard invariant — appropriate.
- **Scope honesty is sound.** The "detect-on-failure, cannot poll account limits" non-scope is correct (loom has no interface to billing/rate state; only the per-conversation window is observable) and correctly framed as an orchestration rule, not a hook.
- **Frozen-spec/playbook changes correctly deferred** per ADR 0005 (spec 04/03 amendments + playbook wiring named in Consequences as a later pure-docs slice); supersedes none; builds on the correct ADRs.

Both findings are MINOR and honestly deferred; neither undermines the decision. The ADR is traceable, decisive, and its consequences are honest.

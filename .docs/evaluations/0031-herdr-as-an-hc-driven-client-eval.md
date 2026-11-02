# Evaluation: ADR 0031 and drafted amendments

Verdict: FAIL
Round: 1
Commit: 18dbb41570b3809a953ea2018e5e36297ebf3fdc
Reviewed against: ADRs 0004, 0005, 0023, 0025, 0026, 0029, 0030; spec index and frozen specs; named research; owner decision; plan evaluation rubric.

## Summary

The ADR and drafted amendments do not yet hold together: spec 08 keeps a three-client
requirement, hook scope contradicts the owner decision, the `hc` guard enumerates verbs
instead of denying by default, and several factual claims overreach the research.

## Required changes

1. Reconcile all surviving three-client requirements in spec 08 and make the amendment mechanically complete.
2. Correct the factual claims about the app and milestone; distinguish lack of evidence from proof of absence.
3. Resolve the hook scope against the owner decision and specify a complete, fail-closed hc guard.
4. Place the proposed ADR in the proper register section.

## Findings

### BLOCKER

- [BLOCKER] The proposed spec 08 edits leave its conformance requirement for “all three clients” intact at `.docs/spec/08-playbook.md:221`, contradicting the proposed two-client fixture contract in `.docs/slice-plans/herdr-hc-spec-amendments.md:94`. Applying the proposed edits would freeze an inconsistent spec. Amend that requirement too. Command: `rg -n -i 'herdr|\bhc\b|plugin|\.herdr-plugin|three clients' .docs/spec .docs/slice-plans/herdr-hc-spec-amendments.md`.
- [BLOCKER] `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:30` and `:56` retain Codex hook wiring, while the binding owner decision says Loom's hooks stay inside Claude Code. The draft repeats this at `.docs/slice-plans/herdr-hc-spec-amendments.md:127`. Align the decision and amendments with the owner instruction. Command: `rg -n -i 'hooks|hook wiring' .docs/ADR/0031-herdr-as-an-hc-driven-client.md .docs/slice-plans/herdr-hc-spec-amendments.md`.
- [BLOCKER] `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:134` calls its enumerated list mutation verbs but omits `hc exec`, which can start a program, and `label`, `keep`, and `put`, which mutate state; research documents these at `.docs/research/2026-11-01-hc-agent-runtime-reference.md:32`–`:39`. This leaves direct, documented routes around the stated role guard, beyond its acknowledged shell evasions. Specify a deny-by-default hc policy or include the missing verbs. Command: `rg -n 'label|keep|put|exec|connect|mutation' .docs/ADR/0031-herdr-as-an-hc-driven-client.md .docs/research/2026-11-01-hc-agent-runtime-reference.md`.

### MAJOR

- [MAJOR] `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:26` asserts the desktop app only displays what hc runs as product fact. `herdr-app --skill` describes `tab.new` and `terminal.open` starting programs, and the research at `.docs/research/2026-11-01-hc-agent-runtime-reference.md:9` observes an app-started terminal. State the owner-selected integration constraint without claiming the app cannot launch. Command: `herdr-app --skill`.
- [MAJOR] `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:13` claims M9 was recorded complete; `.docs/status/roadmap.md` records M9 in progress, and `.docs/status/progress.md` distinguishes completed offline slices from outstanding live evidence. Correct the history while retaining the proposed reopened status. Command: `rg -n -i 'M9|offline|live' .docs/status/roadmap.md .docs/status/progress.md .docs/ADR/0031-herdr-as-an-hc-driven-client.md`.
- [MAJOR] `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:19` asserts no plugin-install or marketplace API exists in the app, CLI or bundle; the research records a search and absence of evidence, not exhaustive proof of absence. Qualify the claim to the evidence found. Command: `cat .docs/research/2026-11-01-herdr-extension-loading.md`.

### MINOR

- [MINOR] `.docs/ADR/README.md:46` registers a Plan Review ADR under `## Accepted` rather than `## In Review` at line 48. Move the entry. Command: `rg -n '## Accepted|## In Review|0031' .docs/ADR/README.md`.

## Notes

The blind-review constraint is explicitly blocking for hc evaluators pending a follow-up decision. The specified plugin files and matrix entries exist; the commit leaves ADRs 0029 and 0030 unchanged. The ADR has Context, Decision, and Consequences sections. Commands: `git diff 18dbb41^ 18dbb41 -- .docs/ADR/0029* .docs/ADR/0030*`; `cat .herdr-plugin/marketplace.json plugins/loom/.herdr-plugin/plugin.json plugins/loom/adapters/roots/herdr-plugin-root-v1.json`; `jq '.clientFloors, .rootBindings, .profiles' plugins/loom/adapters/compatibility/v0.3.0.json`; `cat plugins/loom/skills/loom-playbook/templates/adr.md`.

## Prior Rounds Summary

No prior rounds.

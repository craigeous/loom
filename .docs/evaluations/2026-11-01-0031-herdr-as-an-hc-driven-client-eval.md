# Evaluation: ADR 0031 and drafted amendments

Verdict: PASS
Round: 2
Reviewed against: ADRs 0004, 0005, 0023, 0025, 0026, 0029 and 0030; frozen specs; named research; owner decision and Round 2 clarification; plan evaluation rubric.

## Required changes

None.

## Findings

### BLOCKER

None.

### MAJOR

None.

### MINOR

None.

## Notes

- The Round 1 findings are resolved: the spec 08 conformance amendment covers all three-client references at `.docs/slice-plans/herdr-hc-spec-amendments.md:87`; the guard is deny-by-default at `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:140`; the app and M9 claims are corrected at `:13` and `:28`; the absence claim is qualified at `:19`; and the register entry is under In Review at `.docs/ADR/README.md:49`. Command: `git diff 18dbb41 8a0077e -- .docs/ADR/0031-herdr-as-an-hc-driven-client.md .docs/slice-plans/herdr-hc-spec-amendments.md .docs/ADR/README.md`.
- Round 2 hook scope is resolved: Herdr has no hook role and existing Claude and Codex wires remain governed by spec 08 at `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:38` and `.docs/slice-plans/herdr-hc-spec-amendments.md:124`. Command: `git diff 3380bf3 8a0077e`.
- The ADR states partial supersession and retains prior ADR bodies, specifies retirement of the existing manifests, root and matrix entries, explicitly blocks hc evaluator use pending a follow-up decision, and records M9 as reopened at `.docs/ADR/0031-herdr-as-an-hc-driven-client.md:71`, `:173`, `:210`, and `:222`. Commands: `git diff 18dbb41^ 8a0077e -- .docs/ADR/0029\* .docs/ADR/0030\*`; `cat .herdr-plugin/marketplace.json plugins/loom/.herdr-plugin/plugin.json plugins/loom/adapters/roots/herdr-plugin-root-v1.json`; `jq '.clientFloors, .rootBindings, .profiles' plugins/loom/adapters/compatibility/v0.3.0.json`.
- The proposed amendments address the Herdr references in frozen specs; research and read-only CLI output support the relevant product descriptions, with live probes and blind review explicitly unresolved. The ADR uses the required Context, Decision and Consequences shape. Commands: `rg -n -i 'herdr|\bhc\b|plugin|\.herdr-plugin|three clients' .docs/spec`; `cat .docs/research/2026-11-01-hc-agent-runtime-reference.md .docs/research/2026-11-01-herdr-extension-loading.md`; `hc --help`; `hc --skill`; `herdr-app --skill`; `cat plugins/loom/skills/loom-playbook/templates/adr.md`.

## Prior Rounds Summary

| Round | Phase | Verdict | Resolution |
|---|---|---|---|
| 1 | Plan | FAIL | Spec 08 coverage, hook scope, deny policy, factual claims, milestone and register corrected. |
| 2 | Plan | FAIL | Hook scope clarified under owner reading A; Claude and Codex wires remain governed by spec 08. |

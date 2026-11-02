# Evaluation: ADR 0032

Verdict: FAIL
Round: 3
Reviewed against: owner decisions, ADRs 0019, 0024, 0027, 0031, specs 07 and 10, README, CLAUDE.md, and check.yml. Artifact: explicitly requested commit 4fc30af.

## Findings

- [BLOCKER] The specified artifact does not explicitly supersede ADR 0019's Intel clause; it keeps it and requires Intel evidence (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:145-165,280; .docs/ADR/0019-supported-runtime-and-release-contract.md:43-47). Exact command: `rg -n -C 3 'Ubuntu|x86-64|green on the declared matrix|blocks publication' .docs/ADR/0019-supported-runtime-and-release-contract.md; git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | rg -n -i 'intel|superseded|unchanged'`.
- [MAJOR] The four and ten pairs and atomic requirement conflict with the permission to omit an unavailable pair (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:56-68). Exact command: `git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | nl -ba | sed -n '49,70p'`.

## Required changes

1. Explicitly supersede the Intel clause while stating the intended architecture scope and preserving release evidence and publication safeguards.
2. Reconcile pair counts, availability and the atomic release rule.

## Notes

The specified commit is the same revision reviewed in round 2; its two findings therefore remain. A later local revision exists at 3de3890, but it is outside the explicitly requested artifact commit. Exact command: `git diff 4fc30af HEAD -- .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md`.

The stated release sequence matches the owner decisions; E1–E5 define per-pair proof and the external record binds to the tag without a self-hash. Open questions do not contradict the binding decisions; the listed follow-ups are not edited in the revision. No universal cross-OS support claim was found. Status is Plan Review and the register places it under In Review. Exact commands: `git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | cat -n`; `git show 4fc30af:.docs/ADR/README.md | rg -n 'In Review|0032'`; `git diff --name-only b4cc1a3 4fc30af -- README.md CLAUDE.md .docs/spec/10-packaging.md .docs/ADR/0024\* .docs/ADR/0027\* .github/workflows/check.yml`; `jq -r 'keys' plugins/loom/adapters/compatibility/v0.2.0.json plugins/loom/adapters/compatibility/v0.3.0.json`.

## Prior Rounds Summary

| Round | Phase | Verdict | Key findings and resolution |
|---|---|---|---|
| 1 | plan | FAIL | Circular evidence and contradictory questions resolved in 4fc30af. |
| 2 | plan | FAIL | Intel supersession and pair applicability unresolved in 4fc30af. |

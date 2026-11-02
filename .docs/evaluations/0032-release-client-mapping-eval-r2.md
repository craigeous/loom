# Evaluation: ADR 0032

Verdict: FAIL
Round: 2
Reviewed against: binding owner decisions and requested checks; ADR 0019, 0024, 0027, 0031; specs 07 and 10; README, CLAUDE.md and check.yml.

## Findings

- [BLOCKER] The requested explicit supersession of ADR 0019's macOS-Intel release-matrix clause is missing: ADR 0032 instead keeps that clause and requires Intel evidence for v0.2.0 (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:145,163,280; .docs/ADR/0019-supported-runtime-and-release-contract.md:43). Exact command: `rg -n -C 3 'Ubuntu|x86-64|green on the declared matrix|blocks publication' .docs/ADR/0019-supported-runtime-and-release-contract.md; git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | rg -n -i 'intel|superseded|unchanged'`.
- [MAJOR] The revised table requires four and ten pairs and says every pair must pass, but permits a harness unavailable on an architecture to be absent (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:56-68). These incompatible rules leave the release gate ambiguous. Exact command: `git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | nl -ba | sed -n '49,70p'`.

## Required changes

1. Explicitly supersede the specified Intel release requirement, while stating the intended macOS architecture scope and retaining the evidence and publication safeguards.
2. Make the pair counts, availability exception, and atomic publication requirement consistent.

## Notes

The owner sequence is stated at lines 30–36. Per-pair evidence and the external record bind evidence to the tag without a self-referential hash (lines 90–133). Open questions do not reopen the binding choices (lines 289–303). Follow-up edits are listed at lines 250–273. No universal cross-OS support claim found. The artifact is Plan Review and is indexed under In Review. Exact commands: `git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | rg -n -i 'status:|v0\.2\.0|v0\.3\.0|v0\.4\.0|evidence|open questions|all operating|cross.os'`; `git show 4fc30af:.docs/ADR/README.md | rg -n 'In Review|0032'`; `git diff --name-only b4cc1a3 4fc30af -- README.md CLAUDE.md .docs/spec/10-packaging.md .docs/ADR/0024-macos-first-dual-client-dogfood-bootstrap-amendment.md .docs/ADR/0027* .github/workflows/check.yml`; `jq -r '.version // empty' plugins/loom/adapters/compatibility/v0.3.0.json`.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 1 | plan | FAIL | Circular evidence binding and contradictory open questions resolved by external post-tag evidence and revised questions. Verified with `git diff b4cc1a3 4fc30af -- .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md`. |

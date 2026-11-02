# Evaluation: ADR 0032

Verdict: FAIL
Round: 4
Commit: 4fc30af
Reviewed against: owner decisions and named authorities (ADR 0019, ADR 0024, ADR 0027 and ADR 0031; see the round 3 and round 5 records for the full list).
Reviewed artifact: commit 4fc30af; owner decisions and named authorities.

## Summary

FAIL (round 4; BLOCKER: 1, MAJOR: 1, MINOR: 0). Evaluated at commit 4fc30af again; the Intel supersession and pair-rule findings remain in that commit. The remaining sections are the original record, unchanged.

## Required changes

1. Explicitly supersede ADR 0019 §2's Intel release-matrix clause for the specified releases while retaining evidence and publication safeguards.
2. Establish one consistent pair applicability rule and reconcile the table and atomic release condition.

## Findings

- [BLOCKER] The specified commit does not supersede ADR 0019's Intel clause: it explicitly keeps it and requires Intel evidence (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:145-165,280; .docs/ADR/0019-supported-runtime-and-release-contract.md:43-47). Exact command: `rg -n -C 2 'Ubuntu|x86-64|green on the declared matrix|blocks publication' .docs/ADR/0019-supported-runtime-and-release-contract.md; git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | rg -n -i 'intel|superseded|unchanged'`.
- [MAJOR] The four and ten required pairs and atomic requirement conflict with the allowance to omit an unavailable pair (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:56-68). Exact command: `git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | nl -ba | sed -n '49,70p'`.

## Notes

The owner release sequence is stated at lines 29-36. Per-pair E1–E5 and the external post-tag record bind evidence without a self-hash (lines 90-133); publication remains blocked without evidence. Open questions do not contradict binding decisions. Follow-up edits are listed at lines 250-273, and the named files were not changed in the revision. No universal cross-OS support claim found. Status is Plan Review and the register places it under In Review. Exact commands: `git show 4fc30af:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | nl -ba`; `git show 4fc30af:.docs/ADR/README.md | rg -n 'In Review|0032'`; `git diff --name-only b4cc1a3 4fc30af -- README.md CLAUDE.md .docs/spec/10-packaging.md '.docs/ADR/0024*' '.docs/ADR/0027*' .github/workflows/check.yml`; `jq -r 'keys' plugins/loom/adapters/compatibility/v0.2.0.json plugins/loom/adapters/compatibility/v0.3.0.json`.

The later working-tree revision differs from the explicitly specified commit and is not the artifact evaluated. Exact command: `git diff 4fc30af HEAD -- .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md`.

## Prior Rounds Summary

Rounds 1–3 failed; round 1's circular evidence and open questions were resolved at 4fc30af, while rounds 2–3 identified the two findings above, still present in that specified commit.

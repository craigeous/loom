# Evaluation: ADR 0032

Verdict: FAIL
Round: 5
Commit: 1088fc5
Reviewed against: owner decisions, ADR 0019, 0024, 0027, 0031, specs 07 and 10, README, CLAUDE.md, check.yml, and the plan-evaluation rubric.

## Summary

FAIL (round 5; BLOCKER: 1, MAJOR: 1, MINOR: 0). The ADR 0019 section 5 Ubuntu CI requirement was replaced without an explicit supersession, and E4 conflicted with the NOT APPLICABLE pair rule. The remaining sections are the original record, unchanged.

## Required changes

1. Explicitly supersede ADR 0019 §5's Ubuntu CI requirement for the affected releases, and make the supersession summary and follow-up register instruction consistent.
2. Limit E4 to required pairs so NOT APPLICABLE pairs do not need impossible live conformance.

## Findings

- [BLOCKER] The revision says only ADR 0019 §2 is superseded and treats §5 as unchanged, yet replaces its explicit requirement for “Ubuntu and macOS CI” with macOS CI alone. §5 expressly requires Ubuntu CI, independently of the §2 platform list; this is a substantive supersession, not an applied reading. The follow-up register instruction also calls §5 superseded. This leaves conflicting release authority. Evidence: .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:50,184,267,296; .docs/ADR/0019-supported-runtime-and-release-contract.md:101. Exact command: `rg -n -C 2 'Ubuntu|x86-64|green on the declared matrix|blocks publication|published' .docs/ADR/0019-supported-runtime-and-release-contract.md; git diff 4fc30af 1088fc5 -- .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md`.
- [MAJOR] The new v0.4.0 table and pair rule allow a pair to be NOT APPLICABLE when its harness cannot run, but E4 still requires live conformance for each pair in the release row, including that pair. An implementer cannot satisfy both requirements. Evidence: .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:76,84,141. Exact command: `git diff 4fc30af 1088fc5 -- .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md; rg -n -C 2 'NOT APPLICABLE|each\*\* \(platform, harness\)' .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md`.

## Notes

The owner sequence and Intel exclusion are stated at lines 29–37 and 59–78. The named Intel and Ubuntu §2 clauses are explicitly superseded; evidence and publication safeguards remain at lines 173–207. E1–E5 define pair evidence, and the post-tag descendant record binds the tag commit without a self-hash (lines 118–162). The open questions at lines 322–337 do not reopen owner decisions. Follow-up edits are listed at lines 283–306; the named files were not edited in the revision. No universal cross-OS support claim was found. Status is Plan Review and the ADR register lists it under In Review. Exact commands: `git show 1088fc5:.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md | nl -ba`; `rg -n '0032|In Review' .docs/ADR/README.md`; `git diff --name-only 4fc30af 1088fc5 -- README.md CLAUDE.md .docs/spec/10-packaging.md '.docs/ADR/0024*' '.docs/ADR/0027*' .github/workflows/check.yml`; `jq -r 'keys' plugins/loom/adapters/compatibility/v0.2.0.json plugins/loom/adapters/compatibility/v0.3.0.json`.

## Prior Rounds Summary

Rounds 1–4 failed. The round 4 Intel supersession finding is resolved at lines 50 and 173–183; the new pair rule resolves the earlier atomic table inconsistency but introduces the E4 conflict above. Exact command: `git diff 4fc30af 1088fc5 -- .docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md`.

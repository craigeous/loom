# Review findings — release-conformance-and-evidence-schema

- Protocol: loom-local-review/v1
- Run: release-conformance-and-evidence-schema-c55ac98372b3
- Aggregate: ran-with-findings
- Base: d877660a8c5038f444dd8c5b474169bfa7b5f4be
- Head: c55ac98372b3a1c9ad496bb2ff15cf8a834726d1
- Diff sha256: 97c65b3027645b1402738ed41e125de52e56b696546de1793fe0b55297e736db
- Manifest sha256: fd3ec52e5a2569da1d3f37d3e75238c2f4388e0d213be0050e34e0ef206ea783
- Findings sha256: 06f1ceea64485fb6767e9fefab98a47e9cc6ebeaccd9e964b8bbb7451f451f68

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## TST-1 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2781
- Confidence: 0.7
- Claim: Several schema-rejection tests use a bare prefix such as "schema /pairs" or "schema /pairs/1" as the expected substring, so they pass on any error under that prefix and cannot tell the intended rule from an unrelated one.
- Evidence: The third-pair, duplicate-claude-pair, and codex-harness-with-claude-client tests assert only "schema /pairs" or "schema /pairs/1". The duplicate-pair mutation (.pairs[1] = .pairs[0]) also yields /pairs/1/... errors from the per-harness if/then constraints, so the maxContains rule is not isolated.
- Suggested verification: Remove the allOf contains/maxContains constraints from the schema and check whether the duplicate-pair test still passes through the per-pair errors.

## TST-4 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2852
- Confidence: 0.5
- Claim: Matrix drift tests (floor, client absence, e2 binding) mutate only the claude entry. The codex pair is never checked against the matrix.
- Evidence: The tests mutate clientFloors.claude, delete clientFloors.claude, and rename bindings with prefix claude-. No test drifts the codex floor or binding.
- Suggested verification: Change the matrix codex floor or codex binding id and run metadata mode. No existing test covers it.

## TST-2 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2879
- Confidence: 0.6
- Claim: The semantic check that e1.entry equals client is unreachable and untested. The only e1.entry test is rejected earlier by the schema ("schema /pairs/0/e1/entry").
- Evidence: validateReleaseEvidence runs only after schema validation succeeds, and the schema if/then already pins e1.entry per harness.
- Suggested verification: Delete the e1.entry line from validateReleaseEvidence in scripts/validate-repository.mjs. No test fails.

## TST-3 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2890
- Confidence: 0.6
- Claim: Two correction-chain error branches have no test: the original record carrying supersedes, and a correction present without the original. Only the happy path is covered.
- Evidence: validate-repository.mjs reports "the original record must not carry supersedes" and "correction record requires ...". Neither string appears in repository-validation.bats.
- Suggested verification: Remove either branch from validateReleaseEvidenceChain. The suite still passes.

## COR-1 — proposed MINOR

- Worker: review-correctness/v1
- Location: scripts/validate-repository.mjs:481
- Confidence: 0.7
- Claim: The correction-number check advertises rejecting leading zeros but cannot: numbers are parsed with Number(), so a file named v0.2.0.corr01.json is treated as N=1 and accepted.
- Evidence: Line 467 matches /^v0\.2\.0\.corr([0-9]+)\.json$/ and line 468 stores n: Number(match[1]); corr01 becomes n=1, equal to index+1, so the check at line 480 never fires despite the message 'without gaps or leading zeros'. The evaluations skip regex (line 1094) also accepts corr[0-9]+. Spec 10 names corrections vR.corr<N>.json with no gaps.
- Suggested verification: Create .docs/evaluations/release-evidence/v0.2.0.json plus v0.2.0.corr01.json with a valid supersedes, run node scripts/validate-repository.mjs --metadata, and observe no 'leading zeros' report. Also compare against corr1 and corr01 both present (both n=1) to see only a duplicate-number message.

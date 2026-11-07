# Review findings — release-conformance-and-evidence-schema

- Protocol: loom-local-review/v1
- Run: release-conformance-and-evidence-schema-cb47c1a2c675
- Aggregate: ran-with-findings
- Base: d877660a8c5038f444dd8c5b474169bfa7b5f4be
- Head: cb47c1a2c675e542aaad657c27b849e275fdecb1
- Diff sha256: a5180d8c6cd1f9d0f43c09a19ee2fd8280aaef19ee6c63f049b2520a18140a9f
- Manifest sha256: ac88e169e7812936c8bfbc563088d7ea517438a3933a3666248ed82aff6d62a6
- Findings sha256: 054c91f7ca5dc2502eb470d9dfee33498dec3d2d7c291464d6a84abf4eedf86e

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## TST-2 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2742-2948
- Confidence: 0.6
- Claim: Several schema and semantic negative branches have no test: the original record carrying supersedes ("the original record must not carry supersedes"), a correction present without v0.2.0.json ("correction record requires"), ownerStateUnchanged=false, crossFamilyVerified=false, blindReview!=verified, invalid authSource, wrong platform, and a missing outputHash. A regression removing any of these constraints would leave the suite green.
- Evidence: The added tests (lines 2742-2948) mutate only: role/gate results, floors, pair count, candidate length, log paths, release/tag/matrix, ownerAck.candidate, priorCandidate, bashRuns, e1.entry, and supersedes chain faults. None touch the listed fields, yet schema lines 62-246 and validateReleaseEvidenceChain enforce them.
- Suggested verification: Grep the added bats tests for ownerStateUnchanged, crossFamilyVerified, blindReview, authSource, platform, outputHash, "must not carry supersedes", and "requires"; none appear. Add one mutation test per constraint.

## TST-3 — proposed NIT

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2814-2816
- Confidence: 0.45
- Claim: Several rejection tests assert only a loose schema path prefix (e.g. "schema /pairs", "schema /pairs/1") so any schema error at or under that path satisfies them, including a different constraint than the one intended (e.g. "duplicate claude pair" could be rejected for harness/client mismatch instead of the contains/maxContains rule).
- Evidence: assert_release_evidence_rejected uses a substring glob on the expected text; "third pair" and "duplicate claude pair in place of codex" both expect only "schema /pairs", and "codex harness with claude client" expects only "schema /pairs/1".
- Suggested verification: Mutate the schema to drop maxContains or the client const and confirm whether these tests still pass via another error at the same path.

## TST-1 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2909-2917
- Confidence: 0.7
- Claim: The validator reports "correction numbers must run 1..N without gaps or leading zeros", but no test covers a leading-zero name (e.g. v0.2.0.corr01.json) and the only gap test uses corr3. A leading-zero file passes the n === index+1 check because Number("01") === 1, so the stated rule is neither enforced nor caught by any test.
- Evidence: validate-repository.mjs (changed lines ~468-473) parses the suffix with Number(match[1]) and compares to index+1; the regex accepts [0-9]+. The only numbering test is "gap in correction numbers fails" (install_correction 3 after 1).
- Suggested verification: Add a test installing v0.2.0.corr01.json (copy of corr1) and assert status 1 with a leading-zero message; it currently would pass validation.

## COR-1 — proposed MINOR

- Worker: review-correctness/v1
- Location: scripts/validate-repository.mjs:481
- Confidence: 0.7
- Claim: The correction-number check claims to reject leading zeros but does not; a file such as v0.2.0.corr01.json is accepted as correction 1.
- Evidence: The filename regex is /^v0\.2\.0\.corr([0-9]+)\.json$/ and the number is parsed with Number(match[1]), so 'corr01' yields n=1. The only gap check is entry.n !== index + 1, which passes for n=1, yet its message states 'without gaps or leading zeros'. The predecessor is computed as `v0.2.0.corr${n-1}.json` and the evaluations skip regex also accepts corr[0-9]+, so a zero-padded name passes the chain validation while the spec-described canonical naming is violated. Note a later corr2 would then name predecessor corr1.json (nonexistent), producing a confusing error rather than a leading-zero rejection.
- Suggested verification: Create .docs/evaluations/release-evidence/v0.2.0.corr01.json (with valid supersedes of v0.2.0.json) and run scripts/validate-repository.mjs; observe no 'leading zeros' report. Fix would be matching ([1-9][0-9]*) or comparing the filename to `corr${n}`.

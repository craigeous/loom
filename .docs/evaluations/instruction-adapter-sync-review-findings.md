# Review findings — instruction-adapter-sync

- Protocol: loom-local-review/v1
- Run: instruction-adapter-sync-631d1804008f
- Aggregate: ran-with-findings
- Base: 9b018909019b0f02b2fa8b4b533a6eb98aac1282
- Head: 631d1804008f373531bd7263475eab540784ca87
- Diff sha256: 5220e152fe41ecf968a8332be31ed1787b0a45c91e481f98a654cf96a2771959
- Manifest sha256: 04b45fb52a2d47765c599ea23e4821baa121398dde80e3f1b439f8eb3aae1e41
- Findings sha256: d00e878879315fc94ab314b6b2ed2f52c1d681bd2a705e38654652997275742e

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## TST-1 — proposed MAJOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:1726-1812
- Confidence: 0.8
- Claim: GEMINI.md handling in validateInstructionAdapters is entirely untested; the fixture only creates CLAUDE.md and AGENTS.md.
- Evidence: validate-repository.mjs line 1257 has a GEMINI-specific branch (skip if absent) and GEMINI.md is in ADAPTERS, but put_instruction_fixture writes only CLAUDE.md and AGENTS.md and no added test creates GEMINI.md (present, drifted, stale hash). Removing GEMINI.md from ADAPTERS or breaking the skip would not fail any added test.
- Suggested verification: Delete GEMINI.md from ADAPTERS or invert the GEMINI skip in validate-repository.mjs and run the added bats tests; all still pass. Add a test with a drifted GEMINI.md to confirm it is reported.

## TST-2 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:1726-1812
- Confidence: 0.7
- Claim: Marker-structure negative cases are only partly covered: missing end marker, end before begin, malformed sha256 (non 64-hex) in begin marker, and missing adapter file are not tested.
- Evidence: Only a duplicate begin marker test exists. The condition at validate-repository.mjs line 1263 (begins.length !== 1 || ends.length !== 1 || ends[0] < begins[0]) has three branches and only the first is exercised; a malformed hash makes the begin regex fail, reported as zero begin markers, also untested.
- Suggested verification: Weaken the condition to drop the ends.length or ends[0] < begins[0] checks; the added tests still pass.

## TST-3 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/validate-repository.mjs:1251
- Confidence: 0.6
- Claim: Digest normalization (CRLF to LF, trailing-newline collapse) is untested, and the shared-lines comparison never checks that the last-bullet exemption is limited to the final bullet.
- Evidence: Line 1251 normalizes line endings and trailing newlines before hashing, while the bats fixture hashes the raw file with sha256sum. No test uses CRLF or extra trailing blank lines. The drift test edits a first line only; no test shows that a difference in a non-final bullet in a body with a differing final bullet is still caught, or that an inactive repo (no digest and no markers, line 1248) is skipped.
- Suggested verification: Remove the normalization or change lastBullet logic and run the added tests; they still pass. Add CRLF digest, inactive-repo, and middle-bullet-drift tests.

# Review findings — dogfood-gate-exclusion

- Protocol: loom-local-review/v1
- Run: dogfood-gate-exclusion-a72cf9afcd7a
- Aggregate: ran-with-findings
- Base: c2db41657ff8adfb0f3bd57ae2289175964428bd
- Head: a72cf9afcd7a770745b0b57d1df43dd7aa133418
- Diff sha256: 04197403ec478cafdf222267a6600f98ccb8891424e6a83814fdedcc82cab0e1
- Manifest sha256: 470db39dc2f104987482a129d12e7eb7e5196b6a9ae0a7584395bdbb34e21563
- Findings sha256: 2458c2df014d68c0e680afab8c1ef00bc880aa1d459f3e04998d68eaca5f867a

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## TST-1 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/check:525-543
- Confidence: 0.6
- Claim: The new exclusion-list reader in scripts/check has no automated regression test; its behavior is verified only by one-off manual commands in the plan and code-eval record.
- Evidence: The diff adds parsing of scripts/check-bats-exclusions.txt (comment/blank skipping, '# plan: ' capture, no-trailing-newline handling, missing-file fail-open, skip-by-exact-path) but changes no .bats file; the changed files are only scripts/check, the exclusions list, and .docs records. Grepping source/scripts/tests/*.bats for 'exclusions' or the 'Bats tests' stage finds nothing. If the reader broke (for example a list entry stopped matching, so the dogfood suite ran again, or a malformed list dropped required tests), no test would fail; only the dogfood-specific manual counts (972/931/41) would notice, and those are not part of the gate.
- Suggested verification: Run: grep -n 'exclusions\|Excluding' source/scripts/tests/*.bats (no matches), and confirm diff.patch touches no *.bats file. Optionally break the reader (e.g. change the case pattern) and observe scripts/check and repository-validation.bats still pass.

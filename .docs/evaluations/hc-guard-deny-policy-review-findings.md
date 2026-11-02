# Review findings — hc-guard-deny-policy

- Protocol: loom-local-review/v1
- Run: hc-guard-deny-policy-d11e86a2d4fb
- Aggregate: ran-with-findings
- Base: a1431ed14ce81cf3d9a31f1e9071acbc819f3ae2
- Head: d11e86a2d4fbf948a133892f2c92a8cd6eb654ad
- Diff sha256: 2b09462ad8d9d48283f94bfa5d8f169f6554aa04f5507ae28fd325d6575582a4
- Manifest sha256: e186b0d17e63a370eede646efda6ccdf314c2e897b4ee2805819143ac923e0e7
- Findings sha256: 6f81aee9354baf670da98423eeaac132f915779826696ce5ce1590ca6ac00192

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## COR-1 — proposed MINOR

- Worker: review-correctness/v1
- Location: .docs/slice-plans/hc-guard-deny-policy.md:123
- Confidence: 0.6
- Claim: The slice exceeds its plan's 140-LOC-added target, and the recorded LOC figure is stale after the round-0 fix.
- Evidence: The plan header says 'Target size: <= 140 LOC added (guard + Bats...)'. The manifest shows role-governance-guard.sh +19 and role-governance-guard.bats +139, which is 158 added. The evidence at line 123 still reads 'LOC 127 added ... target <= 140'. The later fix commit 64c15c3 (lines 128-130) adds code and tests but does not update that figure or acknowledge the overrun.
- Suggested verification: Run git diff --numstat base..head on the two hook files and sum the added column (expect 158). Compare with the plan's 'Target size' line and the evidence line 123.

## TST-1 — proposed MINOR

- Worker: review-tests/v1
- Location: plugins/loom/hooks/role-governance-guard.bats:290
- Confidence: 0.6
- Claim: No test pins the unspaced pipe or background separators (`|`, `&`) in the hc scan's tr set, so dropping them from the guard would not fail any test.
- Evidence: The guard maps ';&|<>{}()$`' to spaces (role-governance-guard.sh HCSCAN). The chained test (line 290) uses `ls && hc send t1 x` (spaces around `&&`, which already separate the word), `ls;hc ls` (pins `;`), and `$(hc)` (pins `$`/`)`). The xargs tests use ` | ` with spaces. No case such as `ls|hc ls`, `ls&hc ls`, or `cat <(hc ls)` exists, so removing `|`, `&`, `<`, `>`, `{` or `}` from the second tr set leaves every listed test green.
- Suggested verification: Mutate the guard's second `tr` set to drop `|` and `&`, run `bats role-governance-guard.bats`; all hc tests still pass although `ls|hc ls` becomes allowed for non-orchestrator roles.

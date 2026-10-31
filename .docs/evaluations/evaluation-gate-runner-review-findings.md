# Review findings — evaluation-gate-runner

- Protocol: loom-local-review/v1
- Run: evaluation-gate-runner-6e73adda8a49
- Aggregate: ran-with-findings
- Base: ddc9aa661cc2acce36d17400ed7802f678cc7fa6
- Head: 6e73adda8a4950979cd26b86bf6748ef73b38692
- Diff sha256: 3ac49d49f41b7aae2765bc543b97c51c08221055f2a6d2fe0279cbd4476edd74
- Manifest sha256: 310c9cca3599cfca23be0224e99e56f8d766bdcd013aa47d33556f2fa86bb01b
- Findings sha256: 7b0594f02ff1fe82c7e53c39f4fd4befa8b7b5e9b89447c880d49e0150868ad5

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## COR-1 — proposed BLOCKER

- Worker: review-correctness/v1
- Location: plugins/loom/bin/loom-eval-workspace:1183
- Confidence: 0.95
- Claim: No-checkout operation is unavailable because checkout_inventory is called unconditionally during gate-rerun
- Evidence: Line 1183 invokes checkout_inventory without conditioning on REPO_OK, causing gate-rerun to fail with exit 4 when running without a git checkout.
- Suggested verification: Invoke loom-eval-workspace gate-rerun on a code run without a git repository checkout and observe failure at checkout_inventory.

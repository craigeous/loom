# Review findings — herdr-surface-retirement

- Protocol: loom-local-review/v1
- Run: herdr-surface-retirement-fd933613a9fd
- Aggregate: ran-with-findings
- Base: 0048036b3e540ced538cb41defcbb3d6a32bb5a8
- Head: fd933613a9fde472a6e1a4c6e8390a7d67086d21
- Diff sha256: cd602456cb254933efde1ab70b631ccf755e8c61b9a0e18322fdfee390b546b0
- Manifest sha256: 6461f9cbbd56c48a599ec1d96a860d7f94728712a54fa48f355933e8581918cd
- Findings sha256: eae6615ce284e4aeb7451c911f1f3be3711dd54cd524769f277b17b1dabe469e

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## TST-1 — proposed NIT

- Worker: review-tests/v1
- Location: plugins/loom/schemas/loom-role-launch-v1.schema.json:18
- Confidence: 0.35
- Claim: Narrowing the authorClient enum (herdr removed) has no test that fails if herdr is reintroduced to the schema or launch output; retirement is only asserted via CLI exit codes.
- Evidence: The only added herdr-related launch assertions are in loom-launch-role.bats (launch herdr researcher -> status 1; launch claude plan-evaluator --author-client herdr -> status 2), which exercise the script argument parser, not the schema enum. The new repository-validation.bats tests check path absence and a text grep that excludes *.bats and does not cover the string "herdr" in schemas (pattern is only HERDR_PLUGIN_ROOT|herdr-plugin).
- Suggested verification: Re-add "herdr" to an authorClient enum in loom-role-launch-v1.schema.json and run the bats suite; if all herdr retirement tests still pass, the gap is confirmed.

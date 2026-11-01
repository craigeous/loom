# Review findings — workflow-profiles

- Protocol: loom-local-review/v1
- Run: workflow-profiles-cbfc428e987f
- Aggregate: ran-with-findings
- Base: c640a25548ef7df04dc0308e2e7079fb426667f0
- Head: cbfc428e987fd65e78df599fd0c2defa0749a015
- Diff sha256: e20972e99305755b9fbf95dd66e46a9e5e6ea64877aa041da5c62c457392cf38
- Manifest sha256: bc44ea6c6f0065084ead4614597a912d50bca92913fb108c3331f3156382a524
- Findings sha256: e50a408e69b1855edc35d80694bcc5e4404635636408171d26be37816aa0edec

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## TST-1 — proposed MINOR

- Worker: review-tests/v1
- Location: plugins/loom/bin/loom-resolve-helper:34
- Confidence: 0.6
- Claim: The new loom-profile entry in the resolver allowlist has no resolver test.
- Evidence: loom-resolve-helper.bats only exercises loom-doctor (lines 113-124); no case resolves loom-profile for claude or codex, and scripts/tests/loom-profile.bats never calls the resolver.
- Suggested verification: Remove loom-profile from ALLOWED_HELPERS in loom-resolve-helper; no bats test fails (validate-repository.mjs may still catch binding drift, but not the resolver).

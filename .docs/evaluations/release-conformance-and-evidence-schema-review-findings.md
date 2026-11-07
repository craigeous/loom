# Review findings — release-conformance-and-evidence-schema

- Protocol: loom-local-review/v1
- Run: release-conformance-and-evidence-schema-8845343a9dd6
- Aggregate: ran-with-findings
- Base: d877660a8c5038f444dd8c5b474169bfa7b5f4be
- Head: 8845343a9dd63dd3934bd6152d127791b269f0e5
- Diff sha256: 77911565d06159d310d3fc0cb49764f680ca735831d524107b3ce21b85430ade
- Manifest sha256: 3bfd19a9a39821f75de941a7481294ecb56c6a01a3f9ba4fd5500e813a69c6de
- Findings sha256: 1003326ec9778270fb2becbc10fa544930a99a8e8693314cb7b0cc943425b5e6

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## COR-3 — proposed MAJOR

- Worker: review-correctness/v1
- Location: .docs/spec/10-packaging.md:264
- Confidence: 0.6
- Claim: The diff edits normative specs (spec 10 and spec 07), but the slice plan says the slice edits no spec file. Spec text may change only through planner plus cold plan evaluation.
- Evidence: The plan's Out of Scope section (line 59) says: "Spec 10 and spec 07 text. No spec file is edited by this slice. The normative amendment is the sibling artifact in Context." Its Target files list has no .docs/spec/ entry. The diff nonetheless rewrites .docs/spec/10-packaging.md (for example the new `## Release conformance evidence` section at line 264, and the removed `## Private Apple-silicon dogfood evidence` section) and .docs/spec/07-command-surface.md. The plan's Context says the spec text "lands with the implementing slice", which contradicts Out of Scope. CLAUDE.md says specs change only through planner and cold plan evaluation.
- Suggested verification: Compare the spec hunks in the diff with the approved text in .docs/slice-plans/spec-10-07-release-evidence-amendment.md. If they match, the question is whether the landing was authorised by that sibling plan and the Context wording, which the code evaluator should decide. Check that the spec-10-07 plan's Landed status and its plan-eval record support that reading.

## COR-2 — proposed MINOR

- Worker: review-correctness/v1
- Location: README.md:93
- Confidence: 0.9
- Claim: The documented archive verification command rejects a valid archive. Its first entry check treats directory entries as invalid archive entries.
- Evidence: README line 93: `tar -tzf ARCHIVE | grep -v -E '^(\./)?(MANIFEST\.sha256|logs/[a-z0-9][a-z0-9._/-]*\.log)$' && echo 'INVALID ARCHIVE ENTRY'`. The regex admits only files. A plain `tar -czf` of MANIFEST.sha256 and logs/ lists `logs/` and `logs/bash/` as entries, and both fail the regex. The orchestrator reproduced this in a temporary directory: `tar -tzf` output was `MANIFEST.sha256`, `logs/`, `logs/bash/`, `logs/bash/bash32.log`, and the grep printed `logs/` and `logs/bash/`. The command is copied verbatim from the approved plan's Context block, so the defect is inherited, but the README copy is what a reviewer runs.
- Suggested verification: Build a sample archive with `tar -czf` over MANIFEST.sha256 and logs/ and run the README line 93 pipeline. It prints directory entries. Either the archive build must exclude directory entries (for example `tar --no-recursion` with an explicit file list) and the README must say so, or the entry check must accept `logs/` and `logs/<dir>/`.

## TST-2 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2758
- Confidence: 0.85
- Claim: The valid fixture is only asserted to pass in --metadata mode. The plan requires a pass in --all as well, and the --all test does not check the exit status.
- Evidence: Test at line 2758 runs `metadata` and asserts status 0. Plan Step 8 says: "Copy the fixture ... Assert it passes in --metadata and --all." The docs-state test at line 2837 calls docs_all and asserts only that the output does not contain "unexpected nested path". It has no status assertion, so a --all failure unrelated to nested paths would pass unnoticed.
- Suggested verification: Add a test that installs the valid record and runs `docs_all`, asserting status 0. Confirm that it fails if the record is not accepted in --all mode.

## TST-1 — proposed MINOR

- Worker: review-tests/v1
- Location: scripts/tests/repository-validation.bats:2825
- Confidence: 0.85
- Claim: No test exercises the record-versus-matrix semantic checks for client, floor, e1.entry or e2.binding. Only the priorCandidate and ownerAck.candidate branches are covered.
- Evidence: validate-repository.mjs lines 448-457 (validateReleaseEvidence) add four checks: client in clientFloors, floor equal to clientFloors[client], e1.entry equal to client, and e2.binding equal to the rootBindings id. A grep of repository-validation.bats for `differs from`, `is not a client`, `must equal client` and `rootBindings` finds only pre-existing matrix tests, none that mutate a release record's pairs. Plan Step 8 lists negative cases for priorCandidate and ownerAck and none for these four branches. A regression that deleted those branches would leave the suite green.
- Suggested verification: Add negative cases that mutate a release record's pair floor, e1.entry or e2.binding, or mutate the test root's v0.2.0 matrix clientFloors or rootBindings id so the schema still passes. Each should assert the named semantic message. Then delete one branch and confirm the new test fails.

## COR-1 — proposed MINOR

- Worker: review-correctness/v1
- Location: scripts/validate-repository.mjs:451
- Confidence: 0.45
- Claim: validateReleaseEvidence returns silently when the matrix named by the record cannot be read, so the semantic cross-checks (client, floor, e1.entry, e2.binding, priorCandidate, ownerAck) are skipped with no report.
- Evidence: Line 451: `if (matrix === JSON_READ_FAILURE || !isObject(matrix)) return;`. readJson returns JSON_READ_FAILURE when readText returns null (line 211). readText returns null for a missing file without a report on the missing-file path (lines 129-131). A record that passes the schema (its matrix field is pinned to plugins/loom/adapters/compatibility/v0.2.0.json by const) therefore gets no semantic checks if that matrix file is absent or unreadable. Plan Step 2 requires these checks to run once the schema passes.
- Suggested verification: Read scripts/validate-repository.mjs lines 129-134, 208-216 and 447-466. Confirm whether a missing-file path reports anything. If it does not, run --metadata on a test root holding a valid record with the matrix file removed and check whether any message names the record. Fixing it means reporting the unreadable matrix as a record failure instead of returning.

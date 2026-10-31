# Review findings — evaluation-output-recorder

- Protocol: loom-local-review/v1
- Run: evaluation-output-recorder-711389088045
- Aggregate: ran-with-findings
- Base: 41e9904dd1e85f5896ea9b423126684bfb67a6e0
- Head: 71138908804549f52f1a8799f1514e10ff28d473
- Diff sha256: 1ecf4ac84b645a668e470187216f5b75258ad89d85d2feecd516d60c3a0322fa
- Manifest sha256: 0f0d2c25d0a4c6f6d62cc75197a34067421b36c0fbb15b24065ede5780769265
- Findings sha256: b6f627c1af9e664c6e46a71e98efbd95edc865aaa11f02660324ba6c98652ad3

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | v1 | 524d7b3463fd69e4d3a961900efbc50d89244b160acba32058acf3e53ddde1b2 | claude | sonnet |
| review-security/v1 | v1 | 54a35936e12ca17a790929b5057abac97c7c0ca4463baf4ce8ff9703f7ee1809 | claude | sonnet |
| review-tests/v1 | v1 | 7441d3158be344c3e3c9b40f00aaf27d0d74b8cdbd18e9458d0a74cafec80d1f | claude | sonnet |

## COR-2 — proposed MINOR

- Worker: review-correctness/v1
- Location: plugins/loom/bin/loom-eval-workspace:1384-1405
- Confidence: 0.35
- Claim: The rendered report layout does not match the fixed layout in plan Step 4, which orders the sections as Findings, then Gate rerun evidence. render_report inserts Required changes, Local review adjudication and Notes between them.
- Evidence: render_report emits `## Findings`, then conditionally `## Required changes` and `## Local review adjudication`, then `## Notes`, and only then `## Gate rerun evidence`.
- Suggested verification: Compare the section order produced by render_report with plan Step 4 (`## Findings`, findings, then `## Gate rerun evidence`); decide whether the extra sections are an accepted extension.

## COR-1 — proposed MAJOR

- Worker: review-correctness/v1
- Location: plugins/loom/bin/loom-eval-workspace:1539-1546
- Confidence: 0.6
- Claim: Plan step 5 requires checking the ADR 0023 ratification exception (repository and state eligibility) before a transition, and requires validating the claimed gate. cmd_record does neither: --claimed-gate is only regex-checked and, on a PASS, causes the status to be held; no eligibility check exists and no transition is ever blocked for an ineligible or held state.
- Evidence: The transition block reads: `if [ -n "$claimed" ] && [ "$verdict" = PASS ]; then result=gate-held else set_status "$art_file" "$cur" "$target"`. The `record` additions contain no reference to ADR 0023, ratification, or any eligibility predicate (grep of the added lines for 0023 or ratif finds only the plan header).
- Suggested verification: Read cmd_record from `# transition plan` to the final jq emit in the new file (lines 1508-1551) and search the diff for any ADR 0023 eligibility or claimed-gate validation beyond the name regex at the argument-parsing step; compare with plan Step 5.

## TST-1 — proposed MAJOR

- Worker: review-tests/v1
- Location: plugins/loom/bin/loom-eval-workspace.bats:1337-1626
- Confidence: 0.8
- Claim: The recorder's binding and integrity guards are not exercised by any negative test, so removing them would leave the suite green.
- Evidence: loom-eval-workspace lines 1455-1460 (run_id/manifest_sha256/evaluation_type/head_sha/artifact/base_sha/authority binding jq), 1490 (rerun_attempt seq/result/evidence_sha256 reference), 1466/1471 (prior verdict revision/parse), 1518/1520 (reviewed-artifact status and illegal transition) and 1483-1484 (rerun-incomplete/infrastructure-blocked/invalid) each have a die path. The added @test blocks cover only schema failure, PASS+BLOCKER, round mismatch, tampered blob, missing/extra output, differing report, PASS with rerun-failed. None mutates run_id, manifest_sha256, head_sha, artifact, authority, or rerun_attempt.evidence_sha256/seq in mk_verdict's jq override, none uses a wrong artifact Status, and none uses a missing/infrastructure-blocked rerun.
- Suggested verification: Delete the jq binding check at loom-eval-workspace:1455-1460 and the rerun_attempt check at 1488-1490, then run bats on the record tests; all should still pass. Add mk_verdict overrides such as '.run_id="x"', '.rerun_attempt.evidence_sha256="0...0"' and expect exit 2.

## TST-2 — proposed MINOR

- Worker: review-tests/v1
- Location: plugins/loom/bin/loom-eval-workspace.bats:1479-1486
- Confidence: 0.7
- Claim: The PASS-with-BLOCKER and schema-error tests assert only exit 2 and could pass for an unrelated reason; they also do not assert that the artifact status is unchanged or that no report is written.
- Evidence: Test 'PASS carrying BLOCKER or MAJOR finding fails closed' asserts only [ "$status" -eq 2 ] with no message check and no art_status/report-absence check, and covers only BLOCKER (not MAJOR) despite its name. It exercises the schema else-branch (PASS findings limited to MINOR/NIT) but nothing distinguishes that failure from the binding or round die paths, which also exit 2. The schema's FAIL requires non-empty required_changes, PASS requires empty required_changes, and non-code forbids rerun_attempt/local_review/base_sha; none of those has a test.
- Suggested verification: Change the schema else-branch to allow BLOCKER; the test still passes only if another check fails first. Add assertions on the error text, art_status staying 'Plan Review', and no evaluations report; add MAJOR, FAIL with empty required_changes, PASS with non-empty required_changes, and plan verdict carrying rerun_attempt cases.

## TST-3 — proposed MINOR

- Worker: review-tests/v1
- Location: plugins/loom/bin/loom-eval-workspace.bats:1597-1626
- Confidence: 0.6
- Claim: Round, prior-verdict, claimed-gate and idempotency tests leave key branches and postconditions unasserted.
- Evidence: Only prior verdict FAIL round 0 -> expected round 1 is tested; the prior PASS branch (exp_round stays pr), prior sha/dest mismatch (die at loom-eval-workspace:1528), and a prior verdict without revision are untested. The --claimed-gate test covers PASS only; the FAIL path that still transitions despite a claimed gate (line 1541-1543 condition) and the invalid --claimed-gate value are untested. The idempotency test re-runs record but never asserts the artifact status stays Approved or the report is unchanged, and the already-transitioned cur==target path is the only thing it exercises. The ADR test uses lowercase .docs/adr/ while the repo uses .docs/ADR/ (the production case pattern lists both), so the actual-path variant is untested. Research type and the code FAIL-with-passing-rerun case are also absent.
- Suggested verification: Mutate the claimed-gate condition to ignore verdict (so FAIL is held), or change exp_round for prior PASS; the suite still passes. Add the missing cases and assert post-state.

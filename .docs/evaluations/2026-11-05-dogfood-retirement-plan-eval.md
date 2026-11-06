# Evaluation: dogfood-retirement

Verdict: PASS
Round: 1
Artifact: [dogfood-retirement](../slice-plans/archive/dogfood-retirement.md)
Reviewed against: ADR 0033 §3, ADR 0032 §2, ADR 0024 §§2–5 and §8; specs 03, 08 and 10; the plan-evaluation rubric.
Commit: ad1c13d

## Summary

PASS (round 1, which resolves the round 0 FAIL; BLOCKER: 0, MAJOR: 0, MINOR: 2). The revision
(`git diff d4e278e ad1c13d`) fixes the round 0 blocker. Step 4 now validates the preserved
evidence only when the file is present. The check sits after the `schemaBindings` loop, and
`schemaBindings[0..6]` is unchanged. The stub-evidence test now copies the real evidence, and
the plan adds exactly one `@test`. All three round 0 minors are fixed as well: Step 3 now
uses `mkdir -p` and `rmdir`, the plan explains how withdrawing a plan fits "every plan
preserved unchanged", and Step 8 says what the handoff may contain. I applied Step 4 as
written in a scratch clone. The full `repository-validation.bats` suite went from 206 tests
at baseline to 207, with the same 9 failures both times. Those 9 come from the missing tool
cache in a scratch clone and are not caused by the change.

## Findings

- [MINOR] Internal wording (line 62). The scope bullet says that in `repository-validation.bats`
  "only the stub-evidence lines change". Step 4 also appends the new `@test` to that file. Read
  it as "only the stub-evidence lines change among existing tests", or reword it the next time
  the plan is edited. Implementation is unaffected.
- [MINOR] Step 4 says "add (~4 lines)" but gives a two-statement snippet, which is 2 lines
  as I applied it. This is cosmetic, and the LOC target is unaffected.

## Required changes

None. The minors above do not block.

## Mechanical checks

- **Step 4 feasibility.** I applied it verbatim in a scratch clone at `ad1c13d`, linking the
  main checkout's `scripts/node_modules`.
  - `scripts/validate-repository.mjs` gains 2 lines after the loop.
  - The stub heredoc at `repository-validation.bats:1903–1905` became `mkdir -p` plus `cp`.
  - One new `@test` was appended (12 lines).
  - Running `LOOM_NODE=$(command -v node) TMPDIR=/private/tmp bats scripts/tests/repository-validation.bats` serially:
    - Baseline: 1..206, 197 ok, 9 not ok.
    - Candidate: 1..207, 198 ok, 9 not ok.
    - The failure sets are identical (tests 136, 137, 141, 142 and 144–148, all gate cache or provisioning tests).
  - The stub test (`ok 163`) and the new test (`ok 207`) pass. Verification 6's `--filter` command exits 0.
  - With the new check but the old `{}` stub, the stub test fails at line 1911 (`status -eq 0`), so the stub swap is both needed and sufficient.
  - `--metadata` reports the mutated `.state="bogus"` copy as `…evidence.json: schema /state`.
  - `node scripts/validate-repository.mjs --all` on the real tree exits 0.
- **Discovered count.** Across all tracked `*.bats`, `bats --count` gives 942, and the suite has 41 `@test`. So the baseline is 901 with the suite excluded.
  - After simulating Steps 2, 3, 4, 5 and the CLAUDE.md and README parts of Step 6 in the scratch clone, `bats --count` over the tracked files is 902. With no exclusion list, that equals the gate's `Discovered` count.
  - `Discovered 902` is correct.
- **Step 3.** `dogfood/` tracks only `macos-arm64.json`. The `mkdir -p`/`git mv`/`rmdir` chain
  runs cleanly, `test ! -e …/v0.2.0/dogfood` passes, and the `sha256` before and after is identical
  (`71e53d08…634a`). The only live reference is `README.md:168`, which is a code span, not a link.
- **Verification 1b, withdrawal and README.**
  - With the simulated Step 2 edits (`Status: Abandoned`, the README *Active plans* line), both guard greps match.
  - `! rg --hidden -l "$PAT" "${EXCL[@]}" .` prints nothing after the deletions and the CLAUDE.md:47 and README:168 edits.
  - The spec 03 `Approved → Abandoned` transition is legal.
  - `herdr-hc-client.md` is the in-place precedent (README line 24).
- **Gate.**
  - `scripts/check` reads the list only under `if [ -f "$SCRIPT_DIR/check-bats-exclusions.txt" ]`, so it fails open.
  - `rg dogfood scripts/check .github/workflows/check.yml scripts/check-toolchain.json` exits 1, meaning no hits.
  - The gate runs the validator with `--metadata`, so the new check runs on the real tree.
  - In the simulated candidate, the gate and CI files show a 0-line diff from the baseline.
- **ADR 0033 §3.** The retired set, the preserved evidence and schema, and the byte-identical
  fixture relocation all match the plan. The reconciliation sentence is at lines 48–49.
- **Size and LOC.**
  - The plan is exactly 250 lines (cap ≤ 250).
  - Added LOC is about 2 (validator) + about 14 (Bats) + doc, comment and status edits, well under 60.
  - The deleted-file total is 1838 + 782 + 47 + 3 = 2670, which matches Step 8.
- **Not a finding.** `--all --baseline 65799b8` in the simulation reports the plan's own
  `Approved → Plan Review` status. That is this review cycle's lifecycle state and goes away
  once the plan returns to `Approved`. Verification uses `--all` without a baseline.
- `node scripts/validate-repository.mjs --root <worktree> --all` exits 0 with this record
  installed. I ran it from the main checkout, whose validator is byte-identical to the worktree's.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 (`d4e278e`) | plan | FAIL | BLOCKER: the Step 4 `schemaBindings` entry made the evidence required and broke 33 `repository-validation.bats` tests. Fixed by the present-only check plus the stub swap (verified above). Minors (Step 3 `mkdir`/`rmdir`, ADR 0033 §3 reconciliation, Step 8 handoff wording) are all addressed. |
| (archived r1) | plan | FAIL | `HEAD` baseline and non-hidden scan; resolved by the pinned `Baseline:` and `rg --hidden`. |
| (archived r2) | plan | PASS | Two minors (exact count and fresh-clone commands); added in the approved text. |

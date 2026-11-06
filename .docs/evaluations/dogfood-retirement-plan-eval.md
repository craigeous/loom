# Evaluation: dogfood-retirement

Verdict: FAIL
Round: 0
Artifact: [dogfood-retirement](../slice-plans/dogfood-retirement.md)
Reviewed against: ADR 0033 §3, ADR 0032 §2, ADR 0024 §§2–5 and §8; specs 03, 08 and 10; the plan-evaluation rubric.
Commit: d4e278e

## Summary

FAIL (round 0 in this directory; BLOCKER: 1, MAJOR: 0, MINOR: 3). The revision correctly resolves both
developer clarifications. The `dogfood-int-race` withdrawal, the guarded 1b exclusion, the
exclusion-list deletion and the `Discovered 902` arithmetic all check out against the tree. However, Step 4's
evidence binding, as specified, breaks 33 existing `repository-validation.bats` tests, so the plan's
own required gate (`All checks passed`) cannot pass. Earlier rounds were against an earlier
text. Their records are archived under `.docs/slice-plans/archive/evaluations-reset/`.

## Findings

- [BLOCKER] Step 4 (lines 98–110) is infeasible as written. Appending the evidence to
  `schemaBindings` makes it a *required* file: `validateJson` → `safeNode(target)` reports
  `required file is missing` when absent (`scripts/validate-repository.mjs:100`). Every metadata
  or docs Bats fixture root (`populate_metadata_root`, `make_docs_root`) lacks `.docs/evaluations/…evidence.json`.
  The stub-evidence test (`repository-validation.bats:1903`, writes `{}`) then fails the schema. The
  plan says that test is "unchanged" and expects exit 0, so the claim is false. Reproduced in a scratch clone at `d4e278e`
  with only the Step 4 binding applied. `bats scripts/tests/repository-validation.bats` gives 197 ok at
  baseline and 164 ok with the binding. The 33 new failures are tests 8, 11, 12, 19, 49, 54, 56–58, 62, 67, 69, 149, 155,
  156, 158–160, 163, 165, 167, 169, 171, 173, 179–183, 191, 192, 194 and 195 (e.g. `--metadata` on a fixture root prints
  `.docs/evaluations/macos-dual-client-dogfood-evidence.json: required file is missing`, exit 1).
  The evidence itself does validate: Ajv2020 strict gives true, and `.state="bogus"` is rejected
  on `/state` enum. The plan's escalation trigger covers only "if it [the evidence] fails validation", so it
  does not cover this.
- [MINOR] Step 3 (line 92): the exact `git mv` fails with `fatal: renaming … failed: No such
  file or directory` because `…/v0.2.0/release-install/` does not exist. After a `mkdir -p`
  the move works, but the empty `…/v0.2.0/dogfood/` directory stays in the working tree. Verification 1's
  `test ! -e plugins/loom/adapters/fixtures/v0.2.0/dogfood` then fails locally, though it passes in a fresh clone.
  Add `mkdir -p` before the move and `rmdir` after it.
- [MINOR] ADR 0033 §3 says "Preserved unchanged: … every plan". Step 2 changes `dogfood-int-race.md`'s
  status, Notes and Revision Log. That is a spec 03 lifecycle transition (`Approved → Abandoned`, which the
  validator allows via `legalStep`), and the content is kept, so this is defensible. Still, the plan should state in one
  sentence why a status-only withdrawal satisfies "preserved".
- [MINOR] Verification 1b also scans `.docs/status/handoff.md`, which is not excluded. Step 8's finalize note should
  not spell a retired path such as `scripts/macos-dual-client-dogfood` there, or later re-runs of 1b
  will fail. Say so in Step 8.

## Required changes

1. Rewrite Step 4 so the existing suite stays green. Pick the simplest fail-closed option, for
   example: (a) bind the evidence outside `schemaBindings`, validating it only when it is present
   (`safeNode(…, { missing: false, regularFile: true })`). The new Bats test proves the real-tree pass and the
   mutated-copy rejection, and Verification 3 already pins the bytes. Or (b) the plan's
   own fallback: no validator binding, only Bats assertions. Under either option, state exactly how the stub-evidence test at
   `repository-validation.bats:1903` changes (e.g. copy the real evidence instead of `{}`) or why it
   needs no change. Keep `schemaBindings[0..6]` untouched. Recheck that the `Discovered 902` count still holds
   (exactly one new `@test`) and that the LOC target holds (≤ 60). Keep the plan ≤ 250 lines; it is at 249 now.

## Mechanical checks

- Line counts: `wc -l` on the four deleted files gives 1838, 782, 47 and 3, totalling 2670, which matches Step 8.
  `scripts/check-bats-exclusions.txt` lists only the suite.
- Gate: `scripts/check:527` is the `if [ -f "$SCRIPT_DIR/check-bats-exclusions.txt" ]` guard, so the reader fails
  open. Shell discovery is at 495–507 and Bats discovery at 543. `rg dogfood scripts/check .github/workflows/check.yml
  scripts/check-toolchain.json` exits 1 (no hits).
- Bats count: `bats --count` over all tracked `*.bats` gives 942, of which the suite has 41 `@test`. Excluding the suite
  gives 901. Deleting the suite and list changes the count by 0, and Step 4 adds 1, so 902 is correct.
- 1b at baseline: without the `dogfood-int-race.md` glob it hits int-race, CLAUDE.md, README.md and the
  three deleted files. With the glob it hits only CLAUDE.md:47, README.md:168 and the three deleted files,
  and Steps 3, 5 and 6 remove all of those. The guard greps match the prescribed status and README line.
- Conventions: `herdr-hc-client.md` is the in-place `Abandoned` precedent in *Active plans*.
  The validator's `legalStep` allows `Approved → Abandoned`. Archive renames are allowed only from baseline `Landed` or `Abandoned`
  (`validate-repository.mjs:1111`), as the plan states.
- References: validator exemption at 1013 and `schemaBindings` at 361–369 are correct. CLAUDE.md is 100 lines,
  and lines 13–14, 44 and 47 are as cited. README 114, 168 and 250–255 and the `loom-launch-role` 3–4 and 38–39 / `.bats:3`
  comments are as cited. The replacement invariant text is verbatim from ADR 0032 lines 131–134. The allowlist has 34
  `dogfood` rows, all sourced from historical records, and none targets a retired or relocated path.
- `node scripts/validate-repository.mjs --root <worktree> --all` exits 0 at `d4e278e`, using the byte-identical
  validator from the main checkout because the worktree has no `node_modules`.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| (archived r1) | plan | FAIL | `HEAD` baseline and non-hidden scan; resolved by the pinned `Baseline:` and `rg --hidden`. |
| (archived r2) | plan | PASS | Two minors (exact count and fresh-clone commands); added in the approved text. |

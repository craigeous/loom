# Evaluation: dogfood-gate-exclusion (code)

Verdict: PASS
Round: 0
Commit: dc71785
Artifact: [dogfood-gate-exclusion slice plan](../slice-plans/dogfood-gate-exclusion.md) @ dc71785 (base c2db416)
Reviewed against: ADR 0033 §3 and Consequences; ADR 0024 §8; the slice plan
`.docs/slice-plans/dogfood-gate-exclusion.md` (Steps 1-3, acceptance criteria a-h); the
code-eval rubric; shell gate per spec 08.

## Summary

PASS (BLOCKER: 0, MAJOR: 0, MINOR: 3). The diff adds a name-agnostic exclusion-list reader
to the `scripts/check` "Bats tests" stage and a three-line `scripts/check-bats-exclusions.txt`
naming only `scripts/tests/macos-dual-client-dogfood.bats`. The code matches plan Step 2
exactly. No test is deleted, edited, or skip-annotated. The full gate reran green on dc71785,
and all of criteria a-h hold.

## Findings

- [MINOR] m1. No review-findings artifact for this slice. `.docs/evaluations/dogfood-gate-exclusion-review-findings.md`
  does not exist, and no `skipped: docs-only` status was recorded. This is a code change to
  `scripts/check`, so the ADR 0021 local review applies. Per the rubric, a missing required
  review is not permission to land. The orchestrator must run `loom-review` or record a
  justified status before `Landed`. This verdict judges the diff on its merits and does not
  depend on that review.
- [MINOR] m2. Base..candidate (c2db416..dc71785) also includes d5ad794, which rewrites the plan-eval
  record `dogfood-gate-exclusion-eval.md`: `Round: 1` becomes `Round: 0`, and a `Commit:` field
  and a `## Summary` section are added. That edit is outside the developer's two-file scope.
  Its rationale is that the r1 FAIL is archived outside `.docs/evaluations/`, so the validator's
  eval-sequence counts this as the first evaluation. That is a recorder hygiene fix, not slice
  code, and does not affect the gate. It is noted here so the archived r1 FAIL remains the
  cited history.
- [MINOR] m3. File naming. The validator accepts `dogfood-gate-exclusion-code-eval.md` only for
  allowlisted historical files, because the name resolves to the identity
  `dogfood-gate-exclusion-code` and fails the `authority` rule. The plan-eval verdict already
  occupies `dogfood-gate-exclusion-eval.md`, so this code verdict uses the supported dated form.
  It shares the `dogfood-gate-exclusion` identity and the `eval-sequence` round chain with that
  record.

## Required changes (for FAIL)

None.

## Notes

Gate rerun on candidate dc71785:
`bash -c 'set -o pipefail; TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check 2>&1 | tee …'` → exit 0.

Acceptance criteria, each checked mechanically:

- a. Candidate gate exit 0 (above).
- b. `B` = `grep -c '^@test'` on the dogfood suite = 41. Candidate log: `Discovered 931 Bats tests`.
  T0 = 972: the tracked `*.bats` set is unchanged between c2db416 and dc71785
  (`git diff --quiet c2db416 dc71785 -- '*.bats'`), and `bats --count` over all tracked files
  gives 972. Over all files minus the excluded one it gives 931. 972 - 931 = 41 = B.
- c. Candidate log has exactly one `^Excluding ` line:
  `Excluding scripts/tests/macos-dual-client-dogfood.bats: see dogfood-gate-exclusion plan`.
  The base `scripts/check` has no `Excluding` printf, so the base cannot emit it.
- d. Apart from the Excluding line, `macos-dual-client-dogfood` does not appear in the candidate log.
- e. `rg -n 'dogfood' scripts/check` → no output, exit 1.
- f. The list has exactly one non-comment entry, the dogfood suite path, and `wc -l` = 3.
- g. `git diff --name-only c2db416 dc71785 -- scripts plugins .github .docs/spec .docs/ADR` →
  only `scripts/check` and `scripts/check-bats-exclusions.txt`. Numstat is `19 1` and `3 0`,
  which matches the plan. The only other changed paths are the plan (status plus `## Gate Evidence`)
  and the plan-eval record (m2).
- h. `node scripts/validate-repository.mjs --all` → exit 0. The exit status was captured directly,
  not through a pipe.

Correctness trace: the reader is Bash 3.2-safe. It uses no `mapfile`, guards empty arrays with the
`${a[@]+"${a[@]}"}` idiom for `set -u`, and handles a final line without a trailing newline
(`|| [ -n "$entry" ]`). A missing list means no exclusions, so the gate fails open to running
everything. The `repository-validation.bats` copy of `scripts/check` runs without a list, which
takes this path. The required-file loop adds back only `shell-runtime.bats` and
`repository-validation.bats`, and both still run. An entry with stray whitespace would not match
any tracked path, so it fails open (the file still runs). `shfmt -i 4 -d` and
`shellcheck -s bash` are clean on `scripts/check`. The suite stays tracked, has not been modified,
and can still be run by hand. Commits are author-neutral, with no trailers and no fallback identity.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | PASS | Plan-eval record `dogfood-gate-exclusion-eval.md` (archived r1 FAIL resolved by name-agnostic list file and runnable criteria). |

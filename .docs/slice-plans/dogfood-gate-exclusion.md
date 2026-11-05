# Exclude the macOS Dogfood Bats Suite from the Publication Gate Until Its Removal

Status: Landed
Target specs: none (gate-script change); gate per 08-playbook.md
Authority: ADR 0033 (Accepted) retires the macOS dogfood suite via `dogfood-retirement` (Approved); binding owner decision (option 2): exclude the suite from the gate until that slice lands. This plan supersedes nothing. No accepted ADR is changed: ADR 0024 §8 keeps the M0-M7 release gate (this edits a `scripts/check` stage's input list, not that gate), and ADR 0033 §3 and Consequences already move the suite out of the gate.
Target size: <= 25 LOC net change across two files (`scripts/check` and new `scripts/check-bats-exclusions.txt`); keep this plan <= 250 lines

## Context

`scripts/check` stage "Bats tests" (line 523) discovers every tracked `*.bats` file
with `git ls-files -z -- '*.bats'` (line 525), appends the two required files if
missing (lines 526-530), prints `Discovered N Bats tests` (line 532) and runs all of
them through `scripts/run-bats-under` (line 533). `scripts/tests/macos-dual-client-dogfood.bats`
(41 `@test` lines) has flaky tests (725 and 736 failed in publication gate runs) and is
scheduled for deletion by `dogfood-retirement`. Until then the flake blocks publication.
The owner decided to exclude exactly that file from the gate rather than weaken it.

Design constraint: the Approved `dogfood-retirement` plan (Step 7, Verification #4) requires
zero diff in `scripts/check` against its BASE and no `dogfood` text in `scripts/check`. So
`scripts/check` must stay name-agnostic: it reads a generic list file, and the only
dogfood-specific artifact is that list's one entry, which retirement deletes with the suite.

Discovery consumers, verified against the tree:

- `scripts/check:525` is the only place a `*.bats` list is built. `.github/workflows/check.yml`
  runs `scripts/check` (line 129) and has no separate Bats list, so CI inherits the exclusion.
- `scripts/validate-repository.mjs` never reads a Bats list; it walks `git ls-files`
  (line 170) for links/metadata, which still includes the excluded file (it stays tracked).
  Nothing in validation needs to change and no list must be kept in sync.
- `scripts/run-bats-under` receives the file list as arguments; it needs no change.
- `scripts/tests/repository-validation.bats` copies `scripts/check` into a temp root and
  runs it only in contract/bash-only/shim modes; none asserts on the Bats discovery text.

## Out of Scope & Threat-Model Boundary

- Do not delete, edit, skip-annotate, or weaken the dogfood suite or any other test;
  the file stays tracked and runnable by hand (`bats scripts/tests/macos-dual-client-dogfood.bats`).
- No change to the validator, `run-bats-under`, CI workflow, any ADR, any spec, or the
  `dogfood-retirement` plan. No gate command changes other than the list read and the printed line.
- No environment override or per-test skipping: the list names whole files only.
- Threat-model per `.docs/spec/00-overview.md` `## Non-goals`: no hostile-local assumptions added.
  The list is a tracked, reviewed file; a missing list means no exclusions (fail open to
  running everything, never to skipping).

## Steps

1. Create `scripts/check-bats-exclusions.txt` with exactly three lines: a comment line
   (`# Bats files excluded from scripts/check; one repo-relative path per line.`), a plan
   reference comment line (`# plan: dogfood-gate-exclusion`), and the single entry
   `scripts/tests/macos-dual-client-dogfood.bats`. Blank lines and `#` lines are ignored by the reader.
2. In `scripts/check`, in the `stage "Bats tests"` block (line 523-525), replace the
   one-line discovery loop with the code below. It reads the list (Bash 3.2-safe: no `mapfile`,
   empty-array guard for `set -u`), prints one line per excluded file, and skips those tracked paths.
   The plan name printed comes from the list's `# plan:` line, so `scripts/check` itself never
   contains the word `dogfood`.

   ```bash
   excluded_tests=()
   exclusion_plan=unspecified
   if [ -f "$SCRIPT_DIR/check-bats-exclusions.txt" ]; then
       while IFS= read -r entry || [ -n "$entry" ]; do
           case "$entry" in
           '# plan: '*) exclusion_plan=${entry#'# plan: '} ;;
           '' | '#'*) ;;
           *) excluded_tests+=("$entry") ;;
           esac
       done <"$SCRIPT_DIR/check-bats-exclusions.txt"
   fi
   for entry in ${excluded_tests[@]+"${excluded_tests[@]}"}; do
       printf 'Excluding %s: see %s plan\n' "$entry" "$exclusion_plan"
   done
   while IFS= read -r -d '' tracked; do
       skip=false
       for entry in ${excluded_tests[@]+"${excluded_tests[@]}"}; do [ "$tracked" = "$entry" ] && skip=true; done
       $skip || test_files+=("$REPOSITORY_ROOT/$tracked")
   done < <(git -C "$REPOSITORY_ROOT" ls-files -z -- '*.bats')
   ```

   The required-file loop (lines 526-530) names only `shell-runtime.bats` and
   `repository-validation.bats`, so it cannot re-add an excluded file. The `Discovered` printf and the
   `run-bats-under` call are unchanged.
3. Run `shfmt -i 4 -d scripts/check` and `shellcheck -s bash scripts/check`; fix formatting
   only in the touched lines. No other edits anywhere.

Measured size: applying step 2 to a scratch copy of `scripts/check` gives
`git diff --no-index --numstat` = `19 1` (19 added, 1 removed, net +18); the list file is `3 0`.
Total 22 added, 1 removed, net +21 (within the <= 25 target). The developer re-measures with
`git diff --numstat BASE HEAD -- scripts/check scripts/check-bats-exclusions.txt`.

## Verification

Capture the baseline T0 by running the gate once on the baseline commit, and the candidate by
running it once on the candidate; compare their `Discovered` lines. Use a bash shell
(`PIPESTATUS`-free: `pipefail` is set explicitly). `BASE` is the commit before the candidate.

```bash
BASE=$(git rev-parse HEAD~1)        # candidate = HEAD; adjust if the candidate has fixups
git worktree add /private/tmp/gx-base "$BASE"
bash -c 'cd /private/tmp/gx-base && TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check' 2>&1 | tee /private/tmp/gate-base.log
bash -c 'set -o pipefail; TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check 2>&1 | tee /private/tmp/gate-cand.log'
```

The baseline run's exit status is not asserted (the suite flake may fail it); only its
`Discovered` line is read. Targeted during iteration: `shfmt -i 4 -d scripts/check`,
`shellcheck -s bash scripts/check`.

Acceptance criteria (each is a command; expected result stated):

a. Candidate gate passes: the candidate command above exits 0.
b. Count drops by exactly B. Define
   `B=$(grep -c '^@test' scripts/tests/macos-dual-client-dogfood.bats)` (expected 41),
   `T0=$(sed -n 's/^Discovered \([0-9][0-9]*\) Bats tests$/\1/p' /private/tmp/gate-base.log)` (expected 972),
   `T1=$(sed -n 's/^Discovered \([0-9][0-9]*\) Bats tests$/\1/p' /private/tmp/gate-cand.log)` (expected 931).
   `test "$((T0 - T1))" -eq "$B"` exits 0.
c. Exclusion line visible exactly once, and only in the candidate:
   `rg -c '^Excluding scripts/tests/macos-dual-client-dogfood\.bats: see dogfood-gate-exclusion plan$' /private/tmp/gate-cand.log`
   prints `1`; `rg -c '^Excluding ' /private/tmp/gate-cand.log` prints `1`;
   `rg -c '^Excluding ' /private/tmp/gate-base.log` prints nothing and exits 1.
d. Excluded file is not run: `rg -v '^Excluding ' /private/tmp/gate-cand.log | rg -c 'macos-dual-client-dogfood'`
   prints nothing and exits 1 (the name appears only on the Excluding line).
e. No dogfood text in the gate script: `rg -n 'dogfood' scripts/check` prints nothing and exits 1.
f. List contract: `rg -v '^(#|$)' scripts/check-bats-exclusions.txt` prints exactly
   `scripts/tests/macos-dual-client-dogfood.bats` (one line), and
   `test "$(wc -l < scripts/check-bats-exclusions.txt | tr -d ' ')" -eq 3`.
g. Scope: `git diff --name-only BASE HEAD -- scripts plugins .github .docs/spec .docs/ADR | sort`
   prints exactly `scripts/check` and `scripts/check-bats-exclusions.txt`; and
   `git diff --numstat BASE HEAD -- scripts/check scripts/check-bats-exclusions.txt` shows `19 1` and `3 0`
   (a different count must be reconciled in the code-eval, not silently accepted).
h. `node scripts/validate-repository.mjs --all` exits 0.

Regression proof: `repository-validation.bats` and `shell-runtime.bats` pass unchanged inside
criterion (a) (both still run and still copy/exercise `scripts/check`).

## Gate Evidence

Baseline (c2db416, gate exit 1 from suite flake): Discovered 972. Candidate: Discovered 931, one
Excluding line, `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` exit 0 ("All checks passed").
B=41, T0-T1=41. Criteria a-h pass; numstat `19 1` and `3 0`; validate-repository --all exit 0.

## Notes

- The `dogfood-retirement` slice deletes `scripts/check-bats-exclusions.txt` (or its single
  entry) as part of deleting the suite. That is a file deletion, not a `scripts/check` edit, so
  its Verification #4 (no `git diff --stat` in `scripts/check` against its BASE and no
  `dogfood` in `scripts/check`) still holds. The generic reader then runs with no list, or with
  an empty list, and is left in place as inert, name-agnostic code. This plan does not edit
  the retirement plan.
- Discovery consumers (verified): `scripts/check` is the only place a `*.bats` list is built;
  `.github/workflows/check.yml:129` runs `scripts/check` with no separate list, so CI inherits the
  exclusion; `scripts/validate-repository.mjs` walks `git ls-files` for links/metadata and the file
  stays tracked; `run-bats-under` takes the list as arguments;
  `scripts/tests/repository-validation.bats` copies `scripts/check` and runs it only in
  contract/bash-only/shim modes, none asserting on Bats discovery text (and `$SCRIPT_DIR` in
  the copy has no list, which is the safe no-exclusion path).

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | B1: name-agnostic list file read by `scripts/check` (no dogfood text), retirement deletes the list; M1: runnable criteria with single baseline and candidate gate runs; m1: ADR 0024 §8 / 0033 line; m2: exact numstat LOC |

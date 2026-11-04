# Exclude the macOS Dogfood Bats Suite from the Publication Gate Until Its Removal

Status: Plan Review
Target specs: none (gate-script change); gate per 08-playbook.md
Authority: ADR 0033 (Accepted) retires the macOS dogfood suite via `dogfood-retirement` (Approved); binding owner decision (option 2): exclude the suite from the gate until that slice lands. This plan supersedes nothing.
Target size: <= 15 LOC net change in one file (`scripts/check`); keep this plan <= 250 lines

## Context

`scripts/check` stage "Bats tests" (line 523) discovers every tracked `*.bats` file
with `git ls-files -z -- '*.bats'` (line 525), appends the two required files if
missing (lines 526-530), prints `Discovered N Bats tests` (line 532) and runs all of
them through `scripts/run-bats-under` (line 533). `scripts/tests/macos-dual-client-dogfood.bats`
(41 `@test` lines) has flaky tests (725 and 736 failed in publication gate runs) and is
scheduled for deletion by `dogfood-retirement`. Until then the flake blocks publication.
The owner decided to exclude exactly that file from the gate rather than weaken it.

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
- No change to the validator, `run-bats-under`, CI workflow, any ADR, or any spec. ADR 0033
  remains the authority for retirement; this is a temporary gate carve-out only.
- No generic exclusion mechanism, environment override, or config file: one fixed path.
- Threat-model per `.docs/spec/00-overview.md` `## Non-goals`: no hostile-local assumptions added.
- Removal of the carve-out is `dogfood-retirement`'s job (it deletes the suite; the variable
  and filter then become dead and must be removed in that slice's `scripts/check` edit).

## Steps

1. In `scripts/check`, immediately after `stage "Bats tests"` (line 523) and before
   `test_files=()` (line 524), add the single reviewable exclusion point:

   ```bash
   # Temporary gate carve-out: .docs/slice-plans/dogfood-gate-exclusion.md (ADR 0033).
   # Remove together with the suite in dogfood-retirement.
   BATS_EXCLUDED_FILE="scripts/tests/macos-dual-client-dogfood.bats"
   printf 'Excluding %s from Bats stage (.docs/slice-plans/dogfood-gate-exclusion.md)\n' "$BATS_EXCLUDED_FILE"
   ```

2. Change the discovery loop (line 525) to skip that tracked path, keeping its form:

   ```bash
   while IFS= read -r -d '' tracked; do
       [ "$tracked" = "$BATS_EXCLUDED_FILE" ] || test_files+=("$REPOSITORY_ROOT/$tracked")
   done < <(git -C "$REPOSITORY_ROOT" ls-files -z -- '*.bats')
   ```

   `[ ... ] || cmd` is safe under `set -e` in the loop body (the last command's status is
   the append's, 0). The required-file loop (lines 526-530) names only `shell-runtime.bats`
   and `repository-validation.bats`, so it cannot re-add the excluded file.
3. Run `shfmt -i 4 -d scripts/check` and `shellcheck -s bash scripts/check`; fix formatting
   only in the touched lines. No other edits anywhere.

Expected touched lines: 523-525 region (about 4 added, 1 replaced by 3: net about +7 LOC).

## Verification

Record the baseline before editing (on the unmodified tree):
`B=$(grep -c '^@test' scripts/tests/macos-dual-client-dogfood.bats)` (expected 41) and
the previous total `T0` from the old gate's `Discovered T0 Bats tests` line (expected 972 =
931 other + 41; the developer records the actual printed number).

Gate (once, on the candidate commit): `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
Targeted during iteration: `shfmt -i 4 -d scripts/check`, `shellcheck -s bash scripts/check`.

Acceptance criteria:

a. Excluded file not run: gate prints `Discovered T1 Bats tests` with `T1 = T0 - B`
   (expected 41 fewer); `bats --count` over the discovered list never includes the file.
b. Every other file still runs: the final Bats summary's ok count equals `T0 - B`
   (no other file dropped; `git ls-files '*.bats' | wc -l` is 18, run files are 17).
c. Exclusion line visible: gate output contains exactly one line
   `Excluding scripts/tests/macos-dual-client-dogfood.bats from Bats stage (.docs/slice-plans/dogfood-gate-exclusion.md)`
   (`scripts/check ... | rg -c '^Excluding '` is 1).
d. `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` exits 0 on the candidate.
e. `node scripts/validate-repository.mjs --all` exits 0.

Regression proof: `repository-validation.bats` and `shell-runtime.bats` pass unchanged
(both still run and still copy/exercise `scripts/check`).

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

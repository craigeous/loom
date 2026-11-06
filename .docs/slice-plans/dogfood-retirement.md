# Retire the macOS Dual-Client Checkpoint Tooling

Status: Plan Review
Target specs: 10-packaging.md (release evidence inputs), 08-playbook.md (gate); no spec text changes
Authority: ADR 0033 §3 (Accepted), ADR 0032 §2 (Accepted), ADR 0024 §§2–5, §8 (history, unchanged)
Target size: <= 60 LOC added (one present-only validator check, one Bats test, a one-line stub swap, doc/comment/status edits); deletions and the byte-identical relocation are not counted; keep this plan <= 250 lines

## Context

ADR 0033 §3 (owner decision D1) retires the Apple-silicon checkpoint tooling that ADR
0024 §6 built and ADR 0032 §2 already demoted to history. Four tracked files are
code/state for that tooling and nothing else in the gate depends on them:

| File | Lines | Role |
|---|---|---|
| `scripts/macos-dual-client-dogfood` | 1838 | supervisor/worker harness |
| `scripts/tests/macos-dual-client-dogfood.bats` | 782 | its 41-test suite |
| `plugins/loom/schemas/loom-dogfood-state-v1.schema.json` | 47 | runtime `state.json` schema (`loom-dogfood-state/v1`), used only by the harness (`scripts/macos-dual-client-dogfood:118`) |
| `scripts/check-bats-exclusions.txt` | 3 | gate exclusion list added by landed `dogfood-gate-exclusion`; its only entry is the suite above |

Mechanical facts (verified with `rg` at the pinned baseline `65799b8`; re-run in Step 1):

- `scripts/check` finds shell files and Bats files by `git ls-files` (lines 495–507, 543)
  and reads the exclusion list only inside `if [ -f "$SCRIPT_DIR/check-bats-exclusions.txt" ]`
  (line 527), so deleting the list fails open. `scripts/check`, `.github/workflows/check.yml`
  and `scripts/check-toolchain.json` contain **no** `dogfood` string: no gate edit is needed.
- Bats count: 942 tracked `@test`s − 41 excluded suite = `Discovered 901 Bats tests` at the
  baseline; deleting the suite and list changes that by 0, and Step 4 adds exactly 1 → 902.
- `scripts/validate-repository.mjs` does not load the state schema. Line 1013 exempts the
  evidence file from evaluation-name checks (**keep**); lines 361–369 build `schemaBindings`
  `[0..6]`. Every binding target is *required* (`safeNode` → `required file is missing`,
  line 100) and the Bats fixture roots lack the evidence, so an 8th binding breaks 33 tests.
- The preserved record — `.docs/evaluations/macos-dual-client-dogfood-evidence.json`
  (state `infrastructure-blocked`, candidate `a0bf31604cc760631ba48b8fee574f89ef120cc8`)
  and `plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json` — is read only by the
  harness today, so Step 4 validates it against that schema **only when present**
  (planner-prototyped on `fe1e019`: `repository-validation.bats` 207 tests with the same 9
  cache-dependent scratch-clone failures as the 206-test baseline; real tree `--all` exit 0).
- The install-command fixture `plugins/loom/adapters/fixtures/v0.2.0/dogfood/macos-arm64.json`
  (schema string `loom-dogfood-fixture/v1`, client floors, marketplace/plugin names,
  install commands) is cited by `README.md:168` and read by the harness (`:117`). It
  becomes release-install input for the v0.2.0 live proof (ADR 0033 §2).
- `.docs/slice-plans/dogfood-int-race.md` (`Status: Approved`, listed under *Active plans*;
  unlanded worktree branch) fixes a flake in the suite this slice deletes and cites the
  harness path. It is moot once this slice lands, so Step 2 withdraws it (`Abandoned`) per
  the README's convention (`herdr-hc-client.md`): in place, `Abandoned` label, "history
  kept", no `archive/` move (the validator allows that only from a baseline `Abandoned`).
  This meets ADR 0033 §3's "every plan preserved unchanged": the spec 03 `Approved →
  Abandoned` transition is a status withdrawal, and the plan's content and history stay intact.
- The link allowlist `scripts/validation/relative-link-allowlist.txt` has 34 rows containing
  `dogfood`; every one names an archived or historical `.docs/` record that stays. **No
  allowlist row names the script, state schema, fixture, evidence JSON or exclusion list**,
  so the allowlist needs no prune unless Step 3's relocation creates a link row (it must not).

## Out of Scope & Threat-Model Boundary

- No edit to any ADR, spec, verdict, archive or research note, and no plan other than this
  one and `dogfood-int-race.md` (status + note only; body and history stay). `dogfood-gate-exclusion.md` (Landed) is not touched or
  archived here. Spec 03 line 370 and the `progress.md`/`roadmap.md` mentions are history
  and stay; frozen-spec wording about dogfood is a separate planner cycle (ADR 0033
  Consequences).
- `repository-validation.bats`: only the stub-evidence lines change (Step 4); `schemaBindings` is not edited.
- No edit to `scripts/check`, `check.yml` or `check-toolchain.json`; no change to
  `loom-launch-role` behavior, hooks, matrices, manifests, schemas other than the one
  deleted, or any live-proof procedure. No run of `hc`, Orca, `agy` or live clients. No
  new harness, no rewrite of the fixture's bytes. No deletion of any git branch or
  worktree (including `dogfood-int-race`'s).
- Product install/hook/launch coverage stays in `plugins/loom/bin/loom-launch-role.bats`,
  the hook suites and `repository-validation.bats`; this slice adds none of it back.
- Threat model per spec 00 Non-goals: no hostile-local-actor assumptions added or removed.

## Steps

Prerequisites (met at the baseline): ADR 0033 Accepted; `herdr-surface-retirement` Landed.

0. **Baseline is pinned:** `## Notes` holds `Baseline: 65799b81d9140e4f33497361488b9c0a69c0ccde`
   (committed in `e1a4b59`). Keep that line unchanged; every check uses it, never `HEAD`.
1. **Inventory (no edit).** Run the Verification greps and a baseline `scripts/check`
   (or read its `Discovered N Bats tests` line); record counts in the finalize note. If any
   hit appears outside the allowed set below, or the baseline count is not 901, stop and
   add a `## Notes` clarification rather than guessing.
2. **Withdraw `dogfood-int-race`** (planner-authorized, owner-aligned):
   - In `.docs/slice-plans/dogfood-int-race.md`: `Status: Approved` → `Status: Abandoned`;
     replace `(none)` under its `## Notes` with one dated line:
     `2026-11-05: Abandoned — superseded by ADR 0033 / dogfood-retirement, which deletes the fix target scripts/tests/macos-dual-client-dogfood.bats; history kept.`
     Add one Revision Log row (`2 | Abandoned: moot after dogfood-retirement`). No other edit.
   - In `.docs/slice-plans/README.md` *Active plans*, replace its entry with
     `- [dogfood-int-race.md](dogfood-int-race.md) — \`Abandoned\` — superseded by \`dogfood-retirement\` (ADR 0033), which deletes its target suite (history kept).`
     and move that line to sit directly above the `herdr-hc-client.md` Abandoned entry.
     No `git mv`; the file stays in `.docs/slice-plans/`.
3. **Relocate the fixture, bytes unchanged** (`F=plugins/loom/adapters/fixtures/v0.2.0`):
   `mkdir -p $F/release-install && git mv $F/dogfood/macos-arm64.json $F/release-install/macos-arm64.json && rmdir $F/dogfood`
   (`git mv` fails without the target directory; `dogfood/` holds only that file, so the
   `rmdir` succeeds and Verification 1's `test ! -e` passes locally). Update the one live
   reference `README.md:168` (`fixtures/v0.2.0/dogfood/` → `fixtures/v0.2.0/release-install/`).
   `sha256` is identical before and after (record both). Add no allowlist row; if
   `validate-repository` reports a new broken link, fix the link.
4. **Keep the preserved evidence checkable (present-only, fail closed when present).**
   In `scripts/validate-repository.mjs` `validateMetadata`, directly after the
   `schemaBindings` loop (leave `schemaBindings[0..6]` untouched), add (~4 lines):
   `const dogfoodEvidence = ".docs/evaluations/macos-dual-client-dogfood-evidence.json";`
   then `if (safeNode(dogfoodEvidence, { missing: false, regularFile: true }) && !validateJson(dogfoodEvidence, "plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json", ajv)) structurallyValid = false;`
   Absent → skipped; symlink/non-regular → unsafe; schema-invalid → `schema /…`, exit 1.
   Do **not** edit the evidence or its schema; if it fails, stop and escalate in `## Notes`.
   In `scripts/tests/repository-validation.bats`:
   - **Stub-evidence test** (`docs state: evaluation names accept every legal form…`, ~line
     1903): its `{}` heredoc would now fail the schema and its `status -eq 0`; replace it with
     `mkdir -p "$TEST_ROOT/.docs/evaluations"` + `cp "$REPOSITORY_ROOT/.docs/evaluations/macos-dual-client-dogfood-evidence.json" "$TEST_ROOT/.docs/evaluations/"`
     (its allowlist `grep -v` line and assertions stay).
   - **Exactly one new `@test`** (≈12 LOC), `repository: preserved dogfood evidence validates
     against its schema`: `make_metadata_root`, copy the evidence as above, `metadata` → 0;
     `mutate_json …evidence.json '.state = "bogus"'`, `metadata` → 1 with output containing
     `.docs/evaluations/macos-dual-client-dogfood-evidence.json: schema /state`.
5. **Delete** (one `git rm`): `scripts/macos-dual-client-dogfood`,
   `scripts/tests/macos-dual-client-dogfood.bats`, `plugins/loom/schemas/loom-dogfood-state-v1.schema.json`,
   `scripts/check-bats-exclusions.txt` (authorized: its only entry is the deleted suite;
   `scripts/check` fails open on its absence and is **not** edited).
6. **Update exact references (live files only):**
   - `CLAUDE.md:47` — delete the `scripts/macos-dual-client-dogfood` Map bullet.
   - `CLAUDE.md:13–14` — replace "Private macOS dogfood is not public support or release
     conformance." with ADR 0032 §2's invariant text verbatim ("A (platform, harness)
     pair is supported only in a release whose compatibility matrix lists it with
     complete conformance evidence; there is no private or partial support tier. Evidence
     from one platform or harness is not conformance for another."). Line 44
     (`.docs/` "dogfooding") stays: ordinary self-use. Keep the file ≤ ~100 lines.
   - `README.md:168` as in Step 3. `README.md:250–255` — reword the one paragraph so it
     says the evidence file records a blocked historical checkpoint (Codex role launch
     `infrastructure-blocked`) and confers no support status; keep the link to the
     evidence JSON; remove the claim of "private" tooling. `README.md:114` stays.
   - `plugins/loom/bin/loom-launch-role:3–4,38–39` and
     `plugins/loom/bin/loom-launch-role.bats:3` — comment-only: replace "macos-dual-client-dogfood
     plan Step 6" / "dogfood pass (ADR 0024)" with "the v0.2.0 live proof (ADR 0032 E4)".
     No code or test-body change; `shfmt -i 4 -d` clean.
7. **Gate and CI changes: none** (Context; Verification 4 proves 0 lines changed).
8. **Finalize note** (developer finalize pass): `progress.md`/`handoff.md` record the
   slice (and that `dogfood-int-race` is Abandoned and the exclusion list is gone); the
   Landed log lists the deleted-file line total (2670) and the preserved evidence hash.
   `handoff.md` is in the 1b scan: name the deletions in words ("the checkpoint harness, its
   suite and state schema"), never a `PAT` path. `roadmap.md` is unchanged.

## Verification

Fast targeted (macOS: `TMPDIR=/private/tmp`). Every command exits 0; `! rg` lines print nothing.

```sh
# 0. Baseline from `## Notes` (never HEAD); must be an ancestor of the candidate.
BASE=$(sed -n 's/^Baseline: \([0-9a-f]\{40\}\)$/\1/p' .docs/slice-plans/dogfood-retirement.md)
test "$BASE" = 65799b81d9140e4f33497361488b9c0a69c0ccde
git cat-file -e "$BASE^{commit}" && git merge-base --is-ancestor "$BASE" HEAD
# 1. Retired files are gone; nothing live points at them.
test ! -e scripts/macos-dual-client-dogfood
test ! -e scripts/tests/macos-dual-client-dogfood.bats
test ! -e plugins/loom/schemas/loom-dogfood-state-v1.schema.json
test ! -e scripts/check-bats-exclusions.txt
test ! -e plugins/loom/adapters/fixtures/v0.2.0/dogfood
PAT='loom-dogfood-state|scripts/macos-dual-client-dogfood|fixtures/v0\.2\.0/dogfood'
# 1a. Historic hits, listed on purpose (expected: only history paths, nonempty):
rg --hidden -l "$PAT" --glob '!.git/**' . | sort
# 1b. Assertion. The one non-history plan excluded by exact path is dogfood-int-race.md,
#     and only while it is Abandoned (fail-closed guard runs first).
EXCL=(--glob '!.git/**' --glob '!.docs/slice-plans/archive/**' --glob '!.docs/status/archive/**'
  --glob '!.docs/evaluations/**' --glob '!.docs/research/**' --glob '!.docs/ADR/**'
  --glob '!.docs/status/progress.md' --glob '!.docs/slice-plans/dogfood-retirement.md'
  --glob '!.docs/slice-plans/dogfood-int-race.md')
grep -qx 'Status: Abandoned' .docs/slice-plans/dogfood-int-race.md
grep -q 'dogfood-int-race.md.*`Abandoned`' .docs/slice-plans/README.md
! rg --hidden -l "$PAT" "${EXCL[@]}" .
# 2. Fixture relocated byte-identical (baseline content vs candidate file).
test "$(git show "$BASE":plugins/loom/adapters/fixtures/v0.2.0/dogfood/macos-arm64.json | shasum -a 256 | cut -d' ' -f1)" \
  = "$(shasum -a 256 plugins/loom/adapters/fixtures/v0.2.0/release-install/macos-arm64.json | cut -d' ' -f1)"
# 3. Preserved record byte-identical to baseline and valid JSON.
git diff --exit-code "$BASE" HEAD -- .docs/evaluations/macos-dual-client-dogfood-evidence.json \
    plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json
jq -e '.state=="infrastructure-blocked" and .candidate=="a0bf31604cc760631ba48b8fee574f89ef120cc8"' \
    .docs/evaluations/macos-dual-client-dogfood-evidence.json
# 4. No gate/CI/toolchain edit, no dogfood strings there, and the list reader fails open.
test -z "$(git diff --stat "$BASE" HEAD -- scripts/check .github/workflows/check.yml scripts/check-toolchain.json)"
! rg -n 'dogfood' scripts/check .github/workflows/check.yml scripts/check-toolchain.json
grep -qF 'if [ -f "$SCRIPT_DIR/check-bats-exclusions.txt" ]; then' scripts/check
# 5. Link rows: none added; the 34 historic `dogfood` rows unchanged.
test -z "$(git diff "$BASE" HEAD -- scripts/validation/relative-link-allowlist.txt)"
# 6. New + stub-evidence validation tests (setup_file needs LOOM_NODE) and the touched suites.
LOOM_NODE="$(command -v node)" TMPDIR=/private/tmp bats --filter 'preserved dogfood evidence|evaluation names accept' scripts/tests/repository-validation.bats
TMPDIR=/private/tmp bats plugins/loom/bin/loom-launch-role.bats
shfmt -i 4 -d plugins/loom/bin/loom-launch-role
node scripts/validate-repository.mjs --all
```

Full gate, once, on the candidate commit; its log is the regression proof (exact):

```sh
L=$(mktemp /private/tmp/loom-check.XXXXXX)
TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check >"$L" 2>&1; echo "check exit $?"   # must print 0
# 942 tracked @tests - 41 suite = 901 at baseline (suite excluded); deleting suite+list: 0; Step 4: +1.
grep -qx 'Discovered 902 Bats tests' "$L"
# The exclusion reader ran with no list: nothing is excluded.
! grep -n '^Excluding ' "$L"
grep -qx 'All checks passed' "$L"
```

Fresh-clone proof (candidate commit; reuses `PAT`/`EXCL` from above; must exit 0):

```sh
D=$(mktemp -d /private/tmp/loom-fresh.XXXXXX) && git clone -q . "$D/c" \
  && (cd "$D/c" && git checkout -q "$(git -C "$OLDPWD" rev-parse HEAD)" \
  && grep -qx 'Status: Abandoned' .docs/slice-plans/dogfood-int-race.md \
  && ! rg --hidden -l "$PAT" "${EXCL[@]}" . \
  && TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check)
```

Why 1b excludes `dogfood-int-race.md` by exact path: the Abandoned plan keeps its history
(it cites the deleted harness), so it can never pass a content scan; the glob is guarded by
the `Status: Abandoned` and README checks, so it fails closed if Step 2 is skipped or
reverted. `PAT` omits `check-bats-exclusions` because the unedited `scripts/check` keeps
naming it; the list's removal is proven by `test ! -e` plus Verification 4.

## Notes

(Clarification requests between roles go here, dated.)

Baseline: 65799b81d9140e4f33497361488b9c0a69c0ccde

2026-11-05 developer, Needs Clarification (no slice edits made yet). Two findings:

1. Verification 1b (and the fresh-clone variant) cannot pass as written. At the baseline,
   `.docs/slice-plans/dogfood-int-race.md` (live, `Status: Approved`, listed under Active plans in
   `.docs/slice-plans/README.md`) matches the retired-path pattern (it cites
   `scripts/macos-dual-client-dogfood:1795` and targets `scripts/tests/macos-dual-client-dogfood.bats`)
   and is not in 1b's exclusion globs. Its sole target file is deleted by Step 5, so the plan is moot
   after this slice. Developer may not edit it or the README (not authorized). Planner decision needed:
   e.g. archive/withdraw `dogfood-int-race` before this slice, or add it to the 1b exclusions and
   authorize its status/README handling.
2. Landed `dogfood-gate-exclusion` added `scripts/check-bats-exclusions.txt` (lists the dogfood suite;
   contains `dogfood`, but matches none of PAT). The plan does not mention it. Verified: `scripts/check`
   reads it only `if [ -f ... ]` (fails open on absence) and contains no `dogfood` text, so Verification 4
   holds. Needs authorization to `git rm` the list with the suite (otherwise the list names a missing
   file; harmless to the gate but stale), and Bats count baseline is 901 discovered with it excluded.

2026-11-05 planner: answered in place — (1) Step 2 + guarded 1b exclusion; (2) Step 5,
Verification 4 and the gate-log `Discovered 902` check (901 + 1 new test).

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft for D1 (ADR 0033 §3); Plan Review |
| 1 | Plan-eval r1: pinned explicit `Baseline:` SHA (Step 0) replacing `HEAD`/`HEAD~1` in checks 2-5; hash equality is an executable `test`; reference scan now `rg --hidden` with stated exclusions, a listing command and an empty-output assertion |
| 2 | Plan-eval r2 PASS; owner approved. Added exact runnable count-comparison and fresh-clone commands and the `test` exit-0/no-output statement; no requirement changed |
| 3 | Developer clarification: new Step 2 abandons `dogfood-int-race` (guarded exact-path 1b exclusion); Step 5 deletes `check-bats-exclusions.txt` with fail-open + `Discovered 902` checks replacing the find-based count; line refs refreshed to baseline `65799b8`; steps renumbered |
| 4 | Plan-eval r0 FAIL: Step 4 present-only evidence check (no `schemaBindings` entry), stub test copies real evidence; Step 3 `mkdir -p`/`rmdir`; ADR 0033 §3 reconciliation; Step 8 handoff wording; 902 unchanged |

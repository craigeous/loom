# Retire the macOS Dual-Client Checkpoint Tooling

Status: Plan Review
Target specs: 10-packaging.md (release evidence inputs), 08-playbook.md (gate); no spec text changes
Authority: ADR 0033 §3 (Plan Review; this slice may not start until it is Accepted), ADR 0032 §2 (Accepted), ADR 0024 §§2–5, §8 (history, unchanged)
Target size: <= 60 LOC added (one validator binding, one Bats test, doc/comment edits); deletions and the byte-identical relocation are not counted; keep this plan <= 250 lines

## Context

ADR 0033 §3 (owner decision D1) retires the Apple-silicon checkpoint tooling that ADR
0024 §6 built and ADR 0032 §2 already demoted to history. Three tracked files are
code/state for that tooling and nothing else in the gate depends on them:

| File | Lines | Role |
|---|---|---|
| `scripts/macos-dual-client-dogfood` | 1838 | supervisor/worker harness |
| `scripts/tests/macos-dual-client-dogfood.bats` | 782 | its 41-test suite |
| `plugins/loom/schemas/loom-dogfood-state-v1.schema.json` | 47 | runtime `state.json` schema (`loom-dogfood-state/v1`), used only by the harness (`scripts/macos-dual-client-dogfood:118`) |

Mechanical facts (verified with `rg` on `main` at 68d1dc8; re-run in Step 1):

- `scripts/check` has no entry for the harness: shell files are found by `git ls-files`
  (`*.sh`, and executable extensionless files whose shebang ends in `bash`, line 495–507)
  and Bats files by `git ls-files '*.bats'` (line 525). `.github/workflows/check.yml`
  and `scripts/check-toolchain.json` contain **no** `dogfood` string and pin no
  dogfood schema. Deleting the files therefore shrinks the gate with no gate edit.
- `scripts/validate-repository.mjs` does not load the state schema. Line 1068 exempts the
  preserved evidence file from evaluation-name checks (**keep**); line 389–414 builds the
  schema bindings (the evidence schema is **not** bound today).
- The preserved record — `.docs/evaluations/macos-dual-client-dogfood-evidence.json`
  (state `infrastructure-blocked`, candidate `a0bf31604cc760631ba48b8fee574f89ef120cc8`)
  and `plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json` — is today read only by
  the harness. Retiring the harness would leave the schema unused, so Step 3 binds the
  evidence to its schema in the validator to keep it checkable.
- The install-command fixture `plugins/loom/adapters/fixtures/v0.2.0/dogfood/macos-arm64.json`
  (schema string `loom-dogfood-fixture/v1`, client floors, marketplace/plugin names,
  install commands) is cited by `README.md:168` and read by the harness (`:117`). It
  becomes release-install input for the v0.2.0 live proof (ADR 0033 §2).
- The link allowlist `scripts/validation/relative-link-allowlist.txt` has 34 rows containing
  `dogfood` (lines 39–40, 169–176, 320, 352–370, 463, 468–470); every one names an
  archived or historical `.docs/` record that stays. **No allowlist row names the
  script, state schema, fixture, or evidence JSON**, so the allowlist needs no prune
  unless Step 2's relocation creates a link row (it must not).

## Out of Scope & Threat-Model Boundary

- No edit to any ADR (0024, 0032, 0033), spec, plan, verdict, archive or research note.
  Spec 03 line 370 and the `progress.md`/`roadmap.md` mentions are history and stay;
  frozen-spec wording about dogfood is a separate planner cycle (ADR 0033 Consequences).
- No change to `loom-launch-role` behavior, hooks, matrices, manifests, schemas other than
  the one deleted, or any live-proof procedure. No run of `hc`, Orca, `agy` or live
  clients. No new harness, no rewrite of the fixture's bytes.
- Product install/hook/launch coverage stays in `plugins/loom/bin/loom-launch-role.bats`,
  the hook suites and `repository-validation.bats`; this slice adds none of it back.
- Threat model per spec 00 Non-goals: no hostile-local-actor assumptions are introduced
  or removed.

## Steps

Prerequisites: ADR 0033 Accepted. Ordering (owner decision): this slice runs first;
`herdr-surface-retirement` rebases onto it afterward, and its gate then no longer hits
the `INT during a mutation yields exit 130` race, which lives in the suite this slice
deletes. This slice appends to `schemaBindings` and does not renumber
`schemaBindings[0..6]`, which `fixtureBindings` indexes.

0. **Pin the baseline** before any edit: write `Baseline: <full 40-hex HEAD SHA>` as its
   own line under `## Notes` (committed with the slice's first change). Verification uses
   that SHA, never `HEAD`, so it still works on the candidate commit.

1. **Inventory (no edit).** Run the Verification greps; record counts in the slice's
   finalize note. If any hit appears outside the allowed set below, stop and add a
   `## Notes` clarification rather than guessing.
2. **Relocate the fixture, bytes unchanged:**
   `git mv plugins/loom/adapters/fixtures/v0.2.0/dogfood/macos-arm64.json plugins/loom/adapters/fixtures/v0.2.0/release-install/macos-arm64.json`
   and update the one live reference `README.md:168`
   (`fixtures/v0.2.0/dogfood/` → `fixtures/v0.2.0/release-install/`). The directory
   `…/dogfood/` ends empty (git drops it). `sha256` of the file is identical before and
   after (record both). No allowlist row is added; if `validate-repository` reports a new
   broken-link row, fix the link, never allowlist it.
3. **Keep the preserved evidence checkable.** In `scripts/validate-repository.mjs`,
   append one entry after the last `schemaBindings` item (see Prerequisites):
   `[".docs/evaluations/macos-dual-client-dogfood-evidence.json", "plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json"]`.
   Do **not** edit the evidence file or its schema. If it fails validation, stop and
   escalate via `## Notes`: the record is immutable; the fix is then the binding
   (e.g. drop it and assert only JSON parse + `.state=="infrastructure-blocked"` in Bats),
   decided by the planner.
4. **Add the regression test** in `scripts/tests/repository-validation.bats` (≈25 LOC),
   named `repository: preserved dogfood evidence validates against its schema`:
   it asserts the real evidence validates (the repository validator exits 0 on the real
   tree) and that a copy with `.state` mutated to a non-enumerated value, in a temp
   `TEST_ROOT`, is rejected with the evidence path in the output. The existing test at
   `repository-validation.bats:1895–1918` (stub evidence file) is unchanged.
5. **Delete** (one `git rm`):
   `scripts/macos-dual-client-dogfood`,
   `scripts/tests/macos-dual-client-dogfood.bats`,
   `plugins/loom/schemas/loom-dogfood-state-v1.schema.json`.
6. **Update exact references (live files only):**
   - `CLAUDE.md:47` — delete the `scripts/macos-dual-client-dogfood` Map bullet.
   - `CLAUDE.md:13–14` — replace "Private macOS dogfood is not public support or release
     conformance." with ADR 0032 §2's invariant text verbatim ("A (platform, harness)
     pair is supported only in a release whose compatibility matrix lists it with
     complete conformance evidence; there is no private or partial support tier. Evidence
     from one platform or harness is not conformance for another."). Line 44
     (`.docs/` "dogfooding") stays: ordinary self-use. Keep the file ≤ ~100 lines.
   - `README.md:168` as in Step 2. `README.md:250–255` — reword the one paragraph so it
     says the evidence file records a blocked historical checkpoint (Codex role launch
     `infrastructure-blocked`) and confers no support status; keep the link to the
     evidence JSON; remove the claim of "private" tooling. `README.md:114` stays.
   - `plugins/loom/bin/loom-launch-role:3–4,38–39` and
     `plugins/loom/bin/loom-launch-role.bats:3` — comment-only: replace "macos-dual-client-dogfood
     plan Step 6" / "dogfood pass (ADR 0024)" with "the v0.2.0 live proof (ADR 0032 E4)".
     No code or test-body change; `shfmt -i 4 -d` clean.
7. **Gate and CI changes: none required** (Context, first bullet). Confirm by greps in
   Verification; if a `dogfood` string in `scripts/check`, `check.yml` or
   `scripts/check-toolchain.json` appears, remove only that reference. Expected edits to
   those three files: 0 lines.
8. **Finalize note** (developer finalize pass): `progress.md`/`handoff.md` record the
   slice; the Landed log lists the deleted-file line total (2667) and the preserved
   evidence hash. `roadmap.md` is unchanged.

## Verification

Fast targeted (iteration; macOS needs `TMPDIR=/private/tmp`):

```sh
# 0. Baseline: the full SHA of the commit BEFORE the slice's first change (the then-HEAD). Step 0 of the developer pass records it under
#    `## Notes` ("Baseline: <40-hex>"); every check below reads it from there, never HEAD.
BASE=$(sed -n 's/^Baseline: \([0-9a-f]\{40\}\)$/\1/p' .docs/slice-plans/dogfood-retirement.md)
git cat-file -e "$BASE^{commit}" && git merge-base --is-ancestor "$BASE" HEAD
# 1. Retired files are gone; nothing live points at them.
test ! -e scripts/macos-dual-client-dogfood
test ! -e scripts/tests/macos-dual-client-dogfood.bats
test ! -e plugins/loom/schemas/loom-dogfood-state-v1.schema.json
test ! -e plugins/loom/adapters/fixtures/v0.2.0/dogfood
PAT='loom-dogfood-state|scripts/macos-dual-client-dogfood|fixtures/v0\.2\.0/dogfood'
# 1a. Historic hits, listed on purpose (expected: only history paths, nonempty):
rg --hidden -l "$PAT" --glob '!.git/**' . | sort
# 1b. Assertion (expected: no output, exit 0 = nothing outside the allowed history paths):
! rg --hidden -l "$PAT" --glob '!.git/**' \
    --glob '!.docs/slice-plans/archive/**' --glob '!.docs/status/archive/**' \
    --glob '!.docs/evaluations/**' --glob '!.docs/research/**' --glob '!.docs/ADR/**' \
    --glob '!.docs/status/progress.md' --glob '!.docs/slice-plans/dogfood-retirement.md' .
# 2. Fixture relocated byte-identical (baseline content vs candidate file). `test` succeeds
#    with exit 0 and no output when the two hashes are equal; any output or nonzero exit fails.
test "$(git show "$BASE":plugins/loom/adapters/fixtures/v0.2.0/dogfood/macos-arm64.json | shasum -a 256 | cut -d' ' -f1)" \
  = "$(shasum -a 256 plugins/loom/adapters/fixtures/v0.2.0/release-install/macos-arm64.json | cut -d' ' -f1)"
# 3. Preserved record byte-identical to baseline (works after the candidate commit) and valid JSON.
git diff --exit-code "$BASE" HEAD -- .docs/evaluations/macos-dual-client-dogfood-evidence.json \
    plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json
jq -e '.state=="infrastructure-blocked" and .candidate=="a0bf31604cc760631ba48b8fee574f89ef120cc8"' \
    .docs/evaluations/macos-dual-client-dogfood-evidence.json
# 4. No gate/CI/toolchain edit and no dogfood strings there.
test -z "$(git diff --stat "$BASE" HEAD -- scripts/check .github/workflows/check.yml scripts/check-toolchain.json)"
! rg -n 'dogfood' scripts/check .github/workflows/check.yml scripts/check-toolchain.json
# 5. Link rows: none added; the 34 historic `dogfood` rows unchanged.
test -z "$(git diff "$BASE" HEAD -- scripts/validation/relative-link-allowlist.txt)"
# 6. New validation test and the touched suites.
TMPDIR=/private/tmp bats --filter 'preserved dogfood evidence' scripts/tests/repository-validation.bats
TMPDIR=/private/tmp bats plugins/loom/bin/loom-launch-role.bats
shfmt -i 4 -d plugins/loom/bin/loom-launch-role
```

Full gate, once, on the candidate commit (exact):

```sh
TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check
```

Regression proof: the full Bats count drops by exactly the 41 retired tests plus one added
(record before/after counts); every other suite passes unchanged. A fresh-clone run of the
gate shows no reference to the retired paths. Exact commands:

```sh
# Count comparison (expected: AFTER = BEFORE - 41 + 1). Run the same listing on both trees.
count() { find scripts plugins -name '*.bats' | sort | xargs bats --count | awk '{s+=$1} END{print s}'; }
git worktree add -q /private/tmp/loom-base "$BASE" \
  && BEFORE=$(cd /private/tmp/loom-base && count); git worktree remove --force /private/tmp/loom-base
AFTER=$(count); test "$AFTER" -eq $((BEFORE - 41 + 1)) && echo "bats count ok: $BEFORE -> $AFTER"
# Fresh-clone proof (candidate commit; the retired-path assertion 1b must print nothing).
D=$(mktemp -d /private/tmp/loom-fresh.XXXXXX) && git clone -q . "$D/c" \
  && (cd "$D/c" && git checkout -q "$(git -C "$OLDPWD" rev-parse HEAD)" \
  && ! rg --hidden -l "$PAT" --glob '!.git/**' --glob '!.docs/slice-plans/archive/**' \
       --glob '!.docs/status/archive/**' --glob '!.docs/evaluations/**' --glob '!.docs/research/**' \
       --glob '!.docs/ADR/**' --glob '!.docs/status/progress.md' \
       --glob '!.docs/slice-plans/dogfood-retirement.md' . \
  && TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check)
```

## Notes

(Clarification requests between roles go here, dated.)

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft for D1 (ADR 0033 §3); Plan Review |
| 1 | Plan-eval r1: pinned explicit `Baseline:` SHA (Step 0) replacing `HEAD`/`HEAD~1` in checks 2-5; hash equality is an executable `test`; reference scan now `rg --hidden` with stated exclusions, a listing command and an empty-output assertion |
| 2 | Plan-eval r2 PASS; owner approved. Added exact runnable count-comparison and fresh-clone commands and the `test` exit-0/no-output statement; no requirement changed |
| 3 | Owner order decision: runs before `herdr-surface-retirement`; Prerequisites no longer depend on it; Status back to Plan Review for a fresh cold evaluation; no requirement changed |

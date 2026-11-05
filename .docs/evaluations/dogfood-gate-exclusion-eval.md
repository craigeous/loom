# Evaluation: dogfood-gate-exclusion (slice-plan)

Verdict: PASS
Round: 0
Commit: 4952494
Artifact: .docs/slice-plans/dogfood-gate-exclusion.md @ 4952494
Reviewed against: ADR 0033 (Accepted) §3 and Consequences; ADR 0024 §8; the Approved
`dogfood-retirement` plan (Step 7, Verification #4, count comparison);
`.docs/spec/08-playbook.md` gate list; `gates/shell.md`; plan-eval rubric; and the real tree
(`scripts/check`, `scripts/validate-repository.mjs`, `scripts/run-bats-under`,
`.github/workflows/check.yml`, `scripts/tests/repository-validation.bats`).

## Summary

PASS (BLOCKER: 0, MAJOR: 0, MINOR: 3). The previous FAIL (archived outside `.docs/evaluations/`, see Prior Rounds Summary) is resolved: `scripts/check` stays name-agnostic, so the retirement plan's checks still hold, and every acceptance criterion is runnable.

## Findings

- [MINOR] m1. The handoff to retirement is not enforced. Notes (lines 136-141) say
  `dogfood-retirement` deletes `scripts/check-bats-exclusions.txt` or its entry. The Approved
  retirement plan contains no such step, and this plan does not edit it.
  - Retirement's checks still pass if the list is left behind. Pattern 1b
    (`scripts/macos-dual-client-dogfood`) does not match `scripts/tests/macos-dual-client-dogfood.bats`.
  - The only effect is a stale `Excluding ...` line naming a deleted file. This is benign.
  - Fix: in the finalize pass, add a one-line next step to `handoff.md` (or a dated planner
    clarification in the retirement plan's `## Notes`) so retirement removes the list.
- [MINOR] m2. After retirement, the generic reader stays in `scripts/check` as a permanent,
  inert exclusion hook. ADR 0033 covers only this suite, so any future list entry should
  require a plan and a cold evaluation. Consider stating that in the list file's header
  comment, or scheduling a later planned removal. It does not block this slice.
- [MINOR] m3. Verification hygiene:
  - `/private/tmp/gx-base` is never cleaned up. Add `git worktree remove --force /private/tmp/gx-base`.
  - `BASE=$(git rev-parse HEAD~1)` is wrong if the candidate spans more than one commit, for
    example a code commit plus a finalize commit. This fails closed: criterion (b) would see
    T0=931 and fail. Pinning BASE to the commit before the slice's first change is more robust.

## Required changes (for FAIL)

None.

## Notes

Prior-round resolutions (revision diff 6356a98..4952494):

- **B1 (retirement conflict): resolved.**
  - I applied Step 2 to a scratch copy of `scripts/check`. `grep -n dogfood` on the result
    found nothing (exit 1), so retirement's `! rg -n 'dogfood' scripts/check ...` holds.
  - Retirement needs no `scripts/check` edit, so its `git diff --stat "$BASE" HEAD -- scripts/check`
    assertion holds. The list file is not among retirement's three gate/CI files.
  - Retirement's count comparison uses `find scripts plugins -name '*.bats'`, not the gate's
    `Discovered` line, so this exclusion does not affect `BEFORE - 41 + 1`.
- **M1 (runnable criteria): resolved.** Every criterion (a)-(h) is an exact command with a
  stated result. The plan runs the gate once on the baseline instead of computing T0 offline
  as suggested. That costs more but is explicit and sound.
- **m1 (ADR 0024 §8 / 0033): resolved** (Authority line 5).
- **m2 (LOC): resolved** (exact numstat; checked below).

Mechanical checks performed (HEAD 4952494):

| Check | Result | Evidence |
|---|---|---|
| Cited lines | PASS | `cat -n scripts/check \| sed -n 523,533p`: 523 stage, 524 `test_files=()`, 525 ls-files loop, 526-530 required loop, 532 Discovered printf, 533 run-bats-under |
| `SCRIPT_DIR`/`REPOSITORY_ROOT` exist | PASS | `scripts/check:4-5`; `set -euo pipefail` at :2 |
| Sketch applies, formats, and lints | PASS | Step 2 spliced over line 525 in a scratch copy: `shfmt -i 4 -d -ln bash` exit 0; `shellcheck -s bash` exit 0 |
| numstat | PASS | `git diff --no-index --numstat` = `19 1` (matches plan); list file has 3 lines, so `3 0` |
| Bash 3.2 and `set -euo pipefail` safety | PASS | `/bin/bash` 3.2.57 harness with the exact snippet, five list cases. Present: 17 files and one `Excluding scripts/tests/macos-dual-client-dogfood.bats: see dogfood-gate-exclusion plan` line. Absent, empty, or comments-only: 18 files, no line. No trailing newline: 17 files. All exit 0. The `[ ] && skip=true` loop tail and `$skip \|\| append` are errexit-exempt (the same pattern as existing line 528) |
| Test counts | PASS | `grep -c '^@test'` on the suite = 41; total over 18 tracked `*.bats` = 972, so 931 remain |
| Only Bats list | PASS | `git ls-files '*.bats'` appears only at `scripts/check:525`; `check.yml:129` runs `scripts/check`; `run-bats-under` takes argv; the validator has no Bats list (its `ls-files` at :170 is a general walk) |
| Required loop cannot re-add | PASS | :526 names only `shell-runtime.bats` and `repository-validation.bats` |
| repository-validation.bats copies | PASS | :1003 copies `scripts/check` with no list, which is the no-exclusion path; full runs are rejected before provisioning (:1331-1337) or use CONTRACT/BASH_ONLY modes |
| Criterion (d) false positives | PASS | No other `@test` name contains `macos-dual-client-dogfood`; `run-bats-under` prints no file list; no `Excluding ` emitter exists in scripts or plugins |
| Criterion (h) | PASS | `node scripts/validate-repository.mjs --all` exits 0 at HEAD; `--all` is a valid flag (:30) |
| Spec/gate wording | PASS | `gates/shell.md:26-27` "discovers ... Bats sets dynamically" still holds; spec 08:223 lists Bats as a stage, with no every-file invariant |
| Structure | PASS | Status: Plan Review; Target size stated; Out of Scope & Threat-Model section present; 156 lines (≤ 250); Revision Log table; sections revised in place |

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| (archived r1) | plan | FAIL | Recorded outside `.docs/evaluations/`, so this is the first evaluation here and is Round: 0 (validator eval-sequence). B1: the carve-out conflicted with the Approved retirement plan's zero-diff / no-`dogfood` checks. Resolved by a name-agnostic list file read by `scripts/check`. M1: criteria were not runnable. Resolved by exact commands (a)-(h). m1/m2 resolved. Full record: `.docs/slice-plans/archive/evaluations-reset/dogfood-gate-exclusion-plan-eval-r1.md` |

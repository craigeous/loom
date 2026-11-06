# Plan evaluation — instruction-adapter-sync (Round 1)

Artifact: [instruction-adapter-sync](../slice-plans/instruction-adapter-sync.md)
Commit: 2b23221
Round: 1
Verdict: PASS
Reviewed against: [spec 08](../spec/08-playbook.md) (*Canonical project instruction digest*, *`CLAUDE.md` and `AGENTS.md` adapters*, *Mechanical invariants*), [spec 03](../spec/03-artifact-lifecycle.md), [spec 06](../spec/06-init-modes.md), [spec 09](../spec/09-open-questions.md) (*Instruction files*), [spec README](../spec/README.md), [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md) §2 and §8, [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md), [severity](../../plugins/loom/skills/loom-playbook/references/severity.md), and the Round 0 record [instruction-adapter-sync-plan-eval](instruction-adapter-sync-plan-eval.md).

## Summary

PASS (plan re-review, Round 1; BLOCKER: 0, MAJOR: 0, MINOR: 1). The revision
(`0fc3da3..2b23221`) fixes the Round 0 MAJOR: Verification 8 now checks that the
lint baseline stays the same instead of requiring clean output. The new commands
produce the stated numbers on the real tree. All four Round 0 minors are fixed. A
scratch rerun of Steps 1–5 reproduces every stated result for Verification 1–6 and 8.
The diff does not change scope, size, the rule, the tests, or the fallback. Round is
1 because the validator's eval-sequence rule expects exactly round 1 after a Round 0
FAIL.

## Findings

- [MINOR] Context finding 5 says "170 ShellCheck findings". The command
  `shellcheck ... | grep -c '^In '` counts flagged source locations. ShellCheck groups
  findings on the same line under one `In` header, and
  `shellcheck -s bash -f gcc scripts/tests/repository-validation.bats | wc -l` gives
  206 individual findings. Verification 8's command and its expected `170` are
  correct and still work as a "no new debt" check, so this is wording only. If the
  plan is revised for another reason, say "170 flagged locations".

## Required changes (for FAIL)

None.

## Notes

Mechanical checks at `2b23221` (`scripts/` is unchanged since `1d43ec5`):

- **Verification 8 (Round 0 MAJOR).**
  `shfmt -ln bats -i 4 -d scripts/tests/repository-validation.bats | wc -l` gives
  `15`.
  `shellcheck -s bash scripts/tests/repository-validation.bats | grep -c '^In '`
  gives `170`. `node --check scripts/validate-repository.mjs; echo "exit=$?"` gives
  `exit=0`. These checks mean something. `.bats` files are outside the gate's
  shfmt/ShellCheck stages, and both tools already exit 1 at baseline, so "count
  unchanged" is the right non-regression check. `node --check` covers syntax for the
  edited `.mjs`, which has no JS lint stage. The Out of Scope section now excludes
  pre-existing lint cleanup, so a developer is no longer pushed to reformat the
  file.
- **Round 0 minors.** (1) The Out of Scope section now names the digest-first
  hand-stamp in Steps 2–4 as the interim stand-in for the unimplemented spec 08
  renderer. (2) Verification 7 now sets `LOOM_NODE="$(command -v node)"`. (3) Test 5
  is renamed to "duplicate begin marker fails" and matches its described case.
  (4) Verification 5 now uses `git diff --numstat`.
- **Scratch rerun of Steps 1–5** (clone of `2b23221`, run as written; the rule was
  written to the Step 5 spec in 35 lines, within the ≤ 45 target). Step 2 Node
  normalization and `shasum -a 256` both give `1c04cef5…ee11`. V1 exits 0 with
  `Repository all validation passed`. V2 grep exits 1 and the count is `0`. V3 shows
  one unique marker equal to the new hash. V4 gives three identical 11-line
  shared-body hashes. V5 numstat is `1	1	CLAUDE.md`, and the file is still 101
  lines. V6 exits 1 with the exact stated AGENTS.md diagnostic. V8 `node --check`
  exits 0. With only the rule applied to the unsynced adapters, `--all` exits 1 and
  flags the AGENTS.md and GEMINI.md shared-line drift, so the rule catches today's
  defect. Net for Steps 1–5: about +53/−9. The Step 6 tests (71 lines in Round 0's
  prototype, with no change to lint counts) are not touched by the revision, and the
  test file is unchanged since then, so the ≤ 170 LOC target still holds.
- **No regression.** The revision diff only touches Context (new finding 5, a
  shorter closing paragraph), Out of Scope (stand-in sentence, lint-cleanup
  exclusion, the same CLAUDE.md and digest bullets reworded), Test 5's name,
  Verification 5/7/8, Notes, and the Revision Log. Steps 1–6, the rule's semantics
  and diagnostics, the LOC target (170), and the docs-only fallback (Steps 1–4,
  ≈ 12 LOC) are unchanged. The plan is 250 lines (≤ 250 cap) and still has
  `Target size:`, Out of Scope & Threat-Model Boundary, and a Revision Log row for
  round 1. The slice-plan index entry is present.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | MAJOR: V8 required clean shfmt/ShellCheck on a `.bats` file that already fails at baseline. Resolved by checking for unchanged baseline counts (15/170) plus `node --check`. Four minors (renderer stand-in note, `LOOM_NODE`, Test 5 name, V5 numstat) all resolved. |

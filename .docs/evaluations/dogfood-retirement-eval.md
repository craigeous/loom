# Evaluation: dogfood-retirement

Verdict: PASS
Round: 1
Artifact: [dogfood-retirement](../slice-plans/archive/dogfood-retirement.md)
Commit: 922562a
Reviewed against: `.docs/slice-plans/dogfood-retirement.md`, ADR 0033 §3, ADR 0032 §2, ADR 0024 §§2–5 and §8, specs 08 (gate, root-file size) and 10 (release evidence inputs), the code-eval rubric, `severity.md`, and `.docs/evaluations/dogfood-retirement-review-findings.md`. Diff: pinned baseline 65799b8 to 922562a (code commit 44f4c33, evidence commit 922562a); gate rerun on 3b1d30c, which adds only the review-findings record.

## Summary

PASS (code review; BLOCKER: 0, MAJOR: 0, MINOR: 3). The diff does what ADR 0033 §3 and the plan require. It deletes the harness, its Bats suite, the state schema and the exclusion list (2670 lines). It relocates the install fixture with identical bytes, keeps the evidence record and its schema byte-identical and valid, and withdraws `dogfood-int-race` exactly as Step 2 specifies. It adds one present-only validator check with exactly one new test. The gate was rerun on the candidate and is green with `Discovered 902 Bats tests` and no `Excluding` line. The plan's fresh-clone proof was also run, as recorded below. Round stays 1: this is the first code-phase verdict, the running count for this artifact is 1 (plan-phase FAIL at round 0, PASS at round 1), and a PASS does not increment it.

## Required changes

None.

## Findings

- [MINOR] `AGENTS.md:8-9` and `GEMINI.md:10-11` still state the retired invariant "Private macOS dogfood is not public support or release conformance." ADR 0032 §2 replaces that text, and after this slice there is no private tooling left. The plan authorizes the replacement only in `CLAUDE.md` (Step 6), and the two files carry a rendered `loom:project-instructions` block with a content hash, so the developer was right not to hand-edit them. This is a gap in the plan, not an implementation defect. A follow-up planner cycle should re-render those adapter blocks with the ADR 0032 §2 text.
- [MINOR] `CLAUDE.md` is 101 lines. The baseline was 100, the plan asks for "≤ ~100", and spec 08 sets a target of 80–100 for Loom's root files. The extra line comes from the verbatim ADR 0032 §2 invariant the plan requires. The bound is approximate, no gate checks it, and the overshoot is one line, so this does not block. Reflowing the invariant bullet in a later edit would bring the file back to 100.
- [MINOR] `plugins/loom/bin/loom-launch-role:2-4`: the comment-only substitution dropped a closing parenthesis. The outer `(spec 10 -> …` is never closed: the text now ends `the v0.2.0 live proof (ADR 0032 E4).`, but a literal Step 6 substitution gives `…(ADR 0032 E4)).`. This is cosmetic, and `shfmt -i 4 -d` is clean.

## Review-findings adjudication

- Aggregate `ran-clean` (loom-local-review/v1, base 65799b8, head 922562a). All three finders (correctness, security, tests) were clean, so nothing needed adjudication. This review checked the same ground independently and found only the three non-blocking items above, which the finders did not raise.

## Mechanical checks

- Gate: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` on 3b1d30c exited 0. The log has `Discovered 902 Bats tests` and `All checks passed`, with no `Excluding` line and 0 `not ok`. The tracked `@test` total is 902. `repository-validation.bats` went from 206 to 207, and the deleted suite accounted for 41.
- Fresh-clone proof (plan Verification, required): a clone checked out at 3b1d30c passed the `Status: Abandoned` guard and an empty 1b scan, and its `scripts/check` exited 0 with `Discovered 902 Bats tests`, `All checks passed`, and no `Excluding` line.
- Verification 0: the baseline from `## Notes` is 65799b8 and an ancestor of HEAD.
- Verification 1: the four retired files and `fixtures/v0.2.0/dogfood` are absent. The 1a listing shows only history paths plus `dogfood-int-race.md` and this plan. The 1b guard passes (`Status: Abandoned`, and the README entry is `` `Abandoned` `` and sits directly above `herdr-hc-client.md`), and the 1b scan is empty.
- Verification 2: the fixture sha256 is `71e53d08…b634a` both at baseline and at `release-install/macos-arm64.json`, and git records `R100`.
- Verification 3: the evidence JSON and `loom-dogfood-evidence-v1.schema.json` match the baseline exactly (`git diff --exit-code` reports no difference). The `jq` state and candidate assertion is true, and the schema parses.
- Verification 4: `scripts/check`, `check.yml` and `check-toolchain.json` have no diff from baseline and contain no `dogfood` string. The fail-open `if [ -f … ]` reader is present.
- Verification 5: `relative-link-allowlist.txt` is unchanged.
- Verification 6: the filtered Bats run passes both the new test and the stub-evidence test.
- Validator: the new block runs only when `safeNode(..., { missing: false, regularFile: true })` finds the file. If the file is absent, the check is skipped. A symlink or non-regular file is reported as unsafe, and a schema violation is reported and fails the run. `schemaBindings[0..6]` is untouched.
- Tests: the only removed lines in `repository-validation.bats` are the `{}` stub heredoc, replaced by a copy of the real evidence. The single new `@test` asserts exit 0 on the real record, then exit 1 with `…evidence.json: schema /state` after `.state = "bogus"`. No other test changed.
- Scope: 37 lines added (budget 60). Nothing outside the plan's file list was touched. ADRs, specs, verdicts, archives, `progress.md` and `roadmap.md` are unchanged, and no branch or worktree was deleted.

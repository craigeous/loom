# Plan evaluation — herdr-native-app-hooks

Artifact: .docs/slice-plans/herdr-native-app-hooks.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: 6d35db1
Round: 0
Verdict: FAIL

## Summary

Round 0 findings 2, 3 and 4 are resolved by the revision. Step 2 adds the `plugin.json` `hooks` field and validator check. Steps 1 and 3 to 5 name the spec 10, `hooks.json`, validator comment and `CLAUDE.md` touch points. The Verification section now has `jq`/`git grep`/`git diff` checks, and the test matrix is trimmed to fit the budget. The revision log and in-place structure are fine, and the plan is 93 lines.

Round 0 finding 1 (MAJOR) is not resolved. The "authority" the revision cites for the Herdr hook wire was written in the same revision, is circular, and is not sourced. It also edits an Accepted ADR in place. The verdict stays FAIL.

Round numbering note: this is the re-review of the Round 0 FAIL, so it is recorded as Round 1 because the verdict is FAIL.

## Findings

1. **[MAJOR] (carry-over of Round 0 #1) Herdr hook wire contract is still unsourced; the new authority is self-referential.**
   - The revision adds ADR 0029 §6 and a research-note bullet asserting that Herdr loads `hooks/hooks.json`, injects `HERDR_PLUGIN_ROOT` into hook processes, emits `PreToolUse` (`tool_input.command`) and `PreCompact` (`trigger`, `session_id`), and honors exit 2 with stderr as a block.
   - The research bullet cites `[1], [3]`. Per the Sources list, [1] is Herdr's `Info.plist` and `--skill/--version/--help` output (version, bundle id, CLI syntax, mod architecture), and [3] is Loom's own `10-packaging.md` and compatibility matrix. Neither shows hook events, payload shape, hook-process environment, or exit-code semantics. The wording "In Herdr's POSIX execution runtime ... follow the standard process contract" is an assumption, not a finding.
   - Spec 08 requires exact current-event fixtures and forbids substituted encodings. A guessed wire is frozen into a spec amendment, 24 byte-exact fixtures, and an ADR.
   - Failure scenario: Herdr does not emit `PreToolUse`/`PreCompact`, uses another payload, or treats exit 2 as an ordinary hook error. The fixtures and gate pass, the identity and write-ahead guards never block, and the docs claim conformance. `herdr-verification` would be the first place this surfaces.
   - Fix: either (a) add a researcher-sourced note, with citations that actually contain Herdr hook semantics (events, payload, block encoding, hook env, version floor), or (b) mark the wire contract explicitly as a provisional assumption in the plan and ADR text, and name the mechanism and slice that validates it before the fixtures are treated as conformance evidence. The plan must not assert the contract as established fact without a supporting source.

2. **[MAJOR] ADR 0029 (Status: Accepted) and the Approved research note were rewritten in place.**
   - The diff adds §6 to ADR 0029 and a new bullet to the Approved research note. Project rules say ADRs are immutable after acceptance ("supersede, never rewrite"). The rubric requires no silent supersession and a traceable ADR.
   - The slice plan then relies on the edited ADR as its authority, so the sourcing in finding 1 is also unreviewed by a cold evaluator. Adding a new decision means a new ADR, or an explicitly Extending ADR, that goes through its own plan evaluation.
   - Fix: move §6 into a new ADR (for example 0030, `Extends: 0029`), and put the sourced material in a new or re-approved research note. Then cite those from the slice plan.

3. **[MINOR] Step 1 dropped the spec-amendment approval gate.**
   - The Round 0 draft said the spec amendment must go through planner authorship and independent cold plan evaluation before implementation. The revised Step 1 says only "Spec amendments (prerequisite)". Project rules say specs change only through planner and cold plan evaluation.
   - Fix: restore the sentence that the amendments are approved by a cold evaluator before the developer starts, and that the slice review does not approve them.

4. **[MINOR] Mechanical checks are fragile.**
   - `git diff --exit-code HEAD~1 -- ...fixtures/{claude,codex}` depends on the commit layout. Use a named base (the slice's base commit or merge-base).
   - The `herdr_ok` check greps for a symbol name that the plan never defines in Steps. Name the variable in Step 4, or grep for `HERDR_PLUGIN_ROOT` in the three scripts.
   - The check does not prove the quoted root expression, only that it contains `HERDR_PLUGIN_ROOT`. Compare the full expected string with `jq -e`.
   - Add a `jq -e '.hooks == "hooks/hooks.json"'` check for `.herdr-plugin/plugin.json` alongside the validator step.

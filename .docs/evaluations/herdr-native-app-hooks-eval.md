# Herdr native app hooks code evaluation

Artifact: .docs/slice-plans/herdr-native-app-hooks.md
Reviewed against: plugins/loom/skills/loom-playbook/references/code-eval-rubric.md
Commit: ce29352
Round: 0
Verdict: FAIL

## Summary

The implementation adds Herdr discovery, fixtures, and wire handling, but the PreCompact selector violates the required fail-closed root selection contract.

## Findings

- [BLOCKER] `plugins/loom/hooks/precompact-write-ahead-backstop.sh:60` accepts valid Codex and Claude roots together: its `if`/`elif` checks only the first valid root and returns Codex when Herdr is absent. With both `PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT` set to the physical plugin root and a valid manual event, the hook exited 0 with empty streams instead of rejecting the ambiguous input. ADR 0030 decision 3 and plan step 4 require exactly one valid root across all three scripts; the test at `precompact-write-ahead-backstop.bats` asserting Codex preference instead contradicts that requirement. Count all three independently validated roots, reject any count other than one, and update the ambiguity regression test.

The supplied `loom-local-review/v1` artifact reports `ran-clean` and contains no candidate findings to adjudicate. Live Herdr verification remains explicitly deferred to the next slice.

## Verification

- `node scripts/validate-repository.mjs --root . --all`: passed (snapshot checks; no baseline supplied).
- Requested targeted Bats command: passed, 139 tests.
- All five requested mechanical checks passed, including unchanged Claude/Codex fixtures and manifest, dispatcher, root-reference, and digest checks.
- Direct reproduction of the two-valid-root PreCompact case returned exit 0, confirming the blocker.
- `TMPDIR=/private/tmp scripts/check`: toolchain, metadata, shfmt, ShellCheck, and Bash syntax stages passed; interrupted during Bats after 178 passing tests because the independent contract violation already requires FAIL. The full gate is therefore not verified and must be rerun after the fix; the interruption produced exit 130, not a demonstrated test failure.

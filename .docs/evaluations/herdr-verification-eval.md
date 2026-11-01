# Herdr verification evaluation

Artifact: .docs/slice-plans/herdr-verification.md
Reviewed against: plugins/loom/skills/loom-playbook/references/code-eval-rubric.md
Commit: 7fc32d256eb83002b24ef5b8d9fde6d12963e277 (diff b4a84dc..7fc32d2)
Round: 0
Verdict: PASS

## Required changes

None.

## Summary

The diff adds `scripts/tests/herdr-verification.bats` (212 lines) plus slice docs. No product
code changed, which fits the plan's "product behavior unchanged" rule. The new suite covers
every plan step:

- Step 1: the suite copies `.herdr-plugin` and `plugins/loom` into a private install, resolves
  the marketplace `source` from the copy, and checks the manifest name/version, the skills and
  hooks paths, and that the install is outside the checkout. Every product command runs under
  `env -i` with an isolated HOME and no client roots.
- Step 2: helper resolution is physical. Unset and relative roots, a bad manifest and a missing
  helper all return 2. All five roles launch with the right profile, cold, non-delegating and
  one-level permissions, and `--model`/`--effort` are rejected. The `loom-run` and role skills
  are discoverable.
- Step 3: the commands declared in `hooks.json` are executed as written with only
  `HERDR_PLUGIN_ROOT` set. Exit, stdout and stderr are compared byte-for-byte (`cmp`) with the
  Herdr wire fixtures for both events and all three outcomes. The identity and role-governance
  guards block (exit 2) and allow correctly. `HERDR_PLUGIN_ROOT` plus `CLAUDE_PLUGIN_ROOT`
  fails closed for all three declared commands.
- Step 4: `scripts/check` already discovers the file via `git ls-files`. The suite ran as
  tests 670-685 in the gate log.

The assertions are not weakened, there is no network or Herdr binary use, and the
live-vs-fixture claim is stated honestly in the header comment and the plan.

## Gate

`TMPDIR=/private/tmp scripts/check < /dev/null` was run twice.

- Run 1 failed in the Bats stage on one test, `INT during a mutation yields exit 130` in
  `macos-dual-client-dogfood.bats`. That is outside the slice's diff. I ran the gate from a
  non-interactive background shell, which makes SIGINT ignored. That test passed when run alone
  in the foreground.
- Run 2 reset SIGINT to default and ran the full gate. All stages passed: pinned toolchain,
  shfmt, ShellCheck, Bash syntax, Bats, relative links, Claude strict validation and diff
  whitespace. The log ends "All checks passed", exit 0.

## Review-findings adjudication

The artifact (`loom-local-review/v1`, aggregate `ran-clean`) lists three finders and no
findings. Nothing to adjudicate.

## Findings

- [MINOR] The ambiguity test asserts exit 2 and empty stdout but does not check the
  diagnostic text on stderr, so it can't tell an ambiguity failure from another exit-2 path.
  It is acceptable because the hook suites cover the ambiguity messages. This is not blocking.
- [MINOR] The plan-eval's suggested mechanical no-network guard (PATH stub or `rg` check) was
  not added. The suite contains no network invocations, so the invariant holds. This is not
  blocking.

No BLOCKER or MAJOR findings.

## Prior Rounds Summary

Plan-review Round 0: PASS (no FAILs recorded).

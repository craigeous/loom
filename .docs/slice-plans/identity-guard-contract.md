# Identity Guard Contract

Status: Plan Review
Target specs: 08-playbook.md, 10-packaging.md
Target size: <= 200 LOC net change (keep this plan document <= 250 lines)

## Context

ADR 0003 requires uniform author and committer identity. Spec 08 requires a
recognized-token guard and post-command verification. The existing guard strips
quoted segments, hiding wrapped commands, and post-commit guidance checks only
author. This slice makes those protections and their limits explicit.

## Out of Scope & Threat-Model Boundary

This is defense in depth, not a shell parser or hostile-code sandbox (spec 00
Non-goals). Dynamically constructed commands, aliases, scripts, expansions,
encoded text, commands outside an active hook, and concurrent external mutations
can evade prevention. Verification applies at the documented workflow boundary;
it cannot prove identity of commits outside that boundary or prevent a later
rewrite. No spec or ADR edits, new client support, remote history rewriting, or
OS-level containment are in scope.

## Steps

1. In `plugins/loom/hooks/git-identity-guard.sh`, scan command text for recognized
   identity mutation tokens without stripping quoted wrapped command bodies. Block
   `--author` and `--author=`, `-c user.*` and `-c GIT_AUTHOR*`/`GIT_COMMITTER*`
   overrides, and `GIT_AUTHOR_*`/`GIT_COMMITTER_*` assignments, including in
   `sh -c`, `bash -c`, `env`, and other wrappers. Block `git config` writes to
   `user.name` or `user.email`, including `--local`, `--global`, `--system`, and
   `--file` forms; allow reads without a value. Treat ambiguous recognized
   mutation forms as blocked. Do not discard a recognized token because quoting
   is unbalanced. Accepted false positives include tokens in messages or read
   filters; preserve ordinary commands and safe identity reads. Keep existing
   client wire and malformed-input contracts.
2. Add a portable post-command verifier under `plugins/loom/bin/` and invoke it
   at the commit/handoff boundary in the playbook commit convention and role
   workflow guidance. Capture HEAD before the command and pass that baseline to
   the verifier immediately afterward, before workflow continuation; handle unborn
   HEAD explicitly. If HEAD changed, inspect every newly reachable commit, including
   amended HEAD, against the repository's configured `user.name` and `user.email`
   for both author and committer, and reject `loom <loom@localhost>`, any
   `*@localhost`, and missing or auto-generated fallback identity. Fail closed on
   missing configuration, unreadable history, invalid baseline, or verification
   errors. On mismatch stop and report the offending SHA and explicit remediation:
   restore a real configured identity through the owner, repair the local commit
   only when safe and authorized, reverify, and never rewrite published history
   automatically. No HEAD change is a successful no-op. Document that baseline
   capture and invocation are required, not an automatic PostToolUse guarantee.
3. Extend `plugins/loom/hooks/git-identity-guard.bats` for both known config write
   reproductions, each config scope and file form, safe reads, wrapped author
   bypass, direct author, environment and `-c` overrides, ordinary commits,
   quoted-token false positives, and both client wire adapters. Update obsolete
   allow cases that relied on stripping recognized tokens. Add verifier tests using
   isolated repositories: unchanged/unborn HEAD, valid new and amended commits,
   wrong author, wrong committer, fallback, multiple commits, missing identity and
   invalid baseline; assert stop/remediation and no automatic history mutation.
4. Update `plugins/loom/skills/loom-playbook/references/commit-convention.md`,
   relevant role workflow instructions, hook comments and `hooks.json` description
   to state the exact recognized-token guarantee, accepted false positives,
   required verifier boundary and dynamic-shell limitations. Preserve spec 08
   client wire fixtures and shared policy/client adapter separation.

## Verification

- Developer iteration: run `bats plugins/loom/hooks/git-identity-guard.bats` with
  `LOOM_TEST_BASH` and `LOOM_EXPECTED_BASH_VERSION` set for the selected runtime;
  run the verifier's targeted Bats suite as well.
- Exercise the listed negative and positive cases, verify client wire fixtures
  byte-for-byte, and show a bypassed bad commit stops the workflow with remediation.
- Run `scripts/check` as the full repository gate and
  `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all`.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

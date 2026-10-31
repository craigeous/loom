# Identity Guard Contract

Status: Implemented
Target specs: 08-playbook.md, 10-packaging.md
Target size: <= 250 LOC net change excluding tests/docs (keep this plan document <= 250 lines)

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
   `--author` and `--author=`, `-c user.*`, `-c author.*`/`committer.*`, and `-c GIT_AUTHOR*`/`GIT_COMMITTER*`
   overrides, and `GIT_AUTHOR_*`/`GIT_COMMITTER_*` assignments, including in
   `sh -c`, `bash -c`, `env`, and other wrappers. Block `git config` writes to
   `user.name`, `user.email`, `author.name`, `author.email`, `committer.name`,
   or `committer.email`, including `--local`, `--global`, `--system`, and
   `--file` forms. With a `git config` word and any of those key tokens, block
   unless it is a bare read (no value, `--get`, or `--list`); block `--unset`,
   `--replace-all`, `--add`, and `--edit`. Scan wrapped `sh -c`, `bash -c`,
   and `env` commands as well. Treat ambiguous recognized mutation forms as blocked. Do not discard a recognized token because quoting
   is unbalanced. Accepted false positives include tokens in messages or read
   filters; preserve ordinary commands and safe identity reads. Keep existing
   client wire and malformed-input contracts.
2. Add Bash executable `plugins/loom/bin/loom-verify-identity`, invoked by its
   absolute resolved path as `loom-verify-identity <baseline-sha|unborn>`.
   Register it in `plugins/loom/bin/loom-resolve-helper` as
   `ALLOWED_HELPERS=(loom-coord loom-verify-identity)` and update
   `plugins/loom/bin/loom-resolve-helper.bats` for installed resolution. Add the
   same helper to `allowedHelpers` in each mirrored metadata file:
   `plugins/loom/adapters/roots/claude-plugin-root-v1.json`,
   `plugins/loom/adapters/roots/codex-skill-source-v1.json`,
   `plugins/loom/adapters/fixtures/v0.2.0/metadata/claude-root.json`, and
   `plugins/loom/adapters/fixtures/v0.2.0/metadata/codex-root.json`; update
   `expectedRoots` `allowedHelpers` in `scripts/validate-repository.mjs` to match.
   Update `$defs.allowedHelpers.const` in `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`
   to `["loom-coord", "loom-verify-identity"]`. Review and update the
   `allowedHelpers` mutation cases around lines 433–456 in
   `scripts/tests/repository-validation.bats` for the revised allowlist.
   Verify both installed client roots resolve the helper and metadata stays consistent. Exit 0
   for valid/no-op, 1 for usage/config or verification errors, and 2 for identity
   violations; report offending SHA and remediation on stderr for violations.
   Capture HEAD before the command (or `unborn`) and invoke immediately afterward,
   before workflow continuation. If HEAD advanced, inspect every newly reachable
   commit, including amended HEAD, against configured `user.name` and `user.email`
   for both author and committer; reject `loom <loom@localhost>`, any
   `*@localhost`, and missing or auto-generated fallback identity. Fail closed on
   missing configuration, unreadable history, invalid baseline, or errors. On
   mismatch stop; restore a real configured identity through the owner, suggest
   `git commit --amend --reset-author --no-edit` for an unpushed commit when safe,
   and reverify. Escalate published commits to the owner; never automatically
   rewrite history. No HEAD change is a successful no-op. Document that baseline
   capture and invocation are required, not an automatic PostToolUse guarantee.
   Add the capture and absolute-path invocation instructions to exactly these
   workflow files: `plugins/loom/roles/developer.md`,
   `plugins/loom/skills/loom-developer/SKILL.md`, and
   `plugins/loom/skills/loom-playbook/references/commit-convention.md`.
3. Extend `plugins/loom/hooks/git-identity-guard.bats` for both known config write
   reproductions, each config scope and file form, safe reads, wrapped author
   bypass, direct author, environment and `-c` overrides, ordinary commits,
   quoted-token false positives, and both client wire adapters. Update obsolete
   allow cases that relied on stripping recognized tokens. Add `plugins/loom/bin/loom-verify-identity.bats` using
   isolated repositories: unchanged/unborn HEAD, valid new and amended commits,
   wrong author, wrong committer, fallback, multiple commits, missing identity and
   invalid baseline; assert stop/remediation and no automatic history mutation.
4. Update `plugins/loom/skills/loom-playbook/references/commit-convention.md`,
   the two named developer workflow files, hook comments and `hooks.json` description
   to state the exact recognized-token guarantee, accepted false positives,
   required verifier boundary and dynamic-shell limitations. Preserve spec 08
   client wire fixtures and shared policy/client adapter separation.

## Verification

- Developer iteration: run `bats plugins/loom/hooks/git-identity-guard.bats` with
  `LOOM_TEST_BASH` and `LOOM_EXPECTED_BASH_VERSION` set for the selected runtime;
  run the verifier's targeted Bats suite as well.
- Check all three workflow files contain the invocation:
  `for f in plugins/loom/roles/developer.md plugins/loom/skills/loom-developer/SKILL.md plugins/loom/skills/loom-playbook/references/commit-convention.md; do rg -n 'loom-verify-identity' "$f" || exit 1; done`.
- Audit stale and overbroad claims with `rg -n -U 'Stage [ABC]|fail.open|all identity|every identity' plugins/loom/hooks/git-identity-guard.sh plugins/loom/hooks/hooks.json plugins/loom/skills/loom-playbook/references/commit-convention.md`; inspect every hit and remove or correct stale or broader-than-actual enforcement wording.
- Run `bats scripts/tests/repository-validation.bats` and verify the revised
  allowlist passes while invalid `allowedHelpers` mutations remain rejected.
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
| 1 | Defined verifier CLI, resolution, workflow files and tests; clarified mutation rules, budget, documentation audit and remediation. |
| 2 | Registered the verifier consistently in both root manifests, both fixture manifests, and validator expectations; added resolution and consistency verification. |
| 3 | Added the schema allowlist and repository-validation mutation tests to Step 2 and verification. |

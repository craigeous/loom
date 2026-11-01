# Herdr Native App Hooks

Status: Plan Review
Target specs: 00-overview.md, 08-playbook.md, 10-packaging.md
Target ADRs: 0003, 0013, 0018, 0027, 0029
Target size: <= 180 LOC net code change (excluding test fixtures; plan <= 250 lines)

## Context

M9 slice 1 supplied Herdr plugin discovery and root binding. The shared hook
manifest and three hook scripts currently select only Claude or Codex, so Herdr
cannot reliably execute the identity, role governance, and write-ahead policies.
This slice extends the existing client adapter and fixture contract without
changing those policies or claiming native-app behavioral verification.

## Out of Scope & Threat-Model Boundary

Herdr installation and live native-app workflow verification belong to
`herdr-verification`. Do not change identity token detection, role policy,
checkpoint semantics, client launcher, or release support claims. Per spec 00
Non-goals, hooks are defense in depth, not a hostile-code sandbox or complete
shell parser; hostile local inode swapping and internal helper monkeypatching
are outside the trust model. Preserve Bash 3.2+, Git 2.34+, and jq 1.6+.

## Steps

1. **Spec amendment prerequisite:** The planner amends
   `.docs/spec/08-playbook.md` Hook normalization and output adapters for Herdr
   `PreToolUse` and `PreCompact`: allow is exit 0 with empty streams; block is
   exit 2, empty stdout, stderr `<reason>\n`. Include `herdr` in fixture paths,
   describe three-client conformance, and retain the existing normalization and
   fixed invalid-input reasons. Submit the spec amendment to independent cold
   plan evaluation and obtain approval before implementation; do not treat this
   slice plan's review as approval of a frozen-spec change.
2. In `plugins/loom/hooks/hooks.json`, use the exact quoted command root
   `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${HERDR_PLUGIN_ROOT:-}}}` for each of
   the three hook script paths. Update the description to reflect three clients.
3. In `plugins/loom/hooks/git-identity-guard.sh`,
   `role-governance-guard.sh`, and `precompact-write-ahead-backstop.sh`, extend
   `_loom_hook_select_client` to validate `HERDR_PLUGIN_ROOT` against
   `.herdr-plugin/plugin.json` using existing physical-root, name and version
   checks. Return `herdr` only if exactly that one client root validates; any
   combination of two or three valid roots, or zero valid roots, fails closed
   through the existing invalid-input block. A set but invalid root does not
   count as valid. Preserve Claude/Codex behavior and use the Herdr block wire
   specified in step 1, including for malformed input and policy blocks.
4. Under `plugins/loom/hooks/fixtures/hook-wire-v1/herdr/`, add six cases:
   `allow`, `block`, `malformed` for each of `pre-tool-use` and `pre-compact`,
   with `.input.json`, `.stdout`, `.stderr`, and `.exit` per case (24 files).
   Inputs must validate against
   `plugins/loom/schemas/loom-hook-wire-fixture-v1.schema.json`; compare output
   bytes and exit status to the approved wire contract, including trailing LF.
   Exercise the real scripts and deterministic state setup as existing fixtures do.
5. Extend `plugins/loom/hooks/{git-identity-guard,role-governance-guard,precompact-write-ahead-backstop}.bats`
   with positive and negative Herdr root detection and execution tests: valid
   Herdr root; missing, relative, nonexistent and wrong manifest/name/version;
   each pair and all three valid roots; one valid root alongside invalid roots;
   malformed inputs; policy allows and blocks with exact streams and exit codes.
   Exercise each manifest command with Herdr-only environment and a path with
   spaces, and retain regression coverage for Claude and Codex. Adapt fixture
   enumeration or repository checks if needed so all six Herdr cases are
   schema-validated and executed; do not weaken existing checks.

## Verification

- Fast iteration: `bats plugins/loom/hooks/git-identity-guard.bats plugins/loom/hooks/role-governance-guard.bats plugins/loom/hooks/precompact-write-ahead-backstop.bats`.
- Validate all Herdr fixture inputs with the existing schema validation path;
  byte-compare stdout, stderr, and exit for all six cases. Confirm ambiguous and
  invalid roots fail closed and existing Claude/Codex fixtures remain unchanged.
- Run `node scripts/validate-repository.mjs --root . --all` and the full
  `scripts/check` gate; both must pass. Record actual commands and results for
  independent code evaluation. Measure net code change excluding fixtures
  against the 180 LOC budget.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

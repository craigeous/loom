# Herdr Native App Hooks

Status: Plan Review
Target specs: 00-overview.md, 08-playbook.md, 10-packaging.md
Target ADRs: 0003, 0013, 0018, 0027, 0029, 0030
Target size: <= 180 LOC net code change (excluding test fixtures; plan <= 250 lines)

## Context

M9 slice 1 supplied Herdr plugin discovery and root binding. The shared hook
manifest and three hook scripts currently select only Claude or Codex, so Herdr
cannot execute identity, role governance, or write-ahead policies.
As authorized in `.docs/ADR/0030-herdr-native-app-hooks.md` (Accepted, extending
ADR 0029) and documented in `.docs/research/2026-11-01-herdr-native-app-hooks-contract.md`,
Herdr loads Loom hooks through its manifest declaring `"hooks": "hooks/hooks.json"`,
injects `HERDR_PLUGIN_ROOT` into the hook process environment, and establishes a
provisional POSIX process execution contract (allow: exit 0 with empty streams;
block: exit 2, empty stdout, stderr `<reason>\n`).

This slice extends the hook manifest, root selectors, wire adapters, and fixture
suite to support Herdr across `PreToolUse` and `PreCompact`.

## Out of Scope & Threat-Model Boundary

Herdr installation and live native-app workflow verification belong to
`herdr-verification`. Do not change identity token detection, role policy,
checkpoint semantics, client launcher, or release support claims. Per spec 00
Non-goals, hooks are defense in depth, not a hostile-code sandbox or complete
shell parser; hostile local inode swapping and internal helper monkeypatching
are outside the trust model. Preserve Bash 3.2+, Git 2.34+, and jq 1.6+.

## Steps

1. **Spec amendments (prerequisite):**
   - In `.docs/spec/08-playbook.md`: update Hook normalization and output adapters
     table with Herdr `PreToolUse` and `PreCompact` rows (allow: exit 0, empty
     streams; block: exit 2, empty stdout, stderr `<reason>\n`). Update fixture
     path text to include `herdr` (18 cases, 72 files across 3 clients).
   - In `.docs/spec/10-packaging.md`: under "Installed-root and helper binding",
     add Herdr hooks binding: manifest declares root-relative `hooks/hooks.json`;
     hook commands resolve via hook-process `HERDR_PLUGIN_ROOT`. Authority: ADR 0030.
   - The planner submits the spec amendments to independent cold plan evaluation
     and obtains approval before implementation proceeds; this slice plan's review
     does not approve a frozen-spec change.
2. In `plugins/loom/.herdr-plugin/plugin.json`, declare `"hooks": "hooks/hooks.json"`.
   In `scripts/validate-repository.mjs` (`validateHerdrMetadata`), verify that
   `plugin.json` specifies `"hooks": "hooks/hooks.json"`.
3. In `plugins/loom/hooks/hooks.json`:
   - Update commands to use `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${HERDR_PLUGIN_ROOT:-}}}`.
   - Update description to reflect three clients: Claude, Codex, and Herdr.
   - Update mirrored "both clients" comment in `scripts/validate-repository.mjs`.
4. In `plugins/loom/hooks/git-identity-guard.sh`, `role-governance-guard.sh`, and
   `precompact-write-ahead-backstop.sh`:
   - Extend `_loom_hook_select_client` to validate `HERDR_PLUGIN_ROOT` against
     `.herdr-plugin/plugin.json` (physical canonical directory, name==loom, version==0.2.0).
   - Return `herdr` only if exactly one client root validates; any multiple valid
     roots or zero valid roots fail closed with the standard invalid-input reason.
   - In `_loom_hook_block`, add the `herdr` case: emit empty stdout, stderr
     `<reason>\n`, and exit 2 (matching ADR 0030 and spec 08).
5. Under `plugins/loom/hooks/fixtures/hook-wire-v1/herdr/`, add six cases:
   `allow`, `block`, `malformed` for `pre-tool-use` and `pre-compact` (24 files),
   validating against `plugins/loom/schemas/loom-hook-wire-fixture-v1.schema.json`.
   Update `CLAUDE.md` curated digest count from 12-case (48 files) to 18-case (72 files).
6. Extend Bats test suites:
   - In `git-identity-guard.bats`: test full root selection matrix for Herdr
     (valid Herdr root, missing, relative, wrong manifest/name/version, two valid,
     three valid, valid alongside invalid) and run Herdr hook-wire fixtures.
   - In `role-governance-guard.bats` and `precompact-write-ahead-backstop.bats`:
     add focused Herdr smoke tests (valid execution, policy allow, policy block)
     to preserve the 180 LOC net code budget.

## Verification

- Fast iteration: `bats plugins/loom/hooks/git-identity-guard.bats plugins/loom/hooks/role-governance-guard.bats plugins/loom/hooks/precompact-write-ahead-backstop.bats`.
- Fixture schema validation: all 18 input fixtures validate against
  `plugins/loom/schemas/loom-hook-wire-fixture-v1.schema.json`.
- Mechanical regression check:
  `git diff --exit-code 5ad484b -- plugins/loom/hooks/fixtures/hook-wire-v1/{claude,codex}`.
- Mechanical hook manifest check:
  `jq -e '.hooks == "hooks/hooks.json"' plugins/loom/.herdr-plugin/plugin.json`.
- Mechanical hook dispatcher check:
  `jq -e '.hooks.PreToolUse[0].hooks[0].command == "\"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${HERDR_PLUGIN_ROOT:-}}}/hooks/git-identity-guard.sh\""' plugins/loom/hooks/hooks.json`.
- Mechanical root selector coverage:
  `[ "$(git grep -c 'HERDR_PLUGIN_ROOT' plugins/loom/hooks/*.sh | wc -l | tr -d ' ')" = "3" ]`.
- Gate: `node scripts/validate-repository.mjs --root . --all` and `scripts/check`.
- Budget: net code change excluding fixtures <= 180 LOC.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Sourced Herdr hook wire contract from research note; added Step 2 for `plugin.json` `hooks` field and validator check; listed mirrored enumerations in spec 10, hooks.json, CLAUDE.md, and validator; added mechanical checks and budgeted test matrix |
| 2 | Sourced Herdr hook wire contract from accepted ADR 0030 (extending ADR 0029) and dedicated research note; restored immutability of ADR 0029 and earlier research (Resolving Findings 1 & 2); restored spec-amendment cold-eval approval gate in Step 1 (Resolving Finding 3); robustified mechanical checks with fixed base SHA 5ad484b, full command jq equality, and HERDR_PLUGIN_ROOT grep (Resolving Finding 4) |

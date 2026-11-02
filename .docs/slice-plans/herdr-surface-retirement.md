# Herdr `hc` Client (4 of 4): Retire the Herdr Plugin Surfaces

Status: Plan Review
Target specs: 07-command-surface.md (Host surfaces), 08-playbook.md (hook wire), 10-packaging.md (no Herdr root)
Authority: ADR 0031 §7 (Accepted)
Target size: <= 120 LOC added (Bats edits and re-pin; deletions of retired files and fixtures are not counted); keep this plan <= 250 lines

## Context

ADR [0031](../ADR/0031-herdr-as-an-hc-driven-client.md) §7 retires the plugin framing
that ADRs 0029 and 0030 built. The tree still carries it: two Herdr manifests, the
`herdr-plugin-root/v1` binding, `herdr` branches in `loom-launch-role` and
`loom-resolve-helper`, `HERDR_PLUGIN_ROOT` handling in the three hook scripts and
`hooks.json`, `herdr` entries in `validate-repository.mjs`, the v0.3.0 matrix and two
schemas, 24 `herdr` hook-wire fixtures and `scripts/tests/herdr-verification.bats`.

This is slice 4 of 4 and **lands last**: it edits `role-governance-guard.sh` (slice 1)
and `v0.3.0.json` (slice 2). Slice 2's binding file, its schema and
v0.3.0 fixture stay (slice 2 adds no matrix key). Release state (ADR 0031 §7): no git tag, manifests say `0.2.0`,
the schema and validator bind only `v0.2.0.json`; `v0.3.0.json` is unreleased and is
edited in place. `v0.2.0.json`, `adapters/fixtures/v0.2.0/` and the Claude/Codex root
bindings stay byte-identical (the frozen v0.2.0 evidence lists only those two roots,
so deleting the Herdr root cannot alter it).

## Out of Scope & Threat-Model Boundary

- No new capability: nothing is added except test edits and the schema re-pin. `hc`
  host behavior is slices 1–3.
- Herdr research, ADRs 0029/0030, archived plans, evaluations and the one history link
  in `scripts/validation/relative-link-allowlist.txt` stay as history; the Herdr rows
  in `.docs/` are never edited here.
- The host binding `plugins/loom/adapters/hosts/hc-host-v1.json`, its schema and its v0.3.0
  fixture legitimately name `herdr` as `host` (Herdr is a client) and are kept; retirement
  removes the Herdr plugin root and marketplace schemas and matrix `rootBindings`, not the host binding.
- **Open blocker (retained):** blind review through `hc` is unresolved (ADR 0031 §5 and
  Consequences); hc evaluator use stays blocked pending a follow-up ADR. Retirement does not resolve it.
- Claude and Codex hook wires, fixtures and role launch are unchanged. Selection of the
  hook client stays "exactly one valid root of Claude or Codex, else fail closed".
- Not a boundary change: `hc` deny and defense-in-depth stay as in spec 08 and
  `00-overview.md` Non-goals.

## Steps

1. **Delete**: `.herdr-plugin/marketplace.json`, `plugins/loom/.herdr-plugin/plugin.json`,
   `plugins/loom/adapters/roots/herdr-plugin-root-v1.json`,
   `plugins/loom/hooks/fixtures/hook-wire-v1/herdr/` (24 files),
   `scripts/tests/herdr-verification.bats`. Before deleting the Bats file, list each
   test that asserts a non-Herdr invariant (for example skills discoverable from the
   Claude manifest), confirm another test covers it, and port any uncovered test into
   its natural Bats file (state the mapping in the commit body).
2. **`plugins/loom/adapters/compatibility/v0.3.0.json`**: remove `clientFloors.herdr`,
   the `herdr-plugin-root/v1` root binding and the three per-profile `herdr` keys.
   Add nothing; slice 2 adds no matrix key.
3. **`plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`**: remove the
   `herdr-plugin-root/v1` branch and its `oneOf` entry. **`scripts/check-toolchain.json`**:
   re-pin this schema's `sha256` (it is listed; change nothing else).
4. **`plugins/loom/bin/loom-launch-role`**: remove `herdr` from `CLIENTS`, `_usage`,
   `_valid_model`, the `herdr)` dispatch arm, `_launch_herdr` and the `--author-client`
   accepted set. **`plugins/loom/schemas/loom-role-launch-v1.schema.json`**: drop the
   `herdr` `oneOf` branch and `herdr` from every `authorClient` enum.
5. **`plugins/loom/bin/loom-resolve-helper`**: remove `_resolve_herdr`, the `herdr)`
   arm and its usage/header lines. `ALLOWED_HELPERS` is unchanged.
6. **Hooks** (`git-identity-guard.sh`, `precompact-write-ahead-backstop.sh`,
   `role-governance-guard.sh`): drop the `HERDR_PLUGIN_ROOT` validation line, the
   `herdr` branch of `_loom_hook_select_client` (exactly one valid Claude or Codex root,
   else fail closed) and `herdr` from `claude | herdr | *)` in the block adapters.
   **`plugins/loom/hooks/hooks.json`**: commands use
   `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}`. Claude and Codex wires are unchanged.
7. **`scripts/validate-repository.mjs`**: remove the Herdr manifest paths,
   `validateHerdrMetadata` and its call, the Herdr entries in `rootPaths`, `schemaBindings`
   and `expectedRoots`, and the Herdr entries in fixture-path enumeration; the
   hook-wire fixture expectation becomes 2 clients, 12 cases, 48 files. Do not touch
   slice 2's `validateHostBinding()`. **`scripts/validation/relative-link-allowlist.txt`**:
   touch only if the check demands it (the history link stays).
8. **Tests (offline)**: `loom-launch-role.bats` (delete the `herdr` block; add: `herdr`
   client is a usage error; `--author-client herdr` rejected), `loom-resolve-helper.bats`
   (`herdr` is a usage error), the three hook Bats files (delete Herdr cases; add: a
   lone `HERDR_PLUGIN_ROOT` fails closed on each hook), `scripts/tests/repository-validation.bats`
   (remove Herdr cases; assert 2 clients / 12 cases / 48 files and the absence of every
   retired path).
9. **Docs (finalize pass)**: `CLAUDE.md` Map: the hook fixture line becomes "12-case
   (2 clients × 2 events × 3 outcomes; 48 fixture files at 4/case)"; stay <= ~100
   lines. `.docs/slice-plans/README.md` index. Orchestrator on `main`: `.docs/status/`
   (roadmap M9, progress, handoff): ADR 0031 items landed, `hc` roles still "designed,
   unverified", the probe result recorded as evidence, not role support, and the explicit
   open blocker kept: blind review via `hc` unresolved, hc evaluator use blocked pending a
   follow-up ADR (ADR 0031 §5 and Consequences).

## Verification

- Iteration: `shfmt -i 4 -d -ln bash`, `shellcheck -s bash`, `bash -n` on the changed
  scripts; `node scripts/validate-repository.mjs --all`;
  `TMPDIR=/private/tmp bats` on the changed Bats files above.
- Acceptance, each a command with the stated result:
  1. `rg -n -i 'herdr' plugins/loom/bin plugins/loom/hooks plugins/loom/schemas plugins/loom/adapters/compatibility plugins/loom/adapters/roots .claude-plugin .agents scripts/validate-repository.mjs -g '!*.bats' -g '!loom-host-binding-v1.schema.json'` finds nothing (the host-binding schema and `adapters/hosts/` legitimately name `herdr`; `validateHostBinding()` must not name it).
  2. `rg -n 'HERDR_PLUGIN_ROOT|herdr-plugin' plugins scripts .claude-plugin .agents -g '!*.bats' -g '!scripts/validation/relative-link-allowlist.txt'` finds nothing; none of the Step 1 paths exists.
  3. `plugins/loom/hooks/fixtures/hook-wire-v1` has exactly 12 cases and 48 files and the Claude and Codex fixtures are byte-identical to `HEAD`.
  4. `git diff --stat HEAD -- plugins/loom/adapters/compatibility/v0.2.0.json plugins/loom/adapters/fixtures/v0.2.0 plugins/loom/adapters/roots/claude-plugin-root-v1.json plugins/loom/adapters/roots/codex-skill-source-v1.json` is empty.
  5. `jq -e '(.clientFloors | has("herdr") | not) and (.rootBindings | map(.id) | index("herdr-plugin-root/v1") | not)' plugins/loom/adapters/compatibility/v0.3.0.json` prints `true`.
- Regression proof (unchanged, passing): Claude/Codex hook fixtures, `loom-profile.bats`,
  the Claude/Codex halves of `loom-launch-role.bats` and `loom-resolve-helper.bats`,
  and slices 1–3's Bats files.
- Full gate once on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
  Only the known unrelated `INT during a mutation yields exit 130` dogfood race may
  be recorded and rerun once (owner-declared out of scope); any other failure blocks.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 1 | Plan-eval round 1: retirement scoped to plugin root/marketplace schemas and matrix rootBindings, host binding kept; blind-review open blocker retained in final status updates |
| 0 | Split from `herdr-hc-client` (owner decision): retirement only, lands last; v0.2.0 evidence untouched; acceptance greps scoped so the kept `hc` host binding and history link do not trip them; schema re-pin named |

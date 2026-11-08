# Codex Launch Schema Fix (v0.2.1)

Status: Landed
Target specs: 10-packaging.md
Authority: [ADR 0032](../../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md) (Accepted); [ADR 0033](../../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md) (Accepted; §1)
Target size: <= 50 LOC net change (keep this plan document <= 250 lines)

## Context

During the v0.2.0 live proof (ADR 0032 E1–E5, ADR 0033 D3), launching Codex roles via `plugins/loom/bin/loom-launch-role` failed against the live OpenAI API when `codex exec` received `--output-schema plugins/loom/schemas/loom-role-launch-v1.schema.json`.

The failure occurred because of two fundamental incompatibilities:
1. `loom-role-launch-v1.schema.json` is the schema for the *launcher stdout descriptor* emitted by `loom-launch-role` (recording client, role, profile, coldId, permissions, and argv), not the output of the model. It contains a top-level `oneOf` and non-required properties, which OpenAI Structured Outputs strictly prohibits (HTTP 400 Bad Request).
2. Even if OpenAI accepted the schema, Codex subagents execute `$loom-$role` skills that follow canonical role contracts (`roles/*.md`) requiring bounded markdown text returns (`Status: ...\nPaths: ...\nSummary: ...\nSignal: ...`) per ADR 0012, not JSON objects. Passing `--output-schema` forces the LLM to emit structured JSON conforming to the launch descriptor instead of executing role instructions.

In the v0.2.0 live proof, a temporary wrapper script stripped `--output-schema` from `codex exec`, allowing all five roles, the full loop, and the platform gate to complete natively.

This slice cleanly fixes the Codex launch contract in `loom-launch-role` by removing `--output-schema` from `codex exec` argv, ensuring native un-wrapped execution for v0.2.1 while preserving schema verification of the launcher's own descriptor.

## Out of Scope & Threat-Model Boundary

- **No change to `loom-role-launch-v1.schema.json`.** The schema remains the authoritative contract for `loom-launch-role`'s printed JSON launch descriptor across Claude, Codex, and Antigravity.
- **No change to role contracts or skills.** Canonical role contracts (`plugins/loom/roles/*.md`) and skills (`plugins/loom/skills/loom-*/SKILL.md`) remain untouched.
- **No relaxation of Codex execution guards.** `codex exec` retains `--ephemeral`, `--ignore-user-config`, `--strict-config`, `--disable multi_agent`, `--sandbox read-only`, `--model "$model"`, `-c model_reasoning_effort=$effort`, and `-c tools.web_search=false`.
- **No live network calls in unit tests.** Tests continue using the stubbed `LOOM_LAUNCH_ROLE_CODEX_BIN` boundary.
- **Threat-model boundary:** Caller-supplied overrides (`--model`, `--effort`, `--author-client`) remain strictly validated; unrecognized flags and options fail closed.

## Decisions

- **D1 — Omit `--output-schema` from `codex exec` argv.** In `plugins/loom/bin/loom-launch-role`'s `_launch_codex`, remove `--output-schema "$schema_path"` from the `argv` array passed to `codex exec`. Codex roles communicate bounded results via standard markdown output per ADR 0012, symmetric with Claude.
- **D2 — Verify launch descriptor schema as a required, non-symlinked plugin asset.** `_launch_codex` verifies that `schemas/loom-role-launch-v1.schema.json` is a regular, non-symlinked file (`[ -f "$schema_path" ] && [ ! -L "$schema_path" ]`) before printing the descriptor and launching Codex. The guard error message is updated to `"launch descriptor schema is missing"`.
- **D3 — Update test suite assertions in `loom-launch-role.bats`.** Update the Bats test suite to verify that `codex exec` argv contains all required security/sandbox options and specifically does NOT contain `--output-schema`. Delete the obsolete test that extracted `--output-schema` from `$RECORD`. Add a negative test verifying that a symlinked schema file fails closed.

## Steps

1. **Update `plugins/loom/bin/loom-launch-role`:**
   - In `_launch_codex`:
     - Add non-symlink check alongside regular file check: `[ -f "$schema_path" ] && [ ! -L "$schema_path" ] || _fail "launch descriptor schema is missing"`.
     - Remove `--output-schema "$schema_path"` from the `argv` array.
     - Update header comment to reflect that `--output-schema` is no longer passed to `codex exec`.
2. **Update `plugins/loom/bin/loom-launch-role.bats`:**
   - In `codex: exact argv contract`:
     - Retitle test to `codex: exact argv contract (ephemeral, no user config, strict, no multi-agent, read-only, model/effort, no web search, no output schema, canonical contract)`.
     - Replace `[[ "$output" == *'ARG:--output-schema'* ]]` with `[[ "$output" != *'ARG:--output-schema'* ]]`.
     - Remove `[[ "$output" == *'loom-role-launch-v1.schema.json'* ]]` from argv checks.
   - Delete obsolete test `codex: the closed bounded-output schema path is a real regular file` (since `--output-schema` is no longer emitted in `$RECORD`).
   - In `codex: missing closed bounded-output schema fails closed`:
     - Retitle to `codex: missing launch descriptor schema fails closed`.
     - Expect error output `launch descriptor schema is missing`.
   - Add negative test `codex: symlinked launch descriptor schema fails closed`:
     - In `make_root` fixture, replace `$ROOT/schemas/loom-role-launch-v1.schema.json` with a symlink to a copy, run launch, and assert exit 2 with error `launch descriptor schema is missing`.
3. **Run targeted Bats test:**
   - Run `scripts/run-bats-under /bin/bash '^3\.2' "$(readlink -f "$(which bats)")" scripts/tests/shell-runtime.bats plugins/loom/bin/loom-launch-role.bats`.
4. **Run repository validation:**
   - Run `node scripts/validate-repository.mjs --all`.

## Verification

- **Targeted Bats test:**
  `scripts/run-bats-under /bin/bash '^3\.2' "$(readlink -f "$(which bats)")" scripts/tests/shell-runtime.bats plugins/loom/bin/loom-launch-role.bats` passed: 103/103 tests passing under Bash 3.2 (exit 0).
- **Static code checks:**
  `shfmt -i 4 -d -ln bash plugins/loom/bin/loom-launch-role` clean (exit 0).
  `shellcheck -s bash plugins/loom/bin/loom-launch-role` clean (exit 0).
  `git diff --check` clean (exit 0).
- **Repository state validation:**
  `node scripts/validate-repository.mjs --all` exits 0 with zero rule reports.
- **Full platform gate:**
  `TMPDIR=/private/tmp BASH_BIN=/bin/bash /bin/bash scripts/check` exits 0 under Bash 3.2.

## Notes

- 2026-11-07: Authored initial draft to resolve the Codex live-proof workaround cleanly in product code.
- 2026-11-07: Revised plan in Round 1 addressing plan-evaluator findings (deleted obsolete argv-extraction test, added explicit symlink check and test, retitled argv test).

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Resolved Round 0 findings: deleted obsolete argv-extraction test, added explicit non-symlink schema check and test, retitled argv test, and updated verification commands |

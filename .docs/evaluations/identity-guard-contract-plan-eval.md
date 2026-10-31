# Evaluation: identity-guard-contract (slice-plan)

Verdict: FAIL
Round: 1
Reviewed against: plan-eval-rubric.md, severity.md (anti-goalpost-moving, Round >= 1), repository-improvement-plan.md (M3 `identity-guard-contract`), ADR 0003, spec 00 (Non-goals), spec 08, spec 10, `git-identity-guard.sh`, `loom-resolve-helper`, `adapters/roots/*.json`, `scripts/validate-repository.mjs`, templates/evaluation.md; revision diff `0c32b49..ddccc8f`

## Findings

- [MAJOR] Allowlist registration is incomplete and, as written, breaks the required gate (introduced by the revision) — Step 2 now adds `loom-verify-identity` to `ALLOWED_HELPERS` in `loom-resolve-helper` and its bats, but the same allowlist is mirrored in `plugins/loom/adapters/roots/claude-plugin-root-v1.json:16`, `.../roots/codex-skill-source-v1.json:20`, the release-owned fixtures `adapters/fixtures/v0.2.0/metadata/{claude,codex}-root.json`, and hard-coded in `scripts/validate-repository.mjs:517,526` (`allowedHelpers: ["loom-coord"]`). The plan's Verification runs `scripts/check` and `validate-repository.mjs --all`. A developer who follows Step 2 literally will either fail that validator or be forced to guess which adapter and fixture files to edit. The plan neither lists these files nor says whether the "release-owned static metadata fixtures" may change in this slice.

## Required changes (for FAIL)

1. In Step 2, list every file that carries the helper allowlist: the two `adapters/roots/*.json` bindings, the two `adapters/fixtures/v0.2.0/metadata/*-root.json` fixtures, and `scripts/validate-repository.mjs`. State that all are updated consistently. Alternatively, choose another resolution path that avoids widening the allowlist, for example invoking the verifier through `loom-coord`, and state that path explicitly.

## Notes

Prior [MAJOR 1] (verifier naming and interface): resolved. The diff names `plugins/loom/bin/loom-verify-identity`, defines the CLI `<baseline-sha|unborn>`, the 0/1/2 exit codes and the stderr contract, and adds the `ALLOWED_HELPERS` and `loom-resolve-helper.bats` edits. Only the mirrored-metadata gap above remains.

Prior [MAJOR 2] (unnamed workflow files): resolved. The diff names `roles/developer.md`, `skills/loom-developer/SKILL.md` and `references/commit-convention.md`, and adds an `rg` loop that checks each contains `loom-verify-identity`.

Prior MINORs were also addressed by the diff: the `git config` write rule including `--unset`, `--replace-all`, `--add` and `--edit`; `author.*` and `committer.*` keys; a 250 LOC budget excluding tests and docs; a stale-claim `rg -U` audit; and the remediation reconciliation. The plan is 98 lines, within the 250 limit. No other regressions were found in the diff.

The one finding is small and mechanical. A PASS should follow once the allowlist file set is listed.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | 2 MAJOR: (1) verifier unnamed/no CLI/no resolver registration; (2) workflow files unnamed. Both resolved by the revision diff (verifier named with CLI and exit codes, `ALLOWED_HELPERS` entry added, three files named with an `rg` check). Round 1 found a new MAJOR in the revision: the allowlist is mirrored in adapter JSON, fixtures and the validator, which the plan omits. |

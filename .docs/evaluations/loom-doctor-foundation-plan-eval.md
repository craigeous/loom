# Evaluation: loom-doctor-foundation (slice-plan)

Artifact: `.docs/slice-plans/loom-doctor-foundation.md` (re-reviewed at commit 4f3de55; Round 0 FAIL reviewed at 2b7a1d4)
Authorities: spec 06, 08, 10; spec 00 `## Non-goals`; `repository-improvement-plan.md` M6
Round: 0
Verdict: PASS

## Summary

Round 0 (FAIL) was resolved by the revision diff `2b7a1d4..4f3de55`. Step 3 now
registers `loom-doctor` in every pinned allowlist location, Steps 4-5 tie the
command/skill adapters to the validators, and Step 1 carries a fixed check-ID table.
The revision updates Steps and Verification in place and logs the round in the
Revision Log, with no competing sections. The plan is 112 lines against the 250-line
target and keeps the `Target size:` line and the Out of Scope & Threat-Model section.
This is a PASS that resolves the Round 0 FAIL, so the round counter stays at 0.

## Round 0 finding resolution

| # | Sev | Status | Evidence in diff |
|---|---|---|---|
| 1 | BLOCKER | Resolved | Step 3 lists `loom-resolve-helper` `ALLOWED_HELPERS`; the binding schema `const`; `claude-plugin-root-v1.json`; `codex-skill-source-v1.json`; both v0.2.0 metadata fixtures; both `expectedRoots` arrays in `validate-repository.mjs`; `loom-resolve-helper.bats`; and `repository-validation.bats`. It also states that the release-owned fixtures are deliberately updated because the validator pins them to the live root metadata, and that this is not a new release. |
| 2 | MAJOR | Resolved | Step 4 names the frontmatter for `commands/doctor.md` and `.agents/skills/loom-doctor/SKILL.md`, with a 20-line thin-adapter cap. It adds `doctor` to `workflows` in `compatibility/v0.3.0.json` and states that the manifests and catalogs need no entry. Step 5 gives the `SKILL.md` frontmatter and routing through `loom-resolve-helper`. |
| 3 | MAJOR | Resolved | Step 1 now has a table of 11 fixed check IDs with a probe and status mapping each. It names `loom-review`, the three `review-*-v1.md` finders and `loom-eval-workspace`. Coordination is read directly without calling `loom-coord`, with a stale rule based on `LOOM_LEASE_TTL`. The init classifier reuses `init-detection.md`. Node and SHA-256 are justified as foundation protocol dependencies rather than spec 06 floors. Client support is stated as unchecked, with no support conclusion. Step 2 binds the schema to the same IDs. |
| 4 | MINOR | Resolved | Verification uses `--root .` and adds targeted `shfmt -i 4 -d` and `shellcheck -s bash`. |
| 5 | MINOR | Resolved | Step 6 is now a proportional matrix with at least one pass, warning, error and unchecked case. |
| 6 | MINOR | Resolved | Step 6 asserts that human output contains the `unchecked` label. |

## Revision-diff regression check

No regression or newly introduced BLOCKER/MAJOR found. The additions are consistent
with the Out of Scope section, and deferred spec 08 capabilities remain `unchecked`,
never passing. The diff adds no `spec/` or ADR edits.

## Notes (MINOR, non-blocking)

- This re-review was scoped to the revision diff and the Round 0 findings. The
  developer should confirm mechanically, for example with `rg -n allowedHelpers`
  and `jq`, that no allowlist location was missed. `validate-repository.mjs --all`
  and `scripts/check` will catch any omission.
- Step 7 adds `plugins/loom/bin/loom` without registering it in the helper allowlist.
  This is intentional, since it is a CLI entry point rather than a resolved helper.
  The developer should keep it out of the allowlist unless the validator requires it.

## Rubric checklist

| Item | Result |
|---|---|
| Authority (targets 06/08/10, consistent) | OK |
| Executable, file-scoped numbered steps | OK |
| Verified sketches against tree | OK (allowlist locations enumerated) |
| Single-purpose | OK |
| Canonical structure / Revision Log | OK (in-place update, logged) |
| Out of scope & non-goals | OK |
| Target size budget stated / doc <= 250 lines | OK (112 lines) |
| Verification named | OK (gate, fast shell checks, bats, validator) |

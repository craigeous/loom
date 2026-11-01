# Herdr client adapter code evaluation

Artifact: .docs/slice-plans/herdr-client-adapter.md
Reviewed against: plugins/loom/skills/loom-playbook/references/code-eval-rubric.md
Commit: 2f52d69
Round: 0
Verdict: FAIL

## Summary

The Herdr resolver and descriptor work for the exercised paths, and the targeted 140-test Bats suite and repository validation passed. The three explicitly prescribed affirmative launch checks fail as written, contrary to the implementation evidence. The full `scripts/check` rerun passed; no review-findings artifact was supplied among the permitted inputs, so its candidates could not be adjudicated.

## Findings

- [MAJOR] The plan's three affirmative launch checks invoke `plugins/loom/bin/loom-launch-role` relatively, but the launcher rejects relative invocation with `must be invoked by absolute path`; each pipeline produces no JSON and `jq -e` fails. The plan's implementation evidence says those checks passed, so the required verification and recorded evidence do not match reality. Preserve the launcher's absolute-path security contract and correct the approved verification commands/evidence through the appropriate planning workflow, then rerun them.
- [MINOR] `scripts/validate-repository.mjs` adds the Herdr root descriptor but never reads either new `.herdr-plugin/marketplace.json` or `plugins/loom/.herdr-plugin/plugin.json`. Thus `--all` can pass even if discovery metadata is malformed or points at the wrong plugin, despite the file-scope description saying Herdr metadata is registered for validation.

## Verification

- `node scripts/validate-repository.mjs --root . --all`: passed.
- Requested Bash 5 targeted Bats: 140/140 passed.
- Matrix floor and root-binding `jq` checks passed; invalid root failed closed as expected.
- All three specified relative-path launcher pipelines failed. Absolute-path launches for researcher, developer, and planner emitted descriptors with the expected clients, roles, and profiles.
- `scripts/check`: passed, including 923 Bats tests.
- The mandated local-review findings were not included in the controlled inputs, so no candidate findings were adjudicated.

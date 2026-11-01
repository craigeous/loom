# Plan evaluation — herdr-native-app-hooks

Artifact: .docs/slice-plans/herdr-native-app-hooks.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: 6cec837
Round: 0
Verdict: PASS

## Summary

All four findings from the Round 0 FAIL are resolved in `git diff 6d35db1..6cec837`. There are no open BLOCKER or MAJOR findings. Two MINOR observations remain. They do not block approval.

- **Finding 1 (MAJOR, unsourced wire contract):** Resolved under the fix's option (b). ADR 0030 §5 and the new research note both mark the wire contract as provisional. They name `herdr-verification` (M9 slice 3) as the owner of live verification. The plan Context now says "provisional POSIX process execution contract" and no longer says Herdr "follows" it. The research note's cited sources are still internal Loom files and Herdr's `Info.plist` and CLI output, so the contract is not independently sourced. That is acceptable only because it is declared provisional with a named validating slice.
- **Finding 2 (MAJOR, Accepted ADR rewritten in place):** Resolved. The diff removes the ADR 0029 §6 addition (-14 lines) and the research-note bullet (-1 line), so both are back to their accepted state. The new authority is ADR 0030, which is `Extends: 0003, 0013, 0018, 0029` and has an owner-acceptance record. It is a separate, traceable ADR with a dedicated research note, and it supersedes nothing silently.
- **Finding 3 (MINOR, spec-amendment gate):** Resolved. Step 1 again requires the planner to submit the spec 08 and spec 10 amendments to cold plan evaluation and get approval before implementation. It states that this slice-plan review does not approve a frozen-spec change.
- **Finding 4 (MINOR, fragile checks):** Resolved.
  - The fixture regression check is anchored to fixed SHA `5ad484b`.
  - The hooks.json check compares the full command string with `jq -e`.
  - A `jq -e '.hooks == "hooks/hooks.json"'` check on `plugin.json` was added.
  - The selector coverage check greps for `HERDR_PLUGIN_ROOT` in the three scripts.

The revision is in place. Context, Steps and Verification are updated, and the Revision Log is a compact table. The plan is 98 lines against the 250 limit, has a `Target size:` line, and has an Out of Scope & Threat-Model Boundary section. The fixture arithmetic is consistent: 6 cases × 4 files = 24 files, giving 18 cases and 72 files across three clients.

## Findings

1. **[MINOR] Provisional status is not carried into the plan's Out of Scope section.**
   The plan Context calls only the block envelope provisional. It states Herdr's manifest `hooks` discovery and `HERDR_PLUGIN_ROOT` injection as plain fact. ADR 0030 §5 and the research note treat the whole contract as provisional. Consider one sentence in `## Out of Scope & Threat-Model Boundary`. It should say that all Herdr hook behavior (discovery, environment, events, block encoding) is offline-fixture evidence only until `herdr-verification` confirms it. This keeps the fixtures from being read as conformance evidence. Not required for PASS.

2. **[MINOR] Some asserted invariants have no mechanical check.**
   The `CLAUDE.md` digest count change (12-case/48 files to 18-case/72 files) and the `validate-repository.mjs` `hooks` check have no named command. The gate (`validate-repository.mjs --all` and `scripts/check`) probably covers the validator. An `rg` check for the new count string would cover `CLAUDE.md`. Not required for PASS.

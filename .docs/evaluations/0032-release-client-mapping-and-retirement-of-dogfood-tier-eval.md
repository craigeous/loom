# Evaluation: ADR 0032

Verdict: FAIL
Round: 1
Commit: 07b7da4
Reviewed against: owner decision, ADRs 0019, 0024, 0027, 0031, specs 07 and 10, README and CLAUDE.md.

## Summary

FAIL (round 1; BLOCKER: 1, MAJOR: 1, MINOR: 0). Evidence binding was circular, and the open questions contradicted the binding release and routing decisions. The remaining sections are the original record, unchanged.

## Findings

- [BLOCKER] The evidence must be recorded from the tagged commit while E4 and E5 must name the candidate commit (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:72-73, 86-92). Recording a commit's own hash and post-test acknowledgement in that same commit requires changing the commit, invalidating the binding. Allow an external immutable evidence record bound to the tagged commit, checkable alongside it. Exact command: `nl -ba .docs/ADR/0032-*.md`.
- [MAJOR] Binding decisions are contradicted by open questions: E4 mandates every platform, default routing excludes Antigravity, and all three clients are listed as supported in v0.3.0, but questions 1, 4 and 5 reopen these decisions (.docs/ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md:86-90, 130-132, 202-212). Resolve the questions or explicitly make the proposed requirements conditional before acceptance. Exact command: `nl -ba .docs/ADR/0032-*.md`.

## Required changes

1. Make evidence and sign-off verifiable without requiring a commit to contain its own hash.
2. Reconcile the open questions with the normative release and routing decisions.

## Notes

The mapping matches the owner decision, with v0.3.0 additive. `jq '.' plugins/loom/adapters/compatibility/v0.2.0.json plugins/loom/adapters/compatibility/v0.3.0.json` verifies the current Claude/Codex and additional Herdr entries; the latter is identified as stale, not claimed as conformance. No evidence is asserted as already satisfying E1–E5. ADR 0019's matrix is retained; ADR 0024 and 0027 are superseded in scope without edits, and CLAUDE.md is slated for later change (`git diff HEAD^ HEAD -- CLAUDE.md .docs/ADR/0024\* .docs/ADR/0027\*`). Antigravity and Orca work is listed consistently with `rg -n 'antigravity|orca|agy models' plugins/loom/bin/loom-launch-role .docs/spec/07-command-surface.md` and `rg -in orca plugins/loom/adapters`. Status and index are correct (`rg -n 'Status:|0032|In Review' .docs/ADR/0032-*.md .docs/ADR/README.md`). No universal cross-OS portability claim found: `cat .github/workflows/check.yml` and `rg -n -A14 'Supported Platforms & Prerequisites' README.md` show four CI cells and explicit exclusions; `rg -n 'stat -f|stat -c|flock' plugins/loom/bin scripts` finds platform-specific stat calls, generally with platform branches or fallbacks, and no flock matches. CI configuration alone is not proof of successful release evidence.

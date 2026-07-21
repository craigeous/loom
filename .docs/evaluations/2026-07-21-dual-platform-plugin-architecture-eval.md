# Evaluation: Dual-platform plugin architecture

Verdict: FAIL
Round: 1
Reviewed against: Sources [1]-[15] cited by `.docs/research/2026-07-21-dual-platform-plugin-architecture.md`, including the current local tree and installed-client queries, and the linked official OpenAI and Anthropic documentation.

## Findings

- [BLOCKER] The central `PreCompact` wire-incompatibility claim contradicts source [8]. Current Claude hooks documentation specifies `trigger` (`manual` or `auto`), not `compaction_trigger`, exactly as source [4] specifies for Codex. Source [2] does show that Loom's current hook still reads `compaction_trigger`, so the supported finding is a Loom-versus-both-clients incompatibility, not a Claude-versus-Codex field difference. This mismatch affects the summary, findings 5, M0/M3 impact, and related risks/open questions.
- [BLOCKER] The no-nested-subagent premise contradicts source [9]. Current Claude documentation says that, as of Claude Code v2.1.172, a subagent can spawn its own subagents; the installed version recorded by source [12] is 2.1.216. Loom's current role files in source [2] omit the Agent tool and can still impose hub-and-spoke behavior, but the claims that Claude plugin agents cannot spawn subagents and that both clients default to one delegation level are not supported. This mismatch affects findings 3, M4/M5/M8 impact, and the release-skew discussion.
- [BLOCKER] The statement that Codex “deprecates custom prompts in favor of skills” is not supported by cited sources [3] or [15]. Those sources document plugin components and skills/invocation, but do not state that custom prompts are deprecated. The explicit deprecation claim needs a resolving official source or must be narrowed to what the cited pages actually establish.

## Required changes (for FAIL)

1. Reframe the `PreCompact` analysis using the current `trigger` field documented by both clients, and distinguish the stale Loom hook input parser from a true cross-client difference; re-check the claimed output difference independently.
2. Update the Claude subagent analysis for current nested-subagent support, distinguishing platform capability from Loom's role-level tool restrictions and chosen hub-and-spoke policy.
3. Cite an official source that explicitly supports the Codex custom-prompt deprecation claim, or remove/narrow that claim.

## Notes

All fifteen cited sources resolved. The remaining packaging, marketplace, skill, instruction-file, hook-trust, helper-resolution, CLI-surface, and client-availability claims checked were supported by the cited local or official sources.

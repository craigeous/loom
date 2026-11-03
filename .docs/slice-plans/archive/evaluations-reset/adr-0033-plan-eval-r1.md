# Evaluation: ADR 0033

Verdict: FAIL
Round: 1
Reviewed against: ADRs 0032, 0024, 0031, 0005, 0019; specs 00, 03, 04, 07, 08, 10; ADR template and plan-evaluation rubric; binding owner decisions.

## Findings

- [BLOCKER] The named supersessions are incomplete. ADR 0033 lines 41–46 replaces the v0.3 table and counts, but ADR 0032 line 109 independently states that every pair in the v0.3 rows is required and none is not applicable. This remains in force under ADR 0033 line 112 despite the narrower admitted set. Explicitly supersede or reconcile that clause. Command: `sed -n '85,110p' .docs/ADR/0032-*`.
- [MAJOR] ADR 0033 lines 10–11 says none of the three added harnesses has a matrix entry, binding or pinned floor; `plugins/loom/adapters/compatibility/v0.3.0.json:5` and `:12` contain Herdr's floor and binding entry, which ADR 0032 lines 282–285 itself calls stale. Distinguish stale entries from absent valid evidence. Command: `rg -n 'herdr' plugins/loom/adapters/compatibility/v0.3.0.json .docs/ADR/0032-*`.
- [MAJOR] ADR 0033 lines 52–54 supersedes the sentence restricting v0.3 work to macOS, yet line 112 says macOS-only scope remains in force. Retain the platform restriction explicitly while removing only the five-harness obligation. Command: `sed -n '242,246p' .docs/ADR/0032-*; rg -n 'All v0.3.0|macOS Apple-silicon-only' .docs/ADR/0033-*`.

## Required changes

1. Name and reconcile the remaining v0.3 pair-rule sentence and preserve the macOS platform restriction explicitly.
2. Correct the context to describe the stale Herdr entries accurately.

## Mechanical checks

- Supersession references: `rg -n 'supersedes|^### [167]\.|Counts:|All v0.3.0|Default evaluator|Restoring it|v0.4.0' .docs/ADR/0033-* .docs/ADR/0032-* .docs/ADR/0024-*` confirms the named sections and quoted clauses exist; the platform clause is overbroad as noted above.
- Nothing silently superseded: `sed -n '85,110p' .docs/ADR/0032-*` exposes the unresolved pair-rule sentence above.
- Accepted bodies and evidence: `git diff --name-status 4e83c03^ 4e83c03` and `git diff 4e83c03^ 4e83c03 -- .docs/ADR` show only the new ADR and register change, with no evidence deletions or accepted body edits.
- Owner decisions: `git show 4e83c03 -- .docs/ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md` compared with D1–D4 shows admission mechanics and ordering implement those decisions; no separate unrelated owner decision identified.
- Context: `cat .docs/evaluations/macos-dual-client-dogfood-evidence.json` verifies blocked candidate and launch results; `wc -l scripts/macos-dual-client-dogfood scripts/tests/macos-dual-client-dogfood.bats` gives 2620 lines, consistent with approximately 2700. The Herdr claim fails as above. Exhaustive uniqueness of live records and all code dependencies was not established.
- Status/register: `rg -n '0033|Status: Plan Review' .docs/ADR/README.md .docs/ADR/0033-*` confirms Plan Review and the In Review entry.

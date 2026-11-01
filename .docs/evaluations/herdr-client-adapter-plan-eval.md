# Plan evaluation — herdr-client-adapter

Artifact: .docs/slice-plans/herdr-client-adapter.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: f298478
Round: 1
Verdict: PASS

## Summary

The revision (diff 68ff25a..f298478) resolves every Round 1 blocking finding. ADR 0029 is now `Accepted` (acceptance record present) and the research note is `Approved` (its evaluation is PASS). Steps 2, 3, 5 and 6 now carry exact values: the descriptor `schema` and `id`, the profile JSON, the launch payload, and the validator functions and tables to edit. The negative check is fail-closed. Existing client tests are covered. No scope expansion beyond the Round 1 items was introduced. The plan is approvable. Per the counting rule this PASS resolves the Round 1 FAIL, so Round stays 1.

## Findings

Round 1 finding disposition:

1. [MAJOR] Authority not accepted. **Resolved.** ADR 0029 has `Status: Accepted`, backed by an acceptance record. The research note has `Status: Approved`, and its eval verdict is PASS. The plan cites both with their status.
2. [MAJOR] Residual placeholders. **Resolved.**
   - Step 2 uses `schema: loom-installed-root-binding-v1` and `id: herdr-plugin-root/v1`, as the Round 1 finding asked.
   - Step 3 gives literal profile mappings for Economy, Standard and Deep review.
   - Step 5 enumerates the full launch payload and states that the launcher only emits the descriptor and does not spawn Herdr. That settles the headless-versus-live question for this slice.
   - Step 6 names `validateSchemas()` / `schemaBindings` and `checkMatrixRootBindings()` with exact entries. The developer must still confirm these names against the real script, which was outside this review's read scope.
3. [MINOR] Citation strength for the manifest shape. **Accepted, no change required.** The weakness is in the research note, which was evaluated and approved. The plan's Notes ground the values in that note. Not re-litigated, per the non-expansion rule.
4. [MINOR] Vacuous negative assertion. **Resolved.** It is now `! HERDR_PLUGIN_ROOT=... loom-resolve-helper herdr loom-doctor`, which fails if the helper wrongly succeeds.
5. [MINOR] Existing-client regression coverage. **Resolved.** Step 7 adds an assertion that existing Claude, Codex and Antigravity tests pass. The targeted Bats run covers both whole files, so existing cases run unchanged.

Non-blocking notes for the developer (not findings):

- Confirm the `jq` paths (`.clientFloors`, `.rootBindings`, `.profiles[]`) and the `validate-repository.mjs` function names against the real files. Stop and report back if they differ.
- Step 5's payload uses the placeholder `<profile>`. This is a template for the computed value, and the Verification checks pin the three concrete profiles.

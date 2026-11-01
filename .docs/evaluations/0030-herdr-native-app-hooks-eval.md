# Evaluation: ADR 0030 Herdr native app hooks and spec amendment (spec 08 + spec 10)

Artifact: .docs/ADR/0030-herdr-native-app-hooks.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: 229a10b
Round: 0
Verdict: PASS

## Summary

Round 0 FAIL finding 1 (stale gate text) is resolved. Commit 229a10b changes `08-playbook.md:221` from "both clients" to "all three clients and both supported events", so the conformance-gate bullet now agrees with the fixture contract at lines 154-160. The diff `981b201..229a10b` touches only spec 08 and spec 10. All four requested amendments match ADR 0030 with no drift and no unwarranted scope expansion.

- **Spec 08 adapter table:** Herdr `PreToolUse` and `PreCompact` rows are present. Allow is exit 0 with empty streams. Block is exit 2, empty stdout, stderr `<reason>\n`. This matches ADR 0030 §4.
- **Spec 08 fixtures:** the text lists clients `claude`, `codex`, `herdr` and says "18 cases and 72 files across three clients". The arithmetic is 3 clients × 2 events × 3 cases = 18, times 4 files = 72. Line 221 now reflects all three clients.
- **Spec 10:** the new "Herdr hooks" bullet declares root-relative `hooks/hooks.json`. Hook commands may use the hook-process `HERDR_PLUGIN_ROOT`. This matches ADR 0030 §1-2. The "one physical bin / no copied helpers" invariant is untouched.
- **Authority:** both specs now cite ADR 0030 with a correct relative link.

## Findings

1. **[RESOLVED] Stale conformance-gate list (Round 0 MAJOR).** `08-playbook.md:221` now reads "for all three clients and both supported events". No stale "both clients" wording remains in the amended fixture or gate text.
2. **[MINOR, carried, non-blocking] Unsourced Herdr `trigger` claim.** `08-playbook.md:124` says "All three clients' current `PreCompact` adapters read `trigger`". ADR 0030 does not state Herdr's `PreCompact` input field. The wire is provisional (ADR §5) and live verification is owned by M9 slice 3, so the ADR or research note should record the input contract when verified.
3. **[MINOR, carried, non-blocking] Malformed-case mapping is implicit.** The Herdr rows say only "Policy blocks". ADR §4 maps block and malformed input to exit 2. This follows the existing Claude row convention.
4. **[MINOR, carried, non-blocking] Provisional status not carried into the specs.** It is traceable through the Authority link to ADR 0030 §5.

No new findings. The minors do not block approval.

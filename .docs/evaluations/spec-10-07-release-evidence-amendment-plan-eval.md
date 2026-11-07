# Plan Evaluation: spec-10-07-release-evidence-amendment

Artifact: [spec-10-07-release-evidence-amendment](../slice-plans/spec-10-07-release-evidence-amendment.md)
Commit: dd0a795
Round: 2
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [ADR 0005](../ADR/0005-specs-frozen-after-approval.md), [spec 10](../spec/10-packaging.md), [spec 07](../spec/07-command-surface.md), and [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

F2 is resolved: the revised support rule includes the applicable release row and accepted per-harness admission ADRs. F3 remains open: the newly added archive and invariant checks do not establish the stated conditions. D-a through D-e are reasonable subject to F3.

## Findings

- [MAJOR] **F3 — Verification remains incomplete.** The revised archive-entry regex accepts `logs/file.txt` and `logs/nested/`, although the archive contract permits only `logs/<name>.log` files. Conversely, `find "$D/logs" ! -type f` always reports the `logs` directory itself, and also reports legitimate intermediate directories, so a valid archive cannot pass silently. The retirement check covers only two name patterns, not the checklist's broader dogfood-status and retired-tooling assertion; the host check succeeds if a host is labelled deferred once across either spec, even if another applicable occurrence is unlabelled. Make archive verification enforce the stated file names and entry types while allowing necessary directories, and make the mechanical checks cover the actual retirement and per-spec deferral assertions. The correction naming and separation of git checks remain resolved.

## Prior Rounds Summary

Round 0 (29d74d3) failed on missing evidence details, support/deferral contradictions, and incomplete verification. Round 1 (999f03a) resolved F1 and parts of F2 and F3 but failed on the remaining admission rule and verification gaps. This revision resolves F2; F3 remains open as described above.

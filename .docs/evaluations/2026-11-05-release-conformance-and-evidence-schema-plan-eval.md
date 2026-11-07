# Plan Evaluation: release-conformance-and-evidence-schema

Artifact: [release-conformance-and-evidence-schema](../slice-plans/archive/release-conformance-and-evidence-schema.md)
Commit: 981b784
Round: 0
Verdict: FAIL
Reviewed against: [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md), [ADR 0033](../ADR/0033-narrow-v0.3-scope-and-retire-macos-checkpoint-tooling.md), [spec 10](../spec/10-packaging.md), [spec 07](../spec/07-command-surface.md), and [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md).

## Summary

The plan identifies the release evidence and documentation gaps, but its implementation scope directly edits frozen specs, and the proposed record can validate without evidence for both required pairs or the release's actual matrix. D-a needs the restrictions in findings 2 and 3; D-b's passing-only published record is consistent with the release gate. D-c's sanitized external logs with hashes are a reasonable storage choice, but their location and retrieval need a concrete contract. D-d cannot drop the retained Bash 5.x test obligation: ADR 0019 §1 requires tests on Bash 3.2 and current Bash 5.x, and ADR 0032 §4 does not supersede it. A separate local Bash 5.x run may satisfy that obligation if the release gate explicitly requires and records it. D-e is a reasonable proposed upgrade definition, provided the prior candidate is identified and the install and upgrade are exercised for each client.

## Findings

1. **[BLOCKER] Frozen specs are edited by the implementation slice.** Steps 3–4 direct a developer to change specs 10 and 07. The rubric's severity rules explicitly classify any spec edit from a slice as a blocker, and the spec index requires spec changes through planner and cold plan evaluation. Prepare and evaluate the spec amendments as planning artifacts first, then target the approved specs from an implementation slice.

2. **[BLOCKER] The schema can accept two copies of one required pair.** Step 1 only requires two items with enumerated harnesses; it does not require one of each or bind `client` to `harness`. Thus two Claude entries, or a Codex harness paired with the Claude client, can satisfy the stated rules while E4 for a required pair is absent. Require exactly one entry per required harness and bind each harness to its matching client, floor, binding and matrix entry; add negative tests for duplicate and mismatched pairs.

3. **[BLOCKER] Release and matrix are not bound to v0.2.0.** D-a says this schema is scoped to the v0.2.0 row, but step 1 admits any semver release and matrix path, and step 2 checks neither matrix path against release nor per-pair E1 matrix against it. A purported v0.2.0 record could name a different release matrix, or a later release could validate against the two-pair v0.2.0 rules. Constrain the initial schema and validator to v0.2.0 and its matrix, including E1 references, and test wrong-release and mismatched-matrix records; expand under a later reviewed amendment.

4. **[MAJOR] Bash 5.x evidence is not required by verification.** D-d makes Bash 5.x local evidence only, but the plan's release-gate and verification steps require only Bash 3.2.57. ADR 0019 §1's tests on current Bash 5.x remain in force under ADR 0032 §4. Require a documented Bash 5.x test run and evidence, whether on the existing runner or locally, in addition to the floor run.

5. **[MAJOR] External evidence references cannot be reliably retrieved.** D-c specifies relative log strings and hashes while excluding committed journals, but provides no external store, base, or retrieval convention. A relative path alone does not identify where a reviewer can obtain the sanitized logs, so the per-run references and owner evidence set cannot be checked consistently. Define a stable retrievable external location or base and the canonical evidence-set hash input, and document verification without including secrets.

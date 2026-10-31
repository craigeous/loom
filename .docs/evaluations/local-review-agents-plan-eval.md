# Evaluation: local-review-agents (slice-plan)

Verdict: FAIL
Round: 0
Reviewed against: ADR 0021 §§1–5; ADR 0022 §2; repository-improvement-plan.md M4 `local-review-agents` (lines 560–630); archived `local-review-helper` plan; `loom-local-review-findings-v1.schema.json`; plan-eval-rubric.md; severity.md; evaluation template. Spot-checked the live tree (`plugins/loom/bin/loom-review`, `loom-review.bats`) to verify path and flag claims.

## Findings

- [MAJOR] Override semantics for pinned prompt hashes are contradictory — Step 4 says `prepare` "preserves explicit supported overrides" and also rejects "a mismatch with pinned prompt bytes." It never says what an explicit `--prompt-hash` that differs from the pinned asset hash does. An independent reader could (a) accept it, which lets an unpinned prompt into a run and violates ADR 0021 §5 (a release pins prompt versions/hashes), or (b) reject it, which breaks existing `loom-review.bats` cases. Those cases currently pass arbitrary 64-hex hashes (`loom-review:889` only checks the shape), and the plan never says to migrate them. This is ambiguity on the central pinning invariant.
- [MINOR] Wrong test path in Verification — the plan names `bats tests/loom-review.bats`, but the suite is `plugins/loom/bin/loom-review.bats` and no `tests/` directory exists. The "adjust only if the existing suite path differs" hedge covers it, but the plan should name the real path (Step 5 and Verification).
- [MINOR] Asset location and packaging are under-specified — Step 4 does not say how `loom-review` finds `plugins/loom/finders/` at runtime. The helpers resolve from the physical plugin root, and the same question applies to the path a client hands the worker. Step 5 says only "ensure installation/packaging includes all prompt assets." Name the lookup (script-relative physical root) and the packaging check (`scripts/validate-repository.mjs` or a Bats assertion).
- [MINOR] Prompt boundary clauses are not mechanically checked — Step 2's strict boundary (no edits, no verdict or lifecycle change, no delegation, untrusted-data handling, exact manifest output path) is only prose in the prompts. Fixture runners cannot prove a prompt says it. Add an `rg`-based Bats assertion that each of the three prompts contains the required clauses and its own finder ID. This follows the rubric's "invariants verified mechanically" rule.
- [MINOR] Header says `Target specs: ADR 0021 §§2–5, ADR 0022 §2`, but the work touches spec-governed packaging and playbook surfaces (specs 08 and 10). Cite the governing specs, or state that none is amended.

## Required changes (for FAIL)

1. In Step 4, state the override rule. Recommended: `--prompt-hash` for a standard finder is accepted only if it equals the pinned SHA-256 of the shipped asset, and otherwise fails with exit 2. An omitted value defaults to the pinned hash. `--finder-profile` may be overridden freely, subject to the existing `<adapter>:<profile>` shape check. Add that existing Bats cases using arbitrary hashes are migrated to the pinned or defaulted values, with one negative test for a mismatched explicit hash.

Optionally fold in the MINORs above while revising. They do not block.

## Notes

Adherence checks that passed:

- **ADR 0021 §4:** exactly three auxiliary workers, `review-correctness/v1`, `review-tests/v1` and `review-security/v1`. All three are required, with no cost-driven omission, which correctly overrides the improvement plan's "start with correctness and security" hint. Workers are cold and non-delegating, and are explicitly not a sixth lifecycle role. They are read-only on inputs and source, with a single manifest-assigned output path. The evaluator alone decides PASS/FAIL, and the helper never launches workers.
- **ADR 0021 §5:** immutable versioned assets. A behavioral change needs a new major, formatting changes alter the SHA-256, and a released version is never overwritten. Detection-rate measurement is kept out of deterministic CI.
- **Schema conformance:** IDs `COR-/TST-/SEC-N` match `^[A-Z]{2,5}-[0-9]+$`. The severity enum, confidence 0–1, `line_end` requires `line`, the `finder.{id,prompt_version,prompt_sha256}` object and the provenance fields all match the schema. `ran-clean` and `ran-with-findings` follow the `if/then` constraints, and `failed` is available for failures.
- **Verification:** fixtures cover clean, malformed, missing, failed, truncated, out-of-diff, hash-drift and mutation cases. Results run through `validate` and `assemble` for mixed and all-clean runs, and partial runs must not assemble. The gate and repository validation are named.
- **Canonical structure:** 97 lines, within the 250-line budget. It has a `Target size:` line, an Out of Scope & Threat-Model Boundary section that respects the non-goals, and a Revision Log. It is single-purpose.

## Prior Rounds Summary

| Round | Phase | Verdict | Key Findings & Resolution |
|---|---|---|---|
| 0 | plan | FAIL | First review. One MAJOR (prompt-hash override semantics) plus four MINORs. |

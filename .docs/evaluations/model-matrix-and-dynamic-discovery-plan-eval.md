# Evaluation: model-matrix-and-dynamic-discovery (slice-plan)

Artifact: `.docs/slice-plans/model-matrix-and-dynamic-discovery.md`
Authority: accepted ADR 0027, `.docs/spec/08-playbook.md`, `.docs/spec/10-packaging.md`, `plan-eval-rubric.md`, `severity.md`
Round: 2
Verdict: PASS

Scope: Round 2 re-review (diff `ee66a0b..78a86ed`). Per the non-expansion rule, this checks
only whether the Round 1 findings were resolved. It adds no new finding categories.

## Round 1 finding status

1. **[BLOCKER] Spec 10 matrix contradiction: RESOLVED** (unchanged from Round 1). The plan adds
   `v0.3.0.json` under accepted ADR 0027 and leaves `v0.2.0` alone. The revision also states that
   v0.3.0 preserves the v0.2.0 root bindings and profiles, and the schema pattern now admits both
   `0.2.0` and `0.3.0`.
2. **[BLOCKER] Codex `config.toml` inheritance: RESOLVED** (unchanged). The plan follows ADR 0027
   §2 tier 3 and now fails closed on a malformed or unsupported ambient model.
3. **[MAJOR] Antigravity schema ambiguity: RESOLVED.** The `antigravity` variant now lists
   `enableSubagentTools` and `enableWriteTools` and is stated to match the emitted launcher fields.
   `model` is a plain string, so the emitted `flash`/`inherit`/`pro` values validate.
4. **[MAJOR] Executability gaps: RESOLVED, with one residual advisory.** The plan now specifies:
   - per-client `--model` validation (`claude`: `haiku|sonnet|opus`; `codex`: schema pattern;
     `antigravity`: non-empty), each failing closed with `exit 2`;
   - `agy` absent or failing: fall back to the profile defaults (`pro`, `inherit`, `flash`);
   - cache path, mode `0600`, 86400s TTL and atomic write.
   - Advisory, not a blocker: a requested model that is absent from `agy models`, and the
     ADR-context `gemini-4-argon` fallback chain, are still not mapped to an explicit step.
     The developer should resolve this against ADR 0027 §4.
5. **[MAJOR] Fail-closed behavior untested: RESOLVED.** Step 4 now has negative tests for invalid
   `--effort`, invalid Codex `--model`, unsupported ambient Codex model, a missing or corrupted
   cache with `agy` absent, and cross-family evaluation. This matches the Revision Log.
   - Advisory: `agy` present but failing is not covered separately from `agy` absent.
6. **[MINOR] Size budget:** unchanged, no action required.
7. **[MINOR] Verification hygiene: RESOLVED.** The machine-specific `LOOM_TEST_BASH` is removed.

## Structure checks (pass)

`Target size:`, `## Out of Scope & Threat-Model Boundary`, `## Steps`, `## Verification` and
`## Revision Log` are present. The Revision Log has a Round 2 row. The plan stays under 250 lines.
No goalpost shifts were found in the revision.

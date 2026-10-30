# Evaluation: model-matrix-and-dynamic-discovery (slice-plan)

Artifact: `.docs/slice-plans/model-matrix-and-dynamic-discovery.md`
Authority: accepted ADR 0027, `.docs/spec/08-playbook.md`, `.docs/spec/10-packaging.md`, `plan-eval-rubric.md`, `severity.md`
Round: 1
Verdict: FAIL

Scope: Round 1 re-review (diff `4758044..ee66a0b`). Per the non-expansion rule, this checks
only whether the Round 0 findings were resolved. It adds no new finding categories.

## Round 0 finding status

1. **[BLOCKER] Spec 10 matrix contradiction: RESOLVED.** The plan now cites accepted ADR 0027
   (Round 1 plan-eval PASS) as authority. It creates a new `v0.3.0.json` and leaves the
   `v0.2.0` map alone. It edits no spec. ADR 0027 §5 schedules the spec 10 and 02 amendment
   as a separate planner item.
   - Advisory, not a blocker: the plan should state that it lands after, or alongside, that
     amendment. Spec 10 still reads `gpt-5.6` plus "inheriting … is nonconforming" until then.
2. **[BLOCKER] Codex `config.toml` inheritance: RESOLVED.** ADR 0027 §2 tier 3 now authorizes
   it, and the plan follows the ADR's four-tier precedence.
3. **[MAJOR] Antigravity authority and schema ambiguity: PARTIALLY RESOLVED.**
   - Authority is now ADR 0027 §4.
   - Still open: the launcher emits `"model":"flash|inherit|pro"` plus `enableSubagentTools`
     and `enableWriteTools` (`loom-launch-role:228-234`). The plan's schema variant lists only
     `model`, `subagentName`, `rolePromptPath` and `rolePromptSha256`. It does not say that
     the emitted `flash`/`inherit`/`pro` values are replaced, or how the two extra fields are
     validated. A schema with `additionalProperties:false` would reject the current output.
4. **[MAJOR] Executability gaps: STILL OPEN.** The plan does not say:
   - what `--model` means for `claude`/`auto`, or how it is validated (fail closed outside
     the schema pattern);
   - what happens when `agy models` fails or is absent, or when the cache is unparsable;
   - the cache file format and permissions;
   - what happens when the requested model is absent from `agy models`. The `gemini-4-argon`
     fallback chain from ADR context is not mapped to any step.
5. **[MAJOR] Spec-required fail-closed behavior untested: STILL OPEN.** Step 4 adds one new
   negative test, for an invalid `--effort`. There is still no test for an invalid or
   unsupported `--model`, a stale or missing cache, or `agy` absent or failing. Spec 10
   requires an unavailable or renamed selector to fail launch. The Revision Log claims
   "adds fail-closed negative test cases", which overstates what the plan contains.
6. **[MINOR] Size budget: unchanged.** `<= 180 LOC` is still unproven. No action required.
7. **[MINOR] Verification hygiene: PARTIALLY RESOLVED.**
   - The absolute repo root is gone.
   - `LOOM_TEST_BASH=/opt/homebrew/bin/bash` remains machine-specific.
   - There are still no `rg`/`jq` checks for the text invariants.

## Required to pass (smallest fixes)

- Add fail-closed Bats tests for an invalid `--model`, an expired or missing cache with `agy`
  absent or failing, and an unsupported ambient Codex model.
- Specify `--model` validation and `claude` semantics, and the `agy` failure and cache-corruption
  behavior, in one or two sentences each.
- Reconcile the Antigravity schema variant with the emitted fields and values.

## Structure checks (pass)

`Target size:`, `## Out of Scope & Threat-Model Boundary`, `## Steps`, `## Verification` and
`## Revision Log` are present. The plan is 91 lines, under 250.

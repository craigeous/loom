# Evaluation: model-matrix-and-dynamic-discovery (slice-plan)

Artifact: `.docs/slice-plans/model-matrix-and-dynamic-discovery.md`
Authority: `.docs/spec/08-playbook.md`, `.docs/spec/10-packaging.md`, `plan-eval-rubric.md`, `severity.md`
Round: 0
Verdict: FAIL

## Findings

1. **[BLOCKER] Plan contradicts spec 10 §Versioned compatibility and capability mapping.**
   Spec 10 fixes the v0.2.0 map exactly (Codex `gpt-5.6-terra`/`gpt-5.6`/`gpt-5.6`) and
   says a change to any table value "requires a reviewed matrix change". The plan changes
   the matrix to `gpt-6.1-*` and lists spec 10 as a target, but has no step amending spec
   10, and a slice may not edit specs (severity.md BLOCKER: "any edit to spec/ADR from a
   slice"). As written, landing leaves matrix and spec 10 contradicting each other.
   Smallest fix: route the spec 10 table change through the planner and cold plan eval
   first, then cite it as authority, or drop the matrix change.

2. **[BLOCKER] `~/.codex/config.toml` model resolution violates spec 10.**
   Step 3 reads the user's Codex config and uses its `model` as the base model when
   unpinned. Spec 10 says "inheriting a session model or effort is nonconforming" and
   that a "silently substituted selector fails launch". The plan neither amends the spec
   nor bounds this behavior. Smallest fix: remove it, and use `--model` as the only
   override.

3. **[MAJOR] Antigravity is outside the specs' authority, and the step is ambiguous.**
   Specs 08 and 10 define Claude and Codex surfaces only. The tree has an `antigravity`
   launcher branch (`_launch_antigravity`, `loom-launch-role:219`) but no schema variant.
   The plan does not say how the new schema variant relates to the existing emitted
   `flash`/`inherit`/`pro` model values. It also does not say whether the matrix, the
   spec, or the schema is authoritative for the `claude-opus-5-5-*` and `gemini-*`
   defaults. An independent implementer could implement this wrongly.

4. **[MAJOR] Executability gaps in `--model`, `--effort` and the cache.**
   - Semantics for `--model` on `claude`/`auto` clients are unspecified.
   - Model validation is unspecified: a `--model` outside the schema pattern should fail
     closed.
   - The stale or unparsable cache path and the `agy` failure/absent behavior are
     undefined. The fallback chain (`gemini-4-argon-*`) is stated but not tied to
     "model absent from `agy models`".
   - `--effort` interaction with Antigravity is undefined: the model IDs embed effort
     suffixes.
   - Cache file format, the write method (atomic), and the permissions are unspecified.

5. **[MAJOR] Spec-required behavior is not tested.**
   Spec 10 requires an unavailable or renamed selector to fail launch. The test list
   covers only the happy paths plus "preserving existing" tests. It has no test for an
   invalid or unsupported `--model`, an expired or missing cache, or `agy` absent.
   Smallest fix: add one fail-closed test per case.

6. **[MINOR] Size budget.** The `Target size` of <= 180 LOC looks light for schema,
   matrix, launcher, cache and tests, but is not provably wrong.

7. **[MINOR] Verification hygiene.**
   - It uses an absolute `/Users/craig/git/loom` root in the `validate-repository` command.
   - The `LOOM_TEST_BASH=/opt/homebrew/bin/bash` path is machine-specific.
   - The text invariants (for example "no other `gpt-5.6` references") are not backed by
     a stated `rg`/`jq` check.

## Structure checks (pass)

`Target size:`, `## Out of Scope & Threat-Model Boundary`, `## Steps`, `## Verification`
and `## Revision Log` are present, and the plan is under 250 lines.

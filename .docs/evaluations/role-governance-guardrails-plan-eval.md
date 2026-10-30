# Plan Evaluation: role-governance-guardrails

Artifact: `.docs/slice-plans/role-governance-guardrails.md`
Verdict: FAIL
Round: 0

Authority: specs 02, 04, 05, 08 (`08-playbook.md`; the plan's "08-client-adapters.md" does not exist), 10, `plan-eval-rubric.md`, `severity.md`.

## Findings

1. **[BLOCKER] `LOOM_ROLE` has no producer, so the guard defaults wrongly.** `rg LOOM_ROLE plugins scripts .docs/spec` returns nothing. No step makes `loom-launch-role` or the Claude/Codex adapters export it, and Claude native subagents inherit no such env. The plan treats an unset role as `orchestrator`. Every developer, evaluator and researcher launch would therefore be blocked from running `scripts/check` or `bats`. The evaluator guard would never fire. Fix: add a step that sets `LOOM_ROLE` at launch, or invert the default so that unset means no enforcement and only a positively marked orchestrator is guarded.
2. **[BLOCKER] The orchestrator guard contradicts spec 04 and 05.** Spec 04 (about lines 191-201) has the root run the developer gate and re-verify after each gate. Spec 05 ("Unconditional gate rerun") has the root drive bounded gate runners. Blocking `scripts/check` and `bats` for the root, with "delegate to orca worker-start" as the remedy, forbids behavior the specs mandate. Orca is also not a loom concept. Fix: scope the block to unbounded, unrecorded runs, or name the spec-sanctioned bounded runner as an exception.
3. **[BLOCKER] Spec-governed surfaces are changed with no fixtures, matrix or schema updates.**
   - `v0.2.0.json` and `loom-compatibility-matrix-v1.schema.json` pin the codex model enum to `gpt-5.6*`. Spec 10 requires exact model/reasoning selection per profile, checked against the effective child launch configuration. The plan replaces this with dynamic discovery, config.toml inspection and cached `agy models`. It never lists the matrix, schema or `loom-role-launch-v1` changes.
   - A new hook breaks the "12-case hook-wire-v1" fixture product (spec 08 about line 148, spec 10 hook fixtures). The plan adds no fixtures.
   - `loom-bounded-return/v1` has no consumer or validator step in the orchestrator, though spec 04 owns the bounded-return contract.
   - The plan says it will not rewrite frozen specs, yet its target specs 02/04/05/08/10 need amendment for any of this. Specs change only through planner and cold plan evaluation, so the amendments must be named.
4. **[MAJOR] Not single-purpose, and the size budget is unrealistic.** The slice bundles the hook, model discovery and caching, and a schema. A ≤240 LOC budget cannot cover the bats suites, caching, TTL and two clients. Split into a hook slice and a model-resolution slice.
5. **[MAJOR] Ambiguity an independent reader could implement wrongly.**
   - Command matching is unspecified: whole-command versus substring, compound commands (`cd x && bats`), and `git commit` being allowed for the orchestrator.
   - The Codex wire shape (`continue:false`) is not checked against the existing hook-wire fixtures. `git-identity-guard.sh` uses `permissionDecision` deny plus exit 2.
   - The hook registration (step 2) is a separate `hooks.json` entry. It is unclear whether the root-validation and adapter code is shared or copied.
   - Model IDs (`gpt-6.1-*`, `gemini-3.8-flash-low`, `gemini-4-argon-*`) are unverified, and the Deep-review "or" fallback is undefined.
   - The precedence of `--model`, `.docs/loom-models.json` and `config.toml` is undefined. `.docs/loom-models.json` has no schema or spec home.
6. **[MINOR]** `Status: Plan Review` is fine. Invariants such as "no mutation by evaluators" are stated with no mechanical check (`rg`/`jq`). Step 4 sets reason max "300 characters / <=150 tokens" without saying which is enforced.

## Notes
- Required sections (Target size, Out of Scope & Threat-Model Boundary, Revision Log) are present, and the document is under 250 lines.
- The threat-model boundary is acceptable; no findings were raised for hostile bypass.

## Verdict
FAIL (3 BLOCKERs, 2 MAJORs unaddressed).

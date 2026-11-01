# Workflow profiles

Status: Plan Review
Target specs: 00-overview.md, 04-orchestrator.md
Target size: <= 250 LOC net script/code change; tests and docs separate (plan <= 250 lines)

## Context

M8 slice 2 introduces an owner-selected profile and a recommendation to make the
intended depth of a run visible. The improvement plan proposes Light (Developer →
gate → code evaluator), Standard (Plan → developer → local reviewers → evaluator),
and Strict (Research → plan review → developer → all reviewers → evaluator → owner
gates). The owner chooses; recommendations never choose on the owner's behalf.

The approved specs currently require an approved plan, all three local finders for
code-bearing slices, independent evaluation, and the applicable gates and landing
protocol. Consequently these flows describe intended emphasis, not permission to skip
mandatory stages. In particular, Light cannot execute its reduced flow under current
authority. An approved spec amendment through the planner and cold plan evaluation is
a prerequisite to any future relaxation; this slice does not make that amendment. The configuration records an owner choice,
not a frozen policy prescribing reduced workflows before benchmark evidence exists.

## Out of Scope & Threat-Model Boundary

No spec amendment, change to mandatory lifecycle, finder set, evaluator isolation,
gate, owner-claimed approvals, or remote landing protocol. No automatic profile
selection, cost accounting, historical benchmark, or new client-specific policy.
The private-directory and trusted-local-process boundary in spec 00 Non-goals applies;
this slice does not defend against hostile local inode swapping or helper tampering.
Stop and escalate to the orchestrator if any required behavior needs a spec change
or cannot be implemented within these boundaries; do not improvise a protocol.

## Files to touch

- `plugins/loom/bin/loom-profile` — shared profile resolution and recommendation.
- `plugins/loom/skills/loom-playbook/references/orchestration.md` — root workflow.
- `plugins/loom/skills/loom-run/SKILL.md` — owner-facing invocation guidance.
- `scripts/tests/loom-profile.bats` — behavior and integration contract tests.

## Steps

1. Add the portable Bash 3.2 helper `plugins/loom/bin/loom-profile`. Its interface is
   `loom-profile resolve REPO [--profile light|standard|strict] [--risk low|normal|high]`.
   It reads optional `REPO/.loom/profile.json`, exactly a JSON object with one required
   string property `profile` whose value is `light`, `standard`, or `strict`; reject
   unknown keys, invalid JSON, wrong types, non-regular files, and symlinks. For a
   present file require `[ -f "$file" ] && [ ! -L "$file" ]`. Use standard jq
   1.6+ object validation; duplicate keys follow jq last-key-wins behavior. Missing
   file is allowed. Exit 0 on success, 1 on invalid configuration or other error,
   and 2 on usage errors; diagnose failures on stderr. Do not silently fall back.
   A CLI profile overrides a valid file; absent both, select `standard`. Validate a
   present file even when the CLI overrides it. No environment-variable override.
2. Emit one JSON object on stdout: `{"selected":"...","source":"cli|file|default",
   "recommended":"...","reason":"..."}`. `--risk low` recommends light, `normal`
   recommends standard, `high` recommends strict; omitted risk recommends standard
   with reason `risk unspecified`. Reasons for supplied risk are respectively
   `low risk`, `normal risk`, and `high risk`. A recommendation never changes the
   selected value. Reject duplicate flags, missing values, and unrecognized values;
   repeated calls with the same inputs produce identical output. The owner supplies
   risk; do not infer security or architecture from filenames.
3. In `orchestration.md` and `loom-run/SKILL.md`, document the helper invocation at
   start and resume, CLI-over-file-over-default precedence, the recommendation and
   the three intended flows. Show selected profile, source, recommendation and reason
   to the owner before dispatch; invalid configuration stops dispatch. The owner may
   explicitly choose a different profile. Record `profile` (selected value) and `risk` (low, normal, high, or null) in
   orchestrator run metadata/session state at `.git/loom/session-<id>/checkpoint`
   or `.git/loom/run.json`, or pass them via orchestrator options. Resume reads the
   recorded values without inventing protocol transforms; a changed selection requires
   explicit owner instruction and re-resolution before further dispatch. Preserve all existing
   spec-required stages and claimed owner gates regardless of profile. Strict adds advisory human pauses before developer dispatch and publication, not
   new spec gates or implied owner approval. Make the helper executable (`chmod +x`)
   and invoke it by its resolved absolute installed path, matching existing helpers;
   verify packaging, resolution and inventories against the tree and update any
   required metadata/fixtures. Adapters pass arguments without their own policy.
4. Add Bats tests for all three profiles and risks, default and precedence, valid
   override, malformed/unknown properties and jq duplicate-key behavior, wrong types, invalid and duplicate
   flags, missing file, non-regular file, deterministic output, and unchanged selection
   when recommendation differs. Use table-driven cases where practical. In each
   documentation file add heading `## Workflow Profiles` and require with `grep -Fq`
   the exact literals `Light`, `Standard`, `Strict`, `resume reads the recorded profile`,
   `invalid configuration stops dispatch`, `all required lifecycle stages remain mandatory`,
   and `advisory human pauses before developer dispatch and publication`; require the
   heading with `grep -Fxq '## Workflow Profiles'`. In that section reject matches of
   `(^|[^[:alpha:]])(skip|skips|skippable)[[:space:]]+(any |required )?(lifecycle |stage|gate|review|evaluation)`
   using `grep -Eiq`. Keep existing review and evaluation tests unchanged.

## Verification

- Fast iteration: `bats scripts/tests/loom-profile.bats`.
- Full gate: `scripts/check`.
- `node scripts/validate-repository.mjs --root . --all` checks repository integrity.
- The Bats suite runs those exact positive and negative documentation oracles against
  both files and checks resolution, failure cases, and documented routing obligations;
  the full gate retains existing local review, evaluator, and landing regression tests.

## Notes

This plan does not authorize a reduced Light or Standard lifecycle. If actual
profile-specific omission of required stages is desired, obtain an approved spec
amendment and revise this plan in place before implementation.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Clarified jq behavior, resume state, mechanical documentation oracles, packaging, limits, and stop rules. |

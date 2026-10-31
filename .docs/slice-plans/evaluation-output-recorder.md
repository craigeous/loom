# Evaluation Output Recorder

Status: In Progress
Target specs: 03-artifact-lifecycle.md, 04-orchestrator.md, 05-blind-evaluation.md; ADR 0022, ADR 0023
Target size: <= 350 LOC net change excluding tests and schemas (keep this plan <= 200 lines)

## Context

The sanitized workspace and gate runner prepare and verify controlled evaluation inputs
and reruns; evaluators still need a deterministic way to record their output without
checkout write access. This slice adds the schema and recorder, connects orchestration
to it, and specifies settlement of the recorder's bootstrap retirement. Invalid
output is infrastructure-blocked, not a merits FAIL and cannot advance a lifecycle.

## Out of Scope & Threat-Model Boundary

No evaluator launch isolation, exporter, gate command, remote publication mechanism,
or spec/ADR amendment is introduced here. Spec 00's non-goals exclude OS-level
hostile-code containment, cryptographic anonymity, remote attestation, and proof of
independent model reasoning. The private workspace and checkout are trusted against
hostile concurrent inode swaps or helper monkeypatching; nevertheless reject links,
path escapes, malformed outputs and unverified evidence at the recording boundary.
The ADR 0023 exception remains restricted to its eligible repository and state; no
production failure or stale checkpoint revives retired bootstrap components.

## Steps

1. **`plugins/loom/schemas/loom-eval-verdict-v1.schema.json`**: define strict Draft
   2020-12 `loom-eval-verdict/v1`, rejecting extra properties and requiring a single
   complete verdict: run ID, manifest SHA-256, evaluation type, artifact path,
   reviewed head (and base for code), PASS/FAIL, nonnegative round, authority
   bindings, severity-tagged findings, required changes for FAIL, residual notes,
   and for code the local-review adjudications and gate-rerun reference. Require
   nonempty required changes for FAIL, reject PASS with BLOCKER or MAJOR findings,
   and bind field types, hashes and relative paths.
   Preserve evaluator judgment verbatim; do not infer PASS from an empty findings list.
2. **`plugins/loom/bin/loom-eval-workspace`**: add `record <run-dir|run-id> [--repo
   <path>]`, usage and dispatch; require a usable managed checkout and run `do_verify`
   successfully before examining output. Require exactly one regular, non-symlink
   `output/verdict.json` and no other output entries; validate it with the existing Ajv
   `validate_json_schema` path. Compare every echoed run/type/manifest, artifact,
   revision and authority binding to the verified manifest; reject missing, duplicate,
   malformed, truncated, cross-run or mismatched data. Require exactly one manifest
   artifact for unambiguous destination and reject ambiguous multi-artifact runs.
   Derive the expected round from the manifest-bound prior verdict: 0 if absent;
   otherwise parse its round and verdict, adding 1 after FAIL and retaining the round
   after PASS. Reject an output verdict whose round differs from that expected round.
3. **Same helper**: refactor the existing `rerun_status` checks into a reusable,
   non-exiting validator retaining its status behavior. For code require a completed,
   schema-valid latest attempt bound to run, manifest and command, with matching log
   hashes and contiguous attempt sequence; reject blocked, interrupted, invalid or
   incomplete attempts. Bind the verdict reference to that attempt. A PASS requires
   `rerun-passed`; a FAIL may record a completed `rerun-failed` or `rerun-passed`.
   Prior developer gate evidence never substitutes for a rerun.
4. **Same helper**: derive the destination from the sole manifest artifact basename,
   stripping its final `.md`: slice-plan evaluations use
   `.docs/evaluations/<slice>-plan-eval.md`, code evaluations use
   `.docs/evaluations/<slice>-eval.md`, and research notes or ADRs use
   `.docs/evaluations/<artifact-basename>-eval.md`. Reject non-Markdown, unsafe
   components, traversal, links or special files in the destination and ancestors.
   Render identity-neutral Markdown with fixed layout: `# Evaluation: <title>`, a
   blank line, `Status: Evaluated`, `Round: <N>`, `Verdict: <PASS|FAIL>`, a blank
   line, `## Findings`, findings, then `## Gate rerun evidence` and evidence. Include
   the applicable bootstrap conformance/evidence-mode label; identify production
   evidence as production. Preserve validated judgment verbatim. Publish a private
   temporary file atomically in the destination directory. Identical existing bytes
   succeed idempotently; differing bytes may be replaced only if the manifest binds
   that exact prior verdict (`prior-verdict` input / `revision.prior_sha`), the new
   round matches the expected successor, and the existing file matches the bound
   prior verdict. All other differing existing bytes fail closed. Emit JSON containing
   status, run ID, verdict, report path and report SHA-256; diagnostics go to stderr.
5. **Same helper and orchestration guidance**: accept optional `--claimed-gate` when
   an owner-claimed gate is active. Read the current status from the checkout artifact;
   verify its blob matches the reviewed head/tree blob before editing its `Status:`
   line, and validate the applicable spec-03 legal transition and claimed gate. Map
   Plan/Research PASS to `Approved` (ADR PASS to `Accepted`), Plan FAIL to `Draft`,
   Code PASS to `Ready to Publish`, and Code FAIL to `In Progress`. Preserve the ADR
   0023 ratification exception by checking its repository and state eligibility before
   transition; an ineligible or held state blocks advancement. Apply the transition
   only for a valid recorded verdict. For interruption/retry, an existing matching
   report can complete a pending legal transition; conflicting report or state blocks
   without advancing. Specify transition and recovery ordering in guidance; the
   orchestrator commits report and status under the uniform identity, and the
   evaluator never commits or mutates the checkout. Recording failure consumes no
   round and causes no status advance.
6. **`plugins/loom/skills/loom-run/SKILL.md` and
   `plugins/loom/skills/loom-playbook/references/orchestration.md`**: instruct root to
   invoke `record`, inspect its JSON, commit the valid report and status, and retain
   recovery evidence.
   - Retire root-copy once its component is retired, without retroactively claiming
     production conformance for degraded bootstrap evidence.
   - During settlement of this slice, after fresh verification of its published result,
     freshly read the configured target and prove each recorded result SHA for
     `local-review-orchestration`, `sanitized-evaluation-workspace`, and this slice is an
     ancestor. Record the first such target as `full_sunset.sha`; the terminal successor
     retires all components and full sunset and empties `allowed_slices`. Unavailable or
     unverifiable target blocks settlement; never force-push or reopen bootstrap.
7. **`plugins/loom/bin/loom-eval-workspace.bats`**: exercise plan/research/code valid
   records, FAIL and PASS, schema errors, missing/duplicate/cross-run and hash mismatch,
   changed inputs, completed/failed/incomplete/blocked reruns and latest-attempt
   mismatch, traversal and symlink destinations, conflicting outputs, idempotent retry,
   legal transition and interrupted recovery. Assert no report or status advance on
   failure and preserve existing verify/status/gate-rerun regressions. Cover Round-1
   replacement, unbound or mismatched prior reports, round mismatches, plan-eval then
   code-eval, PASS severity rejection, checkout blob mismatch and claimed gates.

## Verification

Run `TMPDIR=/private/tmp bats plugins/loom/bin/loom-eval-workspace.bats` for targeted
iteration and `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` as the required
full gate. Run `node scripts/validate-repository.mjs --root "$PWD" --all` for
repository validation and `! rg -q 'copies the one valid verdict|root-copy'
plugins/loom/skills/loom-run/SKILL.md plugins/loom/skills/loom-playbook/references/orchestration.md`
to verify root-copy guidance retirement. The new Bats cases prove recording, binding,
confinement, rerun and retry behavior; existing workspace tests must pass unchanged
as regression proof. Review settlement guidance against ADR 0023 and specs 03/04/05,
including fresh target ancestry and terminal-state requirements. The 350 net LOC budget
remains the implementation target.

## Round 2 fix evidence

- Local review companion: `.docs/evaluations/evaluation-output-recorder-review-findings.md`
  (`loom-review` run over `41e9904..7113890`; three cold finders; aggregate
  `ran-with-findings`).
- Recorder: duplicate JSON keys rejected before schema/binding validation (exit 2);
  `--bootstrap-phase` non-`active` yields `state-held`; ADR 0023 PASS yields
  `ratification-held`; `--claimed-gate` yields `gate-held`. Bats cases added for each.
- Guidance: sunset settlement (`git merge-base --is-ancestor`, `full_sunset.sha`) added to
  `orchestration.md` and `loom-run/SKILL.md`.
- `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`: All checks passed (exit 0).
- `node scripts/validate-repository.mjs --root "$PWD" --all`: passed; the root-copy
  guidance retirement grep is clean.

## Notes

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Specify destinations, bound replacement and rounds, status transitions, report layout, severity consistency and verification. |

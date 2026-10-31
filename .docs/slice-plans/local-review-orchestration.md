# Local Review Orchestration

Status: Plan Review
Target specs: 02-roles.md, 04-orchestrator.md, 05-evaluation.md; ADR 0021, ADR 0022
Target size: <= 350 LOC net change (keep this plan document <= 250 lines)

## Context

The local review helper and versioned protocol exist, but operational instructions
still direct the orchestrator to external review commands and describe obsolete
per-command outcomes. This slice aligns those instructions with ADR 0021's exact
commit, three-finder protocol and ADR 0022's controlled-input independent evaluation.
The findings remain advisory; the code evaluator independently adjudicates every one.

## Out of Scope & Threat-Model Boundary

Do not change specs or ADRs, the helper, schemas, finder prompts, launch adapters,
evaluation exporter, or defect battery. Historical ADRs remain historical. This
slice does not claim OS-level network isolation, protection against a hostile host or
provider, cryptographic anonymity, or statistically independent models (ADR 0022).
The review procedure requires no network or remote state; omitting network tools is
not proof that shell egress is sandboxed.

## Steps

1. In `plugins/loom/skills/loom-run/SKILL.md` step d2 and
   `plugins/loom/skills/loom-playbook/references/orchestration.md` under
   “Automated review before a slice lands”, replace the legacy review procedure with
   the following operational contract. Resolve `loom-review` through the installed
   helper mechanism. For a code-bearing slice obtain explicit full existing base and
   head commit IDs, approved tracked plan and gate-evidence paths; do not infer a
   base from a remote, branch, PR, or `origin/HEAD`. Prepare with
   `loom-review prepare --slice <name> --base <base> --head <head> --plan <path> --gate-evidence <path>`.
   Use the returned run ID and manifest; launch three separate cold, non-delegating
   Loom-owned finders `review-correctness/v1`, `review-tests/v1`, and
   `review-security/v1`, each with its manifest-pinned prompt path and its distinct
   manifest-assigned `results/<finder>.json` output path (actual encoded filename is
   authoritative in the manifest). Supply only prepared inputs, read-only, and the
   assigned writable output; no network, provider, PR, or remote-branch tools. Finders
   have no lifecycle or verdict authority. Validate with `loom-review validate
   <run-dir|run-id>` and only on success assemble with `loom-review assemble
   <run-dir|run-id> --output .docs/evaluations/<slice>-review-findings.md`.
   Commit the identity-neutral companion as directed by the existing workflow, then
   clean with `loom-review clean <run-id>` when no longer needed. Preserve evidence
   needed for diagnosis before cleanup on failure.
2. In those same procedure sections specify that missing, failed, pending, duplicate,
   malformed, truncated, inconsistent, or otherwise invalid finder output invalidates
   the whole run. Never assemble partial findings, call an invalid run clean, pass it
   as valid evidence, or land the slice. Classify failure, retry only when safely
   retryable, pause and checkpoint infrastructure failures under ADR 0017, and return
   other failures for correction. A pure-documentation slice records the explicit
   `skipped: docs-only` aggregate without launching a run; unavailable review is not
   an eligible skip for code. No review step requires GitHub, PR metadata, remote
   branch state, an external slash command, or network access.
3. In `plugins/loom/skills/loom-playbook/references/review-findings.md`, replace
   obsolete command-transcription requirements, per-command status table, and
   examples with the helper-assembled `loom-local-review/v1` aggregate and
   provenance: exact base/head and diff hash, run/manifest and prompt hashes,
   required finder identities and results, and normalized finding fields including
   location, evidence, confidence, severity advice, and reproduction. The valid
   aggregate is `ran-clean` only when all required finders are valid and clean, or
   `ran-with-findings` when any valid finder reports findings. Document docs-only
   skip separately and invalid runs as non-assemblable, never as a completed review.
   Preserve identity neutrality without excluding the exact commit IDs required for
   provenance. Replace stale helper/procedure transition language and examples.
4. In `plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`, replace
   external-command references with the valid assembled local-review artifact and
   docs-only skip; require independent confirmation or rejection of every finding,
   reasons for false positives, and severity mapping by the evaluator. Refer to
   ADR 0022's controlled inputs and mandatory gate rerun; a missing or invalid
   required review is not valid evidence or permission to land. In
   `plugins/loom/skills/loom-playbook/SKILL.md`, update operational pointers and
   descriptions to the same protocol, removing obsolete command dependencies.
   Retain any separately authorized bootstrap procedure without treating it as an
   ordinary valid local-review run.

## Verification

- Run `scripts/check` and `node scripts/validate-repository.mjs --root "$PWD" --all`.
- Mechanically search the five changed operational files, including wrapped text,
  for `/code-review`, `/security-review`, `command-unavailable`, `origin/HEAD`, PR
  and GitHub dependencies; inspect each match in context and remove obsolete
  operational requirements. Historical or explicit prohibitions must not imply a
  dependency.
- Inspect the documented command signatures and manifest-assigned output paths
  against the helper contract. Verify the procedure covers three required finders,
  exact SHAs, no-remote operation, invalid and docs-only cases, assembly, cleanup,
  provenance, and independent adjudication. Existing helper tests run unchanged as
  part of the gate; this documentation-only slice adds no mirrored tests.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

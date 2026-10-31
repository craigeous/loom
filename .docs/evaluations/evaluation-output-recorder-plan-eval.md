# Evaluation — evaluation-output-recorder (slice-plan)

Status: Evaluated
Round: 0
Verdict: FAIL

Artifact: `.docs/slice-plans/evaluation-output-recorder.md` (Status: Plan Review)
Authority: ADR 0022; ADR 0023 §6 (lines 290–325); specs 00, 03, 04, 05;
`.docs/repository-improvement-plan.md` § Slice `evaluation-output-recorder`;
`plan-eval-rubric.md`. Facts about the current tree were checked against
`plugins/loom/bin/loom-eval-workspace` and
`plugins/loom/schemas/loom-eval-workspace-manifest-v1.schema.json`.

## Findings

### Blocker

1. **[BLOCKER] The destination path rule plus the no-overwrite rule blocks every
   re-review, and the plan's own path collides with the code evaluation.** Step 4
   derives one path, `.docs/evaluations/<artifact-name>-eval.md`, from the manifest
   artifact basename for every evaluation type and round. It then says "differing
   existing bytes fail closed. Never overwrite another verdict." A slice gets a
   plan evaluation, then re-reviews at Round ≥ 1 (spec 03 § Round limit), then a code
   evaluation of the same slice. All of these resolve to the same path with different
   bytes, so the recorder will refuse every Round-1 re-review and every code
   evaluation that follows a plan evaluation. The plan defines no in-place round
   replacement. The repository's current convention keeps
   `<slice>-plan-eval.md` and `<slice>-eval.md` apart, with Round N replacing Round
   N−1 in place (for example `evaluation-gate-runner-plan-eval.md` and
   `evaluation-gate-runner-eval.md`). The plan neither adopts that convention nor
   justifies leaving it. An independent developer cannot implement Step 4 and still
   satisfy Step 7's "idempotent retry" and "legal transition" cases across rounds.
   *Required change:* set the destination per evaluation type (plan/research versus
   code) to match spec 05 and the existing `.docs/evaluations/` naming, and state
   explicitly when an existing report may be replaced. One way: only when the
   manifest binds that exact prior verdict (`prior-verdict` input /
   `revision.prior_sha`) and the new round is the legal successor. Any other
   differing bytes still fail closed. Add Bats cases for a Round-1 replacement and for
   a plan-eval followed by a code-eval.

### Major

2. **[MAJOR] Status-transition mechanics are underspecified (Step 5).** "Validate the
   applicable spec-03 legal status transition … apply it" leaves open questions that
   an independent reader must answer to implement it:
   (a) Which actor mutates which file? The step is titled "Same helper and
   orchestration guidance". Spec 03 § Evaluation-run validity says the recorder makes
   the transition, but the plan never says that `record` rewrites the `Status:` line
   of the checkout artifact.
   (b) Where does the current status come from? It is not the manifest: the
   production manifest schema has no review-status field. The plan also doesn't say
   how the recorder checks that the checkout artifact is still the reviewed blob/state
   tip before editing it.
   (c) What is the per-type mapping? Research/spec/plan PASS → `Approved`, ADR PASS →
   `Accepted`, plan FAIL → `Draft`, code PASS → `Ready to Publish`, code FAIL →
   `In Progress`.
   (d) How is the ADR 0023 ratification hold detected?
   (e) How are owner-claimed gates communicated to the helper? Claimed gates are
   kickoff state, not manifest state.
   *Required change:* list the transition table, name the file the recorder edits, say
   how source status and gate claims are supplied (for example a `--claimed-gate`
   flag or orchestrator-only application), and add a check that the checkout blob
   matches the reviewed blob before writing.

3. **[MAJOR] Round binding cannot be verified as written.** Step 1 requires a
   "nonnegative round", and Step 2 compares "every echoed … binding to the verified
   manifest". But the manifest schema has no round field (required:
   `protocol, run_id, evaluation_type, created_at, head_sha, head_tree, files,
   exclusions, source_export, manifest_sha256`). Nothing in the plan stops a verdict
   from echoing an arbitrary round. Spec 03's single lifetime counter (FAIL
   increments; PASS retains; fifth FAIL pauses) then depends on an unverified
   evaluator-supplied number. *Required change:* state the source of truth for the
   expected round (for example derived from the bound prior verdict's round plus its
   verdict, or 0 when there is no prior verdict) and reject a mismatch.

### Minor

4. **[MINOR] The rendered report shape is not specified.** Step 4 says "deterministic
   identity-neutral Markdown" but never names the header lines or sections. Existing
   readers parse `Status: Evaluated` / `Round:` / `Verdict:` lines. The plan also
   doesn't say whether to include the conformance/evidence-mode label that spec 04
   requires bootstrap verdicts to carry, or what a production recorder emits instead.
   Name the fixed layout.
5. **[MINOR] Verdict/severity consistency is unchecked.** Spec 05 § Verdict says the
   canonical severity rubric alone maps confirmed findings to PASS/FAIL. Step 1
   forbids inferring PASS from empty findings but does not reject a PASS that carries
   a `BLOCKER`/`MAJOR` finding. Either reject that structurally or record explicitly
   that the recorder does not adjudicate it.
6. **[MINOR] The Verification section omits repository conventions and mechanical
   invariant checks.** Targeted Bats should run with `TMPDIR=/private/tmp` (macOS),
   and the full gate as `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`, per
   project CLAUDE.md. Step 6 asserts that root-copy guidance is retired in `SKILL.md`
   and `orchestration.md`. The rubric requires that invariant to be checked with a
   tool (for example `rg -n 'root-copy|copies the one valid verdict'` with expected
   results), not reviewed "against ADR 0023" by eye.

### Nit

7. **[NIT]** `node scripts/validate-repository.mjs --root /Users/craig/git/loom --all`
   hard-codes a machine-specific absolute path. Use `--root .` or the repository top.
8. **[NIT]** The `## Notes` "None." line can be removed. Step 6's settlement paragraph
   mixes guidance retirement with full-sunset settlement and would read more clearly
   as two sub-bullets.

## Scope & Size budget

- **Plan length:** 104 lines, well under the 200-line target (rubric ≤ 250). PASS.
- **Canonical structure:** has `Status: Plan Review`, a `Target size:` line (≤ 350
  net LOC excluding tests/schemas), `## Context`, an explicit `## Out of Scope &
  Threat-Model Boundary`, numbered file-scoped `## Steps`, `## Verification`, and a
  compact `## Revision Log`. PASS.
- **Single purpose:** one coherent goal, recording a validated evaluator verdict.
  The only outside addition is the full-sunset settlement guidance in Step 6, which
  ADR 0023 §6 and spec 03/04/05 explicitly assign to this slice's settlement. That is
  in scope.
- **LOC realism:** Steps 2–5 add a subcommand, output validation, a rerun-validator
  refactor, path derivation/confinement, a Markdown renderer, atomic publish,
  idempotent retry, and status-transition logic, all in Bash. 350 net LOC is tight
  but plausible if the renderer and binding comparisons are single `jq` programs.
  Resolving findings 1–3 will add some lines. The planner should confirm the budget
  still holds after revision.

## Rubric assessment

| Criterion | Assessment |
|---|---|
| Authority | Targets specs 03/04/05 and ADRs 0022/0023, and follows ADR 0022 §3 (evaluator writes one schema-valid verdict; deterministic recorder validates and copies; orchestrator commits) and the improvement-plan slice. **Pass with gaps**: spec 03 status-transition and round-counter semantics are not carried through (findings 2, 3). |
| Executable | Steps are numbered and file-scoped, and the verdict schema (Step 1), `record` subcommand (Step 2), rerun validation (Step 3), atomic publish (Step 4) and bootstrap sunset (Step 6) are concrete. **Fails**: the destination path/round-replacement rule is self-contradictory (finding 1), and the transition step is ambiguous about actor, source status and mapping (finding 2). |
| Verified sketches | Checked against the real tree: `do_verify`, `validate_json_schema` (Ajv 2020, `$ERRS`), `rerun_status` (exits via `emit_status`, so a non-exiting refactor is a real need), `parse_run_args` / `--repo`, and the run layout (`output/` mode 0700, verified by `do_verify`) all exist as described. The manifest has `files[].role == "artifact"` but no round or review-status field, which affects findings 2 and 3. |
| Single-purpose | Pass. |
| Structure & size budget | Pass (104 lines; target LOC stated; required sections present). |
| Threat-model & proportionality | Pass. It explicitly excludes evaluator launch isolation, the exporter, remote publication, and spec/ADR amendments. It cites spec 00 non-goals (no OS hostile-code containment, cryptographic anonymity, or attestation) and does not demand defenses against hostile inode swaps inside the private run directory, while still rejecting links/escapes at the recording boundary. It keeps the ADR 0023 exception closed, and production failure never revives retired components. Test scope is proportional. |
| Verification named | Partly. It names the targeted Bats file, `scripts/check` as the full gate, repository validation, and a regression expectation. Missing the repository's TMPDIR/jobs conventions and mechanical invariant checks (finding 6). |
| Invariants verified mechanically | Not met for the guidance-retirement and settlement-ordering invariants (finding 6). |
| Playbook conformance | Pass (correct location, name, Status token, Revision Log). |

**Verdict derivation:** under `severity.md`, one BLOCKER and two MAJOR findings mean
**FAIL**. Round 0 → the planner revises in place and updates the Revision Log.

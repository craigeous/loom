# macOS-first dual-client dogfood program amendment

Status: Approved
Target specs: [00-overview.md](../spec/00-overview.md),
[02-roles.md](../spec/02-roles.md),
[03-artifact-lifecycle.md](../spec/03-artifact-lifecycle.md),
[04-orchestrator.md](../spec/04-orchestrator.md),
[06-init-modes.md](../spec/06-init-modes.md),
[07-command-surface.md](../spec/07-command-surface.md),
[08-playbook.md](../spec/08-playbook.md), and
[10-packaging.md](../spec/10-packaging.md)
Authority: [ADR 0024](../ADR/0024-macos-first-dual-client-dogfood-bootstrap-amendment.md)
Improvement slice: `macos-dogfood-program-amendment`

## Context

Remote `main` now contains the verified and settled M0 `ci-baseline` result. Accepted
ADR 0024 authorizes a private Apple-silicon macOS checkpoint before M1 while leaving
the Ubuntu/macOS-Intel v0.2 release matrix and M0–M7 release gate unchanged. This
documentation-only slice publishes ADR 0024 and its ratification evidence as merged
prerequisite authority, inserts the checkpoint without renaming M1–M8, amends the
frozen specs through cold plan evaluation, and brings every canonical/user-facing
document named by ADR 0024 section 7 into one consistent state.

This slice does not change plugin code, manifests, catalogs, fixtures, hooks, helper
behavior, client installation, or any public support/release claim. Those behaviors
belong only to the separately planned `macos-dual-client-dogfood` code slice.

## Exact path boundary

Immutable prerequisite paths, integrated but never edited by this slice:

- `.docs/ADR/0024-macos-first-dual-client-dogfood-bootstrap-amendment.md`
- `.docs/ADR/README.md`
- `.docs/evaluations/0024-macos-first-dual-client-dogfood-bootstrap-amendment-acceptance.md`
- `.docs/evaluations/0024-macos-first-dual-client-dogfood-bootstrap-amendment-eval.md`

The complete literal writable set is:

- `.docs/repository-improvement-plan.md`
- `.docs/spec/README.md`
- `.docs/spec/00-overview.md`
- `.docs/spec/02-roles.md`
- `.docs/spec/03-artifact-lifecycle.md`
- `.docs/spec/04-orchestrator.md`
- `.docs/spec/06-init-modes.md`
- `.docs/spec/07-command-surface.md`
- `.docs/spec/08-playbook.md`
- `.docs/spec/10-packaging.md`
- `.docs/status/project-instructions.md`
- `README.md`
- `CLAUDE.md`
- `AGENTS.md`
- `.docs/slice-plans/macos-dogfood-program-amendment.md`
- `.docs/slice-plans/archive/macos-dogfood-program-amendment.md`
- `.docs/slice-plans/README.md`
- `.docs/evaluations/macos-dogfood-program-amendment-eval.md`
- `.docs/evaluations/README.md`
- `.docs/status/roadmap.md`
- `.docs/status/progress.md`
- `.docs/status/handoff.md`

Product paths under `plugins/loom/**`, catalogs, CI, schemas, fixtures, scripts, and
lockfiles are forbidden.

## Steps

1. Keep this complete planning set `Draft` while the planner authors steps 2–5. Only
   after every file is committed does the planner set the plan and amended specs to
   `Plan Review`; one cold plan evaluator judges that exact candidate and changes only
   status tokens plus its evaluation record. No developer edits a frozen spec.
2. Update `.docs/repository-improvement-plan.md` without renaming or combining M1–M8:
   insert a named `macos-dual-client-dogfood` checkpoint after M0; mark M0 landed;
   state that only Apple-silicon macOS dogfood execution gates the checkpoint; and
   retain the full ADR-0019 host/client matrix plus M0–M7 as the v0.2 release gate.
3. Apply this per-file/per-section matrix (each new section cites ADR 0024):

   | Path | Exact amendment |
   |---|---|
   | `spec/README.md` | Authority list and non-negotiable private-checkpoint/release distinction. |
   | `00-overview.md` Goals/non-goals | Define dogfood-ready as private evidence, not support/release; retain portable shared core. |
   | `02-roles.md` Shared contract | Require five role mappings, one real cold launch per client, bounded return, and child no-delegation proof. |
   | `03-artifact-lifecycle.md` Bootstrap section | Admit only the two ADR-0024 slice names while listed; define docs-planning vs code-bearing review paths and intent/settlement lifecycle. |
   | `04-orchestrator.md` Bootstrap orchestration | Require full protected-state validation, component availability, settled-result containment, exact-base rebuild, and slice-specific evaluator routing. |
   | `06-init-modes.md` Common outputs | Require isolated client/project homes, inside/outside-root consistency, no writes outside owned roots, and clean uninstall evidence. |
   | `07-command-surface.md` Workflows/roles/surfaces | Enumerate exact eight `/loom:*` ↔ `$loom-*` workflow pairs and five role pairs; label Codex behavior pending until the code slice passes. |
   | `08-playbook.md` Hooks/helpers | Define shared `trigger`, per-client block/trust evidence, absolute installed-root/helper containment, and preserve the existing whole-file digest/byte-exact renderer rules. |
   | `10-packaging.md` Validation/release gate | Define isolated install/reinstall/uninstall and behavior evidence on Darwin arm64; explicitly retain Ubuntu/macOS-Intel and M0–M7 for release. |

4. Create `.docs/status/project-instructions.md` using the exact
   `loom-project-instructions/v1` schema already fixed by spec 08. Render one matching
   Loom-owned block into `CLAUDE.md` and new `AGENTS.md`, preserving all owner text
   outside the markers. Normalize CRLF/CR to LF, require exactly one final LF, and hash
   the entire canonical file bytes. Deterministically render each client block from
   that canonical file, permit only the declared invocation/root examples to differ,
   byte-compare each block with its expected rendering, and require both marker hashes
   to equal the whole-file hash.
5. Update `README.md`, `CLAUDE.md`, and `AGENTS.md` outside/inside their appropriate
   ownership boundaries so they agree on: current M0 static baseline, the not-yet-
   complete private macOS checkpoint, exact client floors, client-native invocation,
   installation limitations, full release support obligations, and `scripts/check`.
   Do not say Codex behavior is supported until the later code slice passes.
6. Run a cold plan evaluator over the complete amended planning set, not only this
   plan. Its controlled package includes ADR 0024, the accepted ADR/ratification
   bindings, prior target documents, amended documents, exact diff/path inventory,
   spec/plan rubric, and current protected transition/remote-main observations. Record
   degraded bootstrap labels; do not claim `loom-local-review/v1`, ADR-0022 isolation,
   or release conformance. A BLOCKER or MAJOR returns the planning set to Draft.
7. After PASS, prepare landing-only finalization: mark this plan `Archived`, move it to
   `.docs/slice-plans/archive/`, update the slice index, and update roadmap/progress/
   handoff to say the program amendment is prospectively landed and the code-bearing
   dogfood slice is next. Publish only through ADR-0023 intent, non-force remote-direct
   update, exact verification, receipt, settlement, and claim release.

## Verification

The planning/evaluation candidate must mechanically prove:

1. Write the 22 writable paths above to a sorted temporary allowlist. At Plan Review,
   require every changed path after subtracting the four literal immutable prerequisite
   paths to be in that allowlist and require these planning-set paths to be present:
   the active plan, improvement plan, spec index plus all eight target specs, canonical
   instructions, both root adapters, README, both evaluation files/index, and slice
   index. At finalization, require the active plan absent, archived plan present, and
   roadmap/progress/handoff present; compare that expected final set byte-for-byte with
   sorted `git diff --name-only <base>...<head>` after subtracting the four prerequisites.
   Any extra/missing path fails. Require `git diff --quiet 29e4f649 --` for each
   immutable prerequisite path.
2. Require exactly one heading match for each `^## M[0-8] —` and exactly one
   `^## Checkpoint D0 —` in the improvement plan. An `awk` line-order assertion must
   prove `M0 < D0 < M1`. Bounded searches over the improvement plan, spec 10, and
   README must each find the exact floors `2.1.216` and `0.144.6`, Ubuntu `22.04` and
   `24.04`, both `arm64` and `Intel`, and literal release requirement `M0` through `M7`.
3. Parse a committed table in spec 07 and compare its rows to these exact workflow
   pairs: `run,research,plan,eval-plan,develop,eval-code,status,init` mapped from
   `/loom:<name>` to `$loom-<name>`. Compare the role table to exactly
   `researcher,planner,plan-evaluator,developer,code-evaluator`. Bounded negative `rg`
   checks over live specs/README/CLAUDE/AGENTS fail on `Codex behavior (is )?supported`,
   `dogfood release`, or language making Linux/Intel mandatory for this checkpoint;
   the same set must contain `pending`/`not release` qualifiers.
4. A deterministic checker must normalize only line endings and final LF, hash the
   entire canonical file, validate exact fields/headings/order, require exactly one
   begin/end marker in each adapter, compare marker hashes, render expected Claude and
   Codex blocks, and `cmp` each actual block byte-for-byte. Before inserting blocks,
   hash the complete owner-controlled prefix/suffix of each file; after rendering,
   remove only the marker-bounded block and require those outside hashes unchanged.
5. `scripts/check` passes under system Bash 3.2 and current Bash 5.3 with
   `LOOM_DIFF_BASE` set to the fresh remote base. Because this is pure documentation,
   automated code/security finders are recorded as `skipped: docs-only`; the cold plan
   evaluator remains the verdict authority.
6. At run start and immediately before intent, fetch advertised transition and target
   refs into new temporary refs; require advertised=fetched, full transition ancestry
   root-to-tip valid, protection rule `19471413` active with deletion/non-fast-forward
   and no bypass, exact run-bound tip, phase `active`, no current conflicting intent,
   this slice present, `bootstrap-landing`, `evaluation-workspace`, and
   `evaluation-recorder` all `available`, authority-amendment bytes unchanged, and
   every recorded result an ancestor of target. Require remote `main` equal to the
   candidate base. Any changed tip/base/state rebuilds the package and re-evaluates;
   no stale evidence reuse is permitted.

## Notes

- 2026-07-23: ADR 0024 and its acceptance/evaluation chain were merged without
  rewriting onto the fresh M0 result before this plan was authored.
- 2026-07-23: Cold plan evaluation round 0 failed on lifecycle sequencing, exhaustive
  path scope, per-spec mapping, digest exactness, bootstrap preconditions, and
  mechanical verification. The planner is revising the complete planning set before
  returning it to Plan Review.
- 2026-07-23: Round-0 corrections are present as one planner-authored set: literal
  allowlist, per-spec matrix, whole-file digest/byte renderer contract, full bootstrap
  prerequisites, and bounded mechanical assertions. The exact set is resubmitted.

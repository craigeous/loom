# Docs State Validator

Status: Landed
Target specs: 00-overview.md, 03-artifact-lifecycle.md, 05-blind-evaluation.md, 08-playbook.md
Target size: <= 450 LOC net change (keep this plan document <= 250 lines)

## Context

Spec 08 requires mechanical checks of documentation state. The repository validator
already checks metadata and relative links, but excludes evaluations and archived
plans from link validation and does not enforce the documentation lifecycle. This
slice adds deterministic checks and fixture coverage while preserving existing CLI
modes and diagnostics. Spec 03 defines lifecycle and round semantics; spec 05 defines
evaluation recording and naming. Status alone is not evidence of a valid evaluation
or remote landing.

## Out of Scope & Threat-Model Boundary

No spec or lifecycle policy amendment, review/landing authority, remote verification,
living-doc shape rules, or managed-project initialization changes. This repository
validator checks local artifacts and available history; it cannot prove independent
review, owner decisions, or remote receipts. Spec 00's non-goals exclude hostile-code
containment and replacing owner judgment. Do not silently rewrite historical evidence
or mutate accepted ADR decisions to make checks pass.

## Steps

1. In `scripts/validate-repository.mjs`, extend `--all` with documentation-state
   validation without changing `--metadata` or `--links` semantics. Discover actual
   artifact files separately from README indexes and review-finding companions; report
   stable path and actionable rule for every violation, aggregate failures, and exit
   nonzero. Reuse existing safe path and Markdown parsing mechanisms.
2. Require exactly one `Status:` field on each spec, ADR and slice plan and
   validate the following type-specific tokens. Evaluation verdicts are protocol
   fields, not statuses: reject a `Status:` field on an evaluation itself (a quoted
   target status in `Artifact:` is not a field). `Needs Clarification` pauses and
   restores the prior status; `Abandoned` records deliberate cessation.

   | Type | Legal statuses |
   |---|---|
   | Spec | Draft, Plan Review, Approved, Needs Clarification, Abandoned |
   | ADR | Draft, Plan Review, Accepted, Needs Clarification, Abandoned |
   | Slice plan | Draft, Plan Review, Approved, In Progress, Implemented, Ready to Publish, Landed, Archived, Needs Clarification, Abandoned |
   | Evaluation | No Status field |

   Enforce one active plan per slice by normalized identity, including the historical
   `-plan` suffix; archived plans must be `Landed` or `Archived`. Record any baseline
   exceptions and their evidence in the implementation's evaluation record; only the
   owner may authorize record corrections. Never silently recategorize history.
3. Default `--all` to snapshot checks; report that transitions were not verified.
   Add optional `--baseline <ref>` for `--all` to compare baseline and working-tree
   statuses including renames and enforce spec 03 arrows, FAIL returns, clarification
   restoration and landing archive transition. Update `usage()` and reject missing,
   unavailable or ambiguous refs and invalid flag/mode combinations with exit 2.
   Preserve existing callers without the flag; do not claim historical proof.
4. Validate names and evidence under `.docs/evaluations/` using only these forms:

   | Form | Treatment |
   |---|---|
   | `<artifact>-eval.md`, `<artifact>-plan-eval.md` | Canonical evaluation; resolve artifact identity and phase. |
   | `<artifact>-review-findings.md`, `<artifact>-acceptance.md` | Companion evidence, not an evaluation or round event. |
   | `README.md`, `macos-dual-client-dogfood-evidence.json` | Static index/evidence; not evaluations. |
   | `YYYY-MM-DD-<artifact>-eval.md`, `YYYY-MM-DD-<artifact>-plan-eval.md` | Historical compatibility: strip the date prefix for identity; retain file as evidence. |

   Reject other forms. For each canonical or dated evaluation read exactly one
   top-level `Round: <N>` field, with N a nonnegative decimal integer, and its
   top-level `Verdict: PASS` or `Verdict: FAIL`; section headings and prose are not
   independent events. Order events by recorded reviewed commit ancestry, not file
   names; if ancestry, phase, verdict, or ordering is missing or ambiguous, report it
   rather than inventing a sequence. A first event is round 0; a merits FAIL advances
   the next event by one, PASS retains the round, and invalid or infrastructure-blocked
   runs, retries and clarifications do not increment. Plan and code share the counter.
   A reset requires a recorded owner decision identifying the artifact, materially new
   direction and reset to 0; otherwise reject a reset. Historical multi-section files
   use their single header as one event, including bootstrap corrections in prose.
5. Require the following headings and nonempty authority references, resolving each
   reference to an existing target. A reference is a Markdown link to the applicable
   artifact; a bare title or empty heading is insufficient. Apply these rules to the
   current artifact, not a quoted target inside an evaluation.

   | Type | Required headings | Authority |
   |---|---|---|
   | Spec | `Authority` | At least one accepted ADR it derives from. |
   | ADR | `Context`, `Decision`, `Consequences` | Link approved research or problem statement and relevant accepted prior authority in the body; no `Authority` heading required. |
   | Slice plan | `Context`, `Out of Scope & Threat-Model Boundary`, `Steps`, `Verification`, `Revision Log` | Link or identify target approved specs and relevant accepted ADRs in metadata or body; resolve each identified target. |
   | Evaluation | `Summary`, `Findings` | Identify reviewed artifact and authority used in header or body; resolve linked local authority. |

   Record narrowly identified historical template exceptions and reasons in the
   implementation evaluation record, subject to owner authorization; never waive an
   entire type. Extend relative link checking under `--all` to evaluations and archived
   plans using existing safe Markdown and fragment resolution. Historical evaluations
   and archived plans are never rewritten: inventory each known broken link in
   `scripts/validation/relative-link-allowlist.txt` as source, target and reason; do not
   allowlist live broken links or broad patterns. The acceptance bound is exactly the
   inventoried historical failures, with no unused entries; report the count in the
   implementation evaluation record. Ignore external URLs and literal code.
6. Under [ADR 0025 reconciliation authority](../../ADR/0025-reconciliation-authority-plugin-root-no-bypass-landing.md)
   and the explicit request at [improvement plan line 737](../../repository-improvement-plan.md#slice-docs-state-validator),
   repair only the single link in `.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md`
   to `../slice-plans/archive/multi-session-lock-helper-plan.md`. Verify `git diff`
   for that ADR changes only that line; do not alter its accepted decision. Add
   proportionate isolated fixture-based Bats cases for positive and negative rules,
   historical compatibility, invalid input and existing CLI modes.

## Verification

Run `bats scripts/tests/repository-validation.bats` for focused iteration, then
`node scripts/validate-repository.mjs --root . --all` and `scripts/check` for the
repository gate. Run named Bats cases `baseline legal transition`, `baseline illegal transition`,
`baseline archive rename`, `baseline invalid ref`, and `baseline usage errors` using
`--root <fixture> --all --baseline <ref>` in a temporary Git fixture; assert nonzero exits and useful
paths for malformed statuses, rounds, names, headings, authority and links. Confirm
existing metadata and link tests pass and the real repository passes without masking
unresolved baseline violations. A snapshot-only run does not certify historical
transitions or landing.

## Verification Evidence

- `scripts/check` (`TMPDIR=/private/tmp LOOM_BATS_JOBS=4`): All checks passed; 848 Bats cases ok.
- `node scripts/validate-repository.mjs --root . --all`: passed (snapshot mode; transitions unverified).
- Named cases `baseline legal transition`, `baseline illegal transition`, `baseline archive rename`,
  `baseline invalid ref`, `baseline usage errors` plus nine `docs state:` cases pass.
- ADR 0016 diff changes only the one link to `../slice-plans/archive/multi-session-lock-helper-plan.md`.
- Historical inventory in `scripts/validation/relative-link-allowlist.txt`: 104 immutable broken-link
  records and 239 exact-source `rule:<id>` exceptions (109 missing Summary, 35+35 plan template headings,
  26 authority, 10 cumulative-round sequence, 6 `Status:` on evaluations, plus spec 09 `Living`, the
  `ci-baseline` location pointer and one Abandoned archived plan). No type is waived; unused entries fail.
  These exceptions are pending owner authorization. Ancestry ordering uses the header `Commit:` or the
  first-adding commit; evaluation files record cumulative rounds, so only cross-file order is checked.

### Round 0 code-eval remediation

- Baseline transitions are direct spec 03 steps checked over the commit history from the baseline;
  Needs Clarification restores only its prior status (ambiguity reported when history lacks one);
  Ready to Publish cannot enter the archive (Landed/Abandoned only); FAIL returns need a FAIL evaluation.
- Evaluations: first event is Round 0, exact progression (merits FAIL +1, PASS retains), `Run-Status:
  invalid|infrastructure-blocked` marks non-merits runs, `Owner-Reset:` must name the artifact, a new
  direction and reset to 0; ordering uses only the recorded `Commit:` (no file-addition fallback).
- Authority: ADRs need approved research/problem plus accepted prior authority; plan targets must be
  Approved specs / Accepted ADRs; evaluations must identify a resolvable artifact and authority.
- Under `--all` every unused allowlist record is stale; only active plans count toward plan identity.
- Historical inventory: 113 new exact-source `authority` / `eval-sequence` rule exceptions added for
  immutable records (pending owner authorization); 3 now-unneeded exceptions removed.
- Verification: `node scripts/validate-repository.mjs --root . --all` passed;
  `bats scripts/tests/repository-validation.bats` and `scripts/check` results recorded in the commit message below.

### Round 0 re-review remediation

- FAIL returns: `checkTransitions()` now requires a merits FAIL of the matching phase (`-plan-eval` for
  Plan Review -> Draft of a plan; code evaluation for Implemented -> In Progress) whose recorded
  reviewed `Commit:` is reachable from HEAD and at or after the commit that entered the rejected status.
  A missing or unresolvable commit reports ambiguity instead of accepting the record.
- Resets: every `Owner-Reset:` (including the first event of a group) must be `Round: 0`, name the
  artifact, record an owner decision, a materially new direction and a reset to 0.
- Authority: ADR grounding is approved research or an approved/accepted top-level `.docs/*.md` problem
  document; evaluation `Artifact:` links must resolve to the named artifact (not an evaluation), and
  `Reviewed against:` must resolve to existing ADRs/specs/research/plan/rubric references.
- Two historical records (ADR 0016, `sanitized-evaluation-workspace-eval`) gained exact-source
  `rule:authority` exceptions, pending owner authorization.
- Tests: new Bats cases for phase/order FAIL evidence, first-event reset validation, ADR problem-statement
  grounding and applicable evaluation references; two existing cases updated to the stricter rules.

### Round 1 code-eval remediation

- FAIL return evidence is bounded to the rejected-status interval: the merits FAIL's reviewed commit must
  descend from the commit that entered the rejected status and, when the return is committed, be an ancestor
  of (or equal to) the commit that returned from it. A FAIL from a later cycle cannot justify an earlier return;
  unorderable evidence still reports ambiguity.
- Evaluation authority bare names (`spec NN`, `research notes`, `rubric`, `playbook`, `slice plan`) count only
  when they resolve to a real applicable file; nonexistent `spec NN` and slice-plan paths are reported.
  Authority roots are `.docs/spec/`, `.docs/ADR/`, `.docs/research/`, `.docs/slice-plans/` and rubric files
  under the playbook references; `scripts/`, `.docs/status/` and other broad roots no longer count.
- ADR problem grounding accepts only approved/accepted research notes or the designated
  `.docs/repository-improvement-plan.md`, not arbitrary top-level `.docs/*.md`.
- Two exact-source `rule:` exceptions were added to the allowlist: `docs-state-validator-eval.md`
  (`eval-sequence`; its rewritten code-eval record shares an identity with the Round 0 plan evaluation) and
  `scope-identity-guard-to-commit-subcommands-eval.md` (`authority`; names only the shipped hook).
- Tests: new Bats cases for interval-bounded FAIL returns, unresolved bare authority names, broad authority
  roots and top-level problem documents.

### Round 2 code-eval remediation

- Generic evaluation authority references no longer pass merely because some file of that category exists.
  `slice plan` must resolve to `.docs/slice-plans/[archive/]<identity>.md` for the reviewed artifact,
  `rubric` to `plan-eval-rubric.md` (plan evaluations) or `code-eval-rubric.md` (code evaluations), and
  `research notes` to `.docs/research/<identity>.md`; direct links and explicit paths still count. An
  unresolved generic reference is reported as an `authority` rule violation naming the generic reference.
- Tests: new Bats case proving a non-matching plan is rejected, the matching plan passes as phrase and link,
  and research and rubric references must resolve to the applicable files.
- Two historical evaluation records gained exact-source `rule:authority` exceptions (wrapped authority lines).
- Verification: targeted Bats, `node scripts/validate-repository.mjs --root . --all` and `scripts/check` green.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Address Round 0 findings: define validation contracts, compatibility, authority and scope. |
| 2 | Implemented; verification evidence recorded. |
| 3 | Address code-eval Round 0 findings; remediation evidence recorded. |
| 4 | Address code-eval Round 1 findings; remediation evidence recorded. |
| 5 | Address code-eval Round 2 findings; generic authority references must resolve. |

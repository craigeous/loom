# Docs State Validator

Status: Plan Review
Target specs: 00-overview.md, 03-artifact-lifecycle.md, 05-blind-evaluation.md, 06-init-modes.md, 08-playbook.md
Target size: <= 250 LOC net change (keep this plan document <= 250 lines)

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
2. Validate exact spec 03 status tokens and type-specific statuses for specs, ADRs,
   plans, and evaluation artifacts where a `Status:` field is present; reject missing,
   duplicate, or unknown required fields. `Accepted` is ADR-only. Enforce one active
   plan per slice by normalized artifact identity, including the historical `-plan`
   suffix, and require every archived plan to be `Landed` or `Archived`. Identify
   baseline exceptions before implementation; resolve conflicts through authorized
   record correction, never blanket exemptions or silently recategorizing history.
3. Check legal transitions against a defined, explicit comparison baseline, not a
   guess from the current file: add a documented optional baseline ref argument for
   `--all`, compare baseline and working-tree statuses including renames, and enforce
   spec 03's type-specific arrows, FAIL returns, clarification restoration and landing
   archive transition. Without a baseline, perform snapshot checks and report that
   transitions were not verified; do not claim historical proof. Reject unavailable
   or ambiguous explicit baselines. Test adds, removals, renames, invalid jumps and
   legal transitions; preserve existing callers when the option is absent.
4. Check evaluation names against `.docs/evaluations/<artifact-name>-eval.md` and
   their identified target, distinguishing review-finding companions. Validate recorded
   round sequences per artifact across plan and code phases: start at 0, merits FAIL
   increments, resolving PASS retains the round, and invalid/infrastructure-blocked
   events, retries and clarifications do not increment. Use explicit recorded evidence;
   flag ambiguous or missing evidence rather than inventing sequence or resets. Cover
   owner-authorized resets as recorded decisions, and do not reinterpret historical
   evaluation formats without a documented, narrowly scoped compatibility rule.
5. Check applicable required headings and nonempty authority references for specs,
   ADRs and plans against their respective templates and spec 05's type-specific
   authority, resolving links to existing targets. Apply checks by artifact type and
   account explicitly for historical templates; do not impose a new `Authority`
   heading on ADRs or plans merely because specs have one. Extend relative link
   checking to the scoped documentation artifacts, including evaluations and archived
   plans, using Markdown parsing, fragment resolution, safe paths, and the existing
   allowlist only for documented intentional exceptions. Diagnose missing files and
   fragments; ignore external URLs and literal code. Inventory and resolve baseline
   failures with explicit evidence rather than broad exclusions.
6. Correct the link in `.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md` to
   `../slice-plans/archive/multi-session-lock-helper-plan.md`; this is a link repair,
   not a change to its accepted decision. Add comprehensive fixture-based Bats cases
   in `scripts/tests/repository-validation.bats` for each positive and negative rule,
   scope exclusions, historical compatibility, invalid input, and existing CLI modes.
   Keep fixtures isolated and ensure diagnostics identify the offending artifact.

## Verification

Run `bats scripts/tests/repository-validation.bats` for focused iteration, then
`node scripts/validate-repository.mjs --root . --all` and `scripts/check` for the
repository gate. Exercise an explicit baseline in a temporary Git fixture with legal
and illegal transitions, including archive renames; assert nonzero exits and useful
paths for malformed statuses, rounds, names, headings, authority and links. Confirm
existing metadata and link tests pass and the real repository passes without masking
unresolved baseline violations. A snapshot-only run does not certify historical
transitions or landing.

## Notes

Plan evaluation must resolve any ambiguity in historical artifact formats and baseline
remediation before development; accepted authority remains controlling.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

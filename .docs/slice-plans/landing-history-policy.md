# Landing History Policy

Status: Plan Review
Target specs: 00-overview.md, 04-orchestrator.md
Target size: <= 200 LOC net code/doc changes (plan <= 250 lines)

## Context

M8 slice 3 is a decision slice for the history of a landed slice. The current
commit-per-handoff convention preserves granular role history, but exposes process
noise on the target branch. Squashing onto the target gives a readable history while
tracked `.docs/` records retain the review trail; those records do not retain every
intermediate Git object. Retaining audit refs or slice branches for a fixed period
would preserve those objects, but adds remote lifecycle, retention, and cleanup
requirements. Choose squash by default, with granular commits on the slice branch and
one author-neutral squash commit on the authoritative target; durable evaluation and
review records remain in `.docs/`. Retained refs are not required by this decision.

The decision must be accepted before changing landing behavior: the existing remote
verification and receipt rules in spec 04 remain authoritative until then. This slice
establishes the decision and specification, not the implementation.

## Out of Scope & Threat-Model Boundary

No changes to `loom-land`, orchestration reference implementation, tests, publication
modes, or existing receipts in this slice. A later implementation slice must cover
migration and compatibility. No required audit-ref retention, provider-specific
branch retention, history rewriting, force-push, or erasure of existing history is
introduced. Respect spec 00's non-goals: this decision does not claim cryptographic
anonymity, hostile local process containment, or protection against local tampering.

## Files to touch

- `.docs/ADR/0026-landing-history-policy.md` — proposed decision and consequences.
- `.docs/spec/00-overview.md` — authority list if needed for the accepted ADR.
- `.docs/spec/04-orchestrator.md` — precise landing history contract.
- `.docs/ADR/README.md` — register the decision if the index requires it.

## Steps

1. In `.docs/ADR/0026-landing-history-policy.md`, record the problem and compare the
   three options in Context, including their audit, noise, and operational costs.
   Decide on granular handoff commits on the slice branch and exactly one
   author-neutral squash commit per slice on the authoritative target. Preserve full
   plan, evaluation, and review records in tracked `.docs/` as candidate contents;
   do not claim that these records reproduce every intermediate commit. State that
   audit refs and retained branches are optional external practices, not guaranteed
   recovery or required retention. Identify any superseded or extended prior authority
   explicitly and document implementation and compatibility as follow-on work.
2. In `.docs/spec/04-orchestrator.md`, specify that the candidate's single commit has
   the freshly fetched target base as its sole parent and contains the integrated
   slice plus deterministic finalization and tracked evidence. Require the candidate
   tree and exact candidate/result SHA to be checked by the existing gate and affected
   reviews; target movement rebuilds the squash candidate and reruns affected checks.
   Preserve configured publication mode, non-force publication, fresh independent
   remote verification, receipt binding (including slice head, bases, candidate and
   result), claim recovery, and the `Landed` rule. Specify that a provider mode is
   conforming only when it can prove the single-commit result and checked tree; it
   must fail closed without changing modes otherwise. Preserve configured Git identity
   and author-neutral messages without role attribution or co-author trailers.
3. Update `.docs/spec/00-overview.md` and `.docs/ADR/README.md` as necessary to register
   the accepted decision and its authority. Submit the decision and spec amendment to
   a distinct cold plan evaluator before acceptance; resolve findings in place. A
   subsequent separately planned implementation must update `plugins/loom/bin/loom-land`
   and orchestration references and test candidate construction, moved-target rebuild,
   checked-tree/receipt binding, provider incompatibility, and recovery.

## Verification

- Fast documentation check: `node scripts/validate-repository.mjs --root . --all`.
- Run `scripts/check` as the repository gate for the decision and spec changes.
- Mechanically check the accepted ADR and spec for the chosen policy, sole parent,
  tracked evidence, remote verification, no force, and target-movement rebuild using
  targeted `rg` searches; inspect each match in context against the steps above.
- Cold plan evaluation verifies the option tradeoffs, authority and specification
  consistency; implementation behavior is verified by the follow-on slice's tests.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

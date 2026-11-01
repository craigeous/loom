# Landing History Policy

Status: Plan Review
Target specs: 00-overview.md, 04-orchestrator.md
Target size: <= 200 LOC net code/doc changes (plan <= 250 lines)

## Context

M8's workflow-benchmark delivered a harness and paired measurement protocol, not
benchmark evidence establishing a permanently preferred history shape. Following
that deliverable, this slice proposes squash as a provisional default to test:
retain granular handoff commits on the slice branch and publish one author-neutral
squash commit on the authoritative target. Tracked `.docs/` evidence preserves the
review trail but not every intermediate Git object. Retained audit refs or branches
could preserve objects at additional operational cost; they are not required.
This provisional experiment is subject to benchmark evidence and reassessment; it
is not a frozen target-history choice prohibited by spec 00's non-goal.

Existing remote verification and receipt rules remain authoritative until the
proposed decision is accepted and its spec amendment is approved. This slice
establishes the provisional decision and specification, not implementation.

## Out of Scope & Threat-Model Boundary

No changes to `loom-land`, orchestration implementation, tests, publication modes,
or existing receipts. A later implementation slice must cover migration and
compatibility. No required audit-ref retention, provider-specific branch retention,
history rewriting, force-push, or erasure of existing history is introduced. The
provisional default does not freeze history policy before benchmark evidence. This
slice does not claim cryptographic anonymity, hostile local process containment, or
protection against local tampering.

## Files to touch

- `.docs/ADR/0026-landing-history-policy.md` — proposed decision and consequences.
- `.docs/ADR/README.md` — register ADR 0026 with its lifecycle status.
- `.docs/spec/00-overview.md` — add ADR 0026 to authority and clarify that the
  non-goal permits a provisional default to test while prohibiting a frozen choice
  before benchmark evidence.
- `.docs/spec/04-orchestrator.md` — add ADR 0026 to authority and specify the
  provisional landing history contract.

## Steps

1. Draft ADR 0026 at `Status: Plan Review`, register it in the ADR index, and compare
   granular target commits, squash, and retained refs in Context, including audit,
   noise, and operational costs. Propose squash as a default to test after the M8
   harness, not as a settled benchmark conclusion. Preserve tracked plan,
   evaluation, and review evidence; explain that it cannot reproduce every
   intermediate commit. Identify extended or superseded authority and document
   containment, tree-equivalence, implementation, compatibility, optional retention,
   and later evidence-based reassessment as consequences.
2. Submit the ADR to a distinct cold plan evaluator; resolve findings and obtain PASS,
   then obtain owner acceptance and record `Status: Accepted` and the index status.
   Only then draft the spec amendments as a new planning cycle: the existing Approved
   specs remain authoritative while proposed amendments carry `Status: Plan Review`.
   Submit the amendments to a distinct cold plan evaluator and resolve findings before
   approval. Use the normal controlled-input planning evaluation path; do not assume
   bootstrap eligibility for a spec amendment.
3. Amend spec 00's authority list and non-goal as described above. Amend spec 04's
   authority list and specify the provisional contract: one candidate commit with
   the freshly fetched target base as sole parent, containing the integrated slice,
   deterministic finalization, and tracked evidence. The gate and affected reviews
   check the exact candidate tree and candidate/result SHA; target movement rebuilds
   the candidate and reruns affected checks. Preserve non-force publication, fresh
   independent remote verification, receipt binding of slice head, bases, candidate
   and result, claim recovery, configured identity, author-neutral messages, and the
   `Landed` rule. Squash does not make slice head an ancestor: define integration and
   idempotent cleanup through receipt-bound slice head and verified checked-tree
   equivalence, not slice-head ancestry; fail closed when proof is unavailable.
4. Include a mode table in spec 04: `remote-direct` publishes the checked candidate;
   `pr-per-slice` and `merge-queue` conform only if the actual provider result proves
   the same single-parent commit and checked tree, including receipt binding. A
   provider-created squash with a different SHA or base requires a rebuilt and
   rechecked candidate; if the mode cannot prove the contract, fail closed without
   switching modes. A later separately planned implementation must test all modes,
   moved-target rebuilds, containment replacement, checked-tree/receipt binding,
   incompatibility, migration, and recovery.

## Verification

- Run `node scripts/validate-repository.mjs --root . --all` and `scripts/check`.
- The authored ADR and spec 04 must each use the exact phrases below in affirmative
  contract prose. Each command must return at least one match (exit 0):
  ```sh
  for f in .docs/ADR/0026-landing-history-policy.md .docs/spec/04-orchestrator.md; do
    rg -i 'provisional default to test' "$f"
    rg -i 'sole parent' "$f"
    rg -i 'tracked evidence' "$f"
    rg -i 'remote verification' "$f"
    rg -i 'target movement' "$f"
    rg -i 'tree equivalence' "$f"
  done
  rg -i 'benchmark evidence' .docs/spec/00-overview.md
  rg '0026-landing-history-policy' .docs/ADR/README.md .docs/spec/00-overview.md .docs/spec/04-orchestrator.md
  rg 'remote-direct' .docs/spec/04-orchestrator.md
  rg 'pr-per-slice' .docs/spec/04-orchestrator.md
  rg 'merge-queue' .docs/spec/04-orchestrator.md
  ```
- Check added lines only for forbidden command or attribution text; the following
  must produce no matches (exit 1), with any other error treated as failure:
  ```sh
  git diff --unified=0 -- .docs/ADR/0026-landing-history-policy.md .docs/ADR/README.md .docs/spec/00-overview.md .docs/spec/04-orchestrator.md |
    rg '^\+[^+]' | rg -i -- '--force|co-authored-by|^(\+)(researcher|planner|developer|plan evaluator|code evaluator):'
  ```
  Include the new ADR in this diff by staging it first. Inspect matches for the
  positive checks in context for semantics; cold evaluation assesses consistency.

## Notes

ADR number 0026 is already assigned to `.docs/ADR/0026-docs-governance-plugin-prompt-doc-scope.md`.
Resolve the numbering collision with the orchestrator before drafting the decision;
this plan retains the requested paths pending that resolution.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |
| 1 | Made the policy provisional, fixed scope and sequencing, specified modes and containment, and added mechanical checks. |

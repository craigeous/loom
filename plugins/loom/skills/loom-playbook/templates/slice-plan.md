# <Slice Title>

Status: Draft
Target specs: <e.g. 03-foo.md, 05-bar.md>
Target size: <= <N> LOC net change (keep this plan document <= 250 lines)

## Context

<What exists today and what single problem this slice solves. Keep the slice
small and single-purpose; if it grows multiple unrelated goals, split it.>

## Out of Scope & Threat-Model Boundary

<What this slice explicitly does NOT change or defend against. Cite
`.docs/spec/00-overview.md` ## Non-goals where applicable (e.g., private `0700`
directory trust boundary, no hostile local inode-swapping or internal helper
monkeypatching assumptions unless a target spec explicitly requires them).>

## Steps

<Numbered, file-scoped, executable steps. Each names the file(s) it touches and the
concrete change. Include code sketches where they remove ambiguity — verified
against the real tree, not from memory.

Revision rule: when revising this plan after an evaluation FAIL or clarification,
update `## Context`, `## Out of Scope & Threat-Model Boundary`, `## Steps`, and
`## Verification` IN PLACE so the body above is always the single canonical
contract. Never append competing "## Operative contract" or "## Resolving Round N"
sections; record round deltas only in `## Revision Log` below.>

1. <step>
2. <step>

## Verification

<The exact gate that must pass, the fast targeted command(s) for developer
iteration (e.g. `bats --filter ...`), and which tests prove new behavior and guard
against regressions. For a refactor, name the existing tests that must pass
unchanged as the regression proof.>

## Notes

<Clarification requests between roles, dated. A role asks here and sets status to
Needs Clarification; the answering role replies here and the status is restored.
Resolutions are marked, not deleted. (Formal verdicts live in evaluations/, not
here.)>

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

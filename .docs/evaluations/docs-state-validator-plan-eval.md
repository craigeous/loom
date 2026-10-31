# Evaluation: Docs State Validator (slice-plan)

Verdict: FAIL
Round: 0
Commit: f5a3220
Artifact: `.docs/slice-plans/docs-state-validator.md` (Status: Plan Review)
Reviewed against: specs 00, 03, 05, 06, 08; ADR 0016; repository improvement plan
`### Slice: docs-state-validator`; `scripts/validate-repository.mjs`; plan-evaluation
rubric; severity rules. Blind review; no author context.

## Summary

The plan has the canonical structure (Target size, Out of Scope & Threat-Model
Boundary, Revision Log, 94 lines) and covers every bullet of the improvement-plan
slice. It is not yet executable by an independent reader. Steps 2–5 defer the concrete
rules to "historical compatibility" and "explicit evidence" without stating them, the
Notes section hands unresolved ambiguity to the plan evaluator, and the LOC budget
cannot hold the stated scope.

## Findings

### [BLOCKER] 1. Evaluation naming and round rules are unimplementable as written (Steps 4, Notes)

Step 4 validates evaluation names against `.docs/evaluations/<artifact-name>-eval.md`
and requires rounds from "explicit recorded evidence". The real tree has 129 files in
`.docs/evaluations/` that do not fit that pattern:

- 20 `*-plan-eval.md` files;
- `*-acceptance.md` files (ADRs 0024, 0025, 0026);
- `*-review-findings.md` companions;
- `README.md`;
- `macos-dual-client-dogfood-evidence.json`;
- dated names such as `2026-06-10-…-eval.md`.

Round history is also not uniform. `ci-baseline-eval.md` carries a "bootstrap Round 1
through Round 3" correction, "Valid merits Round 1", and a header `Round: 1` over
multi-section content. The plan does not say:

- which suffixes and companions are legal;
- how a round is read from a file (header field, per-section headings, or both);
- what "owner-authorized reset" evidence looks like;
- what the narrowly scoped "compatibility rule" is.

Notes line 86 says "Plan evaluation must resolve any ambiguity in historical artifact
formats". That moves the author's design decision onto the evaluator. The planner must
resolve it in the plan, because a developer would otherwise invent the rules.
Landing test: a developer's guess would either flag most of the existing evaluations
or silently exempt them.

Required change: add a short enumerated table in Step 4 listing the accepted filename
forms and the exact round-evidence grammar. Name the compatibility rule explicitly
(for example: only the listed historical forms are accepted, and anything else is
flagged). Delete the Notes deferral.

### [BLOCKER] 2. Status, heading, and authority rules are not enumerated (Steps 2, 5)

Step 2 says "type-specific statuses" and "where a `Status:` field is present".
Step 5 says "required headings … against their respective templates" and "historical
templates". Neither names:

- the per-type legal status sets (research, ADR, spec, plan, evaluation; `Living` and
  `Abandoned`; whether `Needs Clarification` is allowed everywhere);
- the required headings for each type;
- what counts as a "nonempty authority reference" for an ADR or a plan.

Spec 05 defines authority per type: a slice-plan's is its target specs and ADRs, an
ADR's is research or prior ADRs. Without a table the developer cannot implement it, and
an evaluator cannot check it. "Identify baseline exceptions before implementation" is
an open-ended discovery task, not a step. The plan does not say where the inventory is
recorded or who authorizes the corrections.

Required change: state the status-by-type matrix and heading and authority rule per
type inline (a compact table). Cap baseline remediation by naming the record that holds
the exception inventory.

### [MAJOR] 3. LOC budget is disproportionate to scope

`Target size: <= 250 LOC net change` must cover all of the following:

- status and transition validation, including Git baseline comparison with rename
  detection;
- round-sequence validation;
- naming checks;
- template, heading, and authority checks;
- link-scope extension with fragment resolution and an allowlist;
- the ADR fix;
- "comprehensive fixture-based Bats cases for each positive and negative rule".

That is not achievable in 250 LOC (the validator is already 658 lines). Per severity.md
proportionality, the budget and test scope must be honest or the slice split. The
improvement plan lists this as one slice, so splitting needs planner and owner
authority.

Required change: either restate a realistic LOC budget, or narrow the rules (for
example, make transitions snapshot-only plus the optional baseline, and defer the
rename and owner-reset handling). Test coverage should be stated proportionally.

### [MAJOR] 4. Edit to an accepted ADR lacks cited authority (Step 6)

Step 6 edits `.docs/ADR/0016-…md`. Accepted ADRs are immutable (CLAUDE.md; spec 03),
and severity.md treats any `ADR/` edit from a slice as a BLOCKER unless it is
authorized. The improvement plan does request this fix, and the target is a link-only
change (`../slice-plans/multi-session-lock-helper-plan.md` →
`../slice-plans/archive/…`; the archived file exists). However, the plan cites no
accepted authority that makes the edit developer-executable, such as an ADR 0025-style
owner-authorized reconciliation. It also does not state that the developer may touch
only that single link.

Required change: cite the authorizing record, and constrain the edit to that one link
with a mechanical check (`git diff` limited to that line).

### [MAJOR] 5. Extending link validation to evaluations and archived plans has unquantified blast radius (Step 5)

`validateLinks` currently excludes `.docs/evaluations/` and
`.docs/slice-plans/archive/`. Those trees hold about 130 and about 50 historical files
that have moved since they were written. The plan says to "inventory and resolve
baseline failures with explicit evidence rather than broad exclusions" but gives no
bound, no acceptance criterion for what may go in the allowlist, and no instruction on
whether to repair or allowlist. Evaluations and archived plans are historical evidence
("do not silently rewrite"). The developer would be forced to choose between mass
edits and a large allowlist.

Required change: state the policy, for example: historical-evidence files are never
edited, and stale links are recorded as allowlist entries with a documented reason.
Bound the expected count.

### [MINOR] 6. Spec 06 listed as target but unused

`Target specs` includes `06-init-modes.md`, but nothing in Context or Steps relies on
it, and Out of Scope excludes init changes. Either state which part of spec 06 applies
or drop it.

### [MINOR] 7. Verification names only the whole-file Bats run

There is no named test-case set and no `--root` fixture invocation for the baseline
argument. `--baseline <ref>` has no specified spelling, and `usage()` and its exit
code 2 are not mentioned. State the flag name and the usage text update.

## Passing checks

- Single purpose: yes (documentation-state validation).
- In-place canonical structure, Revision Log, and ≤250 lines: yes.
- Threat-model alignment with spec 00 non-goals: yes.
- Honest boundary that a snapshot run does not prove history or landing: yes.
- Verification names the gate (`scripts/check`) and the focused Bats command: yes.
- Spec 03 token set, FAIL returns, and archive transition are correctly cited.
- The ADR 0016 link target `slice-plans/archive/multi-session-lock-helper-plan.md`
  exists.

## Required for re-review

Resolve blockers 1–2 and majors 3–5 in place (Context, Out of Scope, Steps,
Verification; add a Revision Log row for Round 1).

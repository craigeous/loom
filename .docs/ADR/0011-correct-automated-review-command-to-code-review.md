# 0011 — Correct the Automated-Review Command to `/code-review`

Status: Plan Review
Date: 2026-06-10

## Context

[ADR 0010](0010-orchestrator-run-automated-review-in-code-eval.md) (Accepted)
decided that the orchestrator runs Claude Code's built-in **`/review`** and
**`/security-review`** on a slice's commit diff in "local diff mode only," feeding
identity-neutral findings to the blind code-evaluator. The `/security-review` half
is correct: it scans the **pending changes on the current branch**, locally, with
no PR.

The `/review` half is **factually wrong**. The built-in `/review` is
**"Review a pull request"** — it is **PR-bound**, not a local-diff command. ADR 0010's
"local diff mode only" framing cannot apply to it. The command that actually performs
a local code review on a diff is **`/code-review`**.

**Root cause (named honestly):** the approved research note drifted between `/review`
and `/code-review`; the plan-eval flagged this as an unresolved MINOR, and ADR 0010
standardized on `/review` — baking in the wrong, PR-bound command.

**Empirical verification (evidence for this correction).** In this repo, the built-in
`/code-review` skill was run on a local staged diff — a throwaway file with three
planted defects. It ran **with no PR**, in **default mode** (no `--comment`/`--fix`,
so **no GitHub posting**), and correctly flagged all three defects: an SQL injection,
an off-by-one `IndexError`, and a divide-by-zero. It ran from the **main/orchestrator
session**, consistent with ADR 0010's decision that the orchestrator — not the
sub-agent evaluator — runs it (the built-in `/code-review` fans out to its own agents,
which a sub-agent cannot spawn, per [ADR 0001](0001-plugin-architecture-and-orchestrator.md)).

**In scope:** correcting the command identification (`/review` → `/code-review`) and
fixing the invocation detail so "local mode" is genuinely accurate.
**Out of scope:** everything else in ADR 0010, which is **not reopened** and stands in
force. This ADR builds on ADR 0001 (only the orchestrator spawns), ADR 0004 (the
blind contract), and ADR 0003 (committed author-neutral handoffs).

## Decision

### 1. The local-diff review command is `/code-review`, not `/review`

The orchestrator's automated-review step invokes **`/code-review`** (NOT `/review`)
plus **`/security-review`**. Both run on a **local diff with no pull request and no
GitHub round-trip** — no `--comment`/`--fix`, read-only, network-silent. This replaces
ADR 0010's `/review` with `/code-review` wherever ADR 0010 named the local code-review
command; `/security-review` is unchanged.

### 2. Target the slice's commit range, not the (empty) working tree

At **`Implemented`** the slice is already **committed**, so the working-tree diff is
**empty**. The orchestrator must therefore target the slice's **commit range / branch**
when invoking `/code-review` — for example `git diff <base>...<slice-HEAD>`, or by
passing the slice branch/range as the command's target argument. `/code-review` accepts
a branch/target argument, so this is straightforward. It must **not** be pointed at the
empty working tree. Still no `--comment`/`--fix` (read-only, local). This is the
substantive new operational detail ADR 0010 lacked.

### 3. Everything else in ADR 0010 is unchanged and remains in force

This ADR corrects only the command name and adds the commit-range invocation detail.
ADR 0010's full decision otherwise stands:

- The **orchestrator** runs it (only it may spawn — ADR 0001), never the sub-agent
  code-evaluator.
- **Local-only** preserves the blind contract (ADR 0004) — no PR metadata, no GitHub
  round-trip.
- Findings reach the blind code-evaluator as **advisory input** in the committed,
  identity-neutral `.docs/evaluations/<slice-name>-review-findings.md` artifact.
- The **evaluator adjudicates and owns the verdict** via
  [`references/severity.md`](../../plugins/loom/skills/loom-playbook/references/severity.md);
  findings are not an oracle and not an auto-FAIL.
- Runs on **code-bearing diffs only**, with the docs-only skip-with-a-note.
- The four **distinguishable statuses** (ran-with-findings, ran-clean,
  skipped: docs-only, skipped: command unavailable) are retained.
- It is a **separate review dimension**, not part of the `format → lint → test` gate,
  which is unchanged.

## Scope / relationship

This ADR **supersedes ADR 0010 only on the command identification** (`/review` →
`/code-review`) and **adds the commit-range invocation detail** (Decision §2). It does
**not** revisit or reopen the rest of ADR 0010's decision, which stands unchanged —
mirroring how [ADR 0007](0007-namespaced-command-surface.md) supersedes only the
command-naming in ADR 0001 while the rest of ADR 0001 stands.

ADR 0010 stays **Accepted** and immutable (ADRs are not rewritten — they are
superseded, [ADR 0005](0005-specs-frozen-after-approval.md) discipline); this ADR is
the corrective record of decision. Read every "`/review`" in ADR 0010 — where it means
the local code-review command — as **`/code-review`**, targeting the slice's commit
range.

## Consequences

- **Supersedes (in part) ADR 0010.** Only on the command name and the invocation
  target. ADR 0010 otherwise stands.
- **Specs 04 + 02 must be amended** in a follow-on planning cycle to replace `/review`
  with `/code-review` and reflect the commit-range invocation; with this correction the
  "local mode" language becomes genuinely accurate. Both specs are Approved and frozen
  (ADR 0005), so this is a deliberate planner-authored, blind-evaluated pass — this ADR
  is the decision input.
- **Playbook follow-up** (separate build slices, sequenced after the spec amendments):
  swap `/review` → `/code-review` and add commit-range targeting in
  [`references/orchestration.md`](../../plugins/loom/skills/loom-playbook/references/orchestration.md),
  [`references/review-findings.md`](../../plugins/loom/skills/loom-playbook/references/review-findings.md)
  (the finding-entry "source command" field/example),
  [`references/code-eval-rubric.md`](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md)
  if it names the command, and
  [`agents/code-evaluator.md`](../../plugins/loom/agents/code-evaluator.md) if it names
  the command. Named as consequences; **not implemented here**.
- **Closes ADR 0010's open `/review` PR-mode question** — now moot, since the local
  command is `/code-review`, not `/review`.
- **No gate change, no new status value.** As in ADR 0010, this is a review dimension
  within the existing `Implemented → (code review) → Landed` phase.

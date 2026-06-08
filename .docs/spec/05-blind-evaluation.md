# 05 — Blind Evaluation

Status: Approved

Blind evaluation is loom's mechanism for impartial, critical review. It is
enforced by **controlling what goes into the evaluator's prompt**, not by asking
the evaluator to pretend.

## The guarantees

1. **No author identity.** The evaluator is never told who or what produced the
   artifact. Files carry no author names; the `Driver`/owner fields and any
   identity metadata are stripped from the evaluator's inputs.
2. **No author reasoning.** The evaluator never sees the author's chain of
   thought, chat, or prior drafts' rationale — only the artifact as it stands and
   the authority to judge it against.
3. **No self-review.** Role separation means the role that authored an artifact is
   structurally never the role that approves it. The orchestrator never routes an
   artifact to its own author.

Because every agent is cold and anonymous, these properties hold by construction.

## What a plan evaluator's prompt contains

- The artifact under review (research note / ADR / spec / slice-plan), verbatim,
  minus identity metadata.
- The **upstream authority** it must satisfy:
  - research note → its **cited sources** (the evaluator confirms the sources
    exist and actually support the summary);
  - slice-plan → the target spec(s) and relevant ADRs;
  - spec → its accepted ADRs;
  - ADR → the research and the problem statement it claims to resolve.
- The relevant **playbook** standards and the evaluation **rubric**.
- For a re-review: the prior eval file **and the diff** of the artifact since the
  prior version (so it can verify the required changes were made) — but not the
  author's side of any chat.

### Research review rubric (light)

Research is gated only lightly. The evaluator checks: every claim carries a
citation; the cited sources exist and are reachable; and the cited content
actually supports the summary. It is a sources-match-claims check, not a judgment
of the research's conclusions. (May run on a lower tier than full planning review
— see [09](09-open-questions.md).)

## What a code evaluator's prompt contains

- The **commit diff** for the slice (every developer pass commits, so there is
  always a precise diff to review — ADR 0003).
- The **slice-plan** it was meant to satisfy and the target spec(s).
- The **gate evidence** (which commands ran, results) and the test list.
- The playbook standards and the rubric.
- For a re-review: the prior eval file and the **diff since the prior reviewed
  commit**, to confirm prior findings were addressed.

## What is always excluded

- Author identity, role labels of the author, "who is driving."
- The author's reasoning, scratch work, or conversation with the owner.
- Any signal that would let the evaluator infer it wrote the thing.

## Verdict format

Each evaluation is written to `evaluations/<artifact-name>-eval.md`:

```markdown
# Evaluation: <artifact name>

Verdict: PASS | FAIL
Round: <n>
Reviewed against: <spec/ADR/plan files the judgment used>

## Findings
- [BLOCKER] <must fix before approval> — <where/why>
- [MAJOR]   <significant concern>
- [MINOR]   <nit / improvement>

## Required changes (for FAIL)
1. <concrete, actionable change>

## Notes
<optional reasoning the author may read when revising>
```

Severity drives the verdict: any `BLOCKER` ⇒ FAIL. The author reads the eval file
(not the evaluator) on the next cold pass and revises.

## Why this resists rubber-stamping

The classic failure — an agent going easy because it "knows" it wrote the work —
is impossible when the evaluator has no way to know authorship and never sees its
own prior reasoning. The general sycophancy failure is countered by (a) judging
strictly against an explicit authority and rubric rather than impressions, and (b)
the severity rule that makes any blocker a hard fail.

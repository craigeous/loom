# 0013 — Starvation-Loop Guards for the Orchestrator Cold-Restart

Status: Accepted
Date: 2026-06-11

## Context

[ADR 0012](0012-thin-orchestrator-sonnet-default-bounded-return.md) made the
orchestrator thin and answered context pressure with a **lossless cold self-restart**
at ~60% of budget: checkpoint to `status/handoff.md`, then re-bootstrap from the
`.docs/` status digest with a fresh window. That restart is only safe if durable
progress was recorded **before** the window cleared.

A gap remains. If the orchestrator undertakes a large operation — a heavy role spawn,
the in-window `/code-review` step ([ADR 0010](0010-orchestrator-run-automated-review-in-code-eval.md)/[0011](0011-correct-automated-review-command-to-code-review.md)),
or a long stretch of orchestrator-side work — and blows its budget (or hits the
harness's **hard auto-compact**, ~80% default, *lossy*) **before** recording
progress, the restart re-bootstraps from a **stale** `handoff.md`, re-derives the
**same** next action, repeats the operation, and clears again. The lossless restart
degrades into a lossless **infinite loop** — a starvation loop.

Because roles commit their own output ([ADR 0003](0003-cold-handoffs-commit-per-handoff.md)),
the exposed window is narrow — *orchestrator-side* work and the *in-window*
`/code-review` step — but it is real. Relevant harness constraints: Claude Code
exposes **no discrete "orchestrator restart" event** and **no `settings.json`
compaction threshold** (only the undocumented env var `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`);
the **PreCompact hook can only allow or block** a compaction, not inject instructions,
and **cannot read token counts** (only StatusLine sees remaining %).

In scope: the discipline that prevents the loop, and the contract for a mechanical
backstop. Out of scope: ADR 0012's thin-orchestrator decision (stands) and the exact
backstop **implementation** (a follow-on developer slice).

## Decision

Four discipline rules (prompt-level), plus one mechanical backstop (follow-on slice):

1. **Write-ahead checkpoint.** `handoff.md` records the **next intended action** and
   is **committed before** any large or in-window operation. The checkpoint *leads*
   the work, never trails it — so any clear (the 60% self-restart or the hard
   auto-compact) resumes from an accurate, **advancing** anchor.
2. **Restart before a big op when near budget.** A single operation can jump the
   orchestrator from ~55% to context-full in one step. Never begin an operation you
   can't finish *and record* within the remaining budget; restart first to get a
   fresh window. Staying thin (ADR 0012) is what supplies this headroom.
3. **Forward-progress guard.** On restart, if the re-derived next action is the
   **same** one that triggered the prior restart **and no new commit landed since**,
   that is a no-progress loop → **escalate (pause + summary)** via the round-limit
   contract ([spec 03](../spec/03-artifact-lifecycle.md)); never re-attempt. This
   converts an infinite loop into a single owner escalation.
4. **Lossless beats lossy.** The 60% self-restart (lossless, re-bootstrap from files)
   stays **below** the harness auto-compact (~80%, lossy backstop). **Do not** lower
   the harness threshold to 60% (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) — the ~20% gap is
   the headroom rule 2 needs. An owner may set the override to ~70 in their **own**
   environment as a tighter seatbelt; it is **never** shipped in the plugin.

5. **Mechanical backstop (follow-on slice).** Rules 1–4 are advisory — they tell a
   well-behaved orchestrator what to do but do not enforce it. loom adds a
   **PreCompact hook** that makes the write-ahead invariant **observable**: before a
   compaction, it checks whether `.docs/` has **advanced** (a new commit landed since
   the marker it recorded at the last compaction); if not, it signals the no-progress
   condition. Contract: **identity-neutral**, POSIX-sh, consistent with the existing
   `git-identity-guard.sh`; persists its last-checkpoint marker **outside** the
   tracked worktree (e.g. under `.git/` or a loom state file). **Safety constraint:**
   it must **not** hard-block an *auto*-compaction in a way that can wedge a
   genuinely-full session — a blocked auto-compact with no headroom would fail the
   session. The exact safe behavior (warn vs block; `manual`-only vs `auto`;
   block-with-remediation), the hook-event choice, and the false-positive guard are
   **deferred to the slice-plan**, gated by the shell gate (`shfmt` → `shellcheck` →
   `bats`) and code-eval.

## Consequences

- The lossless cold-restart can no longer degrade into an infinite loop: rules 1–2
  prevent it, rule 3 converts a residual failure into one owner escalation, rule 4
  keeps the lossless path ahead of the lossy backstop.
- Rules 1–4 are recorded here and already **wired** into spec 04 (*Thin-orchestrator
  invariant*) and the playbook (`orchestration.md` → *Restart safely*, `run.md`,
  `CLAUDE.md`) in the same change-set; this ADR formalizes them as durable memory.
- Rule 5 introduces loom's **second** piece of executable code (after
  `git-identity-guard.sh`) — a follow-on slice through the normal loop
  (plan → plan-eval → develop → code-eval), gated by the shell gate.
- **Builds on** ADR 0012 (cold-restart), 0003 (commit-per-handoff / files-are-truth),
  0010/0011 (the in-window review step), 0001 (orchestrator-only spawn). Supersedes
  none.
- **Open question for the slice:** because the PreCompact hook can't read token counts
  and can't distinguish loom's intended 60% restart from an unrelated compaction, its
  enforcement is necessarily coarse (commit-advanced-or-not) — the slice must validate
  it doesn't false-positive on legitimate compactions.

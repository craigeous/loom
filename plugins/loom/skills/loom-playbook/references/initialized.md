# Initialized Init

The behavior the orchestrator runs when `init-detection.md` returns
**Initialized** — a repo whose `.docs/` is already loom-shaped. Initialized is
**Resume**, not scaffold (spec `06 §3`): the playbook is already in place; the
job is to read real state, present a meaningful menu, and hand the owner into
the loop.

Authority: [`../../../../../.docs/spec/06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md) §3.
Spec `06-init-modes.md` wins on any conflict.

Precondition: `init-detection.md` has already classified this repo as
Initialized. Unlike Greenfield/Unaligned, the **resume** half writes nothing
until the owner picks an action and the driver loop runs; the **idempotent
re-application** half (Step 3 below) may write playbook-derived changes under
the merge rules detailed there.

---

## Step 1 — Build the state-derived resume menu

This is the heart of the Resume behavior (spec `06 §3`). The menu is **derived
from real `.docs/` + git state**, not a static hardcoded list.

**How to derive it:** Scan `.docs/` `Status:` lines and `git status`/`git log`
(the same inputs the driver loop uses), then cross-reference the dispatch table
in [`status-machine.md`](status-machine.md) so each offered menu item maps to a
real current status and next-actor. The offered items are:

| Menu item | Appears when | Dispatch table mapping |
|-----------|-------------|------------------------|
| **Continue an in-flight slice-plan** | A slice-plan is at `Plan Review`, `In Progress`, or `Implemented` | plan evaluator / developer / code evaluator (per dispatch table) |
| **Review pending research / ADRs / specs** | Artifacts sit at `Research Review` or `Plan Review` | plan evaluator |
| **Start a new slice from the roadmap** | No blocking in-flight slice; pull from `status/roadmap.md` | planner (new plan) |
| **Run research on a topic** | Owner-initiated; always available | researcher (seeds a `Draft` research note) |
| **Show status** | Always available | — (orchestrator summarizes `.docs/` + git state) |

Also surface `Needs Clarification` and round-limit/escalation states when
present — both are real states the dispatch table recognizes (see
[`status-machine.md`](status-machine.md)); they may require owner attention
before the loop can advance.

**The hard rule:** the menu is derived from actual current statuses, never a
static list divorced from real state. If no in-flight or pending artifacts
exist, the menu still offers "start a new slice from the roadmap" / "run
research on a topic" / "show status."

---

## Step 2 — Hand off into scope + claimed gates + the driver loop

After the owner picks a menu item:

1. The owner declares **scope + claimed gates**. Point the owner at
   [`orchestration.md`](orchestration.md) "Scope & claimed gates" for the
   vocabulary (scope values: `research` / `adr` / `plan` / `implement` /
   `slice` / `full`, or a range/combination; claimed gates: `all`, a named
   list, or none). This body does **not** restate those definitions —
   `orchestration.md` is the single source.

2. The **driver loop** then runs. The single authoritative loop is
   [`../../../commands/run.md`](../../../commands/run.md) Step 3 (steps a–g).
   This body does **not** restate the loop — `run.md` Step 3 is authoritative.
   The menu choice simply tells the loop where to start (which artifact(s) are
   in scope).

**Identity pre-flight:** before handing into the driver loop (under which roles
commit), verify a real git identity is configured per the Greenfield "Ensure a git
identity is configured" step (`greenfield.md` Step F) and `commit-convention.md`.
If absent or an `@localhost` fallback, STOP and ask the owner to configure it —
never invent an identity.

Initialized's Resume half **writes no files itself**. It routes the owner into
the existing loop, which drives the roles. Each role commits its own work
author-neutral per [`commit-convention.md`](commit-convention.md).

---

## Step 3 — Idempotent playbook re-application (Q10 merge strategy)

Re-running init on a loom-shaped repo re-applies the **current** playbook,
picking up improvements since the last init (spec `06`, "Playbook
re-application (idempotent)"). This is the section that
[`orchestration.md`](orchestration.md)'s idempotent pointer references; the
full merge strategy lives here, not inline in orchestration.md.

**Merge rules:**

- **Auto-apply** changes that merge cleanly and don't conflict with
  project-specific content.
- For anything that **conflicts or is ambiguous**, **recommend** an action and
  let the **owner decide** — never silently clobber project-specific edits.
- **Never clobber** project-specific content regardless of merge cleanliness.

**Relationship to the Greenfield / Unaligned idempotence notes:** those bodies
carry only the per-mode safety invariant and explicitly defer "full idempotent
re-application" to this body. `initialized.md` is now the full statement; the
siblings' notes are not restated here.

**Gate re-application:** re-application that would touch the gate hands to
[`gate-learning.md`](gate-learning.md) for unknown stacks — re-application only
re-applies what the current playbook already knows (verified gates), under the
never-clobber rule.

---

## Idempotence / scope-boundary note

**Gate-learning is out of scope for this body.** The Initialized body does not
establish or learn a gate on its own. An evaluator should not read the
re-application step above as having absorbed gate-learning — it has not. When
re-application encounters an unknown stack, it hands to
[`gate-learning.md`](gate-learning.md) — the single authoritative mechanism for:
inspect tooling, propose commands, confirm with the owner, run green once, record
a new `gates/<stack>.md`. See that body (per spec `06` Gate establishment 2nd
bullet, as in `greenfield.md` Step E / `unaligned.md` Step 2).

# 04 — Orchestrator

Status: Draft

## What the orchestrator is

The orchestrator is **the main, interactive Claude Code session that runs when you
invoke `/loom:run`.** The `commands/run.md` body is its operating instructions. It is
not a sixth role and not a sub-agent — it is the session you are talking to, and it
is the only actor that holds the Task tool and can **spawn role sub-agents**.

This resolves the "agents can't call agents" constraint: that limit only applies to
*sub-agents*. The orchestrator (main session) spawns every role. So:

> "Role A calls role B" ≡ "Role A finishes, sets a status, and commits; the
> orchestrator observes that status and spawns role B."

The orchestrator is the switchboard for every handoff. This is exactly how
Anthropic's own `feature-dev` plugin is built.

## The driver loop

```
start(scope, claimed_gates)
  ├─ determine init mode (see 06) and act
  ├─ if greenfield/owner-directed: gather intent, optionally run researcher/planner
  └─ loop:
       state = scan(.docs/ statuses + git)          # files + commits are truth
       action = next_action(state, scope)           # dispatch table (see 03)
       if action == none or out_of_scope: break
       if transition is an owner-claimed gate:
            pause → show artifact + verdict → await owner decision
       agent = spawn_cold(role, tier, inputs, worktree?)   # via Task tool
       wait(agent)                                   # agent works, commits, sets status
       # (the agent committed; orchestrator need not write files itself)
  └─ on break: summarize to owner; ensure status/handoff.md reflects the next step
```

Key properties:

- **Cold every time.** Each role is a fresh agent given only the files/prompt it
  needs. Between calls, the only state is `.docs/` + the repo + git history.
- **Files and commits are truth.** The orchestrator re-scans after every agent, so
  an interrupted loop resumes from the last commit.
- **Right tier per role** (see [02](02-roles.md)).

## Scope (declared by the owner at kickoff)

Scope bounds the driver loop — how far this session goes. Examples:

- `research` — only the researcher (+ its review) on a topic.
- `adr` — through an accepted ADR.
- `plan` — through approved spec + slice-plan(s), no implementation.
- `implement` — take an approved slice-plan through landed code.
- `slice` — a full single-slice pass: plan → evaluate → implement → evaluate →
  land.
- `full` — keep running slices toward the roadmap target until a checkpoint.
- **ranges / combinations** — e.g. "plan and implement one slice but stop before
  landing." When scope spans roles, the orchestrator chains them automatically;
  this is what "agents calling agents" means in practice.

## Approval gates (declared by the owner at kickoff)

By default **evaluator approval is sufficient** to advance. At kickoff the owner
claims gates: either **`all`** (pause before every advance) or a **named list**
(e.g. "every ADR" and "before any code lands"). At a claimed gate the orchestrator
pauses, shows the artifact + the evaluator's verdict, and waits for the owner.

## Parallelism (designed-for; built after the sequential loop)

The orchestrator can launch **multiple role sub-agents at once**, each in the
**background** and each in its own **git worktree** — without any agent-to-agent
calls. This gives parallel slices safely:

- Each in-flight slice gets its **own branch + worktree** → no file clobbering.
- The orchestrator runs e.g. `developer` on slice A and `developer` on slice B
  concurrently, each isolated; as each reaches `Implemented`, it fires a
  `code-evaluator` for each.
- The orchestrator remains the single hub, keeping the status machine and blind
  routing coherent.
- **`.docs/` coordination across branches** (status dashboard on the main branch
  vs. per-slice plan/eval on slice branches) is an open question to settle when
  parallelism is built — see [09](09-open-questions.md).

**`claude -p` fallback:** a sub-agent with `Bash(claude:*)` can shell out to a
headless `claude -p` to spawn a peer agent. Kept in reserve for deep nesting;
the worktree approach is primary because it is more observable and controllable.

## Human checkpoints

The loop pauses and returns to the owner when: the scope boundary is reached; an
owner-claimed gate is reached; an artifact exceeds the round limit (escalation =
pause + summary, see [03](03-artifact-lifecycle.md)); or a role reports it cannot
proceed without owner input. On every pause the orchestrator ensures
`status/handoff.md` reflects the next step.

## One-off invocation

Each role is also runnable directly ([07](07-command-surface.md)). A one-off is a
single cold-agent pass: read files, do the job, write/commit, set status, return —
without the orchestrator chaining the next role.

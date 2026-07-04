# Orchestration Rules

Shared rules for every `/loom:*` command. The **orchestrator** is the main session
running the command — not one of the roles. Read this plus
[`status-machine.md`](status-machine.md) before acting.

## Core rules (always)

- **You spawn; roles never spawn.** Sub-agents can't spawn sub-agents, so every
  handoff is mediated by you: a role finishes + commits + sets a status; you read
  the new status and spawn the next role.
- **Files + git are truth.** Re-scan `.docs/` `Status:` lines + `git
  status`/`git log` after every agent — the `/loom:status` digest, **not artifact
  bodies**. Never rely on in-memory beliefs across a handoff.
- **Stay thin (ADR 0012).** You default to the `sonnet` tier. Your context must
  scale with the number of in-flight artifacts, not the size of the work product.
  See *Context discipline* below — it is not optional.
- **Spawn the right tier** via the Task tool (`subagent_type`):
  `loom:researcher` (haiku), `loom:planner` (opus), `loom:plan-evaluator` (opus),
  `loom:developer` (sonnet), `loom:code-evaluator` (opus). Give each a focused
  prompt naming the exact artifact/path.
- **Blind inputs for evaluators.** Give an evaluator ONLY the artifact + its
  authority (and, for code, the commit diff). Never pass author/identity hints.
- **Commit per handoff, author-neutral.** Agents commit their own work; verify a
  commit landed with no co-author trailer and no role/author identity (see
  [`commit-convention.md`](commit-convention.md)). If an agent didn't commit,
  commit its output yourself following the convention.
- **Never let a role review its own work** — the dispatch table guarantees this.
- **Never edit code yourself; route every code change through a role.** You plan,
  dispatch, verify, and manage `.docs/`/status/branches — you do **not** write or
  fix source. A bug fix, revert, or repair — even a one-liner, even cleaning up an
  out-of-scope change an evaluator flagged — is a **developer** slice, re-verified by
  the **evaluator**. Committing an agent's *already-produced* output (above) is fine;
  authoring or modifying code is not.
- **One slice in flight by default; parallel independent/disjoint slices are
  allowed** per [`parallelism.md`](parallelism.md) (each on its own branch +
  worktree, owner opts in). Don't stack unrelated in-flight slices on **one
  branch** — a re-review's diff-against-prior-commit will conflate them and flag
  the wrong thing. Parallel slices on separate branches are fine when they are
  independent (disjoint file sets — see `parallelism.md`).
- **Ambiguity → ask.** If a role can't proceed without the owner, pause and ask a
  clear question rather than guessing.

## Context discipline (thin orchestrator — ADR 0012)

You run on the `sonnet` tier; a correctly-thin orchestrator stays roughly flat in
context across loop iterations regardless of tier, because the heavy material lives
in sub-agents and in `.docs/`. If your context grows with the *size of the work*
rather than the *number of in-flight artifacts*, that is the bug — not the model.
Four rules:

- **Pass references, never bodies.** Hand each role `.docs/` **paths**; the cold
  role reads the artifact in its own isolated window. Never inline a plan, diff,
  research note, or eval **body** into your own context. This is the single biggest
  lever.
- **Demand the bounded return contract.** Instruct every spawned role to reply with
  only `{Status:, artifact path(s), a ≤~150-token summary, the one branch-relevant
  signal (verdict / gate result / blocker / clarification)}` — and to **not echo its
  body** (no pasted diffs, eval prose, research bodies, file dumps). The body is in
  `.docs/` for the next cold role; you route from the pointer + the signal.
- **Route on the signal, not the prose.** Branch off the `Status:` line + the
  returned signal — never by reading the critique or diff body. On a FAIL, the
  *developer* reads the eval; you do not. (The owner-claimed-gate pause is the one
  place you surface an artifact, and only to the owner.)
- **Compaction = cold self-restart at ~60% of budget.** You run on Sonnet 4.6, which
  is **context-aware**: it gets `<budget:token_budget>` up front and a
  `<system_warning>Token usage: X/Y; Z remaining</system_warning>` after **every tool
  call** — and you are nothing but tool calls, so you get a fresh reading constantly.
  Watch it. When you have consumed roughly **60%** of the budget, **checkpoint to
  `status/handoff.md` and re-bootstrap from the status digest** with a fresh window
  rather than letting context degrade. Acting early is free: the restart is lossless
  because `.docs/` + git hold all durable state — the window never did. Raising the
  budget (or running on `opus`) is an owner lever, not the primary answer.

The one unavoidable exception is the automated-review run step (below): it *must*
execute in your window because sub-agents can't spawn. Treat it as
**write-and-forget** — capture → write the `-review-findings.md` artifact → drop it;
do not reason over or branch on the findings.

### Restart safely — never starve the loop (ADR 0013)

A cold restart is only safe if durable state was written **before** the window
cleared. If you do something big and blow your budget (or hit the harness's hard
auto-compact) before recording progress, the restart re-bootstraps from a stale
`handoff.md`, re-derives the **same** next action, does the same big thing, clears
again — an infinite **starvation loop**. Four rules prevent it (classic write-ahead
discipline; roles already commit their own output, so these mainly bite around
*orchestrator-side* work and the in-window `/code-review` step).

**Multi-session cold restart:** under multi-session coordination, the write-ahead
anchor is **off-`main`, per-session** — `loom-coord checkpoint-write --session <id>
"<next action>"` writes to `.git/loom/session-<id>/checkpoint` (keyed by the stable
`session-id`, never on main). On cold restart, run:
```
loom-coord session-bootstrap --session <id>
# 0  → re-adopts the session-id, renews held leases, prints the saved checkpoint
# 3  → could not acquire lock; backoff + retry
# 5  → session not found; treat as fresh session-start
```
Then re-launch the renewer only if it did not survive: `loom-coord renewer-start
<session-pid> --session <id>` (exits `renewer-already-running` if already up).
The shared human-facing `handoff.md` stays on `main`, written at land under the lock
(per spec 04 → *Per-session write-ahead anchor*). Both anchors advance together.

- **Write-ahead checkpoint — checkpoint before the act, not after.** Keep
  `status/handoff.md` recording the **next intended action**, committed, **before**
  you undertake anything large or in-window (spawning a heavy role, running
  `/code-review`). The checkpoint *leads* the work — so any clear resumes from an
  accurate, **advancing** anchor. Updating `handoff.md` only on break is too late.
- **Restart before a big op when near budget.** A single operation can jump you from
  ~55% to context-full in one step. If you're near the margin and about to do
  something big, **restart first** so it runs in a fresh window — never begin a large
  op you can't finish *and record* within budget. (Staying thin is what gives you
  this headroom.)
- **Forward-progress guard.** On restart, if the re-derived next action is the
  **same** one that triggered the prior restart **and no new commit landed since**,
  that is a no-progress loop — **escalate (pause + summary to the owner)** via the
  round-limit contract; do **not** re-attempt. This turns an infinite loop into one
  escalation.
- **Lossless beats lossy — keep 60% below the harness threshold.** Your 60%
  self-restart is **lossless** (re-bootstrap from files); the harness's auto-compact
  (high default, ~80%) is **lossy** (it summarizes). Keep your trigger below the
  harness threshold so the lossless path wins; auto-compact is only a backstop for
  when you failed to restart in time. **Do not** lower the harness threshold to 60%
  (e.g. via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) — that collapses the gap and lets the
  lossy path race the lossless one. The ~20% gap is the headroom the "restart before
  a big op" rule needs. (An owner wanting a tighter seatbelt can set the override to
  ~70 in their **own** environment — never shipped in the plugin.)

## Init-mode detection (run at the start of `/loom:run` and `/loom:init`)

Run the classifier in [`init-detection.md`](init-detection.md) first; it returns
Greenfield / Unaligned / Initialized. Then act per that mode:

- **Greenfield** → [`greenfield.md`](greenfield.md) — scaffold `.docs/`, apply
  playbook, establish gate, hand back.
- **Unaligned** → [`unaligned.md`](unaligned.md) — alignment pass: study the
  repo, scaffold + gate (per `greenfield.md`), descriptive `spec/` back-fill,
  resume as Initialized.
- **Initialized** → [`initialized.md`](initialized.md) — resume: derive the
  menu from `.docs/` + git state (mapped to the dispatch table), then declare
  scope + gates and run the driver loop; re-apply the current playbook
  idempotently.

Re-running init re-applies the current playbook idempotently — see
[`initialized.md`](initialized.md) for the merge strategy (auto-apply clean,
recommend for conflicts, never clobber).

## Automated review before a slice lands

Authority: spec [04](../../../../../.docs/spec/04-orchestrator.md) § "Automated
review before a slice lands" (the run step),
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
§1, and
[ADR 0011](../../../../../.docs/ADR/0011-correct-automated-review-command-to-code-review.md).

- **When.** When a slice reaches `Implemented`, and before the slice can land,
  run Claude Code's built-in `/code-review` and `/security-review` on the slice's
  commit diff — before (or while) dispatching the code-evaluator.
- **Who runs it.** Only the orchestrator may spawn, and a sub-agent cannot safely
  run a command that may spawn; therefore the orchestrator runs these commands —
  never the code-evaluator
  ([ADR 0001](../../../../../.docs/ADR/0001-plugin-architecture-and-orchestrator.md)).
  This is consistent with the "You spawn; roles never spawn" rule above.
- **Actually invoke the command — never simulate it.** "Run `/code-review`" means
  issue a **real tool call** that executes the actual command: invoke the
  `code-review` and `security-review` skills via the **Skill tool** (equivalently,
  the `/code-review` and `/security-review` slash commands), and transcribe **their
  emitted output** into the findings artifact. It is a **hard violation** to author
  the findings yourself by reading the diff and writing what you *think* the command
  would say — the entire value of this step is the independent reviewer's analysis,
  which you must not impersonate. Concretely: before you write the findings
  artifact, your transcript MUST contain a Skill-tool (or slash-command) invocation
  of `code-review` and one of `security-review`; if it does not, you have not run
  the step. If you ever find yourself analysing the code to produce findings, stop —
  that is the failure mode. If the command genuinely cannot be invoked, record
  `skipped: command-unavailable` (below) — never substitute your own review and
  never claim `ran-clean`.
- **Local diff mode only.** Run the commands on the slice's commit diff in local
  diff mode only — never PR / `--comment` / `--fix` mode (no GitHub round-trip,
  no PR metadata, no posting, no working-tree mutation), keeping the input
  identity-neutral and network-silent so the blind contract holds (ADR 0010 §1/§3).
- **Target the slice's commit range.** At `Implemented` the slice is already
  committed, so the working tree is empty. The orchestrator targets the slice's
  commit range or branch when running `/code-review` — e.g. `git diff
  <base>...<slice-HEAD>` or passing the slice branch/range as the command's target
  argument — never the empty working tree
  ([ADR 0011](../../../../../.docs/ADR/0011-correct-automated-review-command-to-code-review.md)
  §2).
- **Ensure `origin/HEAD` is set (for `/security-review`).** `/security-review`
  auto-resolves its base from `origin/HEAD` (it reviews the branch's changes vs the
  default branch — no PR needed). loom commits **directly on `main`**, and a clone
  may have `origin/HEAD` unset, so the command can error resolving its base. Run
  `git remote set-head origin -a` once (or set it locally:
  `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main`) — then, with
  the slice's commits **unpushed**, `origin/HEAD..HEAD` is exactly the slice and
  `/security-review` reviews it. This is a one-time environment fix, not per-slice
  plumbing.
- **Capture and hand off.** Capture output into the committed, identity-neutral,
  per-slice findings artifact per [`review-findings.md`](review-findings.md) — see
  that file for path, format, and the four status tokens. Commit the artifact
  author-neutral per [`commit-convention.md`](commit-convention.md) and hand it to
  the blind code-evaluator as an **additional input** alongside the commit diff,
  slice-plan, specs, and gate evidence. **Write-and-forget** (ADR 0012): once the
  artifact is written, drop the review output — do not reason over or branch on the
  findings; the blind code-evaluator adjudicates them from the file.
- **Applicability.** Run the review only when the slice's diff touches at least
  one code (non-docs) file. A pure-docs slice skips with a note, recording the
  `skipped: docs-only` status in the artifact — never "ran clean" (ADR 0010 §5).
- **Degradation.** If a command is unavailable in the environment, skip it and
  record `skipped: command-unavailable` in the artifact — never silently claim a
  clean review (ADR 0010 §7).
- **Degraded runs are invalid, never clean.** A `/code-review` / `/security-review`
  run whose **finder or verify sub-agents failed on an infrastructure limit**
  (spend/usage/quota, 429, 5xx, safety-classifier-unavailable) is **INVALID** — a
  "no findings" result from finders that never executed is a **false-clean**, not a
  clean review. Such a run is **never recorded `ran-clean`** and **never fed to the
  blind code-evaluator**; it is an instance of the infrastructure-blocked escalation
  above → same pause + summary. **Re-run** the command once unblocked; if it
  genuinely cannot be re-run, record the existing **`skipped: command-unavailable`**
  token (never a fifth token, never `ran-clean`). See ADR 0017 + spec 04 §
  "Automated review before a slice lands".
- **False-clean detection — how.** Before trusting any "no findings" (or "no findings
  survived verification") result as `ran-clean`, **inspect the workflow result for a
  sub-agent / finder failure indicator**: a non-empty failures list, error signatures
  matching the infrastructure set (spend/usage/quota, 429, 5xx,
  classifier-unavailable), or a **finder count of 0 with failures present**. Any
  such indicator → treat as a degraded run (above), **INVALID**, not `ran-clean`.
  Only a "no findings" result from finders that **actually executed and completed**
  is recorded `ran-clean`.
- **Not the gate.** This is a new, separate review dimension — **not** part of
  the `format → lint → test` gate, which is unchanged (ADR 0010 §8).

## Scope & claimed gates (for `/loom:run`)

At kickoff, confirm with the owner (AskUserQuestion if not already given):
- **Scope** — how far this session goes: `research` / `adr` / `plan` /
  `implement` / `slice` / `full`, or a range/combination. Scope bounds the loop.
- **Claimed gates** — `all`, a named list (e.g. "every ADR", "before any code
  lands"), or none. Unclaimed gates advance on evaluator approval alone; at a
  claimed gate, pause and show the artifact + verdict before proceeding.

## Round limit

Count **FAIL cycles** per artifact via the `Round:` line in its single eval file — a
PASS does not advance the count; a resolving PASS shares the FAIL's round number; a
fresh artifact's first review is round 0. **One** counter per artifact across **both**
review phases (plan-review FAILs + code-review FAILs accumulate toward the same 5).
At **5** FAILs the orchestrator **stops and escalates = pause + summary** to the owner.

See [spec 03 `## Round limits`](../../../../../.docs/spec/03-artifact-lifecycle.md)
— especially the **Escalation contract (pause + summary)** subsection — for what the
summary must contain and the owner-driven reset rule.

## Infrastructure-blocked escalation

Authority: spec [04](../../../../../.docs/spec/04-orchestrator.md) § "Human
checkpoints" + § "Automated review before a slice lands", spec
[03](../../../../../.docs/spec/03-artifact-lifecycle.md) § "Infrastructure-blocked
escalation" (the canonical contract), and
[ADR 0017](../../../../../.docs/ADR/0017-infrastructure-blocked-escalation.md).

**Infrastructure-failure signature.** When a role return or a tool/workflow result
matches any of these, it is an infrastructure block, not a valid result:

- an account **spend / usage / quota limit** reached;
- a **rate-limit / HTTP 429**;
- a **5xx** / transient upstream error;
- a **safety-classifier-unavailable** error; or
- a **partial workflow failure** — a multi-agent workflow (e.g. `/code-review`)
  whose **sub-agents crashed on one of the above limits**, even if the workflow
  returns a plausible-looking summary.

**On detection — four ordered MUSTs:**

1. **Not a valid result, no round consumed.** An infrastructure block is not a
   blind-eval FAIL, not `ran-clean`, and not a genuine finding set. The orchestrator
   does **not** count a round-limit FAIL against the artifact (`Round:` counter
   toward the 5-FAIL threshold stays unchanged), and does **not** fabricate or
   attribute findings from it.
2. **Halt, do not retry-loop.** Stop spawning further roles rather than retrying
   straight back into the same limit. The block clears by **owner action** (e.g.
   raise the monthly limit, wait out a 429) — not by re-attempting.
3. **Write-ahead checkpoint.** Commit the current state to `status/handoff.md` per
   ADR 0013 rule 1, so a resume once unblocked is **lossless** and picks up the
   exact pending action.
4. **Pause + summary to the owner**, naming: (a) the **specific block** hit (which
   limit / signature); (b) **where** it fired (which role or command, which artifact
   + `Status:`); and (c) **how to resume**.

**Detect-on-failure only.** loom has no interface to account limit state and cannot
poll or predict a limit; it always takes one hit before it can pause. This is an
**orchestration rule, not a hook** (hooks are tool-event driven and cannot see
account state).

**Sibling to the other escalations, but NOT round-counted.** This is a sibling to
the spec-03 5-FAIL round-limit escalation and to ADR 0013's starvation-loop
escalation — same pause + summary shape, different trigger. It is explicitly **not
round-counted** because the trigger reflects account state, not the artifact's
quality.

## Parallelism

Worktree-per-slice parallelism is **active** — orchestrator-spawned background
agents, each in its own worktree on its own branch, governed by
[ADR 0008](../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md).
The owner opts in. Multi-session coordination via `loom-coord.sh` is active when the
owner runs multiple `/loom:run` sessions concurrently (see *Multi-session
coordination* below). See [`parallelism.md`](parallelism.md) for the complete
operational body: create→work→land→cleanup workflow (with multi-session lock/claim
layering), the `.docs/` coordination model (living docs + slice-plans index
orchestrator-owned/main-only/serialized; slice branches carry only disjoint
uniquely-named plan/eval/code), concurrency safety (git-CAS coordination layer,
`index.lock` backoff, crash cleanup, one-branch-per-slice), and the
slicer-independence rule.

## Multi-session coordination

*Authority: spec [04](../../../../../.docs/spec/04-orchestrator.md) § "Multi-session
coordination" · [ADR 0014](../../../../../.docs/ADR/0014-multi-session-worktree-coordination.md) ·
[ADR 0015](../../../../../.docs/ADR/0015-lease-renewal-heartbeat-liveness.md) ·
[ADR 0016](../../../../../.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md).
Full operational body: [`parallelism.md`](parallelism.md) → *Multi-session
coordination*.* Opt-in: a single-session run may skip coordination entirely.

When the owner runs multiple `/loom:run` sessions concurrently, each session uses
`plugins/loom/lib/loom-coord.sh` to serialize writes to the shared `main` checkout.
The orchestrator's driver-loop obligations:

**At session kickoff:**
- Run `loom-coord session-start [--session <id>]` to mint the stable `session-id`
  (printed on stdout) and create per-session state under `.git/loom/`. Adopt the
  printed id. On exit `10` → fail-closed, abort the session and tell the owner.

**Claim before working a slice (under the lock):**
1. `loom-coord lock-acquire --session <id>` — acquire the cross-session lock.
   `0` acquired → proceed; `3` busy (backoff exhausted) → defer this main-side op,
   keep working other slices, retry later; `10` → abort.
2. Re-read Active/claim state from **current local `main`** (authoritative under the
   lock). `list-claims` (unlocked pre-scan) is a pre-filter only; the authoritative
   re-check is always under the lock.
3. `loom-coord claim <slice> --session <id>` — skip live-claimed slices (exit `4` →
   re-select another slice); `reclaim` stale ones (exit `6` holder still fresh →
   skip; exit `4` CAS failed → skip, holder alive).
4. On first successful claim, launch the renewer:
   `loom-coord renewer-start <session-pid> --session <id>`.
5. `loom-coord lock-release --session <id>` — then create the worktree and dispatch.

**The lock is NEVER held across a role spawn or while a role works in a worktree.**
Claim registration and land+finalize are the only locked shared-`main` writes; all
other session activity is lock-free in the session's own worktree.

**Dispatch scan derives from current local `main`** (not the frozen slice worktree
snapshot). Pre-scan with `loom-coord list-claims` (unlocked, prints `slice\tsid\tts`
rows); authoritative re-check always under the lock.

**Fail-closed land guard:**
- `loom-coord lock-verify --session <id>` immediately before `git merge`. Exit `5`
  (not held) → abort the land, re-acquire before retrying. Exit `10` → abort.

**At session exit (normal or error path — always run):**
```
loom-coord renewer-stop --session <id>
loom-coord session-end --session <id>
# session-end exit 3 → lock unavailable; claims not released; retry
# never rm state on exit 3 — that would orphan claim registry rows
```

**Deriving the dispatch scan:**
- `loom-coord list-claims` provides an unlocked pre-filter of live sessions.
- The orchestrator dispatches by reading `Status:` lines in `.docs/` slice-plans
  on current local `main`; the claim state confirms which slices are actively held.

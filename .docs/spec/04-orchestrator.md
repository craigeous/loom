# 04 — Orchestrator

Status: Plan Review

## What the orchestrator is

The orchestrator is **the main, interactive Claude Code session that runs when you
invoke `/loom:run`.** The `commands/run.md` body is its operating instructions. It is
not a sixth role and not a sub-agent — it is the session you are talking to, and it
is the only actor that holds the Task tool and can **spawn role sub-agents**. It
defaults to the **`sonnet`** tier (ADR 0012) — orchestration is instruction-
following, role/tool selection, and status routing, not the judgment-heavy work
that reserves `opus` for the planner and evaluators.

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
  an interrupted loop resumes from the last commit. The re-scan reads `Status:`
  lines + git (the `/loom:status` digest) — **not artifact bodies**.
- **Right tier per role** (see [02](02-roles.md)).

## Thin-orchestrator invariant (ADR 0012)

The orchestrator's context must scale with the **number of in-flight artifacts**,
not the **size of the work product** — roughly flat across loop iterations,
regardless of the backing tier. Four rules hold the line:

- **Pass references, never bodies.** Hand each role `.docs/` **paths**; the cold
  role reads the artifact in its own isolated window. The orchestrator never inlines
  a plan, diff, research note, or eval **body** into its own context. This is the
  single biggest lever — it is the difference between context scaling with the work
  product and scaling with the number of steps.
- **Honor the bounded return contract.** A role replies with only `{Status:,
  artifact path(s), ≤~150-token summary, the one branch signal}` — never its body
  (spec [02](02-roles.md) — *Bounded return*).
- **Route on the signal, not the prose.** Branch off the `Status:` line + the
  returned verdict/gate/blocker — never by reading the critique or diff body. The
  full eval text stays in `.docs/` for the next cold role; the orchestrator routes
  from the pointer and the verdict. (The owner-claimed-gate pause below is the one
  place an artifact is surfaced, and only to the owner.)
- **Compaction is a cold self-restart, not a lossy summary.** Because `.docs/` + git
  are truth, the orchestrator checkpoints to `status/handoff.md` and **re-bootstraps
  from the status digest**, continuing with a fresh window — a perfect reset, since
  the durable state was never in the window. Sonnet 4.6 is **context-aware** (it
  receives a running `Token usage … remaining` signal after each tool call), so the
  orchestrator self-triggers the restart at a budget threshold — operational default
  **~60%**, set in the playbook — rather than waiting for a numeric auto-compact
  threshold to fire. Raising the orchestrator's budget (or running it on `opus`) is
  an owner lever, not the primary answer. The restart is only safe if progress was
  recorded **before** the window cleared, so the orchestrator uses **write-ahead
  checkpointing** ([ADR 0013](../ADR/0013-starvation-loop-guards-cold-restart.md):
  commit the next intended action to `handoff.md` *before* a large
  or in-window operation; restart *before* a big op when near budget) and a
  **forward-progress guard** (a restart that re-derives the same action with no new
  commit since is a starvation loop → escalate, never re-attempt). The 60% self-
  restart is **lossless** and stays *below* the harness's lossy auto-compact, which
  is only a backstop. See the playbook (`orchestration.md` → *Restart safely*) for
  the operative rules.

## Automated review before a slice lands

When a slice reaches **`Implemented`**, before (or while) dispatching the
code-evaluator and **before the slice can land**, the orchestrator runs Claude
Code's built-in **`/code-review`** and **`/security-review`** on the slice's commit
**diff** ([ADR 0010](../ADR/0010-orchestrator-run-automated-review-in-code-eval.md),
[ADR 0011](../ADR/0011-correct-automated-review-command-to-code-review.md)).
The orchestrator runs them — never the code-evaluator — because only the
orchestrator may spawn and a sub-agent cannot safely run a command that may spawn
([ADR 0001](../ADR/0001-plugin-architecture-and-orchestrator.md)).

- **Local diff mode only.** Never PR / `--comment` / `--fix` mode — no GitHub
  round-trip, no PR metadata, no working-tree mutation — so the input stays
  identity-neutral and network-silent and the blind contract holds
  ([ADR 0004](../ADR/0004-blind-evaluation-role-separation.md)).
- **Target the slice's commit range.** At `Implemented` the slice is already
  committed, so the working tree is empty; the orchestrator targets the slice's
  **commit range / branch** when running `/code-review` (e.g. `git diff
  <base>...<slice-HEAD>` or passing the slice branch/range as the command's
  target), never the empty working tree
  ([ADR 0011](../ADR/0011-correct-automated-review-command-to-code-review.md) §2).
- **Findings artifact (write-and-forget).** This is the one step that *must* run in
  the orchestrator's own window (sub-agents can't spawn — ADR 0001), so it is the
  one place review output enters that window. The orchestrator captures the output
  into a committed, author-neutral, identity-scrubbed, per-slice file
  `.docs/evaluations/<slice-name>-review-findings.md` (companion to the slice's
  `-eval.md`), hands it to the blind code-evaluator as an additional input, and then
  **drops it** — it does not reason over, re-summarize, or branch on the findings
  text; the blind code-evaluator adjudicates them from the file (ADR 0012).
- **Applicability.** Run only when the slice's diff touches at least one code
  (non-docs) file; a pure-docs slice **skips with a note**.
- **Explicit status.** The artifact records a distinguishable status —
  ran-with-findings / ran-clean / skipped: docs-only / skipped: command
  unavailable. A skip is never confusable with a clean review; if a command is
  unavailable the orchestrator skips and records it, never silently claiming clean.
- **Degraded runs are invalid, never clean**
  ([ADR 0017](../ADR/0017-infrastructure-blocked-escalation.md)). A `/code-review`
  or `/security-review` run whose **finder or verify sub-agents failed on an
  infrastructure limit** (spend/usage/quota, 429, 5xx, safety-classifier-unavailable)
  is **INVALID** — a "no findings" result from finders that never executed is a
  **false-clean**, not a clean review. Such a run is **never recorded `ran-clean`**
  and **never fed to the blind code-evaluator** as review input; extending the
  review faithfulness invariant (ADR 0010/0011), it is an instance of the
  infrastructure-blocked escalation ([03](03-artifact-lifecycle.md)) and triggers the
  same pause + summary. The orchestrator **re-runs the command once unblocked**. If a
  limit-killed run genuinely cannot be re-run, it is recorded as a **non-run** under
  the existing token **`skipped: command-unavailable`** — the command effectively
  could not complete in this environment — and **never** as `ran-clean`. This
  **reuses** the four-token contract in
  [`review-findings.md`](../../plugins/loom/skills/loom-playbook/references/review-findings.md)
  rather than adding a token: a limit-crashed run maps to
  `skipped: command-unavailable`.
- **False-clean detection — how.** Before trusting any `/code-review` /
  `/security-review` "no findings" (or "no findings survived verification") result as
  `ran-clean`, the orchestrator MUST inspect the workflow result for a **sub-agent /
  finder failure indicator**: a non-empty failures list, error signatures matching
  the infrastructure set (spend/usage/quota, 429, 5xx, classifier-unavailable), or a
  **finder count of 0 with failures present**. If any such indicator is present, the
  "clean" result is treated as a **degraded run** (above) — **INVALID**, not
  `ran-clean`. Only a "no findings" result from a run whose finders **actually
  executed and completed** is recorded `ran-clean`.
- **Not the gate.** This is a new, separate review dimension — **not** part of the
  `format → lint → test` gate, which is unchanged.

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
- **`.docs/` coordination across branches** follows the hybrid model decided in
  [ADR 0008](../ADR/0008-parallel-docs-coordination-worktree-per-slice.md) (the
  authority for detail):
  - The three living docs (`roadmap.md`, `progress.md`, `handoff.md`) **and the
    slice-plans index `slice-plans/README.md`** are **orchestrator-owned,
    main-only, and serialized** — a slice branch never edits them.
  - Each slice branch carries only its **uniquely-named** plan file
    (`<slice>-plan.md`), eval file (`<slice>-eval.md`), and its code. These path
    sets are disjoint across slices by construction, so `.docs/` merge conflicts
    cannot arise.
  - Landing is a **serial merge + finalize on main**: the orchestrator merges one
    slice (bringing only its disjoint files), runs the finalize pass on main to
    update the living docs and move the slice's index entry Active → Archived,
    then merges the next.
  - **Concurrency safety:** `index.lock` collisions retried with exponential
    backoff; crashed worktrees reclaimed via `git worktree remove -f` / `git
    worktree prune`; one checkout per branch (each in-flight slice = one unique
    branch in one worktree).
  - **Slicer-independence rule:** only slices that touch **disjoint source files**
    run in parallel; overlapping or mutually dependent slices are **sequenced**.

**`claude -p` fallback:** a sub-agent with `Bash(claude:*)` can shell out to a
headless `claude -p` to spawn a peer agent. Kept in reserve for deep nesting;
the worktree approach is primary because it is more observable and controllable.

### Multi-session coordination (ADR 0014, ADR 0015, ADR 0016)

Everything above assumes a **single** orchestrator session — which is exactly what
makes ADR 0008's "main-only, serialized" true *by construction*. The owner may
instead run **multiple independent top-level `/loom:run` sessions** against the same
repository at once, each its own thin orchestrator (ADR 0012) that cold-restarts
independently (ADR 0013). With N sessions nothing serializes one session's `main`
writes against another's.
[ADR 0014](../ADR/0014-multi-session-worktree-coordination.md) (the authority for
detail) **extends — does not replace** — the ADR 0008 model above so that
"serialized on main" holds *across* sessions. Every single-orchestrator guarantee
above remains intact; the following adds the cross-session layer.
[ADR 0015](../ADR/0015-lease-renewal-heartbeat-liveness.md) supersedes ADR 0014
**on the liveness signal only** — a session's liveness is now **lease freshness** (a
renewal heartbeat within the TTL), **not** worktree-list membership and **not** the
process pid; every other ADR 0014 decision below stands unchanged.
[ADR 0016](../ADR/0016-git-native-ref-cas-lock-mechanism.md) supersedes ADR 0014
**on the lock/claim *substrate* only** — the concrete atomic primitive under the model.
The lock and the slice claims are now **git refs** in the repository's **common (shared)
ref store**, and every acquire / stale-steal / release / claim / renew / reclaim is a
**`git update-ref` compare-and-swap (CAS)**, replacing the hand-rolled `mkdir` lock-dir +
rename-capture CAS and the inline/registry lease marker. git owns the atomicity, so the
CAS is **ABA-safe by construction** (the old-value is the exact prior object SHA) and a
losing CAS is a **clean, retryable failure**. The coordination model below (session-owned
worktrees, the three locked shared-`main` writes, per-session `.git/` state, cold-restart)
and ADR 0015's lease-freshness liveness stand unchanged and now **ride this substrate**;
only the primitive and its storage change.

- **Session-owned slice worktrees.** A `/loom:run` session **never does slice work in
  the shared `main` checkout.** When it picks up a slice it creates **its own**
  worktree off **fresh current local `main`**
  (`git worktree add -b <slice-branch> <session-owned-path> main`) and runs all that
  slice's roles there. This is ADR 0008's `git worktree add` isolation extended one
  level — from *one orchestrator's sub-agents* to *each session's* slice work — so
  disjoint, uniquely-named slice file sets stay conflict-free **by construction** and
  **lock-free**: two sessions building two independent slices cannot collide on any
  slice file. The base is the shared **local** `main`, not `origin/main`: loom commits
  directly to local `main` and does not push, so a landed slice appears on local
  `main` first and `origin/main` lags.

- **Authoritative read = a fresh view of local `main` under the lock.** "What has
  landed and what is claimed" is read from the shared **local `main`**, never the
  session's own slice-worktree snapshot (which froze at worktree-create time and goes
  stale the moment any peer lands or claims). Because there is no push, `origin/main`
  may lag local `main`, so consulting it via `git fetch` is an **unlocked optimization
  / pre-filter only** — never authoritative. The correctness-critical re-read reads
  **local `main` under the lock** (below).

- **A cross-session lock on `main`'s critical section (a git ref — ADR 0016).** The
  critical section is `{claim-a-slice, merge+finalize-land}` — the only operations that
  touch the shared `main` checkout and its single-instance coordination files (the three
  living docs + `slice-plans/README.md`). It is guarded by a **per-repository cross-session
  mutex that is a single git ref — `refs/loom/lock`** — in the repository's **common
  (shared) ref store** (below), not a tracked, mergeable file. The ref's value is a small
  content-addressed **blob** (`git hash-object -w`, which carries **no** author/committer
  metadata) encoding the holder record `{session-id, lease-timestamp, session-pid,
  start-time}`; the `session-pid`/`start-time` are **advisory diagnostics / the session's
  own renewer bookkeeping only, never a cross-session liveness gate** —
  [ADR 0015](../ADR/0015-lease-renewal-heartbeat-liveness.md) — and none of it is ever
  commit/author metadata (ADR 0003 untouched). Each state transition is a **`git update-ref`
  compare-and-swap against the exact object SHA the caller last read**:
  - **Acquire** is a **create-only CAS** from the null OID (`git update-ref refs/loom/lock
    <holder-blob> 0{40}`): it succeeds only if the ref is **absent**, so a peer already
    holding the lock makes it fail.
  - **Stale-steal** is a **value-CAS** from the exact read SHA, taken **only when the
    holder's lease is stale** by the lock-TTL gate (below).
  - **Release** is a **delete-CAS** (`git update-ref -d refs/loom/lock <my-holder-blob>`):
    it deletes only if the ref still equals the caller's own holder blob, so a session that
    already lost the lock cannot delete a peer's.
  Because the old-value in every CAS is the **exact prior object SHA** — checked atomically
  by git under its own per-ref lock — the mutex is **ABA-safe by construction**: any peer
  that changed the ref between the caller's read and its `update-ref` makes the old-SHA
  check fail, so **the caller cleanly loses and retries** and there is never a window in
  which two contenders both believe they captured the same lock. This delegates
  cross-worktree atomicity to git's ref-transaction semantics instead of reconstructing
  compare-and-swap from `mkdir` + `rename(2)` + a re-read, and retires the hand-rolled
  rename-capture machinery. Contention — a lost value-CAS, or a lost race for the ref's
  own transient `.lock` (a clean non-zero exit) — reuses ADR 0008's exponential backoff
  (the same mechanism, now under a git-native primitive). The lock brackets a **short,
  bounded** main-side op and is **never held across a role spawn** or while a role works in
  a worktree. This makes ADR 0008's "serialized on main" true *across* sessions — closing
  concurrent-living-doc-write and concurrent-merge races — while leaving the
  conflict-free-by-construction disjoint slice files lock-free.

- **Lock liveness / TTL — distinct from the slice lease.** The `refs/loom/lock` ref does
  not free itself, so a session that dies mid-critical-section would otherwise deadlock
  every contender. The lock therefore carries its **own short `lock-TTL`** covering only
  the lock ref — separate from and much shorter than the slice-lease TTL below (a held lock
  is a milliseconds-to-seconds op; a lease spans a whole slice). The TTL alone never
  authorizes a force-clear on a *populated* ref: **holder-lease freshness gates it.** A
  contender backing off past the `lock-TTL` reads the current holder blob's SHA `H_obs`
  **and** decodes its `lease-timestamp`, and force-steals **only when that lease is
  stale — older than the `lock-TTL`** ([ADR 0015](../ADR/0015-lease-renewal-heartbeat-liveness.md)
  lease-freshness applied to the lock: because the locked section is a
  milliseconds-to-seconds op — provided the holder is not keeping the lock's lease fresh
  through a long `land` (see the renewer below) — a lease older than the `lock-TTL` means
  the holder crashed mid-section). The steal is a **value-CAS from that exact `H_obs`**, so
  if any peer changed the ref in the interim the CAS fails and the contender cleanly loses
  and retries — two contenders that both saw the lock stale cannot both capture it.
  Worktree-list membership and the process pid do **not** enter this decision. A holder
  still inside its bounded section (or renewing the lock's lease through a long `land`)
  keeps its lease within the `lock-TTL` and is **never** stolen — the contender keeps
  backing off and lets it finish.

- **Liveness rule — lease freshness (a renewal heartbeat)**
  ([ADR 0015](../ADR/0015-lease-renewal-heartbeat-liveness.md)). A holder/claimant is
  treated as **alive iff its lease timestamp is fresh — renewed within the TTL**; a
  lease **older than the TTL is stale → reclaimable**. This is the **sole and
  sufficient** cross-session liveness signal, and it gates **both** force-clear paths
  (the stale lock and the stale slice lease). **Worktree-list membership and the process
  pid are NOT liveness signals:** a crashed session leaves its `wt-<sid>` worktree on
  disk (and `git worktree prune` will not remove a present directory), so membership
  would read a crashed session "alive forever"; and the ephemeral per-invocation helper
  pid is already gone by the time any peer would probe it, so pid reaps the living. A
  peer therefore decides another session's liveness by **lease freshness alone** — it
  **never** probes a peer's pid and **never** consults `git worktree list` for liveness.
  The `session-id` still names the worktree and keys the lease/claim owner (below), but a
  session's `session-id`-in-`git worktree list` **no longer proves it alive** — its
  **fresh lease** does. Any pid retained in a lease stamp is **advisory diagnostics
  only**, never a liveness gate.

- **Renew obligation — a detached, out-of-band background renewer.** A live session
  keeps its lease fresh by **renewing on a cadence well below the TTL** (~TTL/3 as an
  operational default; the exact fraction is a slice-plan parameter). The renew
  obligation **must not** be carried by the driver loop: the thin orchestrator (ADR 0012)
  is **single-threaded** and spends most of its wall-clock **suspended inside long
  (20–40+ min) sub-agent Task calls**, during which its main thread runs nothing and
  could emit **zero** heartbeats — a loop-driven lease would go stale mid-slice **while
  the session is very much alive** (its blocked sub-agent *is* the progress), and a peer
  would reclaim an in-progress slice. Instead, on **first acquire** of any lock or claim,
  the session launches **exactly one** detached background renewer that refreshes every
  held lease on the ~TTL/3 cadence (locked write #2 below),
  **independently of the blocked main thread**, so leases stay fresh straight through a
  multi-hour sub-agent call. Each renew is a **value-CAS** of the held ref (a slice claim
  ref and/or `refs/loom/lock`) from its **exact read SHA** to a blob with a refreshed
  `lease-timestamp` (ADR 0016). The renewer refreshes **the lock ref's own lease-timestamp
  while the lock is held**, not only the slice claims: because the lock holder record
  carries a `lease-timestamp`, a session running a long `land`/merge keeps its **lock**
  lease fresh, so a peer's stale-steal gate (above) sees the lock as **live** and does
  **not** steal it mid-critical-section (this closes the review's un-renewed-lock defect —
  the lock is now heartbeat like any other lease; peers still decide liveness by lease
  freshness alone). Because the renewer mutates the lock ref's SHA, the main thread's
  release / `land` must delete-CAS or value-CAS against the **current** ref value — never a
  remembered stale SHA — so a renew that landed between the main thread's last read and its
  release does not spuriously fail the release. The renewer is gated on the **stable session
  process's
  reuse-robust identity** — the pair **`{session-pid, session-pid-start-time}`** — and
  keeps beating **only while** that pid is alive **and** its current start-time still
  matches the recorded one (`alive(session-pid) && starttime == recorded`). This identity
  gate is **local / intra-session only** — the renewer's own honesty check on whether to
  keep beating its **own** leases — and is **never** used as a cross-session liveness
  signal (doing so would reintroduce the stale-pid failure the liveness rule above
  forecloses). When the session process dies, is killed, or has its pid recycled to an
  unrelated process (start-time mismatch), the gate fails on the next beat and the
  renewer **self-terminates**: the lease goes stale within one TTL and the work becomes
  **reclaimable by design** — a session that stops making progress (including one that
  hits an [ADR 0013](../ADR/0013-starvation-loop-guards-cold-restart.md)
  escalate-and-stop wedge and then exits) is **indistinguishable from a crashed one** and
  is correctly reclaimed, while a **live-but-busy** session (even one blocked in a long
  sub-agent call) keeps its lease fresh and is **never** reclaimed. The renewer is started
  **once** (check-then-launch, never duplicated), and stopped on clean session-end (after
  which the session's leases go stale promptly, so a peer may reclaim without waiting a
  full TTL).

- **Slice claim / lease — a per-slice ref, check-then-act under the lock (ADR 0016).**
  Two sessions must not pick the same next action. Each slice's **lease** is a **per-slice
  git ref — `refs/loom/claims/<slice>`** — in the common ref store, whose value is a blob
  encoding `{session-id, lease-timestamp}` (this resolves ADR 0015's open
  inline-vs-sidecar lease-storage parameter to a ref; the `slice-plans/README.md`
  Active/Archived index remains the ADR 0008 orchestrator-owned listing of which slices are
  in-flight). Because each claim is an **independent** ref, two sessions claiming
  **different** slices never contend, and two racing the **same** slice resolve by CAS —
  exactly one wins. The dispatch scan derives the next action from the `Status:` lines plus
  the claim-ref/Active state on a fresh view of local `main`. To take slice X, a session
  acquires the lock and, **while holding it, re-reads the claim-ref/Active state from
  current local `main`**; if X carries a **live** claim ref by a peer, or landed (moved to
  Archived) in the interim, it **aborts and re-selects**. Only when the re-read still shows
  X free does it write its claim — a **CAS on `refs/loom/claims/X`** (create-only from the
  null OID if absent; a staleness-gated value-CAS steal from the exact read SHA if the prior
  claim is stale; an idempotent re-affirm of its **own** fresh claim) — record X in the
  `main` Active index, release the lock, and only then create the worktree and dispatch
  roles. Because read-validate-write is one locked section **and** the claim itself is an
  atomic CAS, two sessions cannot both observe X free and both claim it. A session **skips**
  any slice carrying a **live** (non-expired) claim ref by another session, so two sessions
  scanning the same `Status:` lines diverge on which slice they take.

- **Stale-claim reclaim — slice-lease TTL.** A claim ref whose `lease-timestamp` is older
  than the slice-lease TTL is **stale**, and — because **lease freshness is the liveness
  signal** ([ADR 0015](../ADR/0015-lease-renewal-heartbeat-liveness.md)) — a stale lease
  **means** its holder is dead: no membership or pid check overrides it. Under the lock
  the reclaiming session **re-reads** `refs/loom/claims/<slice>` from the common ref store,
  and if it is **still stale**, force-steals it with a **value-CAS from the exact read SHA**
  (gated on that staleness), runs `git worktree prune` + `git worktree remove -f` for the
  orphan worktree, updates the expired Active entry, and claims the slice. (Driving
  orphan-worktree cleanup off lease **staleness** — rather than off an always-populated
  worktree-membership read — is what makes a crashed session's worktree reclaimable at
  all.) A holder whose out-of-band renewer is still beating keeps its lease **fresh** and
  is **never** reclaimed — this is exactly how a legitimately long-running or
  sub-agent-blocked slice is protected, since its renewer (above) CAS-renews the claim ref
  on the ~TTL/3 cadence throughout; landing subsumes the claim release (a **delete-CAS** of
  the caller's own claim ref — no separate unclaim step).

- **Per-session write-ahead anchor — off `main`.** Each thin session must write its
  next intended action **ahead of every large/in-window op** (ADR 0013 rule 1) so a
  ~60% cold restart (ADR 0012) resumes from an advancing anchor. Under a single
  orchestrator the shared `handoff.md` doubled as both the human-facing status doc and
  that machine anchor; with N sessions the two roles **split**. The **machine
  cold-restart anchor** moves to **per-session state keyed by `session-id`, persisted
  under `.git/`** (e.g. `.git/loom-session-<session-id>/`, untracked, alongside loom's
  other under-`.git/` coordination state) holding `{session-id, write-ahead checkpoint (next intended action),
  held-claims set}`. Because it is under `.git/` it is **not** a tracked `main` file:
  writing it is **not** a `main` write, needs **no** lock, and is per-session — a
  restarting session reads only **its own** anchor, never a peer's. This **preserves**
  ADR 0013 rule 1's write-ahead invariant and **extends only its medium**; rule 3's
  forward-progress guard now reads this per-session checkpoint plus the session's own
  most-recent commit, so one session's progress is never confused for another's. The
  **human-facing `handoff.md`** (and `roadmap.md`/`progress.md`) **stay shared,
  single-instance, on `main`**, written only at **land**, under the lock, at milestone
  granularity — never on the per-op write-ahead cadence.

- **`session-id` is stable across restart and never pid-derived.** It is allocated
  once at session start and persisted in the per-session `.git/` state, so it survives
  a context clear. On **cold-restart bootstrap** a session re-reads that state,
  re-adopts its `session-id` and held-claims set, and — under the lock — **renews each
  held lease** (refresh `lease-timestamp`); it also refreshes the recorded
  `{session-pid, session-pid-start-time}` to the **restarted** process's identity and
  **relaunches the background renewer only if the recorded one did not survive the
  restart** (dead, or its pid recycled per the start-time check), so a restart never
  leaves two renewers racing. Because a peer decides liveness by **lease freshness**
  (not membership or pid) and the owner's renewer keeps that lease fresh across the
  owner's own restart, a peer never sees the lease as dead across the restart, and the
  owner **recovers** (re-adopts and renews) rather than orphaning its claims.

- **Exactly three locked shared-`main` writes.** With the restart anchor moved
  off `main`, a session mutates the shared `main`-side coordination state (the tracked
  living docs + the `slice-plans/README.md` index on `main`, and the `refs/loom/*` refs in
  the common ref store — ADR 0016) at exactly **three** moments, **all inside the lock**:
  1. **Claim** — CAS the lease ref `refs/loom/claims/<slice>` and record the slice in
     `slice-plans/README.md`'s Active region.
  2. **Lease-renew** — CAS-renew a held lease's `lease-timestamp`: the claim ref and, while
     the lock is held, `refs/loom/lock` itself (ADR 0016), performed by the out-of-band
     background renewer on the ~TTL/3 cadence and by the session on cold-restart bootstrap,
     so a long-running or restarted slice — or a long `land` holding the lock — is not
     reclaimed/stolen.
  3. **Land + finalize** — `git merge <slice-branch>`, the living-doc finalize updates
     (`progress.md`/`handoff.md`, and `roadmap.md` if a milestone closed), moving
     the slice Active → Archived in `slice-plans/README.md`, and the **delete-CAS** of the
     caller's own claim ref (which **is** the claim release — no separate unclaim step).

  At all other times a session operates only in its own slice worktree(s). The
  per-session write-ahead checkpoint is **not** one of these three — it is off-`main`
  per-session `.git/` state.

**Multi-session invariants.**

- Every shared-`main` write happens **inside** the cross-session lock; there are
  exactly **three** (claim, lease-renew, land+finalize). No unguarded living-doc or
  `handoff.md` write is left open.
- A force-clear of the lock **or** a lease is a **staleness-gated value-CAS steal** (ADR
  0016) gated on **holder-lease freshness** — a lease not renewed within the TTL (for the
  lock ref: a holder `lease-timestamp` older than the `lock-TTL`) —
  [ADR 0015](../ADR/0015-lease-renewal-heartbeat-liveness.md); worktree-list membership and
  the process pid are **not** liveness signals. A live-but-busy holder keeps its lease fresh
  via its out-of-band renewer (which now heartbeats the lock ref too) and is **never**
  cleared; a losing steal-CAS is a clean, retryable failure.
- The cold-restart anchor is **off-`main`, per-session, under `.git/`**, keyed by a
  `session-id` **stable across restart and never pid-derived**; the shared `handoff.md`
  stays on `main`, written at land under the lock.
- Disjoint slice files stay conflict-free **by construction** and **lock-free** (ADR
  0008 preserved); only the irreducibly-shared `main` critical section is locked.
- Uniform author-neutral identity (ADR 0003) is **untouched**: the `session-id` is
  out-of-band coordination metadata and any recorded `pid`/`start-time` is out-of-band
  bookkeeping for the session's **own** renewer (never a cross-session liveness gate —
  ADR 0015), **never** commit/author metadata, so cross-session commits stay
  indistinguishable to the blind evaluator; only the session spawns (ADR 0001). The holder
  record lives in a `refs/loom/*` **blob** (via `git hash-object -w`, no author/committer
  metadata) and those refs are **never** `refs/heads/*` branch history and **never** appear
  in the blind code-evaluator's slice-commit diff (ADR 0016 / ADR 0003). No new `Status:`
  token — the lease is coordination bookkeeping in a `refs/loom/claims/<slice>` ref (with
  the slice listed in `slice-plans/README.md`'s Active region, ADR 0008's index bucket), not
  a lifecycle state (spec 03 unchanged).
- **Substrate is now decided (ADR 0016); values remain deferred.** The lock/claim primitive
  is **fixed** as git-native `update-ref` **CAS** on the common ref store —
  `refs/loom/lock` + `refs/loom/claims/<slice>` (create-only, value, and delete CAS on the
  exact read SHA; ABA-safe by construction) — no longer the open `mkdir`-dir-vs-ref-CAS
  parameter. These refs **must** live in the **common (shared) ref store** (never a
  per-worktree / `refs/worktree/` namespace, which would defeat cross-session visibility).
  Two re-implementation notes carry from the ADR 0016 review: **(a) loose-blob cleanup** —
  each CAS supersedes the prior holder blob, leaving it unreferenced; these are reclaimed by
  ordinary `git gc` (noted, not over-specified); **(b) renewer↔release coordination** —
  because the renewer mutates the lock/claim ref's SHA, the main thread's release/`land`
  must CAS against the **current** ref value, not a remembered stale SHA. Still deferred to
  the POSIX-sh helper slice (loom's third executable file, shell-gated): the `lock-TTL` and
  slice-lease TTL values, the exact renew-cadence fraction, the holder-blob field encoding,
  the exact ref names / create-only sentinel, the detached-renewer spawn/reap primitive, the
  **portable** capture of the process start-time for the `{session-pid,
  session-pid-start-time}` identity gate, and the per-session `.git/` state
  location/derivation. This spec records the **contract**, not the implementation. (Liveness
  itself is **no longer** a deferred parameter — ADR 0015 fixes it as lease freshness.)

## Human checkpoints

The loop pauses and returns to the owner when: the scope boundary is reached; an
owner-claimed gate is reached; an artifact exceeds the round limit (escalation =
pause + summary, see [03](03-artifact-lifecycle.md)); an **infrastructure block** is
detected — the infrastructure-blocked escalation
([03](03-artifact-lifecycle.md) / [ADR 0017](../ADR/0017-infrastructure-blocked-escalation.md)),
same pause + summary shape but **not** round-counted; or a role reports it cannot
proceed without owner input. On every pause the orchestrator ensures
`status/handoff.md` reflects the next step.

The infrastructure-blocked escalation is **detect-on-failure only** — loom cannot
poll account limit state, so it reacts to a spend/usage/quota limit, 429, 5xx,
classifier-unavailable error, or a workflow whose sub-agents crashed on such. On
detection the orchestrator does **not** treat the result as a valid FAIL / `ran-clean`
/ finding set, does **not** consume a round-limit count, **halts** rather than
retry-looping into the same limit, **write-ahead checkpoints** (ADR 0013), and
pauses + summarizes to the owner (naming the block and how to resume). The full
contract lives in [03](03-artifact-lifecycle.md) (*Infrastructure-blocked
escalation*); the degraded-review case is handled in *Automated review before a slice
lands* above.

## One-off invocation

Each role is also runnable directly ([07](07-command-surface.md)). A one-off is a
single cold-agent pass: read files, do the job, write/commit, set status, return —
without the orchestrator chaining the next role.

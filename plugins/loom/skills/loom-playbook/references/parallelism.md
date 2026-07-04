# Worktree-per-slice parallelism

Parallelism is **available; the owner opts in.** The orchestrator (the only spawner
— ADR 0001) may launch multiple developer agents concurrently, each in its own git
worktree on its own branch, each processing an independent, already-approved slice.
The governing decision is
[ADR 0008](../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md).
This document is the single authoritative operational body: when the owner opts in
to the parallel model, follow every rule here precisely. The isolation wiring
(`background` agent spawn) is a separate build item; the coordination model and
safety rules documented here are in effect regardless.

This body also operationalizes the **multi-session coordination layer**
([ADR 0014](../../../../../.docs/ADR/0014-multi-session-worktree-coordination.md) /
[ADR 0015](../../../../../.docs/ADR/0015-lease-renewal-heartbeat-liveness.md) /
[ADR 0016](../../../../../.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md)) via
the `loom-coord` executable (`plugins/loom/bin/loom-coord`, on `$PATH` when the plugin
is enabled). That layer is **layered on top of — not replacing
—** the single-orchestrator model: ADR 0008's disjoint-file and worktree-isolation
guarantees are fully preserved. The multi-session layer adds only **cross-session
serialization of the shared-`main` critical section** (claim registration and
land+finalize), enabling N independent `/loom:run` sessions to operate safely on the
same repository without one session clobbering another's in-flight work.

See also: [`orchestration.md`](orchestration.md) (Core rules, Round limit,
Scope & gates), [`status-machine.md`](status-machine.md) (status dispatch).

---

## When to parallelize — the slicer-independence rule

**Only parallelize slices whose file sets are fully disjoint.**

Two slices are independent (safe to run in parallel) when both conditions hold:

1. **Disjoint source/content files.** No source or content file is edited by both
   slices (e.g. if two slices would both edit `CLAUDE.md` or `SKILL.md`, they are
   *not* independent — sequence them instead).
2. **Disjoint per-slice `.docs/` filenames.** Each slice carries a uniquely named
   plan file and eval file (`<slice>-plan.md`, `<slice>-eval.md`); no overlap on
   these names.

**Two distinct mechanisms — do not confuse them:**

- **Shared *coordination/index* files** (the three living docs + `slice-plans/README.md`)
  are pulled off the branch entirely — the orchestrator owns them on main. This is
  a structural placement rule, not a slicer-independence question. A slice branch
  never edits these files at all (see next section).
- **Shared *content/source* files** (e.g. root `CLAUDE.md`, the playbook `SKILL.md`,
  a managed project's source file) are the slicer-independence case: if two slices
  would both edit the same content file, those slices are **sequenced, not
  parallelized**. The orchestrator never authors content — only status; so these
  shared-content files cannot be moved to the orchestrator. Sequence the slices
  instead.

**Dependent slices** (one slice needs another's output to proceed) are always
sequenced — parallelism is only for slices that are truly independent.

This is a **planning/slicing-time responsibility.** The orchestrator must verify
both conditions before spawning two slices concurrently.

---

## The `.docs/` coordination model — who writes what where

*Traces ADR 0008 §1.*

### Orchestrator-owned, main-only, serialized (never on a slice branch)

The following four files are written **only by the orchestrator, only on the main
worktree, and only one at a time** (serialized):

| File | Why it is main-only |
|------|---------------------|
| `.docs/status/roadmap.md` | Living doc — shared single instance |
| `.docs/status/progress.md` | Living doc — shared single instance |
| `.docs/status/handoff.md` | Living doc — shared single instance |
| `.docs/slice-plans/README.md` | **The slice-plans index** — carries one Active-plans region and one Archived-plans region; every plan-authoring commit and every finalize commit edits this one file. Two concurrent slices each appending to that one Active-plans region would conflict on merge. Therefore the index is reclassified into the same bucket as the three living docs: orchestrator-owned, main-only, serialized. The Active region is also the ADR 0008 index bucket that pairs with the `refs/loom/claims/<slice>` lease: a `loom-coord claim` is the cross-session liveness signal; an Active-region entry without a live claim is a stranded slice. |

**A slice worktree never edits any of these four files.**

Under **multi-session**, the serialization of these four files is enforced **across
sessions** by the `loom-coord` cross-session lock (`refs/loom/lock`), not merely *by
construction* of a single orchestrator. Any session that needs to write to these
files must hold the lock first (see *Multi-session coordination* below).

### Slice-branch-local (written on the slice branch, uniquely named)

Each slice carries exactly three categories of files on its branch — no more:

| File | Written by |
|------|------------|
| `.docs/slice-plans/<slice>-plan.md` | planner, in the slice worktree |
| `.docs/evaluations/<slice>-eval.md` | plan-evaluator and code-evaluator, in the slice worktree |
| Source/code for the slice | developer, in the slice worktree |

### Change from the M1 sequential habit

Under M1 (one slice in flight at a time) the planner edited `slice-plans/README.md`
in the *same commit* as the plan file, and the developer's finalize pass archived it
— all on one branch, so it never conflicted. **Under parallelism that index edit
moves off the slice branch:**

- The planner authoring a slice-plan on its branch writes **only** the
  uniquely-named plan file (`.docs/slice-plans/<slice>-plan.md`) — **not** the
  `slice-plans/README.md` index.
- The orchestrator maintains the index's Active/Archived sections on main:
  - **When it creates a slice** → add an entry to Active plans on main.
  - **When it lands a slice** → move that entry from Active to Archived on main.
- Developer/finalize passes no longer touch the index on the branch.

### The disjoint-file invariant

Because each slice owns distinct plan/eval filenames, no slice edits a living doc,
and no slice edits the slice-plans index, **two concurrent slices write disjoint
path sets and cannot collide on any `.docs/` file.** Conflicts are avoided by
construction, not resolved after the fact.

### Agent-input freshness

Worktrees are created from **current local `main`** (see the `git worktree add`
command below), so each agent's `.docs/` snapshot is current as of spawn. loom
commits to local `main` and does not push, so `origin/main` lags; consulting
`origin/main` via `git fetch` is an **unlocked pre-filter only** — never
authoritative. The authoritative "what has landed / what is claimed" read is always
**current local `main` under the lock**. Cold agents (spec 04) receive focused inputs
and do not read main's living docs mid-flight; the orchestrator holds the live picture
and consults/updates the living docs between handoffs. No polling, no per-branch
status replication.

---

## Workflow: create → work → land → cleanup

*Traces ADR 0008 §2.*

### Create (orchestrator, per in-flight slice)

**Single-session (default):**

```
git worktree add -b <slice-branch> <session-owned-path> main
```

**Multi-session (owner opt-in):** before creating the worktree, serialize via
`loom-coord`:

1. `loom-coord lock-acquire --session <id>` — acquire the cross-session lock
   (`0` proceed; `3` busy/backoff exhausted → defer and retry later; `10` → abort).
2. Re-read Active/claim state from **current local `main`** (the authoritative
   snapshot, now under the lock).
3. For each candidate slice:
   - `loom-coord claim <slice> --session <id>` — `0` claimed → proceed;
     `4` live peer already holds it → skip and re-select another slice;
     `5` lock not held → re-acquire; `10` → abort.
   - If the current claim is stale (lease expired), use
     `loom-coord reclaim <slice> --session <id>` instead:
     `0` reclaimed (orphan worktree pruned) → proceed;
     `6` holder still fresh → skip;
     `4` CAS failed (holder renewed between read and steal) → skip, holder alive;
     `5` lock not held or already owner.
4. Record the slice in the `slice-plans/README.md` Active region on main.
5. `loom-coord lock-release --session <id>` — release (`0` released; `5` not held).
6. **Then** create the session-owned worktree and dispatch roles:

```
git worktree add -b <slice-branch> <session-owned-path> main
```

On first claim (`claim` or `reclaim` returns `0` for at least one slice), launch the
background renewer once:

```
loom-coord renewer-start <session-pid> --session <id>
# 0 (renewer-started / renewer-already-running) → ok
# 5 session not started → run session-start first
# 10 cannot read start-time → abort
```

The renewer heartbeats the lock **and** claims in the background, keeping leases
fresh for the lifetime of the session. It is gated on `{session-pid,
session-pid-start-time}` — an intra-session honesty check only, never a
cross-session liveness signal.

- Pass `<session-owned-path>` to the developer agent as its working directory.
- Update the slice-plans index (Active plans entry) on main (done under the lock in step 4 above).

### Work (developer agent, in the slice worktree)

The developer (and the slice's planner/evaluator) run **inside `<worktree-path>`**
on `<slice-branch>`. They commit author-neutral per ADR 0003 and hand back to the
orchestrator. They write only the three categories of slice-branch files listed
above — they do not touch the living docs or the index.

### Land (orchestrator, from the main worktree — serialized, one slice at a time)

**Single-session (default):**

```
# From the main worktree:
git merge <slice-branch>
# Brings only the slice's disjoint files onto main:
#   code + <slice>-plan.md + <slice>-eval.md
#   (slice-plans/README.md index is NOT on the branch; orchestrator updates it here)
```

**Multi-session (owner opt-in):** the lock + claim must wrap the merge and finalize:

1. `loom-coord lock-acquire --session <id>` — acquire (`0` proceed; `3` busy → defer, retry later).
2. `loom-coord lock-verify --session <id>` — **fail-closed land guard** immediately
   before the merge: `0` `held` → proceed to merge; `5` not held → abort land, re-acquire; `10` → abort.
3. `git merge <slice-branch>` (same as single-session).
4. Run the finalize pass (see below).
5. `loom-coord release-claim <slice> --session <id>` — the land subsumes claim release
   (delete-CAS of own claim, under the lock): `0` released; `5` lock not held or not owned.
6. `loom-coord lock-release --session <id>` — exit the critical section.

After the merge, the orchestrator runs the **finalize pass on main**:

1. Update `.docs/status/progress.md` and `handoff.md`.
2. Update `.docs/status/roadmap.md` if a milestone closed.
3. Update the relevant `CLAUDE.md` if the landed slice changed something in the
   curated-digest scope (derived non-spec digest; per-slice history stays in
   `progress.md`; see [spec 08](../../../../../.docs/spec/08-playbook.md) for the
   boundary). `CLAUDE.md` is a **shared single-instance content file** (see
   *When to parallelize* above), so its finalize update is serialized on main here
   alongside the living docs — the slicer-independence rule already sequences any
   two slices that would both edit it.
4. Move the slice's index entry from Active to Archived in `slice-plans/README.md`.
5. `git mv` the slice-plan into `.docs/slice-plans/archive/`.
6. Commit.

Then merge the next slice. Living-doc, `CLAUDE.md`, and index updates are strictly
serialized (one merge+finalize at a time). **Never** run two merge+finalize
sequences concurrently.

**Genuine code conflict** (two slices touched the same source file — a slicing
defect, not a `.docs/` issue): the orchestrator does **not** hand-edit code. Route
the resolution through a **developer** slice, re-verified by the evaluator, per the
never-edit-code Core rule (`orchestration.md`).

### Cleanup (mandatory after every landing)

```
git worktree remove <worktree-path>    # add -f if the worktree is unclean
git worktree prune                     # run periodically (e.g. before a new wave)
                                       # to clear orphaned/missing worktrees
```

Stale worktrees consume disk and may leave stale `index.lock` files. Remove every
worktree immediately after its slice is merged.

**Multi-session (owner opt-in) — additional steps:**

- **Periodic stale sweep** (before launching a new wave of slices):
  `loom-coord cleanup [--session <id>]` — sweeps stale claims and orphan worktrees
  under the lock: `0` `swept N; skipped M`; `3` lock busy → sweep skipped, retry.

- **At session exit** (normal or error path — always run):
  ```
  loom-coord renewer-stop --session <id>   # stop the background renewer
  loom-coord session-end --session <id>    # release claims + lock, remove session state
  # session-end: 0 success; 3 could not acquire lock → claims not released; retry
  # (never rm state on exit-3 — that would orphan claim registry rows)
  ```

---

## Concurrency safety

*Traces ADR 0008 §3.*

### Cross-session coordination — git-CAS lock and claims

Under multi-session, the cross-session coordination mechanism is a `git update-ref`
**CAS** on two sets of git refs in the **common (shared) ref store**:

- `refs/loom/lock` — the cross-session mutual-exclusion lock (blob = `{sid}\t{ts}\t{pid}\t`).
- `refs/loom/claims/<slice>` — per-slice lease (blob = `{sid}\t{ts}\t{b64-slice}`).

A **losing CAS is a clean, retryable failure** — no data is corrupted; the caller
simply re-reads the current ref value and retries or backs off. `loom-coord`
internally applies the same ADR 0008 exponential-backoff loop (0.2 → 0.4 → 0.8 →
1.6 → 3.2 s) before surfacing exit `3` (lock busy) or exit `4` (claim taken). The
cross-session lock replaces the single-session "serialize by construction" guarantee
with an explicit git-CAS mutex; the lower-level `index.lock` still governs concurrent
git object-store writes (see below) and is subordinate to the CAS coordination layer.

**Liveness is lease freshness** (ADR 0015): a claim is alive if its timestamp is
within `LOOM_LEASE_TTL` of now. Worktree-list membership and the process pid are
**never** cross-session liveness signals. A fresh lease whose holder's pid is dead is
still treated as **alive** — fail-closed.

### `index.lock` collisions → exponential-backoff retry

Concurrent commits across N worktrees share one `.git/` object store; git write
operations (commit, merge) can collide on `index.lock`. When a git write fails with
an `index.lock` error, **retry with exponential backoff** — 3–5 attempts at
approximately 200 ms, 400 ms, 800 ms, … — before surfacing the failure. Applies to:

- Agents committing in their slice worktrees.
- The orchestrator's merge and finalize commits on main.

### Crash / stale-lock cleanup

A killed or crashed agent leaves its worktree and possibly a stale `index.lock`.
The orchestrator reclaims it with:

```
git worktree remove -f <worktree-path>
git worktree prune
```

Run `git worktree prune` periodically (e.g. before launching a new wave of slices)
to clear any orphaned worktrees that no longer have a working directory on disk.

### One checkout per branch

A branch can be checked out in only one worktree at a time (git constraint). Each
in-flight slice = one unique branch in one worktree. The orchestrator never:

- Reuses a branch across concurrent slices.
- Uses `--force` to double-checkout a branch.

Name slice branches distinctly (e.g. `slice/<slice-name>`).

### The git-identity-guard hook is parallel-safe

`plugins/loom/hooks/git-identity-guard.sh` is **stateless**: it reads only the hook
`stdin` (`tool_input.command`), inspects that one string, and exits 0 or 2. It
writes no shared file, lock, or database. Concurrent invocations across multiple
worktrees therefore cannot race. The hook continues to enforce ADR 0003's uniform
author-neutral identity in every worktree, which is what keeps parallel commits
blind-eval-safe.

---

## What stays serial

*Traces ADR 0008 §4.*

- **The orchestrator is the only spawner** (ADR 0001) and the **only writer of
  main's living docs and the slice-plans index.** These are not parallelized.
- **Living-doc and slice-plans-index updates are serialized on main** — one
  merge+finalize at a time (see Land above). Under multi-session, this serialization
  is enforced **across sessions** by the `refs/loom/lock` cross-session mutex (managed
  via `loom-coord`), not merely by the single-orchestrator construction. There are
  exactly **three locked shared-`main` writes**: (1) claim registration (write the
  Active-region entry), (2) lease renewal (heartbeat under the lock during a critical
  section), and (3) land+finalize (merge + living-doc update + `release-claim`). All
  other session activity happens **lock-free** in the session's own slice worktree.
- **Planning passes that write `spec/`, `ADR/`, or `research/`**, and any
  cross-slice decision, run as **non-parallel** passes on main. Specs are frozen
  (ADR 0005); ADRs are immutable. Parallelism is for building **independent,
  already-approved** slices — not for concurrent planning of shared design memory.
- **Slices that share a source/content file are sequenced.** If two candidate
  parallel slices would both edit `CLAUDE.md`, `SKILL.md`, or any managed-project
  source file, they are not run concurrently — the diff-against-prior-commit blind
  review (ADR 0003) must remain unambiguous, and shared-content files are a
  slicer-independence violation (see above).
- **Disjoint slice files remain conflict-free by construction and lock-free** —
  the slicer-independence rule (disjoint file sets) means concurrent slice worktrees
  never touch the same source file; no lock is needed for the slice's own work.

---

## Multi-session coordination — the cross-session lock + per-slice claims

*Authority: spec [04](../../../../../.docs/spec/04-orchestrator.md) § "Multi-session
coordination" · [ADR 0014](../../../../../.docs/ADR/0014-multi-session-worktree-coordination.md) ·
[ADR 0015](../../../../../.docs/ADR/0015-lease-renewal-heartbeat-liveness.md) ·
[ADR 0016](../../../../../.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md).
See [`orchestration.md`](orchestration.md) → *Multi-session coordination* for the
driver-loop obligations.*

### Model

Each top-level `/loom:run` session is its own thin orchestrator that owns its slice
worktrees (branched from local `main`). Multiple sessions can run concurrently. The
cross-session coordination is entirely via git refs and the `loom-coord` CLI:

- **Lock** (`refs/loom/lock`): cross-session mutex for the shared-`main` critical
  section. Managed by `git update-ref` CAS — ABA-safe; losing CAS = clean retry.
- **Claims** (`refs/loom/claims/<slice>`): per-slice lease refs. Each active slice
  is claimed by exactly one session; the claim is kept alive by the background renewer.
- **Liveness = lease freshness** (ADR 0015): a session is considered alive if its
  claim timestamp is within `LOOM_LEASE_TTL` of now. Worktree-list membership and
  the process pid are **never** cross-session liveness signals.

### Session lifecycle

| Action | `loom-coord` subcommand | Exit-code handling |
|---|---|---|
| **Session kickoff** | `session-start [--session <id>]` (prints the `session-id`) | `0` adopt the printed id; `10` fail-closed, abort |
| **Launch the renewer** (once, after first lock/claim acquire) | `renewer-start <session-pid> --session <id>` | `0` (`renewer-started` / `renewer-already-running`) → ok; `5` session not started → run `session-start` first; `10` cannot read start-time → abort |
| **Cold-restart bootstrap** | `session-bootstrap --session <id>` then re-`renewer-start` if the renewer did not survive | `0` resume from printed checkpoint; `3` could not acquire lock → backoff + retry; `5` session not found → treat as fresh `session-start` |
| **Acquire the main lock** | `lock-acquire --session <id>` | `0` acquired; `3` busy → defer, keep working slices, retry; `10` → abort |
| **Fail-closed land guard** | `lock-verify --session <id>` | `0` `held` → proceed to merge; `5` not held → abort land, re-acquire; `10` → abort |
| **Claim a free slice** (under lock) | `claim <slice> --session <id>` | `0` claimed; `4` live peer → re-select; `5` lock not held → re-acquire; `10` → abort |
| **Reclaim a stale slice** (under lock) | `reclaim <slice> --session <id>` | `0` reclaimed; `4` CAS failed (holder renewed) → skip; `5` lock not held or already owner; `6` holder still fresh → skip |
| **Release lock** | `lock-release --session <id>` | `0` released; `5` not held |
| **Dispatch pre-scan** (unlocked pre-filter) | `list-claims` | `0` prints `slice\tsid\tts` rows; authoritative re-check still done under the lock against current local `main` |
| **Write-ahead checkpoint** (ADR 0013) | `checkpoint-write --session <id> "<next action>"` | `0`; `5` session not started |
| **Read checkpoint on restart** | `checkpoint-read --session <id>` | `0` |
| **Land subsumes claim release** (under lock) | `release-claim <slice> --session <id>` | `0` released; `5` lock not held or not owned |
| **Periodic stale sweep** | `cleanup [--session <id>]` | `0` `swept N; skipped M`; `3` lock busy → sweep skipped, retry |
| **Session exit** | `renewer-stop --session <id>` then `session-end --session <id>` | `session-end`: `0`; `3` could not acquire lock → claims not released, retry (never `rm` state on `3`) |

### Background renewer

The renewer is started once (after the first successful claim or lock acquire) via
`renewer-start <session-pid> --session <id>`. It runs detached, heartbeating
`refs/loom/lock` at the lock cadence (`LOOM_LOCK_TTL/3` by default) and all held
claims at the claim cadence (`LOOM_RENEW_INTERVAL` by default). Its loop condition is
the `{session-pid, session-pid-start-time}` identity gate — an **intra-session
honesty check only** (prevents a recycled pid from impersonating the session); it is
**never** used as a cross-session liveness signal. The renewer exits when the session
process exits or its start-time changes (recycled pid).

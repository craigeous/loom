# Multi-Session Lock / Claim Coordination Helper

Status: Draft
Lifecycle: Draft → **Plan Review** → Approved → In Progress → Implemented → (code review) → Landed → Archived
Target specs: 04-orchestrator.md → "Multi-session coordination (ADR 0014)"; ADR 0014 §1/§2/§3 + §Consequences (the helper contract)

## Context

[ADR 0014](../ADR/0014-multi-session-worktree-coordination.md) (Approved/immutable)
lets the owner run **N independent `/loom:run` sessions** against one repo by
serializing their writes to the one shared `main` through a **cross-session lock**
and a **slice-lease** protocol. ADR 0014 §Consequences records the **contract** for
loom's **third** piece of executable code (after `git-identity-guard.sh` and
`precompact-write-ahead-backstop.sh`): a POSIX-sh helper, identity-neutral,
persisting its lock/marker/state **outside the tracked worktree** under `.git/`,
gated by the **shell gate** (`shfmt -i 4 -d` → `shellcheck` → `bats`). Spec 04's
"Multi-session coordination" subsection (re-frozen) is the authority on the **three
locked shared-`main` writes** (claim / lease-renew / land) and the
**session-id-primary** liveness rule.

This slice builds **only the helper** — the CLI mechanism the session invokes. It
mirrors the two existing hooks in style, structure, and test discipline (POSIX-sh,
`shfmt -i 4`, `git rev-parse --git-dir` state resolution, jq-with-grep/sed fallback
pattern, an isolated-temp-repo `bats` suite). It is **not a hook**: it has **no**
`hooks.json` registration and is never auto-fired — the orchestrator/session calls
it directly.

**Helper home (decided here):** a **new** directory `plugins/loom/lib/`, file
`plugins/loom/lib/loom-coord.sh`, test suite `plugins/loom/lib/loom-coord.bats`.
Rationale: the two `hooks/` scripts are PreToolUse/PreCompact guards auto-discovered
by `hooks.json`; a hand-invoked CLI helper is a distinct category and belongs in its
own `lib/`. The `CLAUDE.md` "Repo layout" digest gains this directory — a developer
**finalize** concern (spec 03 finalize step 2), **noted here, not pre-written**.

**Fail direction is inverted vs the guard hooks (decided here, important).** The two
hooks **fail open** (allow on any ambiguity) because a false block is worse than a
missed guard. A *coordination* helper must **fail closed**: on any tooling/parse
ambiguity it **denies** (never grants a lock or a claim it cannot prove is safe),
because a falsely-granted lock or double-granted claim corrupts `main`. Every error
branch below exits **non-zero** — never a "fail-open" exit 0.

**Scope of THIS slice (code only).** The playbook-body wiring — *where* the
orchestrator calls these subcommands in the loop, the rendering of the lease into the
human-facing `slice-plans/README.md` Active region on `main`, and the git commit of
that index update — is the **separate next slice W** (`parallelism.md`,
`orchestration.md`, `run.md`, per ADR 0014 §"Playbook bodies to update"). Those doc
edits are **out of scope here**; this plan only *names* them as W's job. This helper
therefore writes **no tracked file** and makes **no git commit** of repo content
(its only `git` writes are `worktree prune` / `worktree remove -f` for orphan
cleanup, which create no commits) — so ADR 0003 is untouched within the helper.

### Decided parameters (ADR 0014 left these to the slice-plan)

| Parameter | Decision | Override |
|---|---|---|
| Lock primitive | `mkdir` lock dir (atomic, fails if exists) | — |
| Lock dir | `<git-dir>/loom/main.lock/` with `holder` file inside | — |
| Claims registry | `<git-dir>/loom/claims` (TSV, per-repo, untracked) | — |
| Per-session state | `<git-dir>/loom/session-<id>/` (`checkpoint`, `held-claims`) | — |
| `lock-TTL` | **30 s** (a held lock is a ms-to-seconds main-side op) | `LOOM_LOCK_TTL` |
| slice-lease TTL | **3600 s** (a lease spans a whole slice) | `LOOM_LEASE_TTL` |
| Backoff | 5 attempts at 0.2 / 0.4 / 0.8 / 1.6 / 3.2 s (ADR 0008 §3; integer-sleep fallback) | `LOOM_LOCK_RETRIES` |
| Renew cadence | helper exposes `renew`; the *cadence* (≈ TTL/3) is W's loop concern | — |
| `session-id` source | caller-supplied stable token (`--session <id>` / `LOOM_SESSION_ID`); `session-start` mints a uuid when unset. Stable across restart, **never pid-derived**. Recovering the token after a context clear is **W's** orchestrator-restart wiring (re-supply the same stable handle); the helper owns persistence + re-adoption **given the id**. | — |
| Liveness probe | **session-id-primary:** alive iff `<session-id>` token appears in `git worktree list --porcelain`; recorded `pid` (`kill -0`) is **secondary** only when the session-id signal is unavailable. Force-clear requires session-id **absent**. | — |

All state lives under `<git-dir>/loom/` (resolved via `git rev-parse --git-dir`,
made absolute) — the same convention `precompact-write-ahead-backstop.sh` already
uses, **untracked**, **per-repo** (shared across every worktree because `.git/` is
shared), never a `.gitignore` entry. Timestamps are epoch seconds (`date +%s`).

### Claim-store boundary (decided here, to stay spec-consistent and self-contained)

Spec 04 makes the **authoritative on-`main` lease** a `{session-id, pid,
lease-timestamp}` marker in the `slice-plans/README.md` Active region, written+
committed under the lock. Parsing/round-tripping that human-curated markdown index in
POSIX-sh is fragile and is a **doc-format concern owned by slice W**. This helper
therefore owns the **operational claims registry** (`<git-dir>/loom/claims`, per-repo
+ immediately visible to all sessions through shared `.git/`) and provides the
locked, liveness-gated claim/renew/reclaim **mechanism**; **W composes** the
`slice-plans/README.md` rendering + on-`main` commit **inside the same held lock this
helper provides** (`lock-acquire` … `claim` … *W renders+commits README* …
`lock-release`). Split responsibilities for the check-then-act re-read:
- **claimed-by-a-live-peer** TOCTOU → closed **by this helper** (`claim` re-reads the
  registry under the held lock and aborts with a distinct exit code).
- **landed-in-the-interim** (Active→Archived in README) → re-read **by W** under the
  same held lock before/around the `claim` call (W's wiring, noted not built here).

## CLI contract

`loom-coord.sh <subcommand> [args]`. Global: `--session <id>` (or `LOOM_SESSION_ID`)
identifies the calling session for every lock/claim subcommand. stdout is terse and
machine-parseable (one line); human detail and errors go to **stderr**.

**Exit codes (uniform across subcommands):**

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | usage / missing-argument error |
| 3 | lock busy — contention not resolved within backoff (could not acquire) |
| 4 | claim taken by a **live** peer — caller must abort + re-select |
| 5 | precondition violation — lock not held by self / claim not owned by self |
| 6 | reclaim refused — target holder is still **alive** |
| 10 | fail-closed: tooling/parse ambiguity (git unavailable, not a repo, unreadable state) — **deny** |

### Lock subcommands

| Subcommand | Requires | stdout | Behavior |
|---|---|---|---|
| `lock-acquire` | `--session` | `acquired` | `mkdir` the lock dir atomically; on success stamp `holder` = `<session-id>\t<pid>\t<epoch>`, exit 0. On `mkdir` failure (held): exponential backoff (table above). **Past `lock-TTL`:** read `holder`, run the liveness probe — if the holder is **dead** (session-id absent), force-clear (`rm -rf` the lock dir) and re-acquire (re-stamp); if **alive**, keep backing off (never clear a live-but-slow holder). On exhausted retries → exit 3. Any state ambiguity → exit 10. |
| `lock-release` | `--session` | — | Verify `holder`'s session-id == self; remove the lock dir; exit 0. Held by another / not held → exit 5 (lock left intact). |
| `lock-holder` | — | `<id>\t<pid>\t<epoch>` or empty | Diagnostics/tests: print the current holder stamp. |

### Claim / lease subcommands (all assert the caller holds the lock → else exit 5)

| Subcommand | Requires | stdout | Behavior |
|---|---|---|---|
| `claim <slice>` | `--session`, lock held by self | `claimed <slice> <id> <epoch>` | **Check-then-act on the registry.** Re-read `<git-dir>/loom/claims`. If `<slice>` has a **live** claim by **another** session → exit 4 (abort/re-select). If a **stale** claim by another → liveness-gated: holder **dead** → reclaim-overwrite; holder **alive** → exit 4. If the caller's **own** live claim exists → idempotent re-affirm (exit 0). If free → write `<slice>\t<session-id>\t<pid>\t<epoch>` and add `<slice>` to the session's `held-claims`; exit 0. |
| `renew <slice>` | `--session`, lock held by self | `renewed <slice> <epoch>` | Assert caller **owns** the claim (else exit 5); refresh its `lease-timestamp` **and** `pid`. Used on the renew cadence **and** by `session-bootstrap`. |
| `release-claim <slice>` | `--session`, lock held by self | — | Remove the caller's claim line + drop `<slice>` from `held-claims`. (Land normally subsumes this; provided for explicit/non-land release.) |
| `reclaim <slice>` | `--session`, lock held by self | `reclaimed <slice>` | Liveness-gated **stale-claim reclaim**: verify the current holder is **dead** (session-id absent). If alive → exit 6 (no change). If dead → `git worktree prune` + `git worktree remove -f` the orphan worktree, clear/overwrite the registry entry, write the caller's claim. |
| `list-claims` | — | registry lines | Diagnostics. |

### Per-session state subcommands (off-`main`, **no lock** — per ADR 0014 §1)

| Subcommand | Requires | stdout | Behavior |
|---|---|---|---|
| `session-start` | `[--session <id>]` | `<session-id>` | Mint a uuid when `--session`/`LOOM_SESSION_ID` is unset (`uuidgen`, else `od -An -N16 -tx1 /dev/urandom`); create `<git-dir>/loom/session-<id>/` with empty `checkpoint` + `held-claims`. **Idempotent** — re-adopt an existing dir. Print the id. |
| `checkpoint-write` | `--session` | — | Write the write-ahead next-intended-action (arg or stdin) to `session-<id>/checkpoint`. No lock (off-`main`, per-session). |
| `checkpoint-read` | `--session` | checkpoint text | Print the current checkpoint (empty if none). |
| `session-bootstrap` | `--session` | re-adopted `held-claims` + checkpoint | **Cold-restart re-adoption (self-locking):** re-read `held-claims`; acquire the lock; `renew` **each** held claim (refresh timestamp + new pid); release the lock; print the re-adopted set + checkpoint. Because the session's worktree(s) keep its session-id present in `git worktree list` across the restart, a peer never sees these leases as dead in the window before renewal. |
| `session-end` | `--session` | — | Cleanup: release any still-held claims (self-locking) then `rm -rf <git-dir>/loom/session-<id>/`. |

### Repo-wide crash cleanup (MINOR (c))

| Subcommand | stdout | Behavior |
|---|---|---|
| `cleanup` | summary | Self-locking sweep: `git worktree prune`; for every registry claim whose session-id is **dead** (absent from `git worktree list`), remove the orphan worktree (`git worktree remove -f`), clear the claim, and `rm -rf` that dead session's `session-<id>/` dir; force-clear a stale lock whose `holder` is dead. **Live** sessions/claims/locks are untouched. |

## Steps

1. **Create `plugins/loom/lib/loom-coord.sh`** (`#!/bin/sh`, `shfmt -i 4` style,
   header comment mirroring the two hooks: purpose, state paths, exit-code table,
   the **fail-closed** note). Structure:
   - **State resolution** (mirror `precompact-write-ahead-backstop.sh` lines 60–80):
     `REPO_ROOT=$(git rev-parse --show-toplevel)`; `GITDIR=$(git rev-parse
     --git-dir)` made absolute; `STATE_DIR="$GITDIR/loom"`;
     `LOCK_DIR="$STATE_DIR/main.lock"`; `CLAIMS="$STATE_DIR/claims"`;
     `SESSION_DIR="$STATE_DIR/session-$SESSION_ID"`. If git is unavailable / not a
     repo → **exit 10** (deny; *not* fail-open).
   - **Arg parsing:** first positional = subcommand; resolve `--session` /
     `LOOM_SESSION_ID`; missing required `--session` (for lock/claim subcommands) or
     unknown subcommand → exit 1.
   - **Helper functions:** `now()` (`date +%s`); `is_alive <session-id> [pid]`
     (session-id-primary: grep the `<session-id>` token in `git worktree list
     --porcelain`; pid `kill -0` only as secondary fallback); `lock_held_by_self`
     (read `holder`, compare session-id); `read_claim <slice>` / `write_claim` /
     `remove_claim` (TSV line ops on `$CLAIMS`, e.g. `grep`/`awk` filter to a temp
     then `mv` — atomic replace); `backoff_sleep <attempt>` (fractional `sleep` with
     integer fallback). Keep all `shellcheck`-clean (quote everything; `mkdir -p`
     state dir before any write).
   - Implement every subcommand per the CLI-contract tables above. Lock/claim
     subcommands fail **closed** (non-zero) on any ambiguity.
   - Identity-neutral: `session-id`/`pid` are out-of-band liveness only; **no** git
     identity is set/overridden; **no** commits are made.

2. **Create `plugins/loom/lib/loom-coord.bats`** (`#!/usr/bin/env bats`, mirroring
   the existing hook suites: header, a `setup()` that builds an **isolated temp git
   repo** in `BATS_TEST_TMPDIR` with a throwaway identity, and helpers to (a) drive
   the helper with a `--session`, (b) fabricate a **live** holder/claimant — a real
   `git worktree add` whose path contains a session-id token so the liveness probe
   reports *alive* — and (c) fabricate a **dead** holder — a session-id with no
   worktree and a guaranteed-dead pid). All state writes land in the temp repo's
   `.git/`, never loom's real `.git/`. Cases in the acceptance plan.

3. **Run the shell gate green and record the evidence** in `## Notes` (see
   Verification).

**Files this slice creates / edits:**
- **create** `plugins/loom/lib/loom-coord.sh`
- **create** `plugins/loom/lib/loom-coord.bats`
- **edit (planner, in this commit)** `.docs/slice-plans/README.md` — add the Active-plans entry
- **finalize, NOT pre-written (developer, on land)** `CLAUDE.md` "Repo layout" digest — new `plugins/loom/lib/` dir + the helper as loom's **third** executable component

**Explicitly NOT touched here:** `plugins/loom/hooks/hooks.json` (the helper is **not**
a hook — no registration); `references/parallelism.md` / `references/orchestration.md`
/ `commands/run.md` (slice W's wiring); `gates/shell.md` (the Verified shell gate is
already path-generic — it applies to `plugins/loom/lib/*.sh` unchanged; **no edit
needed**, a deliberate decision); any spec/ADR text (frozen — ADR 0005/0014).

## Verification

**Gate: Shell** (`gates/shell.md`), run in order on the new files; all must pass and
are **re-run** by the code evaluator (it does not trust the recorded result):
- format: `shfmt -i 4 -d plugins/loom/lib/loom-coord.sh`
- lint: `shellcheck plugins/loom/lib/loom-coord.sh`
- test: `bats plugins/loom/lib/loom-coord.bats`

Record the pass count (e.g. "N/N green") in the slice progress note.

**Required `bats` cases** (new-behavior proof + the negatives ADR 0014 demands):

- **Lock — atomic acquire.** `lock-acquire` on a free lock → exit 0; assert
  `main.lock/holder` exists and its session-id field == the caller.
- **Lock — contention backoff against a LIVE holder.** Holder session-id is present
  in `git worktree list`; a second `lock-acquire` (short `LOOM_LOCK_RETRIES`) →
  **exit 3**; assert the original holder stamp is **unchanged**.
- **Lock — stale force-clear gated on liveness (positive).** Holder is **dead**
  (session-id absent + pid dead) and `holder` epoch is older than `LOOM_LOCK_TTL=0`
  → contender force-clears and acquires → exit 0; assert `holder` now == contender.
- **Lock — live holder NOT cleared (negative).** Holder is **alive** (session-id in
  `git worktree list`) and past `lock-TTL` → contender → **exit 3**; assert holder
  unchanged (the live-but-slow holder is never force-cleared).
- **Lock — release by non-holder.** `lock-release --session <other>` → exit 5; lock
  intact.
- **Claim — free slice.** Under a self-held lock, `claim X` → exit 0; assert the
  registry line and the session's `held-claims` both contain `X`.
- **Claim — check-then-act race (interim live peer).** Registry already has a **live**
  peer claim on `X`; `claim X` → **exit 4**; registry unchanged.
- **Claim — re-affirm own claim** → idempotent exit 0.
- **Claim — not under the lock.** `claim X` with the lock held by **another** session
  → exit 5.
- **Lease — renew.** `renew X` → exit 0; assert the lease epoch advanced **and** the
  pid field was overwritten. `renew` by a non-owner → exit 5.
- **release-claim** removes the line + drops it from `held-claims`.
- **Stale-claim reclaim (positive).** Peer claim on `X`, peer **dead**, lease past
  `LOOM_LEASE_TTL` → `reclaim X` → exit 0; assert orphan worktree pruned
  (`git worktree list` no longer shows it) and the registry entry now owned by the
  reclaimer. **(negative)** peer **alive** → `reclaim X` → **exit 6**, claim unchanged.
- **Per-session state.** `session-start` (no `--session`) prints a fresh uuid and
  creates `session-<id>/`; `checkpoint-write`/`checkpoint-read` round-trip; `claim`
  updates `held-claims`.
- **Restart re-adoption.** `session-start` id `S`; `claim` two slices; simulate a
  cold restart (new pid — drive `session-bootstrap --session S` from a fresh
  invocation) → leases **renewed** (pid overwritten, epoch refreshed), `held-claims`
  re-read and printed. Assert a **peer** liveness probe sees `S` as **alive**
  throughout (its worktree keeps `S` in `git worktree list`), so the lease is never
  reclaimable across the owner's own restart.
- **Cleanup.** A **dead** session's orphan worktree is pruned, its claims cleared, its
  `session-<id>/` removed, and a stale dead-holder lock force-cleared; a concurrent
  **live** session's worktree/claims/lock are untouched.
- **Fail-closed.** `lock-acquire` / `claim` with git unavailable or outside any repo
  → **exit 10** (deny) — explicitly assert it is **not** 0 (the inverse of the hooks'
  fail-open).
- **Usage.** A lock/claim subcommand with no `--session` → exit 1; unknown
  subcommand → exit 1.

**Regression proof:** the existing `plugins/loom/hooks/git-identity-guard.bats` and
`plugins/loom/hooks/precompact-write-ahead-backstop.bats` suites are **not touched**
by this slice and must still pass unchanged; `hooks.json` is unmodified (assert no
new hook entry — the helper is deliberately unregistered).

## Notes

(Reserved for gate evidence and inter-role clarifications, dated. Formal verdicts
live in `.docs/evaluations/`, not here.)

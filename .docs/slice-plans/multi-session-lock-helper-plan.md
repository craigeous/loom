# Multi-Session Lock / Claim Coordination Helper

Status: Implemented
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
| Lock primitive | `mkdir` lock dir (atomic, fails if exists); stale reclaim via **atomic clear-and-own / rename-capture CAS** (never a bare `rm -rf`+re-`mkdir`) — see "Lock ownership invariants + atomic clear-and-own" | — |
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

**Cross-store write-ordering + fail-closed (MINOR — a precondition W must honor).**
Because the helper's `claim` exit 0 means "no live peer claim **in the registry**"
(not "not already landed"), the two stores must be written in an order that fails
**closed** under a partial failure. The mandated ordering, **both inside the same
held lock**: (1) `claim <slice>` writes the operational registry entry → (2) W renders
the `{session-id, pid, lease-timestamp}` lease into `slice-plans/README.md`'s Active
region and **commits** it on `main`. **The registry write must precede the README
commit.** Rationale: the dangerous direction is *README-claimed but registry-free* —
a peer's `claim` would re-read the registry, see the slice free, and **double-grant**.
Registry-first eliminates it: a registry entry always exists at least as long as the
committed README claim. The fail-closed obligation on W: **if the README render/commit
fails, W must `release-claim <slice>` to roll the registry back before releasing the
lock** — never leave a registry claim without its durable README lease. A crash
between the two writes leaves a registry entry owned by a now-dead session, which the
stale-claim liveness reclaim (below) and `cleanup` clear safely; the authoritative
README never shows a claim that was not durably the session's. Peers never observe the
intermediate state because both writes happen under the one held lock and a peer
acquires that lock only after this session releases it.

**W precondition — worktree paths embed the session-id (MINOR).** The session-id-primary
liveness probe is sound **only if** every session names its slice worktree(s) with a
path that contains its `session-id` token (so a live holder's id appears in
`git worktree list --porcelain`). This is derivable from spec 04's session-id-primary
rule, but the helper's correctness rests on it: if W ever creates a worktree whose path
omits the session-id, the probe reads a live holder as **dead** and the helper would
force-clear live locks/leases (catastrophic). **W (the next slice) MUST name slice
worktrees so the path embeds the session-id** — stated here as an explicit precondition
the helper documents and depends on; the helper itself only reads `git worktree list`.

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
| `lock-acquire` | `--session` | `acquired` | `mkdir` the lock dir atomically; on success stamp `holder` = `<session-id>\t<pid>\t<epoch>`, **re-read `holder` and confirm its session-id == self** (INV-1), then exit 0. On `mkdir` failure (held): exponential backoff (table above). **Past `lock-TTL`**, and **only after** the liveness probe shows the holder **dead** (session-id absent — never on the TTL alone, never a live-but-slow holder → keep backing off): run the **atomic clear-and-own** sequence below (a rename-capture CAS, **not** a bare `rm -rf` + re-`mkdir`). On exhausted retries → exit 3. Any state ambiguity → exit 10. |
| `lock-release` | `--session` | — | Verify `holder`'s session-id == self; remove the lock dir; exit 0. Held by another / not held → exit 5 (lock left intact). |
| `lock-holder` | — | `<id>\t<pid>\t<epoch>` or empty | Diagnostics/tests: print the current holder stamp. |
| `lock-verify` | `--session` | `held` | **Holder-assertion primitive (MAJOR).** Atomic single read of `holder`: exit **0** iff its session-id field == self (caller currently holds the lock); exit **5** if held by another / not held; exit **10** on state ambiguity (deny). Makes no change. **This is the mandated land precondition:** W's land wiring MUST call `lock-verify --session <self>` immediately **before** the raw `git merge` and abort fail-closed (non-zero) if it does not hold — so the highest-stakes main write (race point 4) re-asserts ownership and cannot run on a stale "I acquired" belief (INV-2). |

### Lock ownership invariants + atomic clear-and-own (closes BLOCKER 1)

Two invariants make the lock a true mutex, and a third (the rename-capture
sequence) makes stale-reclaim safe. Everything below is the authority for the
`lock-acquire` stale path and the land precondition.

- **INV-1 — single-valued holder.** Ownership is defined as *"the lock dir exists
  and its `holder` file names you."* The only atomic gate that writes a fresh
  `holder` is `mkdir "$LOCK_DIR"` succeeding (it fails if the dir exists). At any
  instant `holder` can name **at most one** session. `lock-acquire` confirms its own
  stamp by re-reading `holder`==self before returning `acquired`.
- **INV-2 — re-assert before every locked act.** Every operation performed *under*
  the lock re-reads `holder`==self **immediately before its effect** and fails closed
  (exit 5) otherwise. `claim`/`renew`/`release-claim`/`reclaim` already do this; the
  **land** path (W's raw `git merge`, which the helper does not mediate) does it via
  the new **`lock-verify --session`** precondition. Consequently a session that lost
  the lock to a concurrent clear-and-own can **never** perform a `main` write on a
  stale "I acquired" belief — even if two `lock-acquire` calls ever both returned
  `acquired`, `holder` names exactly one, so at most one passes the re-assert and
  acts. This is what keeps ADR 0014 race point 4 (concurrent merge) closed.

**Atomic clear-and-own (rename-capture CAS).** A bare `rm -rf "$LOCK_DIR"` is
unconditional on the *directory*, so two contenders that both observed the same dead
holder could each `rm -rf` + `mkdir` and the second would delete the first's
freshly-won lock — both told `acquired`. The fix replaces it with a per-contender
**atomic capture**, because a POSIX directory `rename(2)` of a given source can
succeed for **exactly one** caller (the loser gets `ENOENT` — the source is gone):

1. Read and record the **exact** observed holder stamp `H_obs` from
   `"$LOCK_DIR/holder"`. (Reached only when the probe already showed it **dead** and
   past `lock-TTL`.)
2. `mv "$LOCK_DIR" "$CAP"` where `CAP="$STATE_DIR/.main.lock.reclaiming.<session-id>.<pid>.<epoch>"`
   is **unique per contender**. *Race-free because:* directory rename is atomic and
   only one concurrent `mv` of `"$LOCK_DIR"` can win; the **loser**'s `mv` fails
   (source already moved away) → it does **not** clear anything, returns to the
   backoff loop, and re-reads from scratch.
3. The **winner** verifies the capture: re-read `"$CAP/holder"` and require it ==
   `H_obs` **and** still-dead by the liveness probe.
   - **Match** (it really captured the stale dir it observed): `rm -rf "$CAP"`, then
     `mkdir "$LOCK_DIR"` — the **single atomic ownership gate** (INV-1). On success →
     stamp `holder`=self, confirm `holder`==self, return `acquired`. On failure (a
     peer re-created it first) → do **not** force; read `holder` and treat as a normal
     contended lock (live → back off; dead+stale → loop the sequence again).
   - **Mismatch** (an ABA: a live peer reclaimed in the interim, so `CAP` holds a
     *different / live* stamp): the winner did **not** capture a stale lock and must
     **not** install ownership. Best-effort restore — `mv "$CAP" "$LOCK_DIR"` if
     `"$LOCK_DIR"` is absent, else `rm -rf "$CAP"` — then return to the backoff loop.
     Either outcome is **safe**: ownership is *never* installed on a mismatch, and any
     peer whose dir was momentarily displaced re-asserts `holder`==self before its
     next locked act (INV-2) and aborts fail-closed rather than acting blindly.
4. **Ownership is always decided by `mkdir "$LOCK_DIR"` + the single-valued `holder`
   stamp, never by the rename alone.** The rename only guarantees the stale dir is
   detached-and-removed **exactly once**, so no `rm -rf` can ever destroy a
   freshly-won (live) lock. Combined with INV-1/INV-2, exactly one contender can take
   over a stale lock; the loser exits 3.

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
     integer fallback); `clear_and_own` (the rename-capture CAS of "Lock ownership
     invariants + atomic clear-and-own": `mv "$LOCK_DIR" "$CAP"`, verify captured
     stamp == observed-dead `H_obs`, `rm -rf "$CAP"`, `mkdir "$LOCK_DIR"` as the
     ownership gate, stamp+confirm `holder`==self; restore-or-discard on mismatch;
     **never** a bare `rm -rf "$LOCK_DIR"`). Keep all `shellcheck`-clean (quote
     everything; `mkdir -p` state dir before any write).
   - `lock-verify` is the side-effect-free atomic single read of `holder` (exit 0/5/10
     per the table) — the holder-assertion primitive W's land calls before `git merge`.
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
   worktree and a guaranteed-dead pid — and (d) a **race harness** that launches two
   real `lock-acquire` invocations as **concurrent background subshells** (`&`),
   `wait`s for both, and captures each one's exit code + the resulting `holder`
   stamp (a true concurrency test, not a prose assertion). All state writes land in
   the temp repo's `.git/`, never loom's real `.git/`. Cases in the acceptance plan.

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
- **Lock — mutual exclusion under concurrent stale reclaim (BLOCKER 2, the
  safety-critical case).** Seed a single **dead** holder D's stale lock (session-id
  absent, epoch past `LOOM_LOCK_TTL=0`). Launch **two** contenders A and B racing
  `lock-acquire` as concurrent background subshells via the race harness; `wait` both.
  Assert **exactly one** exits 0 and the other exits **3** (non-zero) — never two
  zeros; and assert `main.lock/holder`'s session-id == the **single** winner (the
  loser's id is never in `holder`). This proves the rename-capture clear-and-own hands
  "acquired" to exactly one session. Run it under a small repeat loop (e.g. 10×) to
  exercise the interleaving, since a single pass can miss a race.
- **Lock — a second `acquired` is never observable while a first is held.** With A
  holding the lock (fresh stamp), a second `lock-acquire --session B` (short
  `LOOM_LOCK_RETRIES`) → **exit 3**, and `lock-verify --session A` → exit 0 while
  `lock-verify --session B` → exit 5 throughout (the holder is single-valued).
- **Lock — `lock-verify` holder-assertion (MAJOR).** While A holds: `lock-verify
  --session A` → **exit 0** (stdout `held`); `lock-verify --session B` → **exit 5**;
  with no lock present → **exit 5**; with git unavailable / outside a repo → **exit
  10** (deny). Assert `lock-verify` makes **no** change to `holder`.
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

**Gate evidence (round 5, 2026-07-03 — W1-W7 peripheral defect fixes):**
- `shfmt -i 4 -d plugins/loom/lib/loom-coord.sh plugins/loom/lib/loom-coord.bats` → FORMAT CLEAN
- `shellcheck plugins/loom/lib/loom-coord.sh plugins/loom/lib/loom-coord.bats` → SHELLCHECK CLEAN (SC3043 suppressed file-wide; pre-existing SC2314 fixed with `run !` + `bats_require_minimum_version 1.5.0`)
- `bats plugins/loom/lib/loom-coord.bats` → **62/62 pass** (pre-existing 62 all green; V2/V3 tests rewritten to exercise CAS paths; W5/W6 now reach the delete-CAS-first / steal-CAS-first branches)
- W1: `LOOM_LOCK_RENEW_INTERVAL` override validated (floor≥1, clamp<TTL); W2/W4: slice name base64-encoded in claim blobs / decoded in list-claims; W3: `refs/loom/schema` v2 marker created + fail-closed on version mismatch; W5/W6: V2/V3 tests rewritten with stale claims (ts=0) to exercise CAS branches; W7: list-claims reads blob once.

**Gate evidence (Pass 3, 2026-07-02 — U2/U5/U6/secondary defect fixes):**
- `shfmt -i 4 -d plugins/loom/lib/loom-coord.sh` → FORMAT CLEAN
- `shellcheck plugins/loom/lib/loom-coord.sh` → SHELLCHECK CLEAN
- `bats plugins/loom/lib/loom-coord.bats` → **55/55 pass** (51 pre-existing + 4 new: U2, U5, U6, PROC-1)
- Fixes landed: U2 (`claim_is_fresh` fail-closed on empty/non-numeric epoch); U5 (`renewer-stop` skips kill when `rst` empty); U6 (covered by U2 + cleanup's existing R7 guard, regression test added); secondary proc parse (robust field-22 via last-`)` split); secondary atomic writes (session.pid, session.starttime, renewer.pid, renewer.starttime all written via temp+mv).

**Gate evidence (round 4, 2026-07-02 — ADR 0015 liveness rework):**
- `shfmt -i 4 -d plugins/loom/lib/loom-coord.sh plugins/loom/lib/loom-coord.bats` → FORMAT CLEAN
- `shellcheck plugins/loom/lib/loom-coord.sh` → SHELLCHECK CLEAN (SC3043 suppressed file-wide)
- `bats plugins/loom/lib/loom-coord.bats` → **52/52 pass** (44 pre-existing + 8 new: T1, T3, T4, T5, LV-fresh, LV-stale, RNW-1, RNW-2)

**Gate evidence (round 3, 2026-06-30):**
- `shfmt -i 4 -d plugins/loom/lib/loom-coord.sh plugins/loom/lib/loom-coord.bats` → FORMAT CLEAN
- `shellcheck plugins/loom/lib/loom-coord.sh` → SHELLCHECK CLEAN (SC3043 suppressed file-wide)
- `bats plugins/loom/lib/loom-coord.bats` → 37/37 pass (30 original + 7 new negatives)
- Existing hook suites unchanged: `bats plugins/loom/hooks/git-identity-guard.bats plugins/loom/hooks/precompact-write-ahead-backstop.bats` → 39/39 pass

**Round-3 fixes (eval round-2 FAIL):**
- F1: replaced unanchored `grep -F "${slice}\t"` in `read_claim`/`write_claim`/`remove_claim` with `awk -F'\t' -v s="$slice" '$1==s'` / `$1!=s` (exact first-field match; prevents `v2` op from touching `auth-v2`).
- F2: guarded all `CLAIMS` mutation in `cmd_cleanup` behind `got_lock=1`; exits 3 (fail-closed) when lock unavailable.
- F3: `clear_and_own` no longer returns 1 on empty holder; `cmd_lock_acquire` and `cmd_session_end` now attempt `clear_and_own` on a holderless lock dir; holderless is always reclaimable.
- F4: `is_alive` primary probe anchored to `grep -qE "${sid}(/|$)"` so `ses-foo` doesn't match `wt-ses-foo-bar`.
- F6: broken `awk '/^/{…}'` replaced with `awk '/^worktree /{print $2}'` in both `cmd_reclaim` and `cmd_cleanup`; `cmd_cleanup` adds dead-pid+expired-lease override to force-remove stale worktree dirs.
- F7: `cmd_session_end` adds stale-lock handling; `rm -rf $sess_dir` only after successful lock+claim-release; exits 3 when lock unavailable.
- F8: removed dead `ORIG_SUBCOMMAND`/`SUBCOMMAND` dance in `cmd_session_bootstrap`.
- F9: hoisted `git worktree list --porcelain` to run once per cleanup sweep.
- 7 new negative bats cases: NEG-F1, NEG-F1b, NEG-F2, NEG-F3, NEG-F4, NEG-F6, NEG-F7.

**Key implementation decisions recorded here:**
- `add_held_claim` does `mkdir -p` on the session dir (defensive, works even if session-start not called first).
- L5 concurrent test uses `LOOM_LOCK_TTL=5` (not 0): dead holder at epoch=0 is always stale; fresh winner's lock at epoch≈now is not (elapsed≈0 < 5), preventing the winner being immediately reclaimed.
- `wait || true` pattern used in L5 so bats doesn't interpret a losing contender's exit 3 as a test failure.
- `session-bootstrap` uses an inline acquire loop (no nested function definition) to stay shellcheck-clean.
- RCL1 test does NOT create a git worktree for the dead session — a registered-but-missing worktree still appears in `git worktree list` until pruned, so creating-then-deleting would make the liveness probe return alive.

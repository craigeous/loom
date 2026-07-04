# Multi-Session Playbook Wiring

Status: Archived
Lifecycle: Draft → **Plan Review** → Approved → In Progress → Implemented → (code review) → Landed → Archived
Target specs: 04-orchestrator.md → "Multi-session coordination (ADR 0014, ADR 0015, ADR 0016)"; ADR 0014 (model) / ADR 0015 (lease-freshness + renewer) / ADR 0016 (git-`update-ref` CAS substrate)

## Context

The multi-session coordination model is **settled** (spec 04 § "Multi-session
coordination", frozen; ADR 0014/0015/0016 accepted) and its CLI has **already
landed**: `plugins/loom/lib/loom-coord.sh` (loom's first non-hook helper), shell-gated
green, code-eval PASS. What is missing is the **playbook wiring**: the operational
bodies the orchestrator actually reads still describe only ADR 0008's
*single-orchestrator* worktree model and never mention `loom-coord.sh`. This slice
folds the multi-session model into those bodies so a cold orchestrator instructed by
the playbook will `session-start`, claim-before-work, lock the shared-`main` critical
section, run the background renewer, and `session-end` — all via real `loom-coord`
subcommands.

**`loom-coord.sh` is frozen and passed here.** This is a **pure-documentation**
slice: it edits playbook prose only, wiring the orchestrator's *instructions* to the
existing CLI. It writes **no code** and does **not** touch `loom-coord.sh`, its bats
suite, the hooks, `hooks.json`, any spec, or any ADR.

The CLI surface being wired to (verified against the `case "$SUBCOMMAND"` dispatch in
`plugins/loom/lib/loom-coord.sh` lines ~1321–1343 and the exit-code header lines
~27–36):

- **Lock:** `lock-acquire`, `lock-release`, `lock-verify`, `lock-holder`
- **Claims:** `claim <slice>`, `renew <slice>`, `release-claim <slice>`,
  `reclaim <slice>`, `list-claims`
- **Session:** `session-start`, `session-bootstrap`, `session-end`,
  `checkpoint-write`, `checkpoint-read`
- **Renewer:** `renewer-start <session-pid>`, `renewer-stop`
- **Sweep:** `cleanup`
- **Exit codes:** `0` success · `1` usage/missing-arg · `3` lock busy (backoff
  exhausted) · `4` claim taken by a live peer (abort + re-select) · `5` precondition
  (lock not held / claim not owned / session not started) · `6` reclaim refused
  (holder still alive) · `10` fail-closed tooling/parse ambiguity.

**Out of scope (non-scope):**

- Any change to `loom-coord.sh`, `loom-coord.bats`, or `hooks/` (code is frozen).
- Any new or edited `spec/` or `ADR/` (spec 04 is the frozen authority; this slice
  only *implements* it in the playbook).
- The TTL / cadence *values* and other implementation parameters (owned by the CLI,
  deferred there per spec 04's closing paragraph).
- Retiring or rewriting ADR 0008's still-valid single-session facts — they are
  **preserved and extended**, never replaced.

## The action → subcommand mapping (author to this shape)

Each edited body must express the orchestrator-action → `loom-coord` subcommand map
below, including the exit-code branch for each. This table is the normative content
the prose must encode (it is **not** copied verbatim into the bodies — each body
phrases the subset it needs).

| Orchestrator action | `loom-coord` subcommand | Exit-code handling |
|---|---|---|
| **Session kickoff** — mint the stable `session-id`, create per-session `.git/` state | `session-start [--session <id>]` (prints the `session-id`) | `0` → adopt the printed id; `10` → fail-closed, abort session and tell the owner |
| **Launch the renewer** — once, on first lock/claim acquire | `renewer-start <session-pid> --session <id>` | `0` (`renewer-started` / `renewer-already-running`) → ok; `5` session not started → run `session-start` first; `10` cannot read start-time → abort |
| **Cold-restart bootstrap** — re-adopt id, renew held leases, print checkpoint | `session-bootstrap --session <id>` then re-`renewer-start` only if the renewer did not survive | `0` → resume from printed checkpoint; `3` could not acquire lock → backoff + retry; `5` session not found → treat as fresh `session-start` |
| **Enter the shared-`main` critical section** (claim registration OR land+finalize) | `lock-acquire --session <id>` | `0` acquired → proceed; `3` busy (backoff exhausted) → defer this main-side op, keep working slices, retry later; `10` → fail-closed, abort the op |
| **Re-verify the lock before landing** (fail-closed land guard) | `lock-verify --session <id>` | `0` `held` → land; `5` not held → abort land, re-`lock-acquire`; `10` → abort |
| **Claim a free slice** (under the lock, after re-reading Active/claim state from current local `main`) | `claim <slice> --session <id>` | `0` claimed → register in Active + release lock + create worktree; `4` live peer → abort, re-select another slice; `5` lock not held → re-acquire; `10` → abort |
| **Reclaim a stale slice** (under the lock) | `reclaim <slice> --session <id>` | `0` reclaimed (worktree pruned) → proceed; `4` CAS failed (holder renewed) → skip, holder alive; `5` lock not held / already owner; `6` holder still fresh → skip |
| **Renew held leases** — background only, never called by the driver loop | `renew <slice> --session <id>` | invoked by the detached renewer; `0` renewed; `5` CAS failed / not owned (renewer self-corrects) |
| **Land subsumes claim release** (delete-CAS of own claim, under the lock) | `release-claim <slice> --session <id>` | `0` released; `5` lock not held / not owned |
| **Exit the critical section** | `lock-release --session <id>` | `0` released; `5` not held by self (renewer-safe re-read handled inside the CLI) |
| **Dispatch pre-scan** — list live claims (unlocked pre-filter) | `list-claims` | `0` prints `slice⇥sid⇥ts` rows; authoritative re-check is still done under the lock against current local `main` |
| **Write-ahead checkpoint** — off-`main` per-session anchor (ADR 0013 rule 1) | `checkpoint-write --session <id> "<next action>"` | `0`; `5` session not started |
| **Read checkpoint on restart** | `checkpoint-read --session <id>` | `0` |
| **Session exit** — stop renewer, release claims + lock, remove state | `renewer-stop --session <id>` then `session-end --session <id>` | `session-end`: `0`; `3` could not acquire lock → claims not released, retry (never `rm` state on `3`) |
| **Periodic stale sweep** (before a new wave) | `cleanup [--session <id>]` | `0` `swept N; skipped M`; `3` lock busy → sweep skipped, retry |

**Invariants the prose must carry** (verbatim from spec 04, keep terminology
identical): the lock + claims are **git refs** (`refs/loom/lock`,
`refs/loom/claims/<slice>`) in the **common (shared) ref store**, mutated by
`git update-ref` **CAS**; **liveness = lease freshness** (a renewal heartbeat within
the TTL) — **never** worktree-list membership and **never** the process pid; a
**losing CAS is a clean, retryable failure**; there are **exactly three locked
shared-`main` writes** (claim / lease-renew / land+finalize); the background renewer
is gated on `{session-pid, session-pid-start-time}` (intra-session honesty check
only, never a cross-session liveness signal); the cold-restart anchor is
**off-`main`, per-session, under `.git/`**, keyed by a `session-id` stable across
restart.

## Steps

Edit four files. Verify every code/spec reference against the real tree before
relying on it (mechanical-check discipline — use `rg`, not the eye).

### 1. `plugins/loom/skills/loom-playbook/references/parallelism.md` — extend to the multi-session model

1a. **Intro (lines ~1–14).** After the ADR 0008 governing-decision sentence, add that
   this body now also operationalizes the **multi-session layer**
   ([ADR 0014](../../../../../.docs/ADR/0014-multi-session-worktree-coordination.md) /
   [0015](../../../../../.docs/ADR/0015-lease-renewal-heartbeat-liveness.md) /
   [0016](../../../../../.docs/ADR/0016-git-native-ref-cas-lock-mechanism.md)) via
   `plugins/loom/lib/loom-coord.sh`, layered **on top of** — not replacing — the
   single-orchestrator model. State that ADR 0008's disjoint-file, worktree-isolation
   guarantees are all **preserved**; the multi-session layer only adds cross-session
   serialization of the shared-`main` critical section.

1b. **New section — "Multi-session coordination — the cross-session lock + per-slice
   claims"** (insert after "What stays serial", or as a clearly-headed top-level
   section). Present the model: each top-level `/loom:run` session is its own thin
   orchestrator that owns its slice worktrees; the cross-session **lock**
   (`refs/loom/lock`) and per-slice **claims** (`refs/loom/claims/<slice>`) are git
   refs in the common ref store, managed **only** through `loom-coord.sh`
   (`git update-ref` CAS; ABA-safe; losing CAS = clean retry). Liveness is **lease
   freshness** kept alive by a `{session-pid,start-time}`-gated **background renewer**
   that heartbeats the lock **and** the claims. State the **three locked
   shared-`main` writes** (claim / lease-renew / land+finalize) and that all other
   session activity happens lock-free in the session's own worktree. Encode the
   subset of the action→subcommand mapping relevant to a session's lifecycle
   (`session-start` → work → `session-end`; the renewer; `session-bootstrap` on
   cold-restart).

1c. **"The `.docs/` coordination model" section (lines ~52–108).** Preserve the
   table (three living docs + `slice-plans/README.md` = orchestrator-owned, main-only,
   serialized) **unchanged in placement**, but add that under multi-session the
   serialization is now **across sessions**, enforced by the `loom-coord` lock rather
   than being true merely *by construction* of a single orchestrator. Add that the
   `slice-plans/README.md` Active region is the ADR 0008 index bucket that pairs with
   the `refs/loom/claims/<slice>` lease (a claim is **not** a new `Status:` token).

1d. **"Agent-input freshness" subsection (lines ~103–108) and the Create workflow
   (lines ~116–127).** Update the worktree base from `origin/main` to **local `main`**
   per spec 04 (loom commits to local `main` and does not push, so `origin/main`
   lags; consulting `origin/main` via `git fetch` is an **unlocked pre-filter only**,
   never authoritative). The authoritative "what has landed / what is claimed" read is
   **current local `main` under the lock**. Change the `git worktree add` command
   accordingly:
   `git worktree add -b <slice-branch> <session-owned-path> main`.

1e. **"Workflow: create → work → land → cleanup" (lines ~113–178).** Keep ADR 0008's
   flow intact and **layer** the lock/claim/renewer onto it:
   - **Create:** `lock-acquire` → re-read Active/claim state from current local `main`
     → `claim <slice>` (or `reclaim` if the current claim is stale) → record the slice
     in the `slice-plans/README.md` Active region → `lock-release` → **then** create
     the session-owned worktree and dispatch roles. On first claim, start the renewer
     (`renewer-start <session-pid>`). Skip any slice with a **live** peer claim
     (exit `4`).
   - **Land:** `lock-acquire` → `lock-verify` (fail-closed guard) → `git merge` →
     finalize the living docs + move the slice Active → Archived → `release-claim`
     (the land subsumes claim release) → `lock-release`.
   - **Cleanup:** unchanged worktree removal, plus `cleanup` as the periodic stale
     sweep and `session-end` at session exit.

1f. **"Concurrency safety" section (lines ~183–226).** Replace the `index.lock`-centric
   framing of the *coordination mechanism* with the git-CAS model: the cross-session
   lock/claim contention is a `git update-ref` **CAS** where a **losing CAS is a
   clean, retryable failure** (`loom-coord` retries with the same ADR 0008 exponential
   backoff internally; a caller that gets exit `3` backs off and retries the main-side
   op). Keep the lower-level `index.lock` note (concurrent commits still share one
   `.git/` object store) but subordinate it to the git-CAS coordination layer. Keep
   the git-identity-guard parallel-safety note as-is.

1g. **"What stays serial" section (lines ~229–247).** Update: the shared-`main`
   living-doc + index writes are now serialized **across sessions** by the
   `refs/loom/lock` cross-session mutex (not only within one orchestrator); name the
   three locked writes; reaffirm disjoint slice files stay conflict-free by
   construction and **lock-free**.

### 2. `plugins/loom/skills/loom-playbook/references/orchestration.md` — driver-loop wiring

2a. **New section — "## Multi-session coordination"** (place after "## Parallelism",
   lines ~222–232). Authority line pointing to spec 04 § "Multi-session coordination"
   + ADR 0014/0015/0016 + `parallelism.md` for the full body. Then the driver-loop
   obligations, each mapped to its subcommand + exit-code branch:
   - **At session kickoff:** run `session-start` (mint/adopt the stable `session-id`,
     create per-session `.git/` state). Opt-in per the owner; a single-session run may
     skip coordination entirely.
   - **Claim before working a slice:** under `lock-acquire`, re-read current local
     `main`, then `claim <slice>` — skip live-claimed slices (exit `4` → re-select),
     `reclaim` stale ones; on first acquire launch the renewer
     (`renewer-start <session-pid>`).
   - **Lock the critical section:** `lock-acquire` around claim-registration and
     land+finalize; `lock-release` after. The lock is **never** held across a role
     spawn or while a role works in a worktree.
   - **Derive the dispatch scan from current local `main`** (not the frozen slice
     worktree snapshot); `list-claims` is an unlocked pre-filter, the authoritative
     re-check is under the lock.
   - **Fail-closed land guard:** `lock-verify` immediately before `git merge`; a `5`
     aborts the land.
   - **At exit:** `renewer-stop` then `session-end` (release claims + lock, remove
     state); on exit-`3` retry, never orphan.

2b. **"### Restart safely" subsection (lines ~80–113) — cold-restart wiring.** Add a
   short note (not a rewrite): under multi-session the write-ahead anchor is the
   **off-`main` per-session** `checkpoint-write`/`checkpoint-read` state (keyed by the
   stable `session-id`), and a cold restart runs `session-bootstrap` to re-adopt the
   `session-id`, renew held leases, and resume from the printed checkpoint —
   relaunching the renewer only if it did not survive. Cross-reference spec 04's
   "Per-session write-ahead anchor" bullet. The shared human-facing `handoff.md` stays
   on `main`, written at land under the lock.

2c. **"## Parallelism" pointer (lines ~222–232).** Add one clause noting multi-session
   coordination is active via `loom-coord.sh` (see the new section + `parallelism.md`).

### 3. `plugins/loom/commands/run.md` — concise pointer

3a. **"Read first" list (lines ~12–16).** Add a bullet:
   `${CLAUDE_PLUGIN_ROOT}/lib/loom-coord.sh` — the multi-session coordination CLI
   (cross-session lock + per-slice claims + renewer), active when the owner opts in.

3b. **Driver-loop step (near step 3d, lines ~54–60).** Add a concise sentence: when
   the owner opts into multi-session runs, coordinate via `loom-coord.sh` —
   `session-start` at kickoff, `claim <slice>` (under `lock-acquire`) before working a
   slice, `lock-verify` before landing, `session-end` at exit — per
   `orchestration.md` → *Multi-session coordination* and `parallelism.md`. Keep it a
   pointer, not a restatement of the mapping.

### 4. `plugins/loom/skills/loom-playbook/SKILL.md` — reference-index pointer

4a. **`parallelism.md` bullet (lines ~70–74).** Extend it to note the body now also
   covers the **multi-session layer** (ADR 0014/0015/0016) — the cross-session
   `refs/loom/lock` + per-slice `refs/loom/claims/<slice>` git-CAS coordination via
   `plugins/loom/lib/loom-coord.sh`, lease-freshness liveness, and the background
   renewer. Optionally add a one-line pointer to `lib/loom-coord.sh` as loom's
   coordination CLI. Do not add a new reference file (the CLI is code, not a
   `references/` body).

## Verification

**Gate:** this is a **pure-documentation** slice — no code changes, so the shell gate
does **not** apply and the automated review (`/code-review` + `/security-review`) is
**skipped: docs-only** (spec 04 § "Automated review" applicability; ADR 0010 §5). The
"gate" here is **doc consistency**. An independent reader runs these mechanical
checks (verify with tools, not by eye):

1. **CLI is wired in every intended file.** `loom-coord` is referenced in all four
   edited files:
   `rg -l 'loom-coord' plugins/loom/skills/loom-playbook/references/parallelism.md plugins/loom/skills/loom-playbook/references/orchestration.md plugins/loom/commands/run.md plugins/loom/skills/loom-playbook/SKILL.md`
   returns all four.

2. **Every named subcommand exists in the CLI.** For each subcommand the bodies name
   (`session-start`, `session-bootstrap`, `session-end`, `lock-acquire`,
   `lock-release`, `lock-verify`, `claim`, `reclaim`, `release-claim`, `renew`,
   `list-claims`, `renewer-start`, `renewer-stop`, `checkpoint-write`,
   `checkpoint-read`, `cleanup`), confirm it appears in the `case "$SUBCOMMAND"`
   dispatch of `plugins/loom/lib/loom-coord.sh`:
   `rg -n '^\s*(session-start|session-bootstrap|session-end|lock-acquire|lock-release|lock-verify|claim|reclaim|release-claim|renew|list-claims|renewer-start|renewer-stop|checkpoint-write|checkpoint-read|cleanup)\)' plugins/loom/lib/loom-coord.sh`.
   No body may name a subcommand not in that dispatch.

3. **Exit codes match the CLI header.** Every exit code cited in the prose
   (`0/1/3/4/5/6/10`) matches the meaning in the `loom-coord.sh` exit-code header
   (lines ~27–36) — cross-read, no invented codes.

4. **Cross-references resolve.** Every relative link added
   (`../../../../../.docs/ADR/0014-…`, `…/0015-…`, `…/0016-…`, the spec-04 anchor)
   points to a real file: `ls .docs/ADR/0014-*.md .docs/ADR/0015-*.md
   .docs/ADR/0016-*.md .docs/spec/04-orchestrator.md`. No broken links introduced
   (check the four edited files' links resolve).

5. **Terminology parity with spec 04.** The bodies use the spec's exact terms —
   "lease freshness", "git-CAS" / `git update-ref`, `refs/loom/lock`,
   `refs/loom/claims/<slice>`, "common (shared) ref store", "three locked
   shared-`main` writes", "background renewer", `{session-pid, session-pid-start-time}`
   (intra-session only), off-`main` per-session checkpoint anchor. Spot-check with
   `rg` that no contradicting claim was introduced (e.g. no text asserting
   worktree-list membership or pid as a **cross-session** liveness signal — that is
   explicitly forbidden by ADR 0015 / spec 04).

6. **ADR 0008 preserved.** The single-orchestrator disjoint-file / worktree-isolation
   guarantees remain stated (not deleted) in `parallelism.md`; the multi-session layer
   is presented as an extension.

## Notes

<none yet>

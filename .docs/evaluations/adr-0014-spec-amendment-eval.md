# Evaluation: ADR 0014 spec amendment (spec 04 Parallelism)

Verdict: PASS
Round: 0
Reviewed against: ADR 0014 (Approved/immutable); ADR 0008, ADR 0005, ADR 0001, ADR 0003, ADR 0013, ADR 0012; references/plan-eval-rubric.md, references/severity.md; the surrounding spec 04 (consistency)

## Findings

No BLOCKER, MAJOR, or MINOR findings.

The amendment (commit `bf881c9`, the new `### Multi-session coordination (ADR 0014)`
subsection, lines 186–347) is a faithful, in-scope, internally consistent fold of
ADR 0014 into the frozen spec it names. Reviewed only the new subsection; the
pre-existing ADR 0008 Parallelism prose above it (lines 149–184) is untouched and
remains coherent with the addition.

### Faithfulness — all five ADR-0014 invariants present and accurate

1. **Session-owned slice worktrees off fresh local `main`** (lines 199–209) —
   `git worktree add -b <slice-branch> <session-owned-path> main`, off fresh current
   local `main`, disjoint uniquely-named slice files conflict-free **by construction**
   and **lock-free**; base is local `main` not `origin/main` (no-push model). Matches
   ADR §1 / §3 / §4-Extended.
2. **Cross-session lock on `main`'s critical section, with a `lock-TTL` distinct from
   the slice lease + liveness-gated force-clear** (lines 219–244) — `{claim,
   merge+finalize-land}` critical section; per-repo mutex under `.git/` (mkdir-dir or
   ref-CAS); out-of-band `{session-id, pid, acquired-timestamp}` stamp; ADR 0008
   backoff reused; held only for a short bounded op, never across a role spawn;
   own short `lock-TTL` separate from the lease TTL; force-clear gated on the liveness
   check, never the TTL alone; live-but-slow holder never cleared. Matches ADR §2.
3. **Slice claim/lease — check-then-act under the lock + liveness-gated stale reclaim**
   (lines 256–279) — lease in the `slice-plans/README.md` Active region; acquire lock,
   re-read lease/Active state from current local `main` while holding it, abort+reselect
   if X was claimed/landed in the interim, else write `{session-id, pid,
   lease-timestamp}`, commit, release, then create worktree; skip live claims;
   stale-claim reclaim gated on a positive holder-is-dead check, renew-or-be-reclaimed.
   Matches ADR §3.
4. **Per-session off-`main` write-ahead anchor** (lines 281–306) — machine cold-restart
   anchor moves to `.git/loom-session-<session-id>/` holding `{session-id, write-ahead
   checkpoint, held-claims}`, untracked, no lock, per-session (a restarting session reads
   only its own); preserves ADR 0013 rule 1's write-ahead invariant, extends only the
   medium; rule 3's forward-progress guard reads the per-session checkpoint + the
   session's own most-recent commit; `session-id` stable across restart, never pid-derived,
   re-adopted + leases renewed (refresh `lease-timestamp` and `pid`) on bootstrap; the
   human-facing `handoff.md`/`roadmap.md`/`progress.md` stay shared, single-instance, on
   `main`, written only at land under the lock at milestone granularity. Matches ADR §1.
5. **Authoritative read = fresh local `main` under the lock** (lines 211–217) — read from
   shared local `main`, never the frozen slice-worktree snapshot; `origin/main` via
   `git fetch` is an unlocked optimization/pre-filter only, never authoritative; the
   correctness-critical re-read is local `main` under the lock. Matches ADR §3.

### The two deliberate living-prose corrections — both stated correctly

- **THREE locked shared-`main` writes** (lines 308–322, restated in the invariant list
  lines 326–327): claim, **lease-renew**, land+finalize. The immutable ADR §1 enumerates
  "exactly two moments" (claim, land), but ADR §3 itself requires lease-renew to write the
  refreshed `lease-timestamp`/`pid` to the Active region on `main` **under the lock** (on
  the renew cadence and on cold-restart bootstrap). The spec's correction to three is the
  more complete and correct enumeration — it folds in a shared-`main` write the ADR's "two"
  count omitted, without weakening anything. Per the invocation this divergence is
  deliberate and is **not** flagged. Verified mechanically (`grep -n "two|three"`): every
  occurrence in the subsection reads "three"; no residual "two locked writes" claim remains.
- **Liveness session-id-primary** (lines 246–254; invariant lines 330–331; applied to both
  the lock force-clear and the stale-lease reclaim, lines 271–279): alive iff `session-id`
  present in `git worktree list`; `pid` a secondary probe only; a force-clear of the lock
  **or** a lease requires `session-id` **absent**, and "pid-not-alive alone is **not**
  sufficient while the session-id is still present." This correctly hardens the ADR's
  "and/or" (ADR §2 line 167, §3 line 258) into the restart-safe primary/secondary rule —
  consistently applied to both resources. Per the invocation this divergence is deliberate
  and is **not** flagged.

### No new contradictions; cross-references resolve

- **ADR 0008 intact.** The amendment opens by stating it **extends — does not replace**
  ADR 0008 (lines 195–197), preserves the disjoint-files-by-construction/lock-free
  guarantee (lines 205–206, 335–336), and the only shared-`main` writes (living docs +
  index) are now serialized **across** sessions by the lock — the same "main-only,
  serialized" property ADR 0008's prose above asserts within one session. No contradiction
  with lines 161–184.
- **ADR 0001** (only the session spawns) — line 340. **ADR 0003** (uniform author-neutral
  identity; `session-id`/`pid` out-of-band liveness metadata, never commit/author metadata)
  — lines 228–229, 338–340. **ADR 0013** (write-ahead anchor relocated, invariant preserved,
  rule 3 guard reads per-session state) — lines 281–306, 292–294. **ADR 0012** (~60% cold
  restart) — line 282. All consistent with their authorities.
- **ADR 0005 / frozen-spec discipline.** This is the deliberate later planning pass ADR 0014
  Consequences call for; the artifact sits at `Status: Plan Review` for owner re-approval,
  not a landing side effect.
- **No new `Status:` token** (line 340) — the lease is bookkeeping in the existing Active
  region, not a lifecycle state; spec 03 stays unchanged. Consistent with ADR §Consequences.
- **Mechanism deferred** to a later POSIX-sh helper slice (lines 343–347) — matches ADR
  §Consequences; the spec records the contract, not the implementation.

## Required changes (for FAIL)

None — this is a PASS.

## Notes

- Spec 08 (and any related open question) is correctly **not** required here: ADR 0014
  Consequences already flags the playbook-body fold (`parallelism.md`, `orchestration.md`,
  `run.md`) and spec 08 as a separate follow-up wired only after this spec-04 amendment is
  approved. Its absence from this amendment is intended sequencing, not a defect.
- The subsection is dense but every clause traces to an ADR 0014 decision; length is not a
  rubric defect. The closing **Multi-session invariants** block (lines 324–347) is a faithful
  restatement of the three §-decisions and does not introduce any claim absent from the body.

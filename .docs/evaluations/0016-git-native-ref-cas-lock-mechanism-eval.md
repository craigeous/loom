# Evaluation: 0016 — Git-Native Ref Compare-and-Swap as the Lock/Claim Substrate

Verdict: PASS
Round: 0
Reviewed against: ADR 0014 (coordination model, immutable), ADR 0015 (lease-freshness
liveness, immutable), ADR 0001/0003, `.docs/evaluations/multi-session-lock-helper-review-findings.md`
(U1–U6 + secondary), spec 04 (frozen — ADR 0005), ADR/README.md; git `update-ref` CAS
semantics verified empirically.

## Findings

- [MINOR] Loose-blob accumulation is unstated. Each renew mints a fresh holder blob via
  `git hash-object -w`; superseded blobs become unreferenced. This is self-limiting — the
  *current* holder blob is always ref-reachable (kept), old blobs are unreachable → collected
  by git's ordinary gc, and lock/claim *refs* themselves are delete-CAS'd on release/land so
  refs do not accumulate — but the ADR names no cleanup expectation. Worth a one-line note in
  §Notes or as a re-impl hygiene obligation. Not a correctness or double-grant hazard.
- [MINOR] Release/delete-CAS assumes the caller knows the *latest* holder-blob SHA. Because
  the out-of-band renewer (ADR 0015 §2) rewrites the lock/claim ref's blob on every beat, the
  main thread's `<my-holder-blob>` for the release delete-CAS and for its own value-CAS must be
  the most-recently-renewed SHA, not the original acquire SHA, or the release CAS fails and the
  ref leaks until TTL. The ADR's *principle* (release is delete-CAS from the caller's own blob)
  is correct; the renewer↔main-thread known-SHA hand-off is a re-implementation detail the ADR
  could flag. Deferrable.
- [MINOR] The README lists 0016 under "In Review" yet already annotates ADR 0014's index
  descriptor as "lock/claim mechanism superseded by 0016." Consistent with the 0015 precedent
  and it is an index annotation (0014's body is untouched), but the supersession is only
  in-force on approval. Cosmetic.

## Required changes (for FAIL)

None — PASS.

## Notes

Scrutiny of the core design (the point of this ADR) holds up:

- **CAS correctness — empirically verified.** In a scratch repo:
  create-only from the 40-zero null OID succeeds when absent and **fails when the ref exists**
  (so a concurrent double-create resolves to exactly one winner); a value-CAS **fails on a wrong
  old-SHA** and succeeds on the exact old-SHA; delete-CAS **refuses a stale old-SHA** and
  succeeds on the current one. Every operation the ADR relies on (§1 acquire/steal/release, §2
  claim/renew/reclaim) maps onto a genuine `git update-ref` CAS. The null-OID literal in the
  ADR is exactly 40 zeros. Acquire is create-only-from-null (absence-required), steal is a value
  CAS on the exact read SHA `H_obs` gated on staleness, release is a delete-CAS on the caller's
  own blob — all three correct.
- **ABA claim holds.** The CAS old-value is the exact prior object SHA the caller read (not a
  separately-reconstructed baseline — the U1 root cause), so the staleness baseline and the CAS
  old-value are the *same* SHA. A peer renew/steal in the interim changes the SHA → the loser's
  CAS fails cleanly and retries. Because the SHA *is* the content, an A→B→A back to an identical
  SHA is genuinely identical holder state, not a spurious match. No path reintroduces a non-CAS
  read-then-write (acquire/steal/release/claim/renew/reclaim are all CAS). U1 eliminated as
  claimed.
- **U4 eliminated.** The holder blob is created first, then the ref is atomically pointed at it,
  so the ref never exists in an unstamped state — no `mkdir`→`stamp` window. Correct.
- **U3 fixed.** The renewer now CAS-renews the *lock* ref's lease-timestamp while held, so a long
  `land`/merge keeps the lock lease fresh and a peer's staleness-gated steal (§1) sees it live.
  Consistent with ADR 0015 lease-freshness; the steal decision keys on the holder blob's lease
  freshness, which the renewer keeps fresh. Closes U3 within the 0015 model.
- **New-substrate hazards checked.** Refs are correctly placed in the **common** ref store with
  an explicit warning against the per-worktree `refs/worktree/` namespace (which would defeat
  cross-session visibility) — confirmed the common-store sharing claim is right. A losing CAS is
  a clean non-zero exit → retry with the ADR 0008 §3 backoff (retryable, not a wedge). Packed-vs-
  loose ref transitions are handled internally by git and don't affect CAS. Reflog growth is a
  non-issue: `refs/loom/*` is outside the default reflog-enabled namespaces. Ref accumulation is
  bounded by delete-CAS on release/land; only loose-blob object growth remains → MINOR above.
- **Scope discipline — verified mechanically.** The 0016 commit touches only the ADR file and
  the README index descriptor; it does **not** edit spec 04, ADR 0014, or ADR 0015 (`git show
  --name-only`). Spec-04 amendment and the helper re-implementation are correctly deferred as
  follow-ons (ADR 0005). ADR 0003 preserved: the holder record is a `refs/loom/*` blob (verified
  `cat-file -t` = blob — blobs carry no author/committer metadata), never `refs/heads/*`, never in
  the slice-commit diff; session-id/pid stay out-of-band. ADR 0001 untouched.
- **Carry-forward honest.** U2/U5/U6 + secondary are named as re-implementation obligations and
  are **not** claimed fixed; the confidence tags (U1/U4 CONFIRMED, U3 PLAUSIBLE) faithfully match
  the review-findings artifact. Supersession is explicit and scoped to the mechanism only (no
  silent supersession); README descriptor is accurate. All cross-links resolve.

# Evaluation: 01 — Concepts & `.docs/` Layout

Verdict: FAIL
Round: 1
Reviewed against: ADR 0001–0006 (esp. 0003, 0005); specs 00-overview, 02-roles,
03-artifact-lifecycle, 05-blind-evaluation, README; the real `.docs/` tree and
`plugins/loom/` layout.

## Findings

- [BLOCKER] "Durable vs transient" contradicts ADR 0005 and specs 03/05 on a
  non-negotiable decision (artifact lines 40–47).
  - Line 41: "**Durable** (`spec/`, `ADR/`) … Changes **only when a slice lands**."
    ADR 0005 states the opposite: "An **approved spec is frozen.** It changes only
    by re-entering the planning cycle"; "**Landing a slice does not edit the
    spec.**" Spec 03 echoes: "**No spec edit happens at landing.**" Spec landing is
    precisely *not* when durable docs change — they change via a planning cycle.
  - Lines 45–47: transient plans "are discussed, evaluated, executed, and then
    **folded back into the durable specs** and archived. A landed plan is history;
    the specs are the record." This describes the **ballboy prototype behavior that
    ADR 0005 was written to reject.** Spec 03's own "Why this differs from the
    prototype" note: "ballboy folded slice outcomes back into its specs at landing.
    loom instead **freezes specs** (ADR 0005)." Per the authority, a landed plan is
    archived and the **living docs (`status/`)** — not the specs — record what was
    built (ADR 0005: "the developer's finalize pass updates `status/progress.md` +
    `status/handoff.md` and archives the slice-plan"). As written, this concepts
    spec teaches the inverse of the governing decision, and per the rubric a spec
    must trace to / not contradict its accepted ADRs. Since the spec wins on
    conflict, this stale model would actively mislead downstream roles.

- [MINOR] The artifact never cites the ADRs whose decisions it restates
  (immutability, freeze, spec-wins). 03 and 05 cite "(ADR 0005)" inline at the
  same claims; adding the parenthetical traces would strengthen authority and make
  the contradiction in §"Durable vs transient" harder to introduce.

## Required changes (for FAIL)

1. Rewrite the **Durable** bullet (lines 40–43): durable docs (`spec/`, `ADR/`)
   change **only through a planning cycle** (`Draft → Plan Review → Approved`),
   never as a side effect of a slice landing. Keep "spec wins on conflict" and ADR
   immutability/supersession (both correct).
2. Rewrite the **Transient** bullet (lines 45–47): a slice-plan is discussed,
   evaluated, executed, and on landing **archived**, with the **living docs
   (`status/`) updated** to record what was built — the specs are **not** edited at
   landing. Remove "folded back into the durable specs." Optionally state that
   spec/reality divergence is surfaced as explicit planning work (ADR 0005).
3. (Optional, MINOR) Add inline ADR traces (e.g. "(ADR 0005)") at the freeze /
   immutability claims, matching the convention in specs 03 and 05.

## Notes

Everything else checks out. The `.docs/` tree diagram matches the real directory
exactly (`research/`, `ADR/`, `spec/`, `slice-plans/` + `archive/`, `evaluations/`,
`status/` with roadmap/progress/handoff). The artifact-types table's authored-by
and approved-by columns agree with spec 02-roles and the 03 dispatch table. The
research/evaluations/slices/status-as-dispatcher sections are consistent with ADRs
0003/0004 and specs 03/05. Cross-reference links (`05-blind-evaluation.md`,
`03-artifact-lifecycle.md`) resolve. No terminology drift was found — no bare
`/loom`, no "skill"-as-product usage, no renamed roles or dirs. The sole blocker is
the durable/transient section, which encodes the rejected prototype model; once the
two bullets are corrected this spec should pass.

---

# Evaluation: 01 — Concepts & `.docs/` Layout (Round 2)

Verdict: PASS
Round: 2
Reviewed against: ADR 0005 (specs-frozen-after-approval); specs 03-artifact-lifecycle,
05-blind-evaluation; the revision in commit `017ad8f` and the real `.docs/` tree.

## Disposition of Round 1 findings

- [BLOCKER] (durable/transient contradicts ADR 0005 / specs 03/05) — **RESOLVED.**
  The Durable bullet (lines 40–45) now reads: an approved spec is **frozen** (ADR
  0005), changing **only through a planning cycle** (`Draft → Plan Review →
  Approved`), authored by the planner, **never as a side effect of a slice
  landing** — exactly ADR 0005 ("approved spec is frozen … changes only by
  re-entering the planning cycle, authored by the planner") and spec 03 lines
  47–49. The Transient bullet (lines 47–52) now reads: plans are executed and on
  landing **archived**, with the **living docs (`status/`) updated** to record what
  was built, the spec **not** edited at landing, and divergence surfaced as
  explicit planning work — matching ADR 0005 lines 19–23 and spec 03 lines 64–72.
  "Folded back into the durable specs" is gone.

- [MINOR] (missing inline ADR traces) — **RESOLVED.** Inline `(ADR 0005)` traces
  now appear at the freeze claim (line 41), the ADR-immutability claim (line 44),
  and the living-docs claim (line 49), matching the convention in specs 03 and 05.

## New-contradiction check

No regression introduced. The planning-cycle path `Draft → Plan Review → Approved`
matches spec 03 line 40; "authored by the planner" matches ADR 0005 line 16; "spec
wins on conflict" and ADR immutability/supersession are preserved correctly. The
remainder of the file (artifact-types table, `.docs/` tree, research / evaluations /
slices / status-as-dispatcher sections) is unchanged and was confirmed correct in
Round 1.

## Findings

- None.

## Notes

Both Round 1 findings are fully addressed and no new conflict with the authority
was introduced. Approved.

# Session Handoff

Status: Living

Restart instructions and compact current context. `progress.md` is the status
source of truth; `roadmap.md` is milestone order.

## Start here each session

1. Confirm repo:
   ```sh
   cd /Users/craig/git/loom
   git status --short
   ```
2. Read `.docs/spec/README.md`, then `.docs/status/progress.md` and this file.

## Where things stand

- **Remediation-3 `playbook-conformance` LANDED — first exercise of ADR 0026's
  broadened `docs-governance/v1` class.** ADR 0026 carried to `main` at
  `Status: Accepted` (broadens the class to admit the prose body of
  `plugins/loom/**/*.md`; frontmatter categorically out of class) alongside its
  pre-placed cold plan-eval + owner-acceptance records and ADR/evaluations
  index entries. The audit's three Theme-B prose drifts were corrected via an
  exhaustive census (mechanical `rg` sweep, every hit FIX/LEAVE-triaged, zero
  un-triaged): lifecycle (code-eval PASS → `Ready to Publish`, not `Landed`),
  evaluator self-commit (evaluator writes to confined scratch and returns; the
  recorder/root installs the verdict, transitions status, and commits), and
  local-`main`-is-not-the-landing-authority (ADR 0020 §1, read-under-the-lock
  coordination preserved). Pure prose-body edits, zero frontmatter lines
  touched, `scripts/check` green. Slice-plan archived. **NEXT ACTION** below.
- **M1 slice 1 `coord-identifier-boundaries` SETTLED (ADR-0023 receipt; result
  main 00582aa).** Centralized identifier validation landed in
  `plugins/loom/bin/loom-coord`: two-grammar split — strict `_valid_identifier`
  (session ids, decoded-blob sids, PIDs) vs. narrow `_valid_slice_name`
  (held-claims line format, preserving the `:`/`..` freeform-slice capability);
  decoded-blob sids guarded before path use; `_remove_session_dir` replaces
  computed-path `rm -rf` with known-file + `rmdir` quarantine; `cmd_cleanup`'s `T3`
  sweep case flips to quarantine (plan-authorized). 18 new `NEG-ID` negatives
  (82/82 `loom-coord.bats`); `LOOM_DIFF_BASE=HEAD scripts/check` green 452/452.
  Plan-eval FAILed round 0 (slice-name grammar broke `SC1`/`V5b`) → revised →
  Approved. Bootstrap review — three cold auxiliary workers
  (correctness/tests/security), loom-repository-bootstrap/v1 degraded, not
  loom-local-review/v1 (ADR 0023 §3) — clean at 4 MINOR (T1-T3
  secondary-call-site test-coverage gaps, T4 a NEG-ID count doc miscount);
  code-eval PASS round 0. `Status: Landed/Archived — settled (ADR-0023 receipt)`.
  Slice-plan archived. **NEXT ACTION: after this docs-governance-reconciliation
  slice lands, remediation-3 (playbook-conformance), then plan M1 slice 2
  `coord-lock-ownership`** (per `.docs/repository-improvement-plan.md` § "M1 — Fix
  coordinator safety"). Also landed on `main` during this slice (separate commit):
  `0ae81c1`, a Linux CI `stat -f` GNU/BSD portability fix — hosted CI green both
  lanes.
- **Owner decisions 2026-07-24 (governance deferred-decisions resolved) + M1 planning
  started (historical — M1 slice 1 above is now complete).** Two owner decisions are recorded (details in `progress.md` → Current
  state / M0 errata): (1) **SCHEDULE `client-floor-adapter-smoke`, do not retire** —
  it is already an ADR 0023 §1 authorized M0 follow-up, so scheduling it needs **no
  new ADR**; the improvement plan now carries a restored `### Slice:
  client-floor-adapter-smoke` under M0 stating what it owes beyond the dogfood
  evidence (a **real authenticated Codex cold role launch** — the D0-blocked leg —
  plus the §7 cross-client floor checks) with an **open owner-input precondition: the
  Codex credential strategy for isolated homes** (short-lived injected credential vs.
  read-only sandboxed real `CODEX_HOME`; owner picks at plan time). (2)
  `loom/bootstrap-authority-b28a747` remote branch **DELETED** after the zero-reference
  scan. The governance slice's other deferred item (ADR 0023 §7 single-session
  publication precondition / M2 duplication) stays deferred to M2 planning.
  **M1 planning underway:** the `coord-identifier-boundaries` slice-plan is authored at
  `Status: Plan Review` (`.docs/slice-plans/coord-identifier-boundaries.md`) — a
  code-bearing bootstrap slice; next action is a cold ADR 0023 bootstrap plan
  evaluation.
- **`macos-dual-client-dogfood` is complete, slice-plan-archived, and settled**
  (ADR-0023 receipt; result `2a4700d`, target `main`). Resolving code-eval PASS round 0
  (head `a000cef`) after a bootstrap review — three cold auxiliary workers
  (correctness/tests/security), loom-repository-bootstrap/v1 degraded, not
  loom-local-review/v1 (ADR 0023 §3) — FAIL round 0 (dogfood-harness
  injection-coverage gaps + cleanup hardening) was fixed and reverified green
  (`LOOM_DIFF_BASE=HEAD scripts/check` exit 0, 434/434 Bats). Delivered: shared
  `loom-*` workflow skills + canonical `roles/*.md` contracts with thin Claude/Codex
  adapters; `loom-resolve-helper`; one shared `hooks.json` with policy/wire split
  (12-case hook-wire-v1 product, 2 clients × 2 events × 3 outcomes; 48 fixture
  files at 4/case); `loom-launch-role`; and a fail-closed macOS
  dogfood harness proven against real Claude 2.1.218 + Codex 0.144.6 in isolated
  homes (full native install/reinstall/uninstall/marketplace-remove lifecycle for
  both clients; Codex's cold role-launch leg is `infrastructure-blocked` — a live
  `401` from a by-design credential-less isolated `CODEX_HOME`, not a product
  defect). Private Apple-silicon dogfood-ready; **not** a public release, **not**
  public Codex support, and does **not** reduce mandatory Linux/macOS-Intel
  obligations. **Single consistent next action: M1 slice 2 `coord-lock-ownership`**
  (after the remediation slices) — see the coord block above.

- **Prior checkpoint (settled):** the macOS program amendment. M0 is verified and
  settled on remote `main` at `51b249e`. Accepted ADR 0024 and its ratification
  chain are integrated unchanged. The complete program/spec/instruction/docs set passed
  cold plan evaluation round 0; both Bash lanes passed 257/257. That docs-only
  candidate published through ADR 0023 intent, non-force target update, fresh
  receipt, and settlement — `macos-dual-client-dogfood` (above) then implemented
  for real isolated Claude Code + Codex CLI behavior on Darwin `arm64`.

- **Earlier M1–M4 and post-M4 session history:** archived in
  [`archive/handoff-history.md`](archive/handoff-history.md) so this handoff stays
  within the `<= 120`-line cold-start budget.

## Notes for the next agent

- Commits are **author-neutral** AND under a **single uniform git identity** —
  roles must not set/override `user.*` (commit-convention; learned from the M1
  first run, where an agent strayed to `loom@localhost`).
- Command surface is `/loom:run` + one-off `/loom:<role>`; agents spawn via Task
  `subagent_type: loom:<role>` (verified).

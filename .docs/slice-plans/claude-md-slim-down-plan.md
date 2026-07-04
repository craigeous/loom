# CLAUDE.md slim-down — apply + enforce the shape & concision discipline

Status: Draft
Lifecycle: Draft → Plan Review → Approved → In Progress → Implemented → (code review) → Landed → Archived
Target specs: 08-playbook.md (§ "Shape and Concision Discipline"), 03-artifact-lifecycle.md (finalize pass step 2)
Target research: 2026-07-03-claude-md-digest-discipline.md (Approved — the target blueprint)

## Context

**Goal.** loom's root `CLAUDE.md` has drifted from a lean entry-point map into a
197-line reference mirror: its "Repo layout" section (lines 27–158) is 132 lines =
67% of the file, each bullet restating in full-paragraph form the very reference
file it names. The Approved spec-08 § "Shape and Concision Discipline" now makes this
a defect (point-don't-restate; ~100-line bound for loom / ~200 for managed;
stable-top + pointer-index zones; scope test) and calls for a **blind
code-evaluator** enforcement check as an explicit follow-on ("Wiring this check into
the code-evaluator rubric is a follow-on playbook slice"). This slice does both:
rewrites `CLAUDE.md` to ~90 lines per the discipline, and wires the enforcement.

**This is a single, coherent slice** (recommend keeping it as one, not splitting):
the rewrite and its enforcement are the two halves of the same discipline, and the
rewrite is the reference example the rubric check will match against. **Pure-docs, no
code** → automated review is `skipped: docs-only`.

**In scope.**
1. Rewrite `/Users/craig/git/loom/CLAUDE.md` to ~90 lines (target 80–100): a stable
   top + a collapsed pointer index (~25 lines replacing the 132-line Repo-layout
   section) + compact Project conventions + Gate + "Update this file" note.
2. Add a code-eval-rubric check that flags restatement / over-bound / lost coverage
   on a finalize `CLAUDE.md` diff.
3. Add a one-line pointer in `agents/developer.md` finalize step 2 to the spec-08
   Shape and Concision Discipline.

**Out of scope.**
- Any edit to `.docs/spec/` or `.docs/ADR/` (the rule is already Approved and frozen;
  this slice makes the digest + rubric conform — it does **not** touch the spec).
- The managed-project `CLAUDE.md` **template** in the playbook (the discipline already
  applies to both levels per spec 08, but no template edit is in scope here — only
  loom's own root `CLAUDE.md` is rewritten; the rubric check is written stack-neutral
  so it covers both bounds).
- No change to the four inclusion/exclusion categories, the gate commands, the
  read-first list content, or any reference-file body. Coverage is **preserved, not
  reduced** — every currently-named reference/component/gate/invariant must still be
  pointed to.

## Files touched

| File | Change |
|------|--------|
| `/Users/craig/git/loom/CLAUDE.md` | Full rewrite to ~90 lines: stable top + pointer index + compact conventions + gate + update-note. |
| `/Users/craig/git/loom/plugins/loom/skills/loom-playbook/references/code-eval-rubric.md` | Add a "CLAUDE.md shape (finalize diffs)" check under **Hygiene**. |
| `/Users/craig/git/loom/plugins/loom/agents/developer.md` | Finalize pass step 2: add a one-clause pointer to spec-08 Shape and Concision Discipline. |
| `/Users/craig/git/loom/.docs/slice-plans/README.md` | Add this plan to the Active-plans index (same commit). |

## New `CLAUDE.md` structure (target ~90 lines)

Three zones, in order:

1. **Stable top (~30 lines).** Keep verbatim in intent (light copy-edit only):
   - Title + one-line what-this-file-is.
   - `## Read first` (the 4-item list) — **unchanged**.
   - `## What loom is (one paragraph)` — **unchanged** (already one paragraph).
2. **Pointer index (~30 lines).** Replace the `## Repo layout` section (current lines
   27–158, 132 lines) with a `## Map (where authoritative things live)` section: one
   line per component/reference file — `**name/path**` + one-clause purpose + the
   ADR/spec tag in parens. See the compression mapping below. Ends with the
   keep-consistent invariant line.
3. **Tail (~30 lines).** Keep:
   - `## Project conventions` — **unchanged** (already compact, 4 bullets).
   - `## Gate` — **unchanged** (Rust + Shell + gate-learning pointer). The gate is a
     durable inclusion category and stays in full.
   - `## Update this file before committing` — extend its spec-08 pointer to name both
     the auto-propagation boundary **and** the Shape and Concision Discipline (one
     added clause), so the file documents its own ~100-line bound.

## Compression mapping (Repo-layout 132 lines → pointer index ~25–30 lines)

Every row below is a **required pointer** in the new index — none may be dropped. Each
current multi-line bullet collapses to a single `**name** — clause (tag).` line.

| Current bullet (lines) | Collapses to one-line pointer naming |
|---|---|
| `plugins/loom/` shippable plugin (29–33) | `plugins/loom/` — commands, agents, skills, hooks; components namespaced `loom:<name>`; marketplace catalog `.claude-plugin/marketplace.json`. |
| `.docs/` design memory (34) | `.docs/` — loom's own design memory (dogfooding), not a plugin component. |
| `plugins/loom/hooks/` (35–42) | `plugins/loom/hooks/` — two POSIX-sh guard hooks `git-identity-guard.sh` (ADR 0003) + `precompact-write-ahead-backstop.sh` (ADR 0013 §Decision 5); auto-discovered via `hooks.json`; shell-gated. |
| `plugins/loom/bin/` loom-coord (43–54) | `plugins/loom/bin/loom-coord` — multi-session coordination CLI (git-CAS lock/claim + lease renewer; on `$PATH`; ADR 0014/0015/0016). |
| Rust gate (55–56) | `gates/rust.md` — Rust gate loom imposes on managed projects. |
| `init-detection.md` (57–59) | `references/init-detection.md` — Greenfield/Unaligned/Initialized classifier; run first by all `/loom:*` (M2). |
| `greenfield.md` (60–62) | `references/greenfield.md` — Greenfield init body (scaffold + seed + CLAUDE.md + gate). |
| `unaligned.md` (63–68) | `references/unaligned.md` — Unaligned init body: bare (back-fill) + migrate (owner gate) (ADR 0009). |
| `initialized.md` (69–73) | `references/initialized.md` — Initialized init body (resume: state-derived menu → driver loop; idempotent re-apply). |
| `gate-learning.md` (74–78) | `references/gate-learning.md` — unknown-stack gate learning (inspect → propose → confirm → green-once → record). |
| `tooling.md` (79–81) | `references/tooling.md` — recommended CLI/LSP toolkit + verify-mechanically-not-by-eye discipline. |
| `parallelism.md` (82–90) | `references/parallelism.md` — worktree-per-slice ops + multi-session coordination layer (ADR 0008, 0014/0015/0016). |
| `migration-recipe.md` (91–98) | `references/migration-recipe.md` — reusable Unaligned-migrate recipe (ADR 0009 §5/§7). |
| Automated review / review-findings (99–121) | `references/review-findings.md` — review-findings artifact + orchestrator-runs-`/code-review`+`/security-review` at `Implemented` (ADR 0010, 0011). |
| Thin orchestrator (122–143) | `references/orchestration.md` — orchestrator context discipline + cold restart + ~60% trigger + bounded return (ADR 0012, 0013). |
| Infrastructure-blocked escalation (144–156) | `references/orchestration.md` (escalation) — infra-blocked escalation + degraded-review honesty + incremental-commit (ADR 0017). *(May share/append the orchestration line if space; must remain a resolvable pointer to ADR 0017.)* |
| keep-consistent line (157) | `When editing the playbook/agents, keep them consistent with .docs/spec/ + ADRs.` — kept as the index's closing invariant. |

Net: Repo-layout 132 → ~25–30 lines; whole file 197 → ~90. Coverage is **complete** —
16 pointers above correspond 1:1 to the 16 current Repo-layout bullets; the stable top,
Project conventions, Gate, and Update-note are retained.

## Enforcement wiring

**A. `references/code-eval-rubric.md`** — add a bullet under the existing `## Hygiene`
section (single-source: point at spec 08, do not restate the whole rule):

> - **CLAUDE.md shape (finalize diffs only).** When the diff touches a `CLAUDE.md`,
>   flag as findings, per spec 08 § "Shape and Concision Discipline": **restatement**
>   (a paragraph that mirrors a named `spec/`/`ADR/`/`references/` file where a
>   single-clause pointer belongs); **over-bound** (loom's root `CLAUDE.md` > ~100
>   lines, a managed project's > ~200 — check with `wc -l`); and **lost coverage** (a
>   reference file / component / gate / read-first pointer that was present before the
>   diff and is no longer pointed to — diff the pointer set, don't eyeball). Severity
>   per [`severity.md`](severity.md); this is a digest-hygiene dimension, not the
>   `format → lint → test` gate.

**B. `agents/developer.md`** finalize pass step 2 — append one clause to the existing
spec-08 pointer so the developer applies shape at write time:

> … See spec 08 (*Evolving the playbook → `CLAUDE.md` auto-propagation*, and
> *§ Shape and Concision Discipline* — keep it a lean pointer-index map under ~100
> lines / ~200 for managed; point, don't restate) for the authoritative boundary.

## Steps

1. **Rewrite `/Users/craig/git/loom/CLAUDE.md`** using a whole-file `Write` (the file
   is fully re-authored). Emit the three zones above: unchanged stable top; the new
   `## Map (where authoritative things live)` pointer index built from the compression
   mapping (16 pointers, one line each); unchanged `## Project conventions`; unchanged
   `## Gate`; the `## Update this file before committing` note with the added
   Shape-and-Concision clause. Keep total ≤ ~100 lines.
2. **Edit `references/code-eval-rubric.md`** — add bullet **A** under `## Hygiene`.
3. **Edit `agents/developer.md`** — append clause **B** to finalize step 2's spec-08
   pointer sentence.
4. **Edit `.docs/slice-plans/README.md`** — add this plan's entry to `## Active plans`
   (replacing `(none)`).
5. **Commit** all four files author-neutral (one handoff = one commit). Verify the
   commit author per `commit-convention.md` ("Verify after committing").

## Verification (doc-consistency — this is a pure-docs slice)

Automated review: **`skipped: docs-only`** (no code-bearing diff). Acceptance is doc
consistency, checked mechanically:

1. **Size bound.** `wc -l /Users/craig/git/loom/CLAUDE.md` ≤ ~100 (target 80–100).
2. **Coverage preserved — every prior reference filename / component still pointed to.**
   Each of these tokens must still appear in the new `CLAUDE.md`
   (`rg -F '<token>' /Users/craig/git/loom/CLAUDE.md` returns ≥ 1):
   `init-detection.md`, `greenfield.md`, `unaligned.md`, `initialized.md`,
   `gate-learning.md`, `tooling.md`, `parallelism.md`, `migration-recipe.md`,
   `review-findings.md`, `orchestration.md`, `git-identity-guard.sh`,
   `precompact-write-ahead-backstop.sh`, `loom-coord`, `gates/rust.md`,
   `gates/shell.md`, `marketplace.json`.
3. **Invariants / read-first / gate intact.** `## Read first` still lists the 4
   entry-point docs; `## Gate` still names `format → lint → test` + the Rust and Shell
   commands + the gate-learning pointer; `## Project conventions` retains the four
   durable-memory bullets; the "keep consistent with `.docs/spec/` + ADRs" line
   survives. The relevant ADR tags (0003, 0008, 0009, 0010, 0011, 0012, 0013, 0017,
   plus 0014/0015/0016) each still appear at least once.
4. **Links resolve.** Every path/file the index names exists on the real tree
   (`plugins/loom/skills/loom-playbook/references/<name>`, `gates/<name>`,
   `plugins/loom/hooks/<name>`, `plugins/loom/bin/loom-coord`).
5. **Rubric check present.** `rg -n 'CLAUDE.md shape'
   /Users/craig/git/loom/plugins/loom/skills/loom-playbook/references/code-eval-rubric.md`
   returns the new Hygiene bullet; `agents/developer.md` finalize step 2 names
   "Shape and Concision".
6. **No spec/ADR edit.** `git diff --name-only` contains no path under `.docs/spec/`
   or `.docs/ADR/`.

## Notes

<none yet>

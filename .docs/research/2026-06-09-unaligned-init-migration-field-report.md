# Field report: Unaligned init on a repo with a mature parallel methodology

Date: 2026-06-09
Author: orchestrator (field report from a real `/loom:init` run)
Status: Draft — feedback for the Unaligned init flow; not yet folded into spec/playbook

## What this is

A retrospective from running `/loom:init` against `~/git/ballboy` — an active
Rust project that **already had a hand-rolled equivalent of loom's whole
methodology** under `docs/` (un-dotted). The classifier returned **Unaligned**,
and the owner chose to **migrate `docs/` → `.docs/`**. The migration succeeded,
but it surfaced several places where the Unaligned playbook
(`references/unaligned.md`, spec `06-init-modes.md §2`) is underspecified or
actively misleading for this class of repo. This note records what went wrong so
the init flow can be improved.

## The repo (why it's the interesting case)

ballboy already had, under `docs/`:

| Loom concept | What the repo already had |
|---|---|
| `spec/` (durable, numbered, frozen) | `docs/specs/00..18` — "Status: Committed", explicitly "the authoritative source of truth" |
| `slice-plans/` + `archive/` | `docs/slice-plans/` with a full Draft→Review→Approved→Land→Archive lifecycle and inline `## Review Notes` |
| `status/roadmap.md` | `docs/specs/08-roadmap.md` |
| `status/handoff.md` | `docs/specs/09-session-handoff.md` |
| `status/progress.md` | `docs/specs/10-progress.md` |
| `ADR/` | decision records *deliberately folded into the numbered spine* (documented choice, not an omission) |

This is not a "no docs, back-fill descriptive specs" repo. It's a repo with a
**second, complete, parallel methodology** that maps almost 1:1 onto loom's. The
playbook has no mode for that.

---

## What was unsuccessful / underspecified

### 1. Unaligned assumes "back-fill descriptive specs," but the real task was *reconciliation/migration*

`unaligned.md` Step 3 ("Descriptive back-fill of `spec/`") frames the design work
as: the planner authors new descriptive specs and the plan-evaluator reviews them
blind. Here there was **nothing to back-fill** — the specs already existed and were
far richer than any generated description. The actual work was *migrating and
reconciling* an existing docs tree into loom's layout. The playbook describes the
wrong job.

**Suggested fix:** split Unaligned into two recognized sub-modes:
- **Unaligned-bare** — non-empty repo, no real docs spine → existing back-fill flow.
- **Unaligned-migrate** — repo already has a docs spine (loom-shaped or a
  near-equivalent under a different path) → a *migration/reconciliation* flow
  (map existing artifacts onto loom roles, move, rewrite refs, retain status).

### 2. No detection of an existing-but-undotted docs spine

Detection only looks for a dotted `.docs/`. A repo whose entire methodology lives
in `docs/` (or `doc/`, `documentation/`, etc.) is classified plain Unaligned with
no signal that a 1:1 migration is the likely intent. The classifier could note
"a non-loom docs spine exists at `<path>`" so the acting body knows to offer
migration rather than back-fill.

### 3. The migrate-vs-pointer-vs-abort decision is an owner gate the playbook never names

I had to fall back on the generic "Ambiguity → ask" rule and invent an
`AskUserQuestion` offering: thin-pointer `.docs/`, full migration, or abort. For
Unaligned-migrate this should be an **explicit required step** with those options
spelled out, including their consequences (e.g. "thin-pointer keeps `docs/` as the
source of truth but future runs re-detect Unaligned forever unless loom learns the
pointer"; "abort leaves the repo re-detected as Unaligned every run").

### 4. Mapping an existing *numbered* spine into `spec/` + `status/` is unspecified and link-hostile

The repo's living docs (roadmap/handoff/progress) were numbers 08/09/10 inside a
00–18 spine. Loom wants them in `status/`, the rest in `spec/`. Pulling three
files out of a numbered spine:
- creates numbering gaps (spec/ now has 00–07, 11–18);
- breaks every **same-directory** relative link to those three (they become
  `../status/...`);
- breaks every **outbound** link *from* those three to the rest of the spine
  (they become `../spec/...`).

There's no playbook guidance on this. It needs an explicit recipe for the
spine→(spec,status) split and the consequent two-directional link rewrite.

### 5. Cross-reference rewriting is a large, ordered, idempotency-sensitive job the playbook ignores

This migration touched ~50+ internal references across >2200 lines. Doing it
correctly required:
- **Ordered** rules (rewrite `docs/specs/08-roadmap.md` → `.docs/status/roadmap.md`
  *before* the generic `docs/specs/` → `.docs/spec/`, or 08/09/10 wrongly land in
  spec/).
- **Three reference forms** handled separately: path-form (`docs/specs/X`), bare
  markdown link targets (`](X.md)`, which resolve relative to the *file's new
  location*), and prose/backtick mentions.
- **Idempotency**: the naive `docs/slice-plans/` → `.docs/slice-plans/` rule
  re-matches its own output and produces `..docs/slice-plans/`. Needed a negative
  lookbehind `(?<!\.)`. Every agent doing a migration will hit this.
- **Living vs history**: archived slice-plans were left as historical snapshots
  (consistent with loom's "archived plans are history") — so refs inside them were
  *not* rewritten, while living docs were. The playbook should state this boundary.

A reusable "migration helper" recipe (ordered idempotent rewrite + link
validation) belongs in the playbook so this isn't reinvented per run.

### 6. Migrated specs must retain their prior status — don't force them back to Draft

`unaligned.md` Step 3 says back-filled specs enter at `Status: Draft` and pass
through Draft→Plan Review→Approved. But these specs were already `Status:
Committed` / authoritative. Re-litigating settled, in-production specs through a
blind plan-evaluator pass would be wrong and wasteful. The playbook needs an
explicit rule: **migrated pre-existing specs retain their prior status; migration
is not a re-review trigger.**

### 7. `/loom:init` does the scaffolding directly, but `unaligned.md` describes role-spawned back-fill — these conflict

`unaligned.md` Step 3 says "the planner authors the descriptive specs and the plan
evaluator reviews them blind." But the `/loom:init` command body does the scaffold
+ back-fill inline (no role spawn). For a *migration* there is no authoring to
spawn at all. The division of labor between init-inline work and `/loom:run`
role-spawned work is muddy for Unaligned; it should be stated which steps init
performs itself vs defers.

---

## Operational failures (process hazards, not playbook gaps per se)

These bit me repeatedly during execution and are worth a "migration gotchas" box:

1. **`git mv` silently skips untracked files.** One spec (`18-python-parity-analysis.md`)
   was a new untracked file; `git mv` failed and left it behind. Migration must
   check for untracked content in the source tree and `mv` + `git add` those
   separately.

2. **Bulk-rewrite file lists built via `$(find …)` + appended names glue the last
   find line to the appended filenames** (newline/space word-splitting), silently
   skipping files. This caused *multiple* passes to leave the status docs and
   tail files unprocessed before I switched to `find -print0 | xargs -0`. The
   migration recipe should mandate NUL-delimited file lists from the start.

3. **A dirty working tree before migration gets bundled into the alignment
   commit.** The repo had pre-existing uncommitted doc edits; `git mv` combined
   rename+modify so they couldn't be cleanly separated and rode along in the
   alignment commit. Migration should check `git status` first and stash/flag a
   dirty tree before moving anything.

---

## Net

The migration worked and ballboy is now loom-shaped (commit `564d8a4` on
`main`). But for any repo that already has its own docs methodology, the current
Unaligned flow points at the wrong job (back-fill), omits the reconciliation
decision, and gives no help with the genuinely hard part (the mechanical,
ordered, idempotent cross-reference rewrite and the numbered-spine split). An
**Unaligned-migrate** sub-mode with an explicit owner gate, a status-preservation
rule, and a reusable migration recipe would close the gap.

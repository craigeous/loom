# 0009 — Unaligned-migrate Sub-mode

Status: Plan Review
Date: 2026-06-09

## Context

Spec [06](../spec/06-init-modes.md) §2 defines a single **Unaligned** mode: an
existing, non-loom repo gets an alignment pass that **descriptively back-fills**
new `spec/` from a survey of the code. The playbook realizes this in
[`references/unaligned.md`](../../plugins/loom/skills/loom-playbook/references/unaligned.md)
(Step 3, "Descriptive back-fill of `spec/`") and classifies it in
[`references/init-detection.md`](../../plugins/loom/skills/loom-playbook/references/init-detection.md)
(rule 3 catch-all). Back-fill assumes the repo has *no real docs spine* — that
loom is the first methodology the project has ever had.

The field report `.docs/research/2026-06-09-unaligned-init-migration-field-report.md`
(Status: Draft) records a real `/loom:init` run on `~/git/ballboy`, a mature Rust
repo that **already had a complete, hand-rolled equivalent of loom's whole
methodology** under an un-dotted `docs/`: a numbered, frozen spec spine
(`docs/specs/00..18`, "Status: Committed", "the authoritative source of truth"), a
full slice-plan lifecycle (`docs/slice-plans/` with Draft→Review→Approved→Land→
Archive and inline review notes), living docs (`docs/specs/08-roadmap.md`,
`09-session-handoff.md`, `10-progress.md`), and ADRs deliberately folded into the
numbered spine. The classifier returned plain **Unaligned**; the owner chose to
**migrate `docs/` → `.docs/`** (landed as ballboy commit `564d8a4`).

The migration succeeded but exposed that Unaligned points at the **wrong job** for
this class of repo, and gives no help with the genuinely hard part. The report
enumerates seven playbook gaps and three operational hazards (cited per-decision
below). In summary: there was **nothing to back-fill** (the existing specs were far
richer than any generated description); the real task was *reconciling and moving*
an existing tree onto loom's layout; the migrate-vs-pointer-vs-abort choice had to
be improvised through the generic "ambiguity → ask" rule; pulling the living docs
out of a numbered spine broke same-directory and outbound links in two directions
with no recipe to follow; the cross-reference rewrite (~50+ refs across >2200
lines) was an ordered, idempotency-sensitive job that bit a naive implementation
repeatedly; and forcing already-`Committed` specs back to `Draft` for a blind
plan-eval would have re-litigated settled, in-production design.

**In scope:** the *decision* to split Unaligned and how that split is recognized,
gated, status-preserved, and divided between init-inline and role-spawned work; and
the decision that a reusable migration recipe must exist with named load-bearing
properties. **Out of scope (deferred to follow-on planning per ADR 0005):** the
amended spec 06 text, the classifier change in `init-detection.md`, the split of
`unaligned.md`, and the migration-recipe reference body itself. This ADR **refines**
spec 06's Unaligned mode and **builds on** [ADR 0001](0001-plugin-architecture-and-orchestrator.md) (only the orchestrator spawns)
and [ADR 0005](0005-specs-frozen-after-approval.md) (specs frozen; ADRs immutable);
it supersedes no existing ADR.

## Decision

### 1. Split Unaligned into two sub-modes

Unaligned is **not one job**. It is split into two named sub-modes (report §1):

- **Unaligned-bare** — a non-empty repo with **no real docs spine**. The job is the
  existing **descriptive back-fill**: survey the code, draft new descriptive `spec/`,
  pass them through `Draft → Plan Review → Approved`. This is today's `unaligned.md`
  behavior, unchanged.
- **Unaligned-migrate** — a repo that **already has a docs spine**, either
  loom-shaped or a near-equivalent methodology under another path (e.g. `docs/`,
  `doc/`, `documentation/`). The job is **reconciliation/migration**: map existing
  artifacts onto loom's roles, move them into `.docs/`, rewrite cross-references, and
  **retain their status**. It does **not** back-fill — there is nothing to describe
  that the existing tree does not already describe better.

The distinguishing fact is the presence of a pre-existing docs spine, not the
language or size of the repo.

### 2. Detection signals an existing-but-undotted docs spine

The classifier (`init-detection.md`) must recognize when a non-`.docs/`
methodology already exists — a docs tree under `docs/`, `doc/`, `documentation/`, or
similar — and **signal that migration is the likely intent** rather than returning
plain Unaligned (report §2). Detection stays **read-only** (it mutates nothing); it
adds an observation ("a non-loom docs spine exists at `<path>`") that the acting
body uses to offer migration instead of back-fill. The exact detection heuristics
(which paths, what counts as a "spine") are playbook detail for the follow-on
`init-detection.md` slice; this ADR fixes only that the signal must exist and must
steer toward Unaligned-migrate.

### 3. A named owner gate — migrate / thin-pointer / abort

Unaligned-migrate has an **explicit, required owner decision point** — not a
fall-through to the generic "ambiguity → ask" rule the field run had to improvise
(report §3). When a pre-existing spine is detected, loom presents the owner three
options, each with its stated consequence:

- **Migrate** — move and reconcile the existing tree into `.docs/`. The old tree
  stops being authoritative; future runs detect **Initialized**.
- **Thin-pointer** — leave the old tree authoritative and place a pointer at
  `.docs/`. Consequence: **future runs re-detect Unaligned** unless/until loom
  learns to honor the pointer (which it does not today). The owner accepts living
  with re-detection.
- **Abort** — make no changes. Consequence: the repo is **re-detected as Unaligned
  on every run**.

This is a decision the acting body must surface and the owner must answer before any
files move; loom does not pick for them.

### 4. Migrated specs retain their prior status — migration is not a re-review trigger

A migrated pre-existing spec **keeps the status it already had** (report §6).
Already-authoritative specs (ballboy's were "Status: Committed") are **not** forced
back to `Draft` and **not** re-litigated through a blind plan-eval. Migration moves
and re-references existing, settled design; it is a mechanical relocation, not a new
planning cycle, so it does not re-open review of in-production specs. (Back-fill's
"new specs enter at Draft and pass through review" rule, `unaligned.md` Step 3,
applies to **Unaligned-bare only** — it never applied to artifacts that already
carry a status.) This is consistent with ADR 0005: the spec lifecycle is untouched;
migration simply preserves each artifact's existing point in it.

### 5. A reusable migration recipe must exist in the playbook

Cross-reference rewriting and the spine-split are a large, ordered,
idempotency-sensitive job that the field run had to reinvent and got wrong several
times before getting right (report §4, §5). This ADR decides that a **reusable
migration-recipe reference must exist in the playbook** so it is not reinvented per
run. The recipe's **load-bearing properties** (which the follow-on reference must
satisfy; the recipe *text* is not written here) are:

- **Ordered rewrite rules** — specific-before-generic. The living-doc renames
  (e.g. the spine's roadmap/handoff/progress → `.docs/status/...`) must run *before*
  the generic spine → `.docs/spec/` rule, or the living docs wrongly land in `spec/`.
- **Idempotency, including the self-match hazard** — a naive `docs/...` → `.docs/...`
  rule re-matches its own output (producing `..docs/...`); the recipe must guard
  against re-matching already-rewritten paths (the report used a negative lookbehind
  `(?<!\.)`). Re-running the recipe must be safe.
- **Three reference forms handled separately** — (a) path-form mentions
  (`docs/specs/X`), (b) bare markdown link targets (`](X.md)`, which resolve relative
  to the file's **new** location), and (c) prose/backtick mentions. Each is rewritten
  by its own rule; collapsing them loses cases.
- **The numbered-spine → `spec/` + `status/` split with two-directional link
  rewrite** — extracting the living docs from a numbered spine creates numbering gaps
  and breaks both **same-directory** links *to* the extracted files (now `../status/`)
  and **outbound** links *from* them to the rest of the spine (now `../spec/`). The
  recipe must rewrite links in both directions.
- **Living-docs-rewritten vs archived-history-left-as-snapshots** — living docs are
  migrated and their refs rewritten; archived slice-plans are left as **historical
  snapshots** (consistent with loom's "archived plans are history") and their internal
  refs are **not** rewritten. The recipe must state this boundary.

### 6. Init-inline vs role-spawned division for Unaligned-migrate

A pure migration has **no specs to author**, so — unlike Unaligned-bare's back-fill —
there is **no planner/evaluator authoring step to spawn** (report §7, which also notes
`unaligned.md` Step 3's "planner authors / evaluator reviews blind" wording already
conflicts with `/loom:init` doing the scaffold inline). For Unaligned-migrate,
`/loom:init` performs the migration **inline**: it runs detection, presents the owner
gate (§3), and — on *migrate* — executes the recipe (move, rewrite, status-preserve)
and seeds/reconciles `status/`, then hands back **Initialized**. There is no
role-spawn step in the migration itself, because there is no new design to author or
review; subsequent design work begins normally through `/loom:run` once the repo is
Initialized. (Unaligned-bare's division is unchanged by this ADR and is clarified
along with the spec amendment in the follow-on cycle.)

### 7. Operational hazards become required preconditions/steps of the recipe

The three execution hazards from the field run (report "Operational failures") are
**required preconditions/steps** of the migration recipe, not optional advice:

- **`git mv` silently skips untracked files** — the recipe must detect untracked
  content in the source tree and `mv` + `git add` those files separately.
- **NUL-delimited file lists** — bulk-rewrite file lists must be built
  NUL-delimited (`find … -print0 | xargs -0`), never via newline/space-split
  `$(find …)`, which silently glues and skips files.
- **Dirty-tree check before moving** — the recipe must check `git status` and
  stash/flag a dirty working tree *before* any move, so pre-existing uncommitted
  edits are not bundled into the alignment commit.

These are named here as recipe requirements; their concrete commands are recipe
text written in the follow-on reference.

## Consequences

- **Spec 06 must be amended in a follow-on planning cycle** to split §2 Unaligned
  into Unaligned-bare and Unaligned-migrate, add the existing-spine detection signal,
  the owner gate, and the status-preservation rule. Spec 06 is **Approved and frozen**
  (ADR 0005), so that amendment is a deliberate planning pass authored by the planner
  and blind-evaluated — **not** a side effect of this ADR or of any landing. This ADR
  is the decision input to that cycle.
- **Three playbook slices follow** (each its own planning/build unit, sequenced after
  the spec amendment lands so the playbook matches the frozen spec):
  1. **`init-detection.md`** — add the existing-but-undotted docs-spine signal and the
     Unaligned-bare vs Unaligned-migrate steer (Decision §2), keeping detection
     read-only.
  2. **Split `unaligned.md`** — separate the bare back-fill flow from a new
     Unaligned-migrate flow carrying the owner gate (§3), status preservation (§4), and
     the init-inline-vs-role-spawn division (§6).
  3. **A new migration-recipe reference** — the reusable ordered/idempotent rewrite +
     spine-split + link-validation recipe, satisfying the load-bearing properties (§5)
     and the operational preconditions (§7).
- **Builds on, does not supersede.** This refines spec 06's Unaligned mode and relies
  on ADR 0001 (orchestrator-only spawning — the migration runs in the init body, no
  sub-agent spawn) and ADR 0005 (specs frozen, ADRs immutable — which is *why* the spec
  change is a separate cycle and *why* migrated specs keep their status rather than
  being re-reviewed). It changes no existing ADR.
- **Easier:** repos with their own methodology become first-class — loom recognizes
  them, offers a real choice, and migrates without re-litigating settled specs or
  discarding richer existing docs; the hard mechanical work (ordered idempotent
  rewrite, spine-split, link fix-up) becomes a shared recipe instead of per-run
  improvisation.
- **Harder / new obligations:** the classifier gains a docs-spine heuristic to
  maintain; `/loom:init` gains a required owner gate and an inline migration path; and
  the migration recipe is executable-shaped guidance (ordered rules, lookbehind
  idempotency, NUL-delimited lists, dirty-tree/untracked preconditions) that must be
  written and kept correct.
- **No status-machine or threshold changes.** The artifact lifecycle (spec 03) is
  untouched; this ADR only adds that migration *preserves* existing status rather than
  resetting it. No detection threshold, gate, or unrelated policy is changed.

## Notes

- **Resolved without invention.** Every decision above traces to a specific field-report
  finding; none required inventing policy. No open questions block approval.

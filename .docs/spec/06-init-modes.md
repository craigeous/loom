# 06 — Init Modes

Status: Plan Review

When loom starts in a repo it first determines which of three modes applies, by
checking for `.docs/` and loom markers.

## Detection

```
if no .docs/ and repo is empty/near-empty   → Greenfield
elif no .docs/ (or .docs/ not loom-shaped)  → Unaligned
    if a pre-existing docs spine is present  → Unaligned-migrate
    else                                     → Unaligned-bare
else                                        → Initialized
```

Within **Unaligned**, detection distinguishes the two sub-modes (see §2) by
**signalling** whether the repo already carries a **pre-existing docs spine** — a
non-`.docs/` methodology under `docs/`, `doc/`, `documentation/`, or a similar path:

- **no pre-existing docs spine** → **Unaligned-bare**.
- **a pre-existing docs spine present** → **Unaligned-migrate** (migration is the
  likely intent). Detection records the observation ("a non-loom docs spine exists
  at `<path>`") and steers the acting body toward the migrate sub-mode rather than
  back-fill.

The exact heuristics — which paths are scanned, what counts as a "spine" — are
playbook detail (the follow-on `init-detection.md` slice), not spec text. Detection
remains **read-only**: it mutates nothing, only observes and steers. The distinguishing
fact is the presence of a pre-existing docs spine, not the language or size of the
repo.

## 1. Greenfield — blank/new project

Start from nothing, like a fresh design conversation.

- Create the `.docs/` structure and seed `status/` empty of design content —
  the roadmap, progress, and handoff files carry no project decisions, only
  scaffold metadata (e.g. a phase / next-step marker pointing at the first
  owner step). "Empty" here means no prior design/project content, not a
  zero-byte file.
- Apply the **playbook**: write a project `CLAUDE.md`, establish the gate (see
  *Gate establishment* below).
- Begin with the owner: research → ADRs → specs → slice-plans, per scope.

## 2. Unaligned — existing project, not loom-managed

An **alignment/migration pass**, not a config interview. loom imposes its
conventions on the project. Unaligned is **not one job**: it splits into two named
sub-modes by whether a pre-existing docs spine exists (see *Detection*). The
authority for this split is [ADR 0009](../ADR/0009-unaligned-migrate-sub-mode.md).

### 2a. Unaligned-bare — existing repo, no real docs spine

A non-empty repo with **no pre-existing docs spine** — loom is the first
methodology the project has ever had. This is the established Unaligned behavior,
unchanged; the job is **descriptive back-fill**.

- Study the repo: languages, build/test/lint tooling, existing docs, structure.
- Create `.docs/` and apply the playbook.
- Establish the gate (below).
- **Descriptive back-fill only.** Draft initial `spec/` that *describes what the
  system currently is* — a map of the existing project so future loops have
  authoritative context. Back-fill does **not** make decisions or propose
  changes; any ADRs or changes require a real planning phase. The back-filled
  specs are **new** artifacts, so they enter at `Draft` and pass through normal
  `Draft → Plan Review → Approved`. (This "new specs enter at Draft → review" rule
  applies to **Unaligned-bare only** — see 2b.)
- Seed `status/` with current state and an initial roadmap.

### 2b. Unaligned-migrate — existing repo with a pre-existing docs spine

A repo that **already has a docs spine** — a loom-shaped-equivalent methodology
under another path (e.g. `docs/`, `doc/`, `documentation/`). The job is
**reconciliation/migration, NOT back-fill**: there is nothing to describe that the
existing tree does not already describe better. loom maps existing artifacts onto
loom roles, moves them into `.docs/`, rewrites cross-references, and **retains each
artifact's prior status**.

- **Named owner gate — migrate / thin-pointer / abort.** Before any files move,
  loom surfaces an explicit, required owner decision point (not the generic
  "ambiguity → ask" fall-through). loom does not pick; the owner must answer. Each
  option's consequence is stated:
  - **Migrate** — move and reconcile the existing tree into `.docs/`. The old tree
    stops being authoritative; future runs detect **Initialized**.
  - **Thin-pointer** — leave the old tree authoritative and place a pointer at
    `.docs/`. Consequence: **future runs re-detect Unaligned** (loom does not yet
    honor the pointer); the owner accepts living with re-detection.
  - **Abort** — make no changes. Consequence: the repo is **re-detected as
    Unaligned on every run**.
- **Status preservation — migration is not a re-review trigger.** A migrated
  pre-existing spec **keeps the status it already had**. Already-authoritative
  specs are **not** forced back to `Draft` and **not** re-litigated through blind
  plan-eval. Migration is a mechanical relocation of settled design, not a new
  planning cycle, so it does not re-open review of in-production specs. The
  back-fill "new specs enter at `Draft` → review" rule (2a) applies to
  Unaligned-bare only; it never applied to artifacts that already carry a status.
  This is consistent with ADR 0005: the spec lifecycle is untouched — migration
  preserves each artifact's existing point in it.
- **Runs inline in `/loom:init`.** A pure migration has **no specs to author**, so
  — unlike Unaligned-bare's back-fill — there is **no planner/evaluator role-spawn
  in the migration itself**. `/loom:init` performs the migration inline: it runs
  detection, presents the owner gate, and — on *migrate* — executes the
  reconciliation (move, rewrite cross-references, preserve status) and
  seeds/reconciles `status/`, then hands back **Initialized**. Subsequent design
  work begins normally through `/loom:run` once the repo is Initialized.
- **The migration recipe lives in the playbook.** The ordered, idempotent
  cross-reference rewrite, the numbered-spine → `spec/` + `status/` split, and the
  operational preconditions are a reusable recipe that belongs in the playbook —
  see ADR 0009 for its load-bearing properties. The recipe **text** is a playbook
  reference authored in a follow-on slice, **not** spec text.

Goal (both sub-modes): leave the project loom-shaped and ready to resume as
`Initialized`.

## 3. Initialized — loom already present

Resume. Present the owner a menu derived from current `.docs/` + git state, e.g.:

- Continue an in-flight slice-plan (`Plan Review`, `In Progress`, `Implemented`).
- Review pending research / ADRs / specs.
- Start a new slice from the roadmap.
- Run research on a topic.
- Show status.

The menu reflects real status so the owner picks up where things stand, then
declares scope + claimed gates and the driver loop runs.

## Gate establishment

The gate is the `format → lint → test` sequence the developer must pass before
review. loom resolves concrete commands by detecting the toolchain:

- **Rust is the only *verified* gate** and ships in the playbook:
  `cargo fmt --check` → `cargo clippy --all-targets -- -D warnings` → `cargo test`.
- **For a stack with no known gate, gate creation is an init responsibility.**
  loom inspects the project's tooling (config files, scripts, CI), proposes the
  format/lint/test commands, confirms with the owner, and **writes them into the
  project's `CLAUDE.md`**. It then **records the new gate back into the playbook**
  so the next project on that stack inherits a known gate. loom *learns* gates
  over time.
- A detected-but-unverified gate is marked as such until it has actually run
  green at least once.

## Playbook re-application (idempotent)

Re-running alignment re-applies the **current** playbook, picking up improvements
since the last init. Merge strategy (Q10):

- **Auto-apply** changes that merge cleanly and don't conflict with
  project-specific content.
- For anything that **conflicts or is ambiguous**, loom **recommends** an action
  and lets the **owner decide** — it never silently clobbers project-specific
  edits.

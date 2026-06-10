# Unaligned Init

The behavior the orchestrator runs when `init-detection.md` returns **Unaligned**
— an existing / non-empty repo whose `.docs/` is absent or not loom-shaped.

Authority: [`../../../../../.docs/spec/06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md) §2a (Unaligned-bare) and §2b (Unaligned-migrate).
Spec `06-init-modes.md` wins on any conflict.

Precondition: `init-detection.md` has already classified this repo as Unaligned
(one of the two sub-modes). This body **writes** files — unlike the read-only
detection classifier.

**Unaligned is an alignment/migration pass, not a config interview.** The repo
already exists; the job is to bring it into loom-shaped alignment and leave it
ready to resume as Initialized.

---

## Two sub-modes

The `init-detection.md` **sub-classification** (slice 1) routes between the two
flows — see [`init-detection.md`](init-detection.md) for the concrete detection
heuristics. Routing summary:

- **Unaligned-bare** — no pre-existing docs spine detected → descriptive back-fill,
  the bare flow below. Canonical definition: spec 06 §2a.
- **Unaligned-migrate** — a pre-existing docs spine present → reconciliation/
  migration, the migrate flow below. Canonical definition: spec 06 §2b.

**Identity pre-flight applies to BOTH flows.** Before any commit in either flow,
verify a real git identity is configured per Greenfield Step F ("Ensure a git
identity is configured"). If the identity is absent or is an `@localhost` fallback,
STOP and ask the owner to configure it — never invent an identity. See
[`commit-convention.md`](commit-convention.md) for the rationale.

---

## Unaligned-bare flow — no pre-existing docs spine

This flow runs when detection found **no pre-existing docs spine** (loom is the
first methodology the project has had). The job is **descriptive back-fill**: study
the repo, scaffold `.docs/` via Greenfield, draft descriptive `spec/` that maps
what the project currently is, seed `status/`, and hand back ready to resume as
Initialized.

### Step 1 — Study the repo (Unaligned-specific, runs first)

Before writing any files, inspect the existing project **read-only**:

- **Languages** — what language(s) are present (file extensions, shebang lines).
- **Build/test/lint tooling** — config files (`Cargo.toml`, `package.json`,
  `Makefile`, `pyproject.toml`, `go.mod`, CI workflow files, etc.), scripts in
  `scripts/` or `Makefile` targets, and any existing CI/CD definitions.
- **Existing docs** — any `README.md`, `CLAUDE.md`, `docs/`, `doc/`, wiki, or
  inline documentation already present.
- **Directory structure** — top-level layout, module/package boundaries,
  significant sub-trees.

This survey produces **notes/understanding** — it does not yet write project
files. The survey feeds two later steps:

1. **Gate detection (Step 2):** which toolchain was found determines which gate
   applies.
2. **Descriptive back-fill (Step 3):** what components and conventions exist
   determines which specs to draft.

---

### Step 2 — Scaffold + apply the playbook + establish the gate (reuse Greenfield)

Run the shared body in [`greenfield.md`](greenfield.md) **Steps A–E** for all
shared work: scaffold the `.docs/` tree (Step A), seed `spec/README.md` (Step B),
seed `status/` (Step C), write/update the project `CLAUDE.md` (Step D), and
establish the gate (Step E). Do **not** restate those steps here — `greenfield.md`
is the single source and the authority on those mechanics.

(Identity pre-flight: see the shared pre-flight in the **Two sub-modes** section
above — Greenfield Step F applies here exactly as stated there.)

The Unaligned **deltas** to the Greenfield body are:

- **Existing files are common, not the exception.** Unaligned runs in a populated
  repo; a pre-existing `CLAUDE.md` and existing docs are expected. Honor
  Greenfield's "update, never clobber" rule for `CLAUDE.md` (Greenfield Step D),
  and never overwrite existing project content while scaffolding.

- **Gate detection uses the Step 1 survey.** Feed the toolchain found in Step 1
  into Greenfield's Step E:
  - A verified Rust toolchain (`Cargo.toml` at repo/workspace root) adopts the
    verified gate in [`../gates/rust.md`](../gates/rust.md).
  - An **unknown stack** takes the learn-a-new-gate path specified in
    [`gate-learning.md`](gate-learning.md) (inspect tooling, propose commands,
    confirm with the owner, run green once, record a new `gates/<stack>.md`).
    That body is now the single authoritative source for the full
    inspect/propose/confirm/learn procedure, exactly as in Greenfield Step E.
    Record a marked-UNVERIFIED placeholder in the project `CLAUDE.md` with an
    explicit `Status: UNVERIFIED — gate-learning not yet complete` notice. This
    placeholder is the UNVERIFIED entry state of the gate-learning lifecycle
    (see `gate-learning.md` Step 4); gate-learning replaces it once the gate
    runs green.

- **Status seeds reflect alignment, not greenfield.** Where Greenfield's Step C
  seeds `progress.md` with "Phase: init / Greenfield scaffold complete," the
  Unaligned pass seeds with an alignment-phase marker: "Phase: init / Unaligned
  alignment in progress." (Step 4 below supersedes this with the full status
  seed after back-fill completes.)

---

### Step 3 — Descriptive back-fill of `spec/`

This is the heart of the Unaligned-bare delta (spec `06 §2a`, "Descriptive back-fill
only"). Draft initial `spec/` bodies that **describe what the project currently
is** — a map of the existing system so future loops have authoritative context.

#### What to map

Use the Step 1 survey to draft specs describing the system as it exists:

- Its components/modules and their responsibilities.
- How it is built, tested, and run (the toolchain and commands found in Step 1).
- Its existing conventions and structure (naming, layout, configuration patterns).

These specs are **descriptive** — a snapshot of current reality. They are not
design documents and they prescribe nothing.

#### No-decisions boundary (hard rule)

Back-fill makes **no decisions and proposes no changes**. It records what *is*,
never what *should be*. No ADRs are authored during back-fill. No spec text
prescribes a change, proposes an improvement, or advocates for a direction. Any
new decision, ADR, or proposed change requires a **real planning phase** — the
normal owner-driven research → ADR → spec loop — not the alignment pass.

This boundary is non-negotiable. If the survey reveals a problem or an
opportunity, note it in `status/roadmap.md` as a future milestone for the owner
to address, not in a spec body.

#### Lifecycle: back-filled specs are not exempt from review (Unaligned-bare only)

Each back-filled spec is authored at `Status: Draft` and passes through the
normal `Draft → Plan Review → Approved` flow (spec `06 §2a`; lifecycle per
[`../../../../../.docs/spec/03-artifact-lifecycle.md`](../../../../../.docs/spec/03-artifact-lifecycle.md)).
Back-fill does not get to skip evaluation. As the orchestrator drives this, the
planner authors the descriptive specs and the plan evaluator reviews them blind,
exactly like any other spec.

This `Draft → review` rule is **Unaligned-bare only** — it applies to newly
authored descriptive specs that have no prior status. It does **not** apply to
Unaligned-migrate, where migrated specs retain their prior status (spec 06 §2b).

#### `spec/README.md` reading order

After back-fill, populate the `spec/README.md` reading order (which Greenfield
Step B seeded empty) with the back-filled specs in a sensible reading order, so
future loops have an entry map. The non-negotiable decisions section stays empty
— none are decided in an alignment pass.

---

### Step 4 — Seed `status/` with current state + initial roadmap

Beyond Greenfield's status seeds, the Unaligned pass records the *actual* current
state of the surveyed project:

- **`progress.md`** — Update to the final alignment-phase marker (e.g. "Phase:
  init / Unaligned alignment complete"). The decision index points at the
  back-filled descriptive specs. No decisions are recorded here (back-fill makes
  none).

- **`roadmap.md`** — An **initial roadmap** seeded from the survey: the
  milestones implied by the project's current state, framed so the owner can
  refine them. Per spec `06 §2a`: "Seed `status/` with current state and an
  initial roadmap." Any problems or opportunities noted during back-fill go here
  as candidate milestones, not into specs.

- **`handoff.md`** — "Start here each session" pointing at `spec/README.md` and
  `progress.md`, with the immediate next step being to resume as **Initialized**:
  declare scope with the owner and run `/loom:run`.

---

### Step 5 — Hand back: ready to resume as Initialized

The goal (spec `06 §2a`): the project is now loom-shaped — `.docs/` scaffolded,
gate established (or UNVERIFIED placeholder recorded per `gate-learning.md`), `spec/`
descriptively back-filled and in the `Draft → Plan Review → Approved` pipeline,
`status/` seeded with current state and initial roadmap — so the **next** loom
run detects it as **Initialized** (its `.docs/` is now loom-shaped per
`init-detection.md`) and resumes from the menu.

Commit(s) are author-neutral per [`commit-convention.md`](commit-convention.md):
no co-author trailers, no role/author identity in the message.

Unaligned-bare's design output is **only the descriptive back-fill** — it authors
no ADRs and no decision-bearing specs. That begins as a real planning phase once
Initialized.

---

## Unaligned-migrate flow — a pre-existing docs spine exists

This flow runs when detection recorded "a non-loom docs spine exists at `<path>`"
(slice 1, [`init-detection.md`](init-detection.md)). The job is
**reconciliation/migration, NOT back-fill**: there is nothing to describe that the
existing tree does not already describe better. See spec 06 §2b for the canonical
sub-mode definition.

### Owner gate — migrate / thin-pointer / abort

Before any files move, loom surfaces an **explicit, required owner decision point**
— not the generic "ambiguity → ask" fall-through. Loom does not pick; the owner
must answer. Each option's consequence:

- **Migrate** — reconcile/move the existing spine into `.docs/`; the old tree
  stops being authoritative; future runs detect **Initialized**.
- **Thin-pointer** — leave the old tree authoritative and place a pointer at
  `.docs/`; consequence: **future runs re-detect Unaligned**.
- **Abort** — make no changes; consequence: the repo is **re-detected as Unaligned
  on every run**.

For the canonical option semantics, see spec 06 §2b / ADR 0009 §3.

### On *migrate* — run the recipe inline

`/loom:init` runs the migration recipe **inline** (no planner/evaluator role-spawn
— see *Inline, no role-spawn* below). For the mechanical procedure — dirty-tree
preconditions, untracked-file handling, NUL-delimited file lists, ordered/idempotent
cross-reference rewrite, numbered-spine → `spec/` + `status/` split with
two-directional link rewrite, three reference forms, living-rewritten vs
archived-snapshot boundary, and final link validation — see
[`migration-recipe.md`](migration-recipe.md). That reference is the single
authoritative source for the recipe mechanics; they are not restated here.

### Status preservation

Migrated specs **retain their prior status** — migration is **not a re-review
trigger**. The Unaligned-bare "new specs enter at `Draft` → review" rule does
**not** apply to migrated artifacts that already carry a status. For the canonical
policy, see spec 06 §2b / ADR 0009 §4.

### Inline, no role-spawn

A pure migration **authors no specs**, so — unlike Unaligned-bare's back-fill —
there is **no planner/evaluator role-spawn in the migration itself** (ADR 0009
§6). `/loom:init` performs the migration inline:

1. Detection (via `init-detection.md`) identifies Unaligned-migrate.
2. Owner gate is presented and answered.
3. On *migrate*: the migration recipe (see `migration-recipe.md`) is executed.
4. `status/` is seeded/reconciled.
5. Loom hands back **Initialized** — the repo is now loom-shaped; `init-detection.md`
   will return Initialized on the next run.

Subsequent design work begins normally via `/loom:run` once Initialized.

Identity pre-flight (see the shared pre-flight in the **Two sub-modes** section
above) applies before any commit in this flow.

Commit(s) are author-neutral per [`commit-convention.md`](commit-convention.md):
no co-author trailers, no role/author identity in the message.

### On *thin-pointer* / *abort*

Per spec 06 §2b consequences: the repo is **re-detected as Unaligned** on
subsequent runs (thin-pointer) or on every run (abort). No files are moved.

---

## Idempotence note

Re-running the appropriate sub-mode re-applies the current playbook:

- **Unaligned-bare** re-application never clobbers existing project content
  (auto-apply clean merges, recommend for conflicts — spec `06` Playbook
  re-application). Full idempotent re-application is the Initialized slice; this
  is only the safety invariant.
- **Unaligned-migrate** re-running is a no-op per the recipe's own idempotence
  guarantee — see [`migration-recipe.md`](migration-recipe.md) for the recipe's
  no-op guarantee rather than restating it here.

# 08 — Playbook

Status: Plan Review

The **playbook** is loom's bundled, evolving set of conventions and templates. It
makes loom opinionated: loom imposes the playbook on the projects it manages
rather than conforming to each project. Improving how you work = editing the
playbook; future inits and re-alignments pick up the change.

## Where it lives (packaging)

The playbook ships **inside the plugin** as a bundled skill:

```
loom/skills/loom-playbook/
├── SKILL.md
├── templates/        # artifact skeletons (research, ADR, spec, slice-plan, eval)
├── references/       # convention docs, the status machine, role rubrics
└── gates/            # known gate definitions (Rust verified; others learned)
```

Commands and agents reference it at runtime via the plugin-root variable, e.g.
`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/templates/spec.md`. The playbook is
**not** copied verbatim into managed projects — they receive the *applied result*
(a `.docs/` tree, a `CLAUDE.md`, concrete gate commands), while the playbook
remains the single source loom applies from.

## What the playbook contains

- **`.docs/` structure** — the canonical directory layout ([01](01-concepts.md)).
- **Artifact templates** — skeletons for research notes (with required citation
  format), ADRs, specs, slice-plans, and evaluations, each with its `Status:` line.
- **Status lifecycle** — the state machine and dispatch rules ([03](03-artifact-lifecycle.md)).
- **Role prompts & rubrics** — the cold-agent instructions and each evaluator's
  rubric, including the blind-input contract ([05](05-blind-evaluation.md)). These
  are largely the same content as the `agents/*.md` system prompts.
- **Gate definitions** — the `format → lint → test` standard plus known per-stack
  commands. **Rust is the only verified gate**; others are *learned* during init
  (see [06](06-init-modes.md)) and recorded back here.
- **`CLAUDE.md` template** — the project-level conventions loom writes into managed
  repos, plus guidance for root-level `CLAUDE.md`.
- **Naming conventions** — artifact ↔ `<artifact>-eval.md`, ADR/spec numbering.

### Slice-plans index ownership under parallelism

Under parallelism the slice-plans index (`slice-plans/README.md`) Active/Archived
sections are maintained by the **orchestrator on main**, not by the planner or
developer in a slice branch. This is a change from the M1-sequential habit, where
the planner wrote the Active-plans entry in the *same plan commit* as the plan file
and the developer/finalize touched it again when archiving. Once parallelism is on,
the planner authoring a slice-plan on its branch writes **only** the uniquely-named
plan file (`<slice>-plan.md`) — never the index; the orchestrator adds the Active
entry when it creates a slice and moves it to Archived when it lands one. See
[ADR 0008](../ADR/0008-parallel-docs-coordination-worktree-per-slice.md) for detail.

## Model tiers

The playbook records the per-role tier assignment (researcher `haiku`, developer
`sonnet`, planner + both evaluators `opus`). Only tiers are pinnable; exact
versions track the user's environment (ADR 0002).

## Evolving the playbook

- The playbook is itself developed through loom (dogfooding): changes are planned,
  evaluated, and landed like any other slice.
- **Gate learning:** when init creates a gate for a new stack, that gate is written
  back into `gates/` so the next project on that stack inherits it.

### `CLAUDE.md` auto-propagation (the curated digest)

loom keeps its conventions where agents already look — in `CLAUDE.md` — and does so
**automatically as slices land**, not as a separate manual chore. The mechanism:

- **Who and when.** The **developer's finalize pass** maintains `CLAUDE.md`. When a
  slice lands (code-eval PASS), the same finalize pass that updates the living docs
  also updates the relevant `CLAUDE.md` if the slice changed something in the
  curated-digest scope (defined below). The convention change and its `CLAUDE.md`
  reflection thus land together. This is specified as a finalize sub-step in
  [03](03-artifact-lifecycle.md) (*finalize pass*).
- **Scope: a curated digest, not a changelog.** `CLAUDE.md` is a stable,
  agent-facing **map** of the project, not a history of work. A finalize pass edits
  it only when the landed slice touched one of these **inclusion categories**:
  1. **Durable conventions** — naming, structure, or working rules that future
     agents must follow (e.g. "specs win over plans on conflict").
  2. **Repo-layout facts** — where authoritative things live (e.g. "the shippable
     plugin lives in `plugins/loom/`").
  3. **Gate definitions** — the format → lint → test commands a slice must pass,
     including a newly learned per-stack gate.
  4. **"Read-first" pointers** — the entry-point list directing an agent to the
     specs/handoff/progress to read before working.
- **Explicit exclusion.** **Per-slice history does not flow into `CLAUDE.md`.**
  What a given slice built, when it landed, milestone progress, and the running
  narrative stay in `progress.md` (and the other `status/` living docs). If the only
  thing a slice produced is history (no change to any inclusion category above), the
  finalize pass makes **no `CLAUDE.md` edit**. This keeps `CLAUDE.md` from degrading
  into a second, drifting changelog.
- **Both levels.** This covers loom's own **root** `CLAUDE.md` and the
  **managed-project** `CLAUDE.md` loom writes into projects it manages (the
  `CLAUDE.md` template above). The boundary is the same in both.
- **Derived, never authoritative.** `CLAUDE.md` is a **derived reflection** of the
  specs and the playbook — a convenience digest, not a source of truth. The specs
  and ADRs remain frozen and authoritative ([03](03-artifact-lifecycle.md), ADR
  0005); maintaining `CLAUDE.md` at landing is a non-spec digest update, not a spec
  edit, so it does not violate the spec freeze. **On any conflict the specs win**,
  and `CLAUDE.md` is corrected to match.

#### Shape and Concision Discipline

The inclusion/exclusion rules above decide *what* may enter `CLAUDE.md`. This
subsection governs its *shape and size*. `CLAUDE.md` is an **always-loaded entry
point**: every agent session reads it in full, so it competes for the same context
budget the thin-orchestrator discipline protects ([ADR 0012](../ADR/0012-thin-orchestrator-sonnet-default-bounded-return.md)
— context-budget discipline; [ADR 0013](../ADR/0013-starvation-loop-guards-cold-restart.md)
— the ~60% cold-restart trigger). A bloated always-loaded file consumes budget that
should go to work and buries high-value navigation under restatement. `CLAUDE.md`
must therefore stay a **lean map that routes to on-demand detail, not a mirror of
it.** The finalize pass applies these rules:

1. **Point, don't restate.** When `CLAUDE.md` names an authoritative reference file
   (a `spec/`, `ADR/`, or `references/` document), a **single-clause pointer**
   (purpose + link) replaces any paragraph that restates that file's content.
   `CLAUDE.md` names *where* the detail lives; the named file remains its sole
   authority. Restating a reference file's body in `CLAUDE.md` is a defect, not a
   convenience.
2. **Bounded size.** The finalize pass keeps loom's own root `CLAUDE.md` **under
   ~100 lines** (target 80–100) and a **managed project's `CLAUDE.md` under ~200
   lines**. If a landed slice's change would push `CLAUDE.md` past its bound, the
   detail **stays in a reference file** and `CLAUDE.md` points to it — the bound is
   held by moving detail out, never by dropping a needed pointer.
3. **Two zones.** `CLAUDE.md` is organized as a **stable top** (read-first
   pointers, the one-paragraph "what is loom", core invariants, the gate) followed
   by a **pointer index** (one entry per authoritative reference file: its name, a
   one-clause purpose, and a link). The stable top rarely changes; the pointer index
   grows by adding compact entries, not paragraphs.
4. **Scope test.** For each bullet a finalize pass would add or change, ask:
   *"Would a reader need the detail here, or just know where to find it?"* If the
   latter, the entry is a **pointer**. If the former, the detail either fits the
   shape and belongs in `CLAUDE.md` (rare) or stays in a reference file that
   `CLAUDE.md` points to.

**Enforcement.** This discipline is enforced at two points. The **developer's
finalize pass** applies it when writing `CLAUDE.md`. Independently, the **blind
code evaluator**, when a slice's diff touches `CLAUDE.md`, **flags restatement of a
named reference file, size over the bound, or a paragraph where a pointer belongs
as a finding.** (Wiring this check into the code-evaluator rubric is a follow-on
playbook slice; it is **not** decided here — the normative rule lives in this spec,
the rubric body is edited separately.)

## Verified gate (Rust)

| Step   | Command                                      |
|--------|----------------------------------------------|
| format | `cargo fmt --check`                          |
| lint   | `cargo clippy --all-targets -- -D warnings`  |
| test   | `cargo test`                                 |

Other stacks: no shipped defaults. loom identifies and creates the gate on first
encounter ([06](06-init-modes.md)), confirms with the owner, runs it green once to
mark it verified, then records it.

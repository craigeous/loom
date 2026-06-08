# Greenfield Init Behavior — the scaffold-and-seed body

Status: Archived
Target specs: 06-init-modes.md, 08-playbook.md, 04-orchestrator.md

## Context

M2 is "init modes & gate learning." The **detection** classifier landed (slice
`init-mode-detection`, commit 5fef2ed): `init-detection.md` is the single
authoritative source that returns Greenfield / Unaligned / Initialized, and it is
explicitly **read-only** — "acting on the detected mode is the caller's job"
(`init-detection.md` edge cases). What remains for M2 are the three **behavior
bodies** that act on a detected mode.

Today those behaviors exist only as terse, divergent prose in the call sites:

- `plugins/loom/commands/init.md` step 2 — one run-on sentence covering
  Greenfield *and* Unaligned scaffolding + playbook + gate.
- `plugins/loom/commands/run.md` step 1 — "greenfield → scaffold; unaligned →
  alignment pass; initialized → summarize current state and continue."
- `plugins/loom/skills/loom-playbook/references/orchestration.md` → *Init-mode
  detection* — "Then act per that mode (behaviors per `06-init-modes.md` and the
  relevant M2 slice)." This is the dangling pointer this slice resolves.

Spec `06-init-modes.md §1` and `docs-layout.md` define *what* Greenfield must
produce, but no executable body tells an agent the concrete, ordered steps. Two
agents in the same blank repo could scaffold different trees, seed different
status files, or skip gate establishment.

**This slice writes the Greenfield behavior body** as one authoritative playbook
reference (`references/greenfield.md`), mirroring how detection was single-sourced
in `init-detection.md`, then points the call sites at it. Greenfield is the first
coherent cut because it is the **foundation**: it establishes the scaffold + seed +
CLAUDE.md + gate primitives that Unaligned reuses (Unaligned = Greenfield scaffold
**plus** descriptive back-fill) and that Initialized re-applies idempotently. Cut
this first and the remaining two modes become "scaffold + delta."

### Why a reference file (not inline in the commands)

The detection slice established the pattern: behavior the command surface invokes
lives in `references/`, single-sourced, and the `commands/` + `orchestration.md`
sites point at it rather than restating it. Greenfield is invoked from two call
sites (`run.md` step 1, `init.md` step 2) and Unaligned will reuse the same
scaffold body, so it must be single-sourced to stay consistent. Inlining it twice
would recreate exactly the divergence the detection slice removed.

### Out of scope (explicit non-goals — deferred follow-up slices)

These are named here so nothing is lost; each is its own later M2 slice:

- **Unaligned back-fill** (spec `06 §2`): study the repo, scaffold (reusing this
  slice's Greenfield body), then **descriptive** `spec/` back-fill mapping what the
  project currently is. Deferred — *follow-up slice "unaligned-init-behavior"*.
- **Initialized resume menu** (spec `06 §3`): derive a menu from `.docs/` + git
  state and continue. Deferred — *follow-up slice "initialized-init-behavior"*.
- **Gate-learning for unknown stacks** (spec `06` *Gate establishment*, 2nd bullet):
  inspecting tooling, proposing commands, confirming with the owner, running green
  once, and **recording a new `gates/<stack>.md` back into the playbook**. This
  slice covers gate *establishment* only to the extent of **wiring the existing
  Rust-verified path and pointing at the learn-a-new-gate procedure**; it does
  **not** author the learn-and-record mechanism. Deferred — *follow-up slice
  "gate-learning"*.
- **Idempotent playbook re-application** (spec `06` last section, Initialized-only):
  auto-apply clean merges, recommend for conflicts. Deferred — folds into
  *"initialized-init-behavior"*.
- Any change to `.docs/spec/` or `.docs/ADR/` — frozen/immutable; this slice works
  within spec `06`.
- Any change to the canonical tree in `docs-layout.md` — that file is the source
  this body points *at*, not something this slice edits.

## Steps

1. **Create `plugins/loom/skills/loom-playbook/references/greenfield.md`** — the
   single authoritative Greenfield behavior body. The author must keep every
   listed artifact and ordering consistent with `docs-layout.md` and spec
   `06-init-modes.md §1`. Required content:

   - **Header + authority line.** `# Greenfield Init` and a one-line purpose: "The
     behavior the orchestrator runs when `init-detection.md` returns **Greenfield**
     — a blank/near-empty repo with no `.docs/`." State that the authority is
     `.docs/spec/06-init-modes.md §1` (use the same relative path style as
     `init-detection.md`, which links `../../../../../.docs/spec/06-init-modes.md`)
     and "spec `06` wins on any conflict." Note the precondition: detection already
     classified Greenfield; this body **writes** files (unlike read-only detection).

   - **Step A — Scaffold `.docs/`.** Create the full tree exactly as enumerated in
     `docs-layout.md` (cross-link it as the authority for the tree, do not restate
     the ASCII tree divergently — point at it and list the create actions):
     `research/`, `ADR/`, `spec/`, `slice-plans/` (+ `slice-plans/archive/`),
     `evaluations/`, and `status/`. Each folder gets a `README.md`; `slice-plans/`
     additionally seeds `archive/` (with a `.gitkeep` so the empty dir is tracked).
     State that each folder README follows the shape of "the loom repo's own
     `.docs/*/README.md`" (per `docs-layout.md` Seeds) — purpose, who authors /
     approves, lifecycle.

   - **Step B — Seed `spec/README.md`.** Reading order (initially empty / "specs
     are added as the owner declares scope") + a "Non-negotiable decisions"
     section, per `docs-layout.md` Seeds. No spec bodies are authored in Greenfield
     — design (research → ADR → spec) begins with the owner after scaffold (spec
     `06 §1`: "Begin with the owner").

   - **Step C — Seed `status/`** with the three living docs, each with its single
     job (cross-link `docs-layout.md` Seeds for the exact field set):
     - `roadmap.md` — milestone order; seeded empty / "start with the milestones the
       owner names."
     - `progress.md` — `Phase`, `Last action`, `Next`, decision index; seeded with
       "Phase: init / Greenfield scaffold complete."
     - `handoff.md` — "start here each session" + immediate next step ("declare scope
       and run `/loom:run`").

   - **Step D — Apply the playbook: write project `CLAUDE.md`.** Per `docs-layout.md`
     *Project `CLAUDE.md`*: write a `CLAUDE.md` that points new agents at
     `.docs/spec/README.md` and `.docs/status/handoff.md`, and records the project's
     gate commands (filled in by Step E). State that if a `CLAUDE.md` already exists
     in the (near-empty) repo it is updated, not clobbered — but in true Greenfield
     it is created.

   - **Step E — Establish the gate.** Per spec `06` *Gate establishment* and
     `gates/rust.md`:
     - If the toolchain is **Rust** (detected by `Cargo.toml` at repo/workspace
       root, per `gates/rust.md`), adopt the **verified** gate from `gates/rust.md`
       (`cargo fmt --check` → `cargo clippy --all-targets -- -D warnings` →
       `cargo test`) and record those commands in the project `CLAUDE.md`.
     - For **any other / unknown stack**, the gate must be *learned*: point at the
       deferred **gate-learning** procedure (spec `06` Gate establishment, 2nd
       bullet) — inspect tooling, propose commands, confirm with the owner, run
       green once, mark unverified until green, and record `gates/<stack>.md`. This
       body **references** that path; it does not implement it (see Out of scope).
       Until the gate-learning slice lands, a non-Rust Greenfield records the
       proposed commands in `CLAUDE.md` marked **unverified** and notes the
       follow-up.
     - State the gate is `format → lint → test` run in that order before any slice
       is `Implemented` (consistent with `SKILL.md` Gates and root `CLAUDE.md`).

   - **Step F — Commit + hand back.** The scaffold is committed author-neutral (per
     `commit-convention.md`); then control returns to the orchestrator, which
     confirms scope + claimed gates with the owner and begins the design loop
     (research → ADRs → specs → slice-plans). Greenfield's job ends at "repo is
     loom-shaped and ready to design"; it does **not** author any design artifact.

   - **Idempotence note (one line).** Re-running Greenfield on an
     already-scaffolded repo is a no-op for files that already match; it never
     clobbers existing project content. (Full idempotent re-application is the
     Initialized slice; this is just the safety note.)

2. **Repoint `orchestration.md` at the new body.** In
   `plugins/loom/skills/loom-playbook/references/orchestration.md`, *Init-mode
   detection* section: after the "Then act per that mode" sentence, the Greenfield
   branch must link `greenfield.md` as the behavior body (e.g. "Greenfield →
   [`greenfield.md`](greenfield.md)"). Leave Unaligned / Initialized as pointers to
   their forthcoming M2 slices (do not invent their bodies here). Keep the
   idempotent-re-application sentence. Do not restate the scaffold steps here — the
   reference owns them.

3. **Repoint `commands/run.md` step 1.** Change the Greenfield branch from
   "greenfield → scaffold" to point at the body: "greenfield → scaffold per
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/greenfield.md`". Leave the
   Unaligned / Initialized branches unchanged (they remain terse pending their
   slices) and leave steps 2–4 (scope/gates, driver loop, break) intact.

4. **Repoint `commands/init.md` step 2.** The current step 2 covers Greenfield and
   Unaligned together. Split the Greenfield path to reference the body:
   "**Greenfield:** run the scaffold/seed/gate body in
   `${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/references/greenfield.md`." Keep the
   Unaligned path describing "scaffold (per `greenfield.md`) **plus** descriptive
   back-fill" as a *pointer to the forthcoming Unaligned slice* — do not author the
   back-fill body here. Leave steps 1, 3 (Initialized), and 4 unchanged.

5. **Add `greenfield.md` to the playbook skill index.** In
   `plugins/loom/skills/loom-playbook/SKILL.md`, the References (`references/`) list,
   add a bullet: "`greenfield.md` — the Greenfield init behavior body (scaffold +
   seed + CLAUDE.md + gate)." Place it after the `init-detection.md` bullet.

6. **Update root `CLAUDE.md` "Repo layout (M2 in progress)" section.** Add a short
   line noting the Greenfield behavior body now lives in `references/greenfield.md`
   (paralleling the existing `init-detection.md` line), so future agents know where
   per-mode behavior is single-sourced. Per the user's workflow rule, keep
   `CLAUDE.md` current when committing. (Do not touch `.docs/spec/` or `.docs/ADR/`.)

## Verification

loom is markdown; **there is no compiled gate on loom's own repo** (root
`CLAUDE.md`: "This repo has no compiled code yet, so it has no concrete gate to
run"). Acceptance is by **review against the specs**, not format/lint/test. The
blind plan/code evaluator confirms:

- **Spec fidelity (06 §1).** Every Greenfield obligation in spec `06 §1` appears as
  a concrete step in `greenfield.md`: (a) create `.docs/` structure and seed
  `status/`; (b) apply the playbook = write project `CLAUDE.md` + establish the
  gate; (c) hand back to begin the design loop with the owner. No new behavior or
  decision beyond spec `06` is introduced.
- **Layout completeness (docs-layout.md).** Every artifact in the `docs-layout.md`
  tree is created by `greenfield.md` — checkable item by item: the six folders
  (`research/`, `ADR/`, `spec/`, `slice-plans/` + `archive/`, `evaluations/`,
  `status/`), each folder `README.md`, `spec/README.md` with reading-order +
  non-negotiables, and the three `status/` files with their named fields. No tree
  divergence: `greenfield.md` points at `docs-layout.md` for the canonical tree
  rather than restating a different one.
- **Gate establishment correct.** Step E references `gates/rust.md` for the verified
  Rust path **and** points at the learn-a-new-gate procedure (spec `06` Gate
  establishment) for unknown stacks, marking unverified gates as such. It does
  **not** invent a Rust gate for loom's own repo, and it does **not** author the
  learn-and-record mechanism (correctly deferred).
- **Steps are concrete, ordered, single-purpose.** An independent agent following
  `greenfield.md` top to bottom produces the same scaffold every time — no
  ambiguous ordering, no "figure it out." Greenfield writes **no design artifacts**
  (research/ADR/spec bodies) — that boundary is explicit.
- **Single source of truth.** The scaffold *behavior* lives only in `greenfield.md`;
  `run.md`, `init.md`, and `orchestration.md` reference it rather than restate it.
  Confirm: `grep -rn "scaffold" plugins/loom/commands plugins/loom/skills/loom-playbook/references`
  shows the call sites pointing at `greenfield.md`, with the step bodies only in
  `greenfield.md`.
- **No spec/ADR edits.** `git diff --name-only` touches only
  `plugins/loom/skills/loom-playbook/references/greenfield.md`,
  `.../references/orchestration.md`, `plugins/loom/commands/run.md`,
  `plugins/loom/commands/init.md`, `plugins/loom/skills/loom-playbook/SKILL.md`,
  `CLAUDE.md`, and `.docs/slice-plans/`. Nothing under `.docs/spec/` or `.docs/ADR/`.
- **Links resolve.** Every relative / `${CLAUDE_PLUGIN_ROOT}` path added points at a
  file that exists in the tree (`docs-layout.md`, `gates/rust.md`, the spec path,
  `greenfield.md` from each call site).

Regression guard: the repointed call sites keep their surrounding behavior intact —
`run.md` still drives the full loop (steps 2–4 unchanged), `init.md` still handles
Unaligned (as a pointer) and Initialized (step 3 unchanged) and reports, and the
Unaligned / Initialized branches are **not** prematurely fleshed out. Only the
Greenfield wiring changes.

## Notes

### MINOR resolutions (from eval)

1. **`archive/README.md` vs `.gitkeep`:** Seeded `archive/` with a `README.md`
   (consistent with every other scaffolded folder) rather than a bare `.gitkeep`.
   Rationale: (a) every other folder gets a README per `docs-layout.md`; (b) a
   README is more useful than a silent placeholder for a future agent reading the
   directory. `greenfield.md` Step A records this decision explicitly.

2. **Non-Rust placeholder clarity:** Step E now clearly states the non-Rust path
   records only a **marked-unverified placeholder** (`Status: unverified —
   gate-learning not yet complete`) and that this placeholder is never treated as
   a live gate. The inspect/propose/confirm/learn mechanism is explicitly deferred
   to the gate-learning slice.

### Verification evidence (gate: review-against-spec)

`git diff --name-only` (relative to the In-Progress commit) touches only:
```
CLAUDE.md
plugins/loom/commands/init.md
plugins/loom/commands/run.md
plugins/loom/skills/loom-playbook/SKILL.md
plugins/loom/skills/loom-playbook/references/orchestration.md
plugins/loom/skills/loom-playbook/references/greenfield.md  (new)
.docs/slice-plans/greenfield-init-behavior.md
```
No files under `.docs/spec/` or `.docs/ADR/` touched — confirmed by
`git diff --name-only HEAD | grep -E "spec/|ADR/"` returning empty.

**Single-source check:** `grep -rn "scaffold" plugins/loom/commands
plugins/loom/skills/loom-playbook/references/` shows step bodies only in
`greenfield.md`; `init.md`, `run.md`, and `orchestration.md` reference it.

**Link resolution:** all relative links in `greenfield.md` resolve to real files:
`docs-layout.md`, `init-detection.md`, `commit-convention.md`,
`../gates/rust.md`, `../../../../../.docs/spec/06-init-modes.md` — each
confirmed present.

**Spec fidelity (06 §1):** Steps A–C = scaffold `.docs/` + seed `status/`; Step D =
write project `CLAUDE.md`; Step E = establish gate; Step F = hand back to owner
for design loop. Greenfield writes no design artifacts — boundary is explicit.

**Layout completeness:** six folders (`research/`, `ADR/`, `spec/`,
`slice-plans/` + `archive/`, `evaluations/`, `status/`); each with `README.md`;
`spec/README.md` with reading-order + non-negotiables; three `status/` files with
named fields — matches `docs-layout.md` item by item.

**Gate establishment:** Step E adopts `gates/rust.md` verified Rust path and
references deferred gate-learning for other stacks, marking non-Rust gates as
unverified placeholder only.

**Regression guard:** `run.md` steps 2–4 unchanged; `init.md` steps 1, 3, 4
unchanged; Unaligned and Initialized branches are forward pointers only, not
fleshed out.

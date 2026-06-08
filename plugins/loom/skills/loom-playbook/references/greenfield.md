# Greenfield Init

The behavior the orchestrator runs when `init-detection.md` returns **Greenfield**
— a blank/near-empty repo with no `.docs/`.

Authority: [`../../../../../.docs/spec/06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md) §1.
Spec `06-init-modes.md` wins on any conflict.

Precondition: `init-detection.md` has already classified this repo as Greenfield.
This body **writes** files — unlike the read-only detection classifier.

---

## Step A — Scaffold `.docs/`

Create the full `.docs/` tree exactly as enumerated in
[`docs-layout.md`](docs-layout.md) (that file is the canonical authority for the
tree; this body does not restate a divergent ASCII tree — it points at it and
lists the create actions).

Create these directories and seed each with a `README.md`:

1. `.docs/research/README.md`
2. `.docs/ADR/README.md`
3. `.docs/spec/README.md` (content per Step B)
4. `.docs/slice-plans/README.md`
5. `.docs/slice-plans/archive/README.md`
6. `.docs/evaluations/README.md`
7. `.docs/status/` — no top-level README; see Step C for the three living files.

Each folder `README.md` follows the shape of the loom repo's own
`.docs/*/README.md` (per `docs-layout.md` Seeds): purpose, who authors/approves,
lifecycle. Use the loom repo's own `.docs/research/README.md`,
`.docs/ADR/README.md`, `.docs/evaluations/README.md`, and
`.docs/slice-plans/README.md` as reference shapes.

> **`archive/` gets a `README.md`, not a bare `.gitkeep`**, for two reasons:
> (a) it keeps the folder conventions consistent — every scaffolded folder gets a
> README; (b) the README is more useful than a silent placeholder, since a future
> agent reading the archive directory will immediately know its purpose.

---

## Step B — Seed `spec/README.md`

The `spec/README.md` must contain two sections:

1. **Reading order** — initially empty ("specs are added as the owner declares
   scope"). The note should read: "Reading order is established after the owner
   declares scope in the first `/loom:run` session."
2. **Non-negotiable decisions** — a placeholder section heading (initially empty or
   "none yet"), present so future agents know where to record settled constraints.

No spec bodies are authored during Greenfield. Design (research → ADR → spec)
begins with the owner after scaffolding (spec `06 §1`: "Begin with the owner").

---

## Step C — Seed `status/`

Create the three living docs, each with a single job (field names match
`docs-layout.md` Seeds):

- **`status/roadmap.md`** — milestone order. Seed with: "Start with the milestones
  the owner names." Fields: milestone list (initially empty).
- **`status/progress.md`** — status source of truth / decision index. Seed with:
  `Phase: init / Greenfield scaffold complete`. Fields: `Phase`, `Last action`,
  `Next`, decision index (initially empty).
- **`status/handoff.md`** — restart instructions + immediate next step. Seed with
  "Start here each session" instructions pointing at `spec/README.md` and
  `progress.md`. Immediate next step: "Declare scope with the owner and run
  `/loom:run`."

---

## Step D — Apply the playbook: write project `CLAUDE.md`

Per `docs-layout.md` *Project `CLAUDE.md`*: write a `CLAUDE.md` at the project
root that:

- Points new agents at `.docs/spec/README.md` and `.docs/status/handoff.md` as the
  first two reads.
- Records the project's gate commands (filled in by Step E below).

If a `CLAUDE.md` already exists in the (near-empty) repo it is updated, not
clobbered — add the loom sections without removing existing content. In a true
Greenfield repo it is created from scratch.

---

## Step E — Establish the gate

Per spec `06` *Gate establishment* and [`../gates/rust.md`](../gates/rust.md):

**Rust (verified gate):** If a `Cargo.toml` exists at the repo root or workspace
root (the detection signal per `gates/rust.md`), adopt the verified Rust gate and
record these commands in the project `CLAUDE.md`:

| Step   | Command                                       |
|--------|-----------------------------------------------|
| format | `cargo fmt --check`                           |
| lint   | `cargo clippy --all-targets -- -D warnings`   |
| test   | `cargo test`                                  |

**Any other / unknown stack:** The gate must be *learned* via the deferred
gate-learning procedure (spec `06` Gate establishment, 2nd bullet — inspect
tooling, propose commands, confirm with the owner, run green once, record a new
`gates/<stack>.md`). That full inspect/propose/confirm/learn mechanism is
**not implemented here** — it is the subject of the follow-up *gate-learning*
slice.

Until the gate-learning slice lands, a non-Rust Greenfield records a
**marked-unverified placeholder** in the project `CLAUDE.md`: the proposed
commands are listed with an explicit `Status: unverified — gate-learning not yet
complete` notice and a follow-up note. This placeholder is never treated as a live
gate; it is only a starting point for the gate-learning slice to fill in.

The gate runs in `format → lint → test` order before any slice is marked
`Implemented`, consistent with `SKILL.md` Gates and root `CLAUDE.md`.

---

## Step F — Commit and hand back

Commit the scaffold author-neutral per
[`commit-convention.md`](commit-convention.md): one commit, no co-author trailers,
no role/author identity in the message, no `user.*` override.

Then return control to the orchestrator. The orchestrator confirms scope and
claimed gates with the owner and begins the design loop (research → ADRs →
specs → slice-plans).

Greenfield's job ends here: **the repo is loom-shaped and ready to design.**
Greenfield does not author any design artifact (no research notes, no ADRs, no
spec bodies).

---

## Idempotence note

Re-running Greenfield on an already-scaffolded repo is a no-op for files that
already match; it never clobbers existing project content. (Full idempotent
re-application is the Initialized slice; this note covers only the Greenfield
safety invariant.)

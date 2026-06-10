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

This `CLAUDE.md` is a **curated digest** — a stable, agent-facing map of the
project, not a changelog. The developer's finalize pass keeps it current as
slices land (the curated-digest boundary is defined in
[spec 08](../../../../../.docs/spec/08-playbook.md) — *Evolving the playbook*;
per-slice history stays in `progress.md`). Greenfield's job is to **establish**
it, not to dump everything into it.

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

**Any other / unknown stack:** The gate must be *learned* via the mechanism
specified in [`gate-learning.md`](gate-learning.md) (inspect tooling, propose
commands, confirm with the owner, run green once, record a new
`gates/<stack>.md`). That body is now the single authoritative source for the
full inspect/propose/confirm/learn procedure.

For a non-Rust Greenfield, record a **marked-UNVERIFIED placeholder** in the
project `CLAUDE.md` before gate-learning runs — list the proposed commands with
an explicit `Status: UNVERIFIED — gate-learning not yet complete` notice. This
placeholder is the **UNVERIFIED entry state** of the gate-learning lifecycle
(see `gate-learning.md` Step 4's state machine); it is never treated as a live
gate. Gate-learning replaces it once the gate runs green.

The gate runs in `format → lint → test` order before any slice is marked
`Implemented`, consistent with `SKILL.md` Gates and root `CLAUDE.md`.

---

## Step F — Ensure a git identity is configured

Before committing, verify that the repository's git identity is properly
configured. This step is what makes `commit-convention.md`'s claim that
"the orchestrator/`/loom:init` ensures an identity exists before any role
commits" true.

Run:

```
git config user.name
git config user.email
```

**Acceptance criteria:** both commands return non-empty values, and the email
is NOT an auto-generated fallback — reject any email ending in `@localhost` (e.g.
`loom@localhost`) or containing `.(none)` (git's implicit/autodetected host form).
A real, owner-provided `user.name` and `user.email` must be present in git config.

**If a real identity is present:** proceed to Step G. Make no change to the
identity — never overwrite an existing identity.

**If absent or a fallback is detected:** STOP. Ask the owner to configure the
repository's git identity before proceeding:

```
git config user.name "Your Name"
git config user.email "you@example.com"
```

Never auto-invent an identity, never run `git config user.*` on your own
initiative, and never proceed to commit under a fallback identity. See
`commit-convention.md` for the rationale (uniform identity, blind evaluation).

---

## Step G — Commit and hand back

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

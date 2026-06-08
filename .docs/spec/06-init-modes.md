# 06 — Init Modes

Status: Approved

When loom starts in a repo it first determines which of three modes applies, by
checking for `.docs/` and loom markers.

## Detection

```
if no .docs/ and repo is empty/near-empty   → Greenfield
elif no .docs/ (or .docs/ not loom-shaped)  → Unaligned
else                                        → Initialized
```

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
conventions on the project.

- Study the repo: languages, build/test/lint tooling, existing docs, structure.
- Create `.docs/` and apply the playbook.
- Establish the gate (below).
- **Descriptive back-fill only.** Draft initial `spec/` that *describes what the
  system currently is* — a map of the existing project so future loops have
  authoritative context. Back-fill does **not** make decisions or propose
  changes; any ADRs or changes require a real planning phase. The back-filled
  specs still pass through normal `Draft → Plan Review → Approved`.
- Seed `status/` with current state and an initial roadmap.

Goal: leave the project loom-shaped and ready to resume as `Initialized`.

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

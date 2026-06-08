# `.docs/` Layout & Seed Contents

What loom scaffolds in a managed project on init. All committed to git.

```
.docs/
├── research/      + README.md
├── ADR/           + README.md
├── spec/          + README.md   (reading order, non-negotiables)
├── slice-plans/   + README.md   (active/archived lists)  + archive/
├── evaluations/   + README.md
└── status/
    ├── roadmap.md   (milestone order — "what's next and why")
    ├── progress.md  (status source of truth / decision index)
    └── handoff.md   (restart instructions, compact current context)
```

## Seeds

- **Each folder README** explains its purpose, who authors/approves, and the
  lifecycle (see the loom repo's own `.docs/*/README.md` as the reference shape).
- **`spec/README.md`** — reading order + "non-negotiable decisions" section.
- **`status/roadmap.md`** — start with the milestones the owner names.
- **`status/progress.md`** — `Phase`, `Last action`, `Next`, decision index.
- **`status/handoff.md`** — "start here each session" + immediate next steps.

## Project `CLAUDE.md`

Init also writes/updates a project `CLAUDE.md` that points new agents at
`.docs/spec/README.md`, `.docs/status/handoff.md`, and records the project's gate
commands (see `../gates/`). Long-term, loom keeps best practices in root- and
project-level `CLAUDE.md`.

## Conflict rule

`spec/` wins over `slice-plans/`. Accepted `ADR/` entries are immutable. Approved
specs are frozen — changed only through a new planning cycle.

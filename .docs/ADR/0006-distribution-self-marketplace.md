# 0006 — Distribution as a Single-Plugin Self-Marketplace

Status: Accepted
Date: 2026-06-08

## Context

The owner wants loom to be its own repo, installable into any project via a
marketplace. A Claude Code marketplace is a git repo containing
`.claude-plugin/marketplace.json` that lists plugins; plugin `source` can be a
local subdir (`./plugins/x`), the repo root, or an external git repo/subdir.

## Decision

- The **loom repo is its own single-plugin marketplace.** Both
  `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` live at the
  repo root, with the marketplace listing loom at `source: "."`.
- Install flow: `/plugin marketplace add <owner>/loom` → `/plugin install loom@loom`.

## Consequences

- One repo, one `marketplace add`, one `install` — simplest distribution for a
  single plugin.
- If loom later grows into a suite, split the marketplace into its own repo and
  reference loom via `git-subdir`.
- The exact root-plugin `source: "."` form must be verified against current docs at
  M1; fallback is `plugins/loom/` with `source: "./plugins/loom"` (tracked as
  OQ-E in spec 09).
- loom's own `.docs/` is dev memory, not a plugin component; installing loom
  elsewhere creates a fresh `.docs/` in the target project.

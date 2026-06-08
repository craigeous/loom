# 0006 — Distribution as a Single-Plugin Self-Marketplace

Status: Accepted
Date: 2026-06-08

## Context

The owner wants loom to be its own repo, installable into any project via a
marketplace. A Claude Code marketplace is a git repo containing
`.claude-plugin/marketplace.json` that lists plugins; plugin `source` can be a
local subdir (`./plugins/x`), the repo root, or an external git repo/subdir.

## Decision

- The **loom repo is its own single-plugin marketplace.** The marketplace catalog
  lives at the repo-root `.claude-plugin/marketplace.json`; the shippable plugin
  lives in a subdirectory `plugins/loom/` with its own
  `plugins/loom/.claude-plugin/plugin.json`, listed at `source: "./plugins/loom"`.
- Install flow: `/plugin marketplace add <owner>/loom` (or `./loom` locally) →
  `/plugin install loom@loom`.

## Consequences

- One repo, one `marketplace add`, one `install` — simplest distribution for a
  single plugin.
- **Why the subdir, not root:** docs confirm a relative `source` must be `"./sub"`
  resolved from the marketplace root; a root plugin (`source: "."`) is not
  documented, so we use the proven `./plugins/loom` form (resolves former OQ-E).
- The repo root is "the loom project" (with `.docs/` design memory + the
  marketplace); `plugins/loom/` is the artifact it ships. loom's own `.docs/` is
  dev memory, not a plugin component — installing loom elsewhere creates a fresh
  `.docs/` in the target project.
- If loom later grows into a suite, additional plugins become sibling
  `plugins/<name>/` entries in the same marketplace.

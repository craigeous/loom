# 0002 — Model Selection by Tier

Status: Accepted
Date: 2026-06-08

## Context

We wanted to assign the cheapest capable model to each role (researcher cheap,
developer mid, planner/evaluators strongest). The owner initially thought in exact
versions (Opus 4.8, Sonnet 4.6). Research into the plugin format showed the
`model` field on both agents and commands accepts **only** `inherit` / `sonnet` /
`opus` / `haiku` — there is no way to pin an exact minor version, and the Task tool
has the same enum.

## Decision

Pin models by **tier**:

| Role           | Tier     |
|----------------|----------|
| researcher     | `haiku`  |
| developer      | `sonnet` |
| planner        | `opus`   |
| plan evaluator | `opus`   |
| code evaluator | `opus`   |

Exact versions resolve in the installer's environment.

## Consequences

- loom gets the intended cost/capability profile (cheapest-capable per role)
  without guaranteeing a specific minor version.
- Because loom is installed in arbitrary environments, tier-based selection is the
  portable and correct choice; loom must behave correctly under whatever versions
  a tier maps to.
- Spec text must speak in tiers, not exact versions.

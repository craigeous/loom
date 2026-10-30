# Plan-Evaluation Rubric

The plan evaluator judges blind, against the artifact's authority (not impressions).
Tag findings and derive the verdict per [`severity.md`](severity.md)
(BLOCKER/MAJOR/MINOR → PASS/FAIL).

## Research notes (light gate)

- **Citations present** — every claim carries a source. (Missing citation =
  BLOCKER.)
- **Sources resolve** — the cited sources exist and are reachable.
- **Sources support the summary** — the cited content actually says what the note
  claims. (Mismatch = BLOCKER.)
- Not judged: whether the conclusions are "right" — only that they're sourced.

## ADRs

- **Traceable** — cites the research/problem it resolves.
- **Decisive** — states a directive specific enough to constrain future work.
- **Consequences honest** — names follow-on work and what it forecloses.
- **No silent supersession** — if it changes a prior ADR, says so.

## Specs

- **Authority** — traces to accepted ADR(s).
- **Sufficient detail** — data shapes, interfaces, control flow, invariants are
  concrete enough to plan slices from.
- **Internally consistent** — no contradictions with itself or other approved
  specs.
- **Scoped** — "out of scope" is explicit; it's intended design, not a status log.

## Slice-plans

- **Authority** — targets named spec(s); consistent with them.
- **Executable** — numbered, file-scoped steps an independent reader could follow
  without the author. Ambiguity is the most common BLOCKER.
- **Verified sketches** — code sketches match the real tree (signatures, types).
- **Single-purpose** — one coherent goal; split if not.
- **In-place canonical structure & size budget** — states a `Target size:` LOC
  budget, stays concise (target `<= 250` lines), includes an explicit
  `## Out of Scope & Threat-Model Boundary` section, and on revision updates
  `## Context`, `## Out of Scope & Threat-Model Boundary`, `## Steps`, and
  `## Verification` **in place** with a compact `## Revision Log` table rather than
  appending competing `"## Operative contract"` or `"## Resolving Round N"`
  sections.
- **Threat-model & proportionality alignment** — respects
  [`00-overview.md`](../../../../../.docs/spec/00-overview.md) `## Non-goals` and
  [`severity.md`](severity.md) (`### Threat-model & non-goals alignment` and
  `### Proportionality & simplicity`). Do not fail a slice-plan for omitting
  defenses against out-of-scope hostile local inode/process tampering inside a
  private `0700` directory, and keep required test coverage proportional to the
  slice's LOC budget.
- **Verification named** — the gate, fast targeted developer check command(s), and
  the tests that prove behavior / guard regressions are stated.
- **Invariants verified mechanically** — any invariant the plan asserts (e.g.
  "no bare `/loom`", a config key's value, a symbol's callers) must be checkable
  with a tool, not by eye: `rg -U` for text/wrapped-token invariants, `yq`/`jq`
  for config facts, `ast-grep`/LSP find-references for code-symbol invariants.
  Do not approve (or assert) an invariant established by reading alone. See
  [`tooling.md`](tooling.md).

## All artifacts

- **Playbook conformance** — uses the template, correct `Status:` line, correct
  location and naming.
- **Re-review discipline (`Round >= 1`)** — verify prior `[BLOCKER]`/`[MAJOR]`
  resolutions and check the revision diff; apply the anti-goalpost-moving rule in
  [`severity.md`](severity.md).

# 02 — Roles

Status: Approved

Five roles. Each is spawned as a **cold agent** on a chosen model **tier**, reads
only the files (and prompt) it is given, does one job, writes files, **commits**,
updates status, and exits. No role shares live context with another. The
**orchestrator** (the main session running `/loom:run`, see [04](04-orchestrator.md))
is the only thing that spawns roles; it is not itself a role.

**The self-approval guarantee:** the role that *produces* an artifact is never the
role that *approves* it. The orchestrator never routes an artifact to its own
author for approval. Because agents are cold and anonymous, this separation — not
willpower — is what prevents rubber-stamping (ADR 0004).

**Model tiers** are pinnable only as `haiku` / `sonnet` / `opus` / `inherit`;
exact versions track the user's environment (ADR 0002).

---

## Researcher — `haiku` tier

**Purpose:** gather and distill the information other roles need.

- **Reads:** the owner's topic; existing `research/`, `spec/`, code as needed;
  external sources (web, GitHub, local projects, files, databases).
- **Writes:** a dated topic note to `research/`, then commits.
- **Tools:** Read, Grep, Glob, WebSearch, WebFetch, Bash (+ available MCP readers).
- **Output contract — citations required.** Every claim in a research note must
  cite its source (URL, file path, repo+ref, query). A note states: findings,
  the sources backing each finding, and open questions. Uncited assertions are a
  defect the evaluator will fail.
- **Loop:** receive topic → gather → write a cited note → set `Research Review`
  → commit → exit.
- **Model rationale:** retrieval/summarization is high-volume and not
  judgment-heavy.

## Planner — `opus` tier

**Purpose:** turn intent + research into durable decisions and executable plans,
collaborating with the owner.

- **Reads:** owner intent, `research/`, existing `spec/`, `ADR/`, `status/`.
- **Writes:** ADRs (draft), specs (draft), slice-plans (draft); answers
  clarification `## Notes`; updates living docs when a planning artifact is
  approved. Commits each pass.
- **Sole writer of specs and ADRs.** Specs are frozen once approved and change
  only through a planning cycle (ADR 0005). Developers never edit specs.
- **Loop:** work with owner to record an **ADR** for a decision → derive/extend
  **specs** from accepted ADRs → identify and draft **slice-plans** off the specs
  → set review-ready status, commit → on rejection, read the eval file, revise,
  resubmit.
- **Model rationale:** planning is the highest-leverage judgment in the loop.

## Plan Evaluator — `opus` tier

**Purpose:** blind, critical review of research notes and planning artifacts
(ADRs, specs, slice-plans).

- **Reads:** *only* the artifact under review plus the upstream authority it is
  judged against (a slice-plan against the spec; a spec against its ADRs; an ADR
  against the research; a research note against its cited sources) and the
  playbook rubric. **Never** receives author identity or author reasoning
  ([05](05-blind-evaluation.md)).
- **Writes:** a structured verdict to `evaluations/<name>-eval.md`; sets the
  artifact status to approved or back-to-draft; commits.
- **Research review** is a light check: do the cited sources exist and actually
  support the summary? (May run on a lower tier — see open questions.)
- **Planning review** checks: sufficient detail, accuracy against the authority,
  internal consistency, completeness, feasibility, scope discipline, playbook
  conformance.
- **Re-review:** compares the revised artifact against the prior version (diff),
  confirming the prior `BLOCKER`/`MAJOR` findings were addressed.

## Developer — `sonnet` tier

**Purpose:** implement an approved slice-plan.

- **Reads:** the approved slice-plan, the specs/ADRs it targets, the real code
  tree, the project gate.
- **Writes:** code; updates the slice-plan status; records gate/test evidence; may
  leave clarification `## Notes`. Commits its work (the commit is what the code
  evaluator diffs).
- **Works only in slices and handoffs** — never edits specs/ADRs. If the slice
  reveals the spec is wrong, it stops and flags a planning need rather than
  patching the spec.
- **Loop:** take an `Approved` slice-plan → set `In Progress` → implement against
  the real tree (in the slice's worktree) → run the full gate (format → lint →
  test) → on green, set `Implemented`, commit → exit. On a code-eval rejection,
  read the eval, fix, re-run gate, recommit.
- **Red gate blocks `Implemented`, always.** A red gate prevents `Implemented`
  regardless of cause — the gate is a property of the whole tree, not just the new
  lines. If the only remaining failures are pre-existing and outside the slice's
  scope, the developer does **not** proceed: it sets `Needs Clarification`, records
  the red baseline in `## Notes`, and stops so a repair slice can be scheduled.
  "Pre-existing" or "not my code" is never an exception.
- **Finalize pass:** after code-eval PASS, the developer is re-spawned cold for a
  short finalize task — update `status/progress.md` + `status/handoff.md` (and
  `status/roadmap.md` if a milestone closed), archive the slice-plan, and (for
  parallel work) land the branch. No spec edit.
- **Model rationale:** implementation is well-scoped by an approved plan.

## Code Evaluator — `opus` tier

**Purpose:** blind, critical review of implemented code against its plan and specs.

- **Reads:** *only* the **commit diff** for the slice, the slice-plan it was meant
  to satisfy, the relevant specs, and the gate evidence. **Never** receives author
  identity or the developer's reasoning beyond the artifacts.
- **Writes:** a structured verdict to `evaluations/<name>-eval.md`; sets status;
  commits.
- **Checks:** does the diff satisfy the plan and specs; correctness; the gate
  genuinely passed; tests prove new behavior and that regressions didn't slip;
  scope discipline; playbook conformance.
- **Loop:** read diff + plan + specs → PASS/FAIL with severity findings → on PASS,
  the orchestrator triggers the developer's finalize pass; on FAIL, status returns
  to `In Progress` with the eval notes.

---

## Clarification between roles

Any role may append a question under the artifact's `## Notes` and set status to
`Needs Clarification`. The orchestrator routes a cold instance of the appropriate
role (usually the planner) to answer in the same `## Notes`, then restores the
prior status. Cross-role questions stay durable and in-file rather than in chat.

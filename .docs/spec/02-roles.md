# 02 — Roles

Status: Plan Review

## Authority

ADRs [0001](../ADR/0001-plugin-architecture-and-orchestrator.md),
[0002](../ADR/0002-model-selection-by-tier.md),
[0003](../ADR/0003-cold-handoffs-commit-per-handoff.md),
[0004](../ADR/0004-blind-evaluation-role-separation.md),
[0012](../ADR/0012-thin-orchestrator-sonnet-default-bounded-return.md),
[0017](../ADR/0017-infrastructure-blocked-escalation.md),
[0018](../ADR/0018-shared-core-and-client-adapters.md),
[0021](../ADR/0021-loom-owned-local-review-protocol.md), and
[0022](../ADR/0022-controlled-input-independent-evaluation.md).

## Exactly five lifecycle roles

Loom has exactly five logical lifecycle roles: researcher, planner, plan evaluator,
developer, and code evaluator. A role is a fresh non-delegating invocation loaded
with a shared role contract. It receives references to authorized inputs, performs
one bounded job, completes the mediated handoff, and exits.

The orchestrator is not a sixth role. Correctness, tests, and security local-review
workers are auxiliary finder procedures, not roles. Neither adapter may promote a
worker into the status lifecycle, model-role table, approval chain, or mediated
handoff graph.

Only the top-level orchestrator delegates. Claude role launch adapters omit the
`Agent` capability. Codex launches generic cold children with permissions that omit
delegation and a one-level hierarchy. Conformance tests must prove a role or finder
child cannot launch a descendant.

## Shared contract and client launch

Each canonical role contract states its purpose, authorized reads, permitted writes
or output channel, authority, tools/capabilities, lifecycle transitions, bounded
return, and non-delegation rule. Client bindings are thin:

- Claude Code loads a `plugins/loom/agents/*.md` adapter for the selected role.
- Codex's orchestrator skill launches a generic cold subagent and loads the same
  shared role contract. Loom does not create managed-project `.codex/agents/*.toml`.

The behavioral contract is shared even where the client launch mechanism differs.

## Capability profiles and model mapping

Shared policy uses profiles, not vendor model names:

| Profile | Lifecycle roles |
|---|---|
| Economy | researcher |
| Standard | developer; orchestrator (not a role) |
| Deep review | planner, plan evaluator, code evaluator |

The Claude adapter maps Economy/Standard/Deep review to
`haiku`/`sonnet`/`opus`. The Codex adapter maps each profile to an exact tested
model plus reasoning-effort setting in the versioned compatibility matrix. Exact
Codex identifiers are release data, not shared policy. A missing or untested mapping
is an error; adapters never silently fall back.

## Common handoff rules

- Role invocations are cold: no producing-role transcript or hidden live context is
  intentionally forwarded.
- The real output is the referenced artifact or isolated output, not the final chat
  message.
- Every completed handoff is committed under the repository's existing uniform,
  author-neutral identity. The orchestrator/recorder may make the commit where the
  role is intentionally denied repository writes.
- Final return is bounded to `Status:`, artifact path(s), a roughly 150-token
  summary, and one routing signal: verdict, gate result, blocker, or clarification.
- A role never pastes the artifact, diff, findings, or reasoning into the
  orchestrator context.
- No role approves its own output. This is separation of duties; it does not prove
  impartiality or anonymity.

## Researcher — Economy

**Purpose:** collect and distill evidence needed for planning.

- **Reads:** owner topic, relevant repository files, existing research/specs, and
  authorized external or connected sources.
- **Produces:** a dated research note whose material claims cite exact sources.
- **Transition:** `Draft → Research Review`.
- **Constraints:** no design authority; no uncited substantive claims; no
  delegation.

For later source evaluation, citations must be capturable: local references identify
repository/content revision where needed; external references provide stable locators
and any freshness requirement.

## Planner — Deep review

**Purpose:** turn owner intent and approved evidence into durable decisions and
executable plans.

- **Reads:** intent, approved research, accepted ADRs, approved specs, status, and
  repository facts needed to make the design concrete.
- **Writes:** ADRs before acceptance; spec amendments; slice-plans; clarification
  answers. The planner is the sole writer of specs and ADRs.
- **Transition:** planning work to `Plan Review`; rejected work back through `Draft`.
- **Constraints:** no product implementation and no approval of its own artifacts.

Accepted ADRs are immutable. Approved specs change only through a new planning
cycle. Slice-plans are authored only when requested after design approval.

## Plan evaluator — Deep review

**Purpose:** independently judge research and planning artifacts against their
authority and rubric.

- **Inputs:** a sanitized per-run workspace containing only the reviewed artifact,
  upstream authority, rubric/severity rules, hashed manifest, and allowed evidence.
  Re-review also receives the prior verdict and exact revision diff.
- **Evidence lanes:** current-tree claims use a read-only snapshot at one
  `evidence_sha`; cited-source claims use deterministic captured source evidence.
- **Output:** one schema-valid verdict in the run output directory.
- **Mutation:** none in the managed checkout. The deterministic recorder validates
  and installs the verdict, and the orchestrator commits the handoff.
- **Constraints:** no producer transcript, credentials, live checkout, network-
  specific client tools, repository write, or delegation.

Research review confirms evidence supports claims; planning review checks authority,
completeness, internal consistency, feasibility, scope, and playbook conformance.
Missing required evidence makes the run invalid/infrastructure-blocked rather than a
merits PASS or FAIL.

## Developer — Standard

**Purpose:** implement one approved slice-plan.

- **Reads:** approved plan, target specs/ADRs, exact branch tree, and configured gate.
- **Writes:** scoped product/test/docs changes, plan notes/status, and gate evidence.
- **Flow:** `Approved → In Progress → Implemented` after the full gate succeeds.
- **On evaluation FAIL:** return to `In Progress`, address findings, rerun the gate,
  and commit a new handoff.
- **Constraints:** never edit specs/ADRs, approve its own work, or bypass a red gate.

A whole-tree red gate blocks `Implemented`, including a pre-existing failure. The
developer sets `Needs Clarification` with evidence when repair requires a distinct
scope. It should commit coherent, gate-green substeps to limit infrastructure-loss
blast radius, while preserving a clean reviewable head.

Final living-doc, instruction-adapter, archive/index, and publication-receipt changes
are prepared by the deterministic landing flow in the disposable integration
candidate. They are not an unconstrained post-PASS developer edit to local `main`.

## Code evaluator — Deep review

**Purpose:** independently judge the exact code change and its evidence.

- **Inputs:** immutable source at exact `head_sha`, exact base/head diff, approved
  plan, relevant specs/ADRs, gate evidence, valid `loom-local-review/v1` companion,
  rubric/severity rules, and hashed manifest. Re-review additionally receives prior
  verdict and exact revision diff.
- **Required action:** invoke the bounded deterministic runner to rerun the entire
  declared gate in a verified disposable writable execution copy. Prior gate evidence
  is comparison input, never a substitute.
- **Review findings:** independently confirm or reject every advisory finder claim,
  map confirmed issues through the severity rubric, and record rejection reasons.
- **Output/mutation:** write one schema-valid verdict to isolated output only; the
  recorder installs it and the orchestrator commits it.
- **Constraints:** no live checkout, repository write, delegation, network-specific
  client tool, or unsupported gate-rerun outcome.

The code evaluator alone owns PASS/FAIL. A valid review run with zero findings does
not compel PASS; a finder-proposed severity does not determine the verdict.

## Auxiliary local-review workers

The root orchestrator launches exactly the required `loom-local-review/v1` finder
set against one prepared run:

| Finder | Advisory concern |
|---|---|
| `review-correctness/v1` | behavior, edge cases, plan/spec conformance |
| `review-tests/v1` | test sufficiency and meaningful failure coverage |
| `review-security/v1` | security consequences introduced by changed lines |

Each worker is cold, network-silent, non-delegating, read-only over common prepared
inputs, and writable only to its distinct output directory. It emits structured
findings; it does not change `Status:`, edit code, assemble results, or issue a
verdict. Missing, failed, malformed, duplicate, truncated, or invalid worker output
invalidates the aggregate run.

## Clarification

A producing role may record a concise question under the artifact's `## Notes` and
request `Needs Clarification`. The orchestrator records the prior status, dispatches
the authoritative clarifying role cold, commits the answer, restores the prior status,
and resumes. Evaluators do not use clarification to gain producer conversations; they
receive only recorded artifacts allowed by the evaluation manifest.

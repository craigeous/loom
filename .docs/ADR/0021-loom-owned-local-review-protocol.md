# 0021 — Loom-Owned Local Review Protocol

Status: Draft
Date: 2026-07-21

## Context

ADRs [0010](0010-orchestrator-run-automated-review-in-code-eval.md) and
[0011](0011-correct-automated-review-command-to-code-review.md) add local code and
security review before evaluation, but bind Loom to Claude-specific hidden slash
commands whose prompts, spawning, availability, and updates Loom does not control.
That mechanism cannot be reproduced on Codex or pinned and regression-tested as part
of a Loom release.

The [repository improvement plan](../repository-improvement-plan.md) requires a
network-silent, PR-independent, versioned `loom-local-review/v1` protocol over exact
commits, with Loom-owned finders and deterministic validation. ADR 0018 also requires
review behavior to be shared core rather than a client command dependency.

In scope are protocol inputs/outputs, finder vocabulary, validation and partial-run
behavior, provenance, prompt versioning, orchestration ownership, and the exact
replacement of ADRs 0010/0011. Finder prompt prose, helper implementation, defect
fixtures, and performance thresholds are follow-on work. The blind code evaluator
continues to own the final verdict.

## Decision

### 1. `loom-local-review/v1` is the only supported automated-review input

For every code-bearing slice, the top-level orchestrator invokes the repository-owned
`loom-review` helper to prepare a run from two full, existing commit object IDs:
`base_sha` and `head_sha`. Symbolic refs, a dirty working tree, an implicit merge base,
`origin/HEAD`, a PR, and the current checkout are not review targets. The review is of
the exact `base_sha..head_sha` change and the source tree at `head_sha`; rename, add,
delete, mode, and binary metadata are part of the captured diff.

The helper exports a `.git`-free source snapshot and immutable inputs. The reviewer
agents receive no network, web, provider, PR, or remote-branch tools. Preparation,
finder execution, validation, and assembly SHALL work in a clone with no remote and
make no network request. Client adapters may differ in how they launch a cold agent,
but do not change this protocol.

Pure-documentation slices retain the aggregate `skipped: docs-only` result without
starting a protocol run. Every applicable code slice must produce a valid protocol run;
“review command unavailable” is no longer an acceptable terminal skip because Loom
ships the helper, prompts, and adapters itself. Missing runtime/client capability is an
invalid/infrastructure-blocked run that must be repaired before landing.

### 2. The manifest and findings are versioned, hash-bound data

The canonical run manifest is UTF-8 JSON with stable key ordering for hashing and
contains at least:

- `protocol: "loom-local-review/v1"`, a unique `run_id`, slice ID, and Loom product/
  helper version;
- full `base_sha` and `head_sha`, head tree ID, canonical diff SHA-256, and an inventory
  of changed paths/statuses including binary and rename metadata;
- approved slice-plan, relevant spec/ADR, and gate-evidence paths with SHA-256 hashes;
- the required finder set, each finder ID, prompt protocol/version and prompt-content
  hash, expected output path, and client adapter/model-profile provenance; and
- source-export hash/manifest, creation time, and the manifest's own canonical hash.

Each finder writes one UTF-8 JSON result containing the protocol, run/manifest hash,
finder ID and prompt version/hash, exact base/head and diff hash, status, finding list,
and execution provenance. It never edits source, plan, evidence, another finder's
output, product code, or the repository checkout.

Each finding contains a run-stable ID, finder ID, confidence, proposed severity, changed
file and line/range, claim, concrete evidence, and suggested reproduction or
verification. A finding location must intersect the reviewed diff; supporting evidence
may cite unchanged context, but findings solely outside the changed diff are invalid.
Finder severity is advice only.

### 3. Finder and aggregate states cannot turn failure into clean

Every required finder has exactly one state:

- `pending` — declared but not yet completed;
- `ran-with-findings` — completed successfully with one or more valid findings;
- `ran-clean` — completed successfully with zero findings;
- `failed` — launch, execution, timeout, truncation, or infrastructure failure; or
- `invalid` — output is missing, malformed, inconsistent, modified, or violates schema.

The required initial set is `review-correctness/v1`, `review-tests/v1`, and
`review-security/v1`. A later reviewed protocol revision may change the required set;
an orchestrator may not silently omit a required finder for cost.

Validation recalculates every object/hash, verifies the source export is unchanged,
rejects unknown protocol/prompt versions and out-of-diff locations, and requires exactly
one complete result from every declared required finder. The aggregate result is
`ran-with-findings` if any valid finder has findings and otherwise `ran-clean` only if
all required finders are valid and clean. Any `pending`, `failed`, `invalid`, missing,
duplicate, truncated, or malformed finder makes the whole run `invalid`; partial valid
findings may be preserved for diagnostics but SHALL NOT be assembled or represented as
a completed review.

An invalid run is never handed to the code evaluator as valid review evidence and never
permits landing. The orchestrator classifies and checkpoints the failure: retry only
when the failure is safely retryable; pause under ADR 0017 for infrastructure failures;
otherwise return the slice for correction. “No valid findings were produced” is never
translated to `ran-clean`.

### 4. Loom owns three cold finder roles; the evaluator alone decides PASS/FAIL

The root orchestrator launches separate cold, non-delegating roles for correctness,
tests, and security against the same prepared run. Each has read-only access to the
prepared inputs and a distinct writable output directory. Finders produce structured
claims only: they do not edit code, approve work, determine the aggregate validity, or
write the final evaluation.

After deterministic validation, `loom-review assemble` creates the existing
identity-neutral `.docs/evaluations/<slice>-review-findings.md` companion artifact with
the aggregate status, full provenance, and normalized findings. The blind code
evaluator must independently confirm or reject each finding against its controlled
inputs, map confirmed issues through the severity rubric, and remain the sole owner of
PASS/FAIL. Automated review remains separate from the developer's format/lint/test gate.

### 5. Protocols and prompts are immutable versioned release assets

`loom-local-review/v1` fixes the required meaning and validation rules above. An
incompatible schema, hash, state, required-finder, or validity change introduces
`v2`; an implementation must reject unknown majors rather than guess. Compatible
clarifications may retain v1 only when old readers produce the same validity result.

Each finder prompt has its own immutable major name (`review-correctness/v1`, etc.) and
content hash. Any behaviorally meaningful prompt change creates a new prompt version;
formatting-only changes still change the recorded hash. A release pins protocol,
prompt versions/hashes, schemas, and defect-battery evidence. Detection rates are
benchmark evidence, not deterministic CI assertions; schema, isolation, and failure
handling are deterministic gates.

## Consequences

- **Partially supersedes ADR 0010.** Preserved: review occurs before land on code diffs;
  the orchestrator owns execution; the companion findings artifact is identity-neutral;
  findings are advisory; the code evaluator and severity rubric own the verdict;
  docs-only skips are explicit; and review is separate from the gate. Replaced:
  `/code-review`/`/security-review` execution, hidden external prompts, the
  `skipped: command unavailable` terminal state, and graceful degradation that could
  allow an applicable slice to land without a valid local review.
- **Supersedes ADR 0011's external-command decision.** `/code-review` and
  `/security-review` are no longer Loom dependencies. ADR 0011's correction from an
  empty working tree to an exact committed range is preserved and strengthened as
  mandatory full `base_sha`/`head_sha` protocol inputs.
- **Partially supersedes ADR 0017's review terminal-state wording.** Its infrastructure
  detection, false-clean prohibition, pause/checkpoint, and rerun requirements remain
  in force and now apply mechanically to finder states. Its allowance to end an
  applicable degraded review as `skipped: command-unavailable` is replaced: a shipped
  Loom finder/helper failure remains invalid until repaired and rerun.
- Specs 02, 04, and 05 and the playbook require later planner-authored amendments;
  helpers, schemas, prompts, agents, fixtures, and tests follow as separate slices. No
  external command is removed in this decision pass.
- Loom owns review reproducibility and update cadence, at the cost of three additional
  role assets and versioned protocol maintenance. Cost-driven reductions require a
  later reviewed protocol/profile decision backed by M8 evidence.

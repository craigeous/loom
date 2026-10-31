# Review-Findings Artifact Format

The review-findings artifact is the single, committed, identity-neutral record
that carries the helper-assembled `loom-local-review/v1` output **from the orchestrator to
the blind code-evaluator**, as an additional input alongside the commit diff,
slice-plan, specs, and gate evidence.

**Authority:**
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
(the initial governing decision),
[ADR 0021](../../../../../.docs/ADR/0021-loom-owned-local-review-protocol.md)
(`loom-local-review/v1` unattended three-finder local review package, and
[ADR 0023](../../../../../.docs/ADR/0023-repository-self-hosting-bootstrap-transition.md) §3
`loom-repository-bootstrap/v1` degraded bootstrap review), spec
[04](../../../../../.docs/spec/04-orchestrator.md) §"Automated review before a
slice lands" (the orchestrator's run step — Slice B scope), and spec
[02](../../../../../.docs/spec/02-roles.md) (Code Evaluator). The orchestrator —
not the code-evaluator — produces this artifact because **only the orchestrator may
spawn**, and finders are launched by the root; see
[ADR 0001](../../../../../.docs/ADR/0001-plugin-architecture-and-orchestrator.md).

This file owns the artifact **format** only. It **points to**, not restates:

- the orchestrator's run procedure → spec 04 § "Automated review before a slice
  lands" (and Slice B's `references/orchestration.md` update when landed); and
- the evaluator's adjudication procedure → `severity.md` + `code-eval-rubric.md`
  (Slice C scope).

---

## Location and naming

```
.docs/evaluations/<slice-name>-review-findings.md
```

This is a **per-slice companion** to `.docs/evaluations/<slice-name>-eval.md` in
the same `evaluations/` namespace, distinct from the evaluator's own verdict file.

Under worktree parallelism it is **branch-local and uniquely named** — one file
per slice, so it never collides across concurrent branches — consistent with
[`parallelism.md`](parallelism.md) (slice-branch-local, uniquely-named files per
[ADR 0010](../../../../../.docs/ADR/0010-orchestrator-run-automated-review-in-code-eval.md)
§2 / [ADR 0008](../../../../../.docs/ADR/0008-parallel-docs-coordination-worktree-per-slice.md)).

It is **committed author-neutral** per [`commit-convention.md`](commit-convention.md).

*When* the orchestrator writes and commits it in the driver loop is spec 04 scope
(Slice B) — point there, not here.

---

## Identity-neutral content — a hard invariant

**The review-findings artifact is identity-neutral.** It names **no author** and
carries **no remote or review-platform metadata and nothing that would leak
authorship** into the blind evaluator. The exact base/head commit IDs are required
provenance (they bind the artifact to the reviewed diff) and are not author identity.

Authority: [ADR 0004](../../../../../.docs/ADR/0004-blind-evaluation-role-separation.md)
(the blind contract) and
[ADR 0021](../../../../../.docs/ADR/0021-loom-owned-local-review-protocol.md).

---

## Findings come from validated finder results — a hard invariant

**Every finding is a normalized copy of a validated finder result**, produced only by
`loom-review assemble`. The orchestrator never reads the diff and writes findings of
its own; an artifact not produced by `assemble` from a validated run is invalid.

---

## Invalid runs are non-assemblable (ADR 0017, ADR 0021)

A missing, failed, pending, duplicate, malformed, truncated, or inconsistent finder
output invalidates the **whole** run. `assemble` refuses (exit 2); no artifact is
written, the run is never called clean, and it is never fed to the code-evaluator.
Infrastructure failures follow [`orchestration.md`](orchestration.md) §
"Infrastructure-blocked escalation" (pause + checkpoint); other failures are returned
for correction. There is no skip token for unavailable review.

---

## Required aggregate status

The artifact carries one `Aggregate:` line, set by the helper:

| Token | Meaning |
|---|---|
| `ran-clean` | All three required finders valid and report no findings. |
| `ran-with-findings` | All finders valid; at least one finding recorded below. |
| `skipped: docs-only` | Pure-docs slice; no run launched (recorded by the orchestrator). |

A skip is never confusable with a clean review. An invalid run has no status token —
it produces no artifact.

---

## Finding entry fields

Each entry is advisory input the evaluator adjudicates, not a verdict, under a
`## <ID> — proposed <severity>` heading:

- **Worker** — the finder identity;
- **Location** — file path and line range from the slice diff;
- **Confidence** — the finder's numeric confidence;
- **Claim**, **Evidence**, **Suggested verification**.

---

## Adjudication — boundary pointer

The evaluator treats findings as **advisory input, not auto-FAIL**; it confirms or
rejects each against the diff, plan, and specs, and maps confirmed findings to
severity per [`severity.md`](severity.md) — the single verdict authority. See
[`severity.md`](severity.md) and [`code-eval-rubric.md`](code-eval-rubric.md) for
the adjudication procedure (confirm/reject/discard steps and severity mapping).

**This file owns the artifact format; the rubric owns the adjudication procedure.**

---

## Helper contract — `loom-review` (`loom-local-review/v1`)

`plugins/loom/bin/loom-review` is the deterministic helper behind the
`loom-local-review/v1` run package ([ADR 0021](../../../../../.docs/ADR/0021-loom-owned-local-review-protocol.md)).
It resolves like the other helpers (`loom-resolve-helper`) and never launches a finder,
uses the network, or decides PASS/FAIL; its `assemble` output is advisory evidence only.

| Subcommand | Purpose |
|---|---|
| `prepare` | Fail-closed snapshot: exact `--base`/`--head` commit ids, clean tree at `head`, tracked plan/spec/ADR inputs, gate evidence, per-finder prompt hash and adapter/model profile; writes `manifest.json`, `diff.patch`, `inputs/`, and an object-exported `source/`. |
| `validate` | Re-derives everything from git objects and checks the three finder results; the aggregate is `ran-with-findings` or `ran-clean` only when all three finders are valid, otherwise `invalid`. |
| `assemble` | Re-validates, then writes the identity-neutral `*-review-findings.md` (default `.docs/evaluations/<slice>-review-findings.md`); refuses unless the aggregate is `ran-*`. |
| `status` | Read-only phase report: `prepared`, `collecting`, `validated`, `assembled` (`--json` available). |
| `clean` | Removes named, `--all`, or `--older-than <days>` runs under the review root only. |

**Exit codes:** `0` ok, `1` usage/environment, `2` target or content rejection (invalid
run), `3` run incomplete (`status` only).

**Run layout** (untracked, under `<git-common-dir>/loom/review/<run-id>/`): `manifest.json`
(canonical JSON, hash-bound), `source/` (read-only export of `head`), `inputs/`,
`diff.patch`, `results/<finder-id with / as __>.json` (written by finders), and
`state.json` (helper-only verdict). Schemas:
`plugins/loom/schemas/loom-local-review-{manifest,findings}-v1.schema.json`.

---

## Assembled format

```markdown
# Review findings — <slice-name>

- Protocol: loom-local-review/v1
- Run: <run-id>
- Aggregate: ran-with-findings
- Base: <full base sha>
- Head: <full head sha>
- Diff sha256: <hash>
- Manifest sha256: <hash>
- Findings sha256: <hash>

## Provenance

| Finder | Prompt version | Prompt hash | Adapter | Model profile |
|---|---|---|---|---|
| review-correctness/v1 | ... | ... | ... | ... |
| review-security/v1 | ... | ... | ... | ... |
| review-tests/v1 | ... | ... | ... | ... |

## <finding-id> — proposed <severity>

- Worker: review-security/v1
- Location: src/handler.rs:42-58
- Confidence: 0.9
- Claim: ...
- Evidence: ...
- Suggested verification: ...
```

A pure-docs slice records only the explicit `skipped: docs-only` status and launches
no run.

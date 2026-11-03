# 0033 — Narrow the v0.3.0 Scope, Prioritize v0.2.0 Live Proof, and Retire the macOS Checkpoint Tooling

Status: Plan Review
Date: 2026-11-03

## Context

[ADR 0032](0032-release-client-mapping-and-retirement-of-dogfood-tier.md) (Accepted)
fixed a release table whose v0.3.0 row requires five macOS pairs: Claude Code CLI,
Codex CLI, Antigravity, Orca and Herdr (`hc`). A repository review (evidence, not
authority) found that none of the three added harnesses has a matrix entry, binding,
pinned floor or live run; Herdr evaluators on `hc` stay blocked by
[ADR 0031](0031-herdr-as-an-hc-driven-client.md) §5; and the v0.2.0 pairs themselves
still lack the live proof 0032 §3 E4 requires. The only live record for them,
`.docs/evaluations/macos-dual-client-dogfood-evidence.json`, is
`infrastructure-blocked`: candidate `a0bf31604cc760631ba48b8fee574f89ef120cc8`, Codex
role launch exit 1 (HTTP 401, no authentication in the isolated home), Claude researcher
launch succeeded.

[ADR 0024](0024-macos-first-dual-client-dogfood-bootstrap-amendment.md) §6 and §7 still
read as open obligations (a "complete only when" proof for a checkpoint that 0032 §2
already demoted to history, and documentation-synchronization duties for a program that
has landed). The checkpoint harness `scripts/macos-dual-client-dogfood`, its Bats suite
and its runtime state schema are the only code those obligations keep alive.

**Owner decisions (binding).** D1: retire the macOS checkpoint tooling under a reviewed
slice; preserve the blocked evidence, its evidence schema, and all plans and verdicts;
carry the install-command fixture forward as release-install input. D2: replace 0032's
five-harness v0.3.0 scope with a narrower, evidence-backed expansion after v0.2.0.
D3: v0.2.0 live proof for the two shipped clients comes first. D4: the Herdr/`hc`
evaluator question is deferred until that proof completes; `hc` evaluators stay
prohibited.

In scope: the v0.3.0 scope and rotation consequences, ADR 0024's ongoing obligations,
the order of work, and what stays in force. Out of scope: editing any accepted ADR,
spec, `CLAUDE.md` or README text (the follow-on slice and finalize pass do that), and
any implementation.

## Decision

ADR 0033 supersedes ADR 0032 §1 for v0.3.0: the table rows `| v0.3.0 | macOS 14+ Apple
silicon | CC, Codex | REQUIRED (carried) |`, `| v0.3.0 | macOS 14+ Apple silicon |
Antigravity | REQUIRED |`, `| v0.3.0 | macOS 14+ Apple silicon | Orca | REQUIRED |` and
``| v0.3.0 | macOS 14+ Apple silicon | Herdr (`hc`) | REQUIRED |``, together with the
sentence "Counts: v0.2.0 has 2 required pairs; v0.3.0 has 5 required pairs." (the
five-pair v0.3.0 set), are replaced by §1 below.

ADR 0033 supersedes ADR 0032 §1 for v0.4.0: the row `| v0.4.0 | macOS 14+ Apple silicon
| the five v0.3.0 harnesses | REQUIRED (carried) |` is read as "the v0.3.0 harnesses as
admitted under §1 below" and no longer counts five.

ADR 0033 supersedes ADR 0032 §6 (Disposition for v0.3.0) only where it depends on the
five-pair v0.3.0 set: the lead sentence "All v0.3.0 work is on macOS pairs", the
per-harness work lists for Antigravity, Orca and Herdr (`hc`) as v0.3.0 requirements,
and the rotation sentence "Default evaluator rotation excludes Antigravity until v0.3.0
meets §3" together with "Restoring it to default rotation needs the v0.3.0 evidence
record to verify first", which now read "until an admission under §1 below meets 0032
§3 and the evidence record verifies". The Antigravity default-rotation exclusion itself,
and its explicit-opt-in, undocumented-as-supported treatment, stand.

ADR 0033 supersedes ADR 0024 §6 (Define the minimum macOS dual-client dogfood proof)
as an ongoing obligation: the checkpoint's "complete only when" criteria are no longer
a standing requirement and no longer a gate on any slice or release. The proof they
describe is replaced by ADR 0032 §3 E4 live conformance, bound to the final candidate
(§2 below). ADR 0033 supersedes ADR 0024 §7 (Synchronize documentation and preserve
full-matrix release evidence) as an ongoing obligation: the duty to keep dogfood
surfaces synchronized across specs, README and agent digests, and the paragraph "ADR
0019's Ubuntu and macOS Intel v0.2 support and release evidence were never suspended",
are no longer in force (ADR 0032 §4 already replaced that matrix). ADR 0024 §§2–5 and §8,
its Context, its historical record and its blocked evidence are not superseded.

### 1. Narrow v0.3.0 scope (replaces the five-pair set)

- v0.3.0 carries the two v0.2.0 pairs (macOS 14+ Apple silicon: Claude Code CLI, Codex
  CLI) and adds **only** pairs that have been *admitted*. A pair is admitted by a
  separate per-harness admission ADR, accepted before the v0.3.0 candidate is chosen,
  that cites a research note of verified CLI behavior, a pinned floor, the ADR 0032 §6
  work list for that harness, and the E1–E5 plan. No pair is admitted by this ADR.
- Antigravity, Orca and Herdr (`hc`) are **deferred, not built now**. Antigravity
  keeps ADR 0032 §6's unsupported status and default-rotation exclusion. Orca has no
  host adapter and none is started. Herdr keeps ADR 0031 §5–§8; `hc` evaluators remain
  prohibited and the evaluator question is reopened only after §2 completes.
- The pair rule of ADR 0032 §1 applies to the admitted set: all admitted pairs satisfy
  §3 together or v0.3.0 is not published. If no pair is admitted, no v0.3.0 is cut.
  The label is not reserved for any harness.

### 2. Sequence and v0.2.0 live proof

Work proceeds in this order: (1) land `herdr-surface-retirement`; (2) the
`dogfood-retirement` slice (D1); (3) v0.2.0 live proof for Claude Code CLI and Codex CLI
on macOS 14+ Apple silicon: authenticated isolated runs of all five roles and the full
loop, install/upgrade/uninstall, and the platform gate, bound to the final candidate
under ADR 0032 E1–E5 with the §3 evidence record; (4) only then any admission under §1.
The Codex 401 in the isolated home is an unmet proof and must be resolved (authenticated
isolated home) before E4 can be claimed; ADR 0024's blocked journal is not E4 evidence.
The shelved plans `hc-host-adapter` and `hc-live-probe` stay unbuilt until reopened.

### 3. Retired tooling and preserved records

The harness `scripts/macos-dual-client-dogfood`, its suite
`scripts/tests/macos-dual-client-dogfood.bats` and `plugins/loom/schemas/loom-dogfood-state-v1.schema.json`
are retired by the `dogfood-retirement` slice. Preserved unchanged: the blocked evidence
`.docs/evaluations/macos-dual-client-dogfood-evidence.json`, its schema
`plugins/loom/schemas/loom-dogfood-evidence-v1.schema.json`, and every plan, verdict and
archive. The install-command fixture `plugins/loom/adapters/fixtures/v0.2.0/dogfood/macos-arm64.json`
is relocated (bytes unchanged) as release-install input, with links and allowlists
updated in the same commit.

### 4. What remains in force

ADR 0032 in full except the clauses above (the v0.2.0 row, macOS Apple-silicon-only
scope, Ubuntu at v0.4.0, E1–E5, the evidence record, the dogfood-tier retirement, the
ADR 0019 supersessions, ADR 0027 §4); ADR 0031 in full; ADR 0024 §§2–5, §8, Context and
history; ADR 0019 as kept by 0032 §4. Accepted ADR bodies are not edited; the ADR
README register records the supersession.

## Consequences

- The next release claim is two macOS pairs; scope growth is gated on evidence, not on a
  pre-committed list. v0.3.0 may never exist under that label.
- ~2,700 lines of checkpoint tooling and tests leave the gate; coverage of install,
  hooks and launch stays in their own suites. Historical evidence stays checkable.
- The `CLAUDE.md` Map entry for the harness and the invariant text 0032 §8 lists need a
  finalize pass after the slice lands; README/spec text naming a five-harness v0.3.0 or
  the harness needs the same pass (listed by the slice, not drafted here).
- Orca, Antigravity and Herdr users have no path until admission. `hc` evaluators remain
  blocked; no new `hc`, Orca or `agy` build starts.

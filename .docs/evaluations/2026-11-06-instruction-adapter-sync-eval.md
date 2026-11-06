# Code evaluation — instruction-adapter-sync

Artifact: [instruction-adapter-sync](../slice-plans/instruction-adapter-sync.md)
Commit: 631d180
Round: 1
Verdict: PASS
Reviewed against: [spec 08](../spec/08-playbook.md) (*Canonical project instruction digest*, *`CLAUDE.md` and `AGENTS.md` adapters*, *Mechanical invariants*), [spec 09](../spec/09-open-questions.md) (*Instruction files*), [spec README](../spec/README.md), [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md) §2 and §8, [code-eval rubric](../../plugins/loom/skills/loom-playbook/references/code-eval-rubric.md), [severity](../../plugins/loom/skills/loom-playbook/references/severity.md), the review-findings artifact [instruction-adapter-sync-review-findings](instruction-adapter-sync-review-findings.md), and the plan-eval records [Round 0](instruction-adapter-sync-plan-eval.md) and [Round 1](2026-11-06-instruction-adapter-sync-plan-eval.md).

## Summary

PASS (code review of `9b01890..631d180`; BLOCKER: 0, MAJOR: 0, MINOR: 3). Round is 1:
the counter is shared with the plan evaluations (Round 0 FAIL, then Round 1 PASS), and
the validator's eval-sequence rule requires exactly round 1 after a PASS at round 1.
The full gate (`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`) was rerun on
`631d180`'s tree and exited 0. All of Steps 1–5 are implemented as specified. Step 6's
six tests are present and pass. Verification 1–8 were rerun independently and match the
plan.

## Findings

- [MINOR] (TST-1, downgraded from proposed MAJOR) No Bats fixture covers `GEMINI.md`. The
  claim is correct: `put_instruction_fixture` writes only `CLAUDE.md` and `AGENTS.md`.
  Removing `GEMINI.md` from `ADAPTERS` would not fail any added test. This is a plan
  choice, not an implementation gap. Plan Step 6 says "An optional GEMINI.md case is not
  required" and relies on the real-tree test `all mode passes for the valid repository`,
  and the plan passed cold evaluation on that basis. Spec 08 names only `CLAUDE.md` and
  `AGENTS.md`, so this is not "a case the spec admits is untested" under severity.md's
  MAJOR rule. The loop body that runs for `GEMINI.md` is the same one `AGENTS.md`
  exercises. Removing the absent-file skip would fail fixture tests 1 and 4 with
  `GEMINI.md: required file is missing`. Mutation probes in a scratch clone showed the
  behavior is correct: GEMINI shared-line drift exits 1 with the parity diagnostic,
  a GEMINI marker hash change exits 1 with the sha256 diagnostic, and a combined middle
  plus final bullet drift exits 1. Suggested follow-up, non-blocking: one GEMINI drift
  fixture test.
- [MINOR] (TST-2, confirmed) Negative marker-structure coverage is partial. Only the
  duplicate begin marker is tested. No test covers a missing end marker, an end marker
  before the begin marker, a malformed hash, or a missing `AGENTS.md`. The plan fixed the
  six tests and did not require these. The condition was traced by hand and is correct.
- [MINOR] (TST-3, partly confirmed) The CRLF and trailing-newline normalization has no
  fixture test. A scratch probe on the real tree showed that appending `\r\n\n` to the
  digest still validates, which is correct per spec 08's algorithm. Middle-bullet drift
  alongside a differing final bullet is also untested in fixtures, but the probe above
  shows it is caught. The "inactive-repo skip untested" part is **rejected**. About 60
  existing `make_docs_root` tests run `--all` on roots without the four files. If the
  rule did not skip, all of them would fail with a missing digest. The plan names them
  as the regression proof.
- [MINOR] Size: the Bats addition is 87 lines against a target of at most 85, which
  includes the section header and blank lines. The validator function is 34 lines
  (target at most 45). Net slice LOC is about 136, within the 170 target. Not
  load-bearing.

Correctness, security, and fidelity checks (all confirmed, no findings):

- The digest's `## Core invariants` bullet now carries the exact ADR 0032 §2 wording,
  with nothing else changed. `grep` for `Private macOS dogfood is not` /
  `dogfood is not public support` across the digest and the three adapters finds
  nothing (exit 1). The new wording appears once in each of the four files.
- `shasum -a 256` and the plan's Step 2 `node` command both give
  `1c04cef53e48e9ca8830087536edc77948f71b176de0e02393defaddb495ee11`. All three
  markers carry that one value, and the old `025e848a…` is gone.
- Shared body lines: the first 11 lines of each block hash identically
  (`775a476e…`) across `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md`. Only the
  client-specific final bullet differs. The `AGENTS.md` and `GEMINI.md` bullets are
  byte-identical to `CLAUDE.md`'s.
- `CLAUDE.md`: numstat `1 1` against both `cc2b1ef` and `9b01890` (marker only), 101
  lines.
- Validator rule: read-only, using `safeNode`/`readText` and no writes. It uses a
  fixed `DIGEST` path and a fixed `ADAPTERS` list, with no git or network calls and
  deterministic output, sorted through `report`. It runs only under `--all`. It is
  active only when the digest exists or an existing adapter contains the marker. The
  `GEMINI.md` probe uses `missing: false` and reports nothing when the file is absent.
  The separate `GEMINI.md: required file is missing` diagnostic seen when the file is
  deleted comes from a pre-existing rule; it reproduces at `9b01890`.
- Verification 6 (AGENTS drift on the real tree) exits 1 with the expected
  diagnostic. Verification 7: the 6 `instruction adapters` tests pass. Verification 8:
  shfmt diff lines 15 and ShellCheck `In ` count 170 (baseline unchanged), and
  `node --check` exits 0.
- Scope: no changes under `.docs/spec/`, `.docs/ADR/`, `README.md`, or
  `hc-live-probe.md`. The Bats diff only adds lines, so no test was weakened. The plan
  edit is limited to the Status line and Gate Evidence.

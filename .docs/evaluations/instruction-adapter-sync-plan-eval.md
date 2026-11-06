# Plan evaluation — instruction-adapter-sync

Artifact: [instruction-adapter-sync](../slice-plans/instruction-adapter-sync.md)
Commit: f32b9b0
Round: 0
Verdict: FAIL
Reviewed against: [spec 08](../spec/08-playbook.md) (*Canonical project instruction digest*, *`CLAUDE.md` and `AGENTS.md` adapters*, *Mechanical invariants*), [spec 03](../spec/03-artifact-lifecycle.md) (*Candidate finalization*), [spec 06](../spec/06-init-modes.md), [spec 09](../spec/09-open-questions.md) (*Instruction files*), [spec README](../spec/README.md), [ADR 0032](../ADR/0032-release-client-mapping-and-retirement-of-dogfood-tier.md) §2 and §8, [plan-eval rubric](../../plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md), and [severity](../../plugins/loom/skills/loom-playbook/references/severity.md).

## Summary

FAIL (plan review, Round 0; BLOCKER: 0, MAJOR: 1, MINOR: 4). The plan's factual
claims, authority, scope, size budget, validator rule, and Bats tests all check out
mechanically against the tree and a scratch prototype. One verification step
(Verification 8) states a lint result the current file cannot produce, and that
blocks approval.

## Findings

- [MAJOR] Verification 8 states a result the tree cannot produce. It says
  `shfmt -i 4 -d scripts/tests/repository-validation.bats` and
  `shellcheck -s bash scripts/tests/repository-validation.bats` give "no output and
  exit 0". At `f32b9b0`, before any slice edit, both already exit 1: shfmt prints a
  diff (the default dialect also misparses Bats; `shfmt -ln bats -i 4 -d` prints 15
  lines) and ShellCheck reports 170 findings (mostly SC2030/SC2031 info and SC2314).
  `.bats` files are not in the gate's shfmt/ShellCheck stages (`scripts/check`
  lints only `*.sh` and executable Bash scripts). A developer who follows the step
  literally must either reformat and annotate the whole 2654-line file, far outside
  the 170-LOC budget and the slice's scope, or stop at an unsatisfiable check. Per
  `severity.md`, this is an ambiguity an independent reader could implement wrongly.
- [MINOR] Steps 3–4 edit the derived blocks by hand, and spec 08 lists "manual block
  edits" as an error. This is acceptable here because the renderer does not exist
  yet. The plan says so (Context finding 1, Out of Scope), the edit restores
  digest-first consistency, and spec 03 already expects the digest and both adapters
  to change together when the curated digest changes. Consider one sentence in the
  Out of Scope section saying the hand-stamp is the interim stand-in for the
  unimplemented renderer.
- [MINOR] Verification 7's "with `LOOM_NODE` set as `scripts/check` sets it" points
  at a pinned Node that exists only inside a `scripts/check` run directory. Say
  "`LOOM_NODE` = an absolute Node executable (for example `$(command -v node)`)".
  Any modern Node runs these tests (verified with v26.7.0).
- [MINOR] Test 5 is named "duplicate or missing markers fail" but the plan only
  describes the duplicate case. Rename it, or add the one-line missing-end case.
- [MINOR] Verification 5's "1 line changed" is `git diff --stat` "1 insertion(+),
  1 deletion(-)". Optionally state it as `git diff --numstat cc2b1ef -- CLAUDE.md`
  → `1	1	CLAUDE.md`.

## Required changes (for FAIL)

1. Replace Verification 8 with a check that can pass. Either (a) record the
   pre-slice counts and require that they do not change:
   `shfmt -ln bats -i 4 -d scripts/tests/repository-validation.bats | wc -l`
   (15 at `f32b9b0`) and
   `shellcheck -s bash scripts/tests/repository-validation.bats | grep -c '^In '`
   (170 at `f32b9b0`), or (b) drop it and note that `.bats` files are outside the
   gate's shfmt/ShellCheck stages. Do not require the whole file to be lint-clean.

## Notes

Everything else in the plan was checked mechanically and holds:

- **Digest and hash claims.** `.docs/status/project-instructions.md` is canonical
  (spec 08, spec 09 *Instruction files*, spec README, spec 01). The file is LF-only
  with exactly one trailing LF. `shasum -a 256` and the plan's Step 2 Node
  normalization both give `025e848a…b2bf`, which equals all three current markers.
  The marker covers the digest, not the block.
- **No generator or checker exists.** `rg -l "project-instructions|AGENTS\.md|GEMINI\.md"`
  over `plugins/`, `scripts/`, and `.github/` finds nothing. Neither `--all` nor
  `--metadata`/`--links` validates the blocks. The blocks were added in `aacf8da`
  (AGENTS.md, digest) and `0dd3db9` (GEMINI.md).
- **Old wording locations.** `rg -nU "Private macOS\s+dogfood is not|dogfood is not public support"`
  finds exactly the places Context finding 4 lists: the digest at 20–21,
  `AGENTS.md:8`, `GEMINI.md:10`, ADR 0032 (13, 130, 309), the two archived plans,
  `dogfood-retirement-eval.md`, and `hc-live-probe.md:39`. There are no spec or
  fixture copies.
- **Authority for the digest edit.** ADR 0032 §2 gives the replacement text
  verbatim and §8 lists the edit. Spec 08 permits a digest change when an
  authorized durable convention changes, and spec 01 says the digest summarizes
  existing authority. No spec or ADR is edited. CLAUDE.md's header text says
  finalize-pass maintenance per a spec 08 "*CLAUDE.md auto-propagation*" passage,
  but no such passage exists in the current spec 08. The governing text is the
  adapters section plus spec 03 *Candidate finalization*, and the plan's
  slice-level edit is consistent with both: finalization would then have nothing
  further to re-render.
- **Prototype in a scratch clone at `f32b9b0`.** Steps 1–4 were applied with the
  plan's exact commands. New hash `1c04cef5…ee11`; Node normalization and `shasum`
  agree. Verification 2–5 give the stated results: grep exit=1 and count 0; one
  unique marker hash equal to `shasum`; three identical 11-line shared-body hashes;
  CLAUDE.md numstat `1 1`, still 101 lines. A Step 5 rule was written as specified
  in 40 lines (≤ 45). With the slice applied, `--all` exits 0. Verification 6's
  negative check exits 1 with the exact stated diagnostic. On the untouched current
  adapters with only the rule added, `--all` exits 1 and flags AGENTS.md and
  GEMINI.md shared-line drift, so the rule catches today's defect. The six Step 6
  tests were written as specified in 71 lines (≤ 85), and
  `bats --filter 'instruction adapters'` gives 6/6 ok. Adding them changes neither
  shfmt nor ShellCheck counts. Net diff: +128/−9 (≈ 119 LOC), inside the 170 target.
- **Fixture isolation.** `make_metadata_root`/`make_docs_root` copy none of
  `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, or the digest, so the rule stays inactive
  for existing roots. The real-tree test `all mode passes for the valid repository`
  is a required file in `scripts/check`'s Bats stage, so future drift will fail the
  gate as the plan intends. Full `repository-validation.bats` results, baseline vs.
  slice applied: baseline 198/207 ok, slice applied 204/213 ok. The same 9 tests
  fail in both runs (136, 137, 141, 142, 144–148: tool-cache and provisioning tests
  that need the `scripts/check` download cache, which scratch clones lack). There are
  no new failures, and all `make_docs_root` packaging/docs-state tests and the
  real-tree `--all` test pass with the slice applied.
- **Structure.** The plan is 250 lines (≤ 250) and has `Target size:`, an explicit
  Out of Scope & Threat-Model Boundary section, and a Revision Log. The docs-only
  fallback (Steps 1–4, ≈ 12 LOC) is coherent. This evaluation does not invoke it:
  the hash/marker/parity subset is a proportionate first step toward spec 08
  *Mechanical invariants* and changes no spec.

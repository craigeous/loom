# Evaluation: 0024 — macOS-First Dual-Client Dogfood Bootstrap Amendment

Verdict: FAIL
Round: 0
Evidence mode: `loom-repository-bootstrap/v1`
Bootstrap-ratification: degraded ADR 0024 one-time ratification
Isolation: not established under ADR 0022
Release conformance: not established
Run: `adr-0024-912ae46-ratification-r0`
Reviewed artifact commit: `912ae46d2813b3a383cb9daeed18c37afea5bc9e`
Reviewed artifact blob: `9df00621f1671e90a2b197f77c49c37d073fbf5f`
Manifest SHA-256: `d325455741643f34922826cbfd2eaf9d7720e2f4e2e885df1955b645ec43ffbb`
Input-inventory SHA-256: `072c21756d2280532e51edb66256283b512ff808cf4c122a90a78f0cbdedb476`
Evaluator verdict SHA-256: `57d3dc6ce73d6c06caf9d4f83b5df823fce1507ac4f1a21a6afebe90eb4071f2`

## Findings

- [BLOCKER] The proposed state successor is circularly authorized: ADR 0024 says none
  of its authority applies until the successor exists, while ADR 0023 forbids the
  addition that creates it.
- [MAJOR] The ratification text requires seven decision assessments, but the ADR and
  manifest define eight.
- [BLOCKER] The sealed package does not mechanically prove the asserted authority/M0
  ancestry, boundary trees, commit counts, path counts, or inventories on which the
  publication exception depends.
- [MAJOR] Rebuilding from an advanced remote target does not specify one deterministic
  integration algorithm, commit/tree mapping, overlap rule, or regenerated evidence.
- [BLOCKER] The Linux/macOS-Intel restoration wording implies suspension of ADR 0019's
  unchanged v0.2 support matrix.
- [MAJOR] The exhaustive documentation synchronization list omits `AGENTS.md` and the
  canonical instruction-digest parity required by ADR 0018.

## Required changes

1. Make owner acceptance activate authority only to construct and verify the one exact
   transition successor; keep both added slices blocked until that successor is
   freshly verified, and define the extended state validation precisely.
2. Require eight exact decision assessments.
3. Add hash-bound mechanical ancestry, boundary-tree, commit, changed-path, and count
   evidence to the ratification package and bind it in the ADR.
4. Define deterministic advanced-target integration and all evidence regenerated when
   commit IDs or trees differ.
5. State that only dogfood execution is deferred; ADR 0019's v0.2 matrix and release
   evidence remain authoritative.
6. Add `AGENTS.md` and canonical digest parity to documentation synchronization.

## Assessment

The two-slice separation, minimum dual-client behavioral proof, and review-integrity
rules are sufficient. Three confirmed BLOCKERs and three MAJOR findings prevent
ratification. The ADR returns to `Draft`; owner acceptance is unavailable until a
cold re-evaluation passes.

---

Verdict: FAIL
Round: 1
Evidence mode: `loom-repository-bootstrap/v1`
Bootstrap-ratification: degraded ADR 0024 one-time ratification
Isolation: not established under ADR 0022
Release conformance: not established
Run: `adr-0024-a8a0d63-ratification-r1`
Reviewed artifact commit: `a8a0d63557f517d7c39bf476f55d84ff6a48c37f`
Reviewed artifact blob: `cc661a984e7c9a552393faed3cac3b54cb027b56`
Manifest SHA-256: `4bd1268ecadcbababf33c5d2915f8180db2182bd22a0639464b36e1866378603`
Input-inventory SHA-256: `6f97a6a021f384600e76a64a047fa3970ce8554adf123c96091aaa7a37bc1921`
Publication-evidence inventory SHA-256: `d74d4d008e36f5c3b6934ae3e46ab3d22d1afcc4a841f5826baa7ffbab909b32`
Evaluator verdict SHA-256: `2a5b70b95a1600c24d6c17f2c0376639c446849c1ca6c8958761cf2f6dd5d7d8`

## Round 1 findings

- [BLOCKER] The sealed M0 classification covers the 52-path net diff but omits five
  history-only paths from the required 57-path per-commit union: the evaluations for
  ADRs 0018–0020 and `scripts/tests/run-bats-under.bats` plus
  `scripts/tests/toolchain-contract.bats`.
- [BLOCKER] Both sealed boundary range raw files contain seven-character abbreviated
  object IDs even though the inventory summary and ADR require full 40-character
  object IDs.

## Round 1 required changes

1. Classify all 57 M0 historical-union paths and mechanically reject any
   union/classification difference before sealing a replacement package.
2. Regenerate both net boundary raw inventories with full object IDs, validate the
   object-field widths, and reseal the evidence and ratification inventories.

## Round 1 assessment

The revised ADR closes five of the six Round 0 findings and passes six of its eight
decision assessments. The remaining Round 0 mechanical-evidence finding stays open
only because of the two defects above. Two BLOCKERs require `FAIL`; the ADR returns
to `Draft`, and owner acceptance remains unavailable until a cold re-evaluation
passes.

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

# Changelog

All notable changes to loom are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

Unreleased: this section records the changes leading to v0.2.0; it does not claim
the release has shipped.

- M0 — Baseline & multi-client proof: reproducible local gate (`scripts/check`),
  four-cell hosted CI, static Claude Code and Codex packaging contracts, and verified
  native lifecycle (install, hook wire, helper resolution, uninstall).
- M1 — Coordinator safety: centralized identifier validation, ABA-safe git-ref CAS
  locking, atomic claims, ownership re-adoption, and background lease renewal in
  `loom-coord`.
- M2 — Remote publication landing boundary: remote publication as the sole landing
  authority via `loom-land`, push-destination verification, and receipt binding.
- M3 — Identity guards & PreCompact backstop: raw-command identity scanning,
  post-command verification (`loom-verify-identity`), and per-session write-ahead
  PreCompact backstops.
- M4 — Local review orchestration: Loom-owned review finders and deterministic findings
  assembly (`loom-review`) with no external plugin dependency.
- M5 — Evaluation trust model: sanitized evaluation workspaces, bounded gate reruns in
  isolated scratch workspaces, and schema-valid evaluation recording
  (`loom-eval-workspace`).
- M6 — Executable checks & living document shape: foundation diagnostics (`loom doctor`),
  mechanical documentation-state validation (`validate-repository.mjs --all`), and
  living-document shape rules.
- M7 — Packaging conformance: root MIT `LICENSE`, this changelog, a supported-platforms
  and prerequisites section in the README, and `--all` validation of both files.

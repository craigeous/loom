# Evaluation: 0019 — Supported Runtime, Platforms, Compatibility, and Release Contract

Verdict: PASS
Round: 0
Reviewed against: repository improvement plan M0/M7 and release policy; approved dual-platform architecture research; ADR 0018; ADR 0002; approved specs 08 and 10; plan-evaluation rubric and severity rules.

## Findings

No BLOCKER, MAJOR, or MINOR findings.

## Required changes (for FAIL)

None.

## Notes

The ADR turns every runtime/release choice left open by M0 and M7 into a testable
contract: Bash 3.2+, explicit supported hosts and exclusions, production versus build
dependencies, independently pinned client floors, SemVer, protocol-version rejection,
atomic surface versioning, and a clean-tag release gate. These choices are feasible and
do not decide M8's workflow profiles or target-history shape.

Mechanical checks confirm the motivating tree facts: shipped shell entry points still
use `#!/bin/sh`, the coordinator uses `local`, the Claude manifest has no version, and no
Codex manifest exists yet. The locally inspected clients are exactly Claude Code 2.1.216
and Codex CLI 0.144.6, matching the conservative floors stated by the ADR; system Bash
3.2 is present on the supported macOS host. The later spec/code/CI changes are honestly
identified rather than performed in this decision pass.


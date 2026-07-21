# Evaluation: 08 — Shared Playbook, Instructions, Hooks, and Helpers

Verdict: FAIL
Round: 1
Reviewed against: accepted ADRs 0018–0022 and retained prior ADR authority; approved dual-platform research; repository improvement plan M0/M3–M7; sibling frozen specs; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] Hook response adapters remain non-deterministic where ADR 0018 requires
  exact fixture-tested client outputs. For blocked Claude `PreCompact`, the spec
  permits either exit 2/stderr or `decision: "block"` JSON “according to the pinned
  fixture,” without selecting the contract or locating/versioning that fixture;
  `PreToolUse` likewise leaves client decision encoding unspecified. Independent
  implementers can produce incompatible adapters while each claims conformance.
- [MAJOR] The Authority section omits retained ADR 0013 for the normative PreCompact
  write-ahead behavior and ADR 0020 for the landing/remote-doctor contracts included
  in the portable core and mechanical checks.

## Required changes (for FAIL)

1. Specify one exact blocked response and exit-status contract per client/event,
   including `PreCompact` and `PreToolUse`, and name the versioned fixture/schema path
   that conformance tests consume.
2. Add the omitted accepted authority for write-ahead and remote landing/doctor
   behavior.

## Notes

The canonical digest schema/rendering, Bash/dependency floor, exact local-review
protocol, evaluation utilities, doctor surface, and absence of external review-command
dependencies otherwise agree with the authority.

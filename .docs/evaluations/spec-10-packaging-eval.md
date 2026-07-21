# Evaluation: 10 — Packaging, Compatibility & Release

Verdict: FAIL
Round: 1
Reviewed against: accepted ADRs 0018–0022 and retained ADRs 0006–0007; approved dual-platform research; repository improvement plan M0/M2/M4–M7; sibling frozen specs; current tree; plan-evaluation rubric and severity rules.

## Findings

- [BLOCKER] The required Codex capability-profile mapping is not actually defined.
  ADR 0018 assigns exact Codex model IDs plus reasoning-effort settings to versioned
  adapter/release data, but this packaging/release spec supplies neither the mapping
  nor a concrete compatibility-matrix asset/schema/path. The validation matrix tests
  role launch and merely forbids fallback, so it cannot prove Economy/Standard/Deep
  use the selected model/reasoning settings at the supported floor.
- [BLOCKER] Helper-root resolution is an assertion rather than an implementable
  adapter contract. The research mechanically establishes that Codex does not promise
  Claude's plugin-`bin` PATH behavior, while ADR 0018 requires each adapter to resolve
  the installed root and invoke absolute helper paths. The spec names smoke tests but
  never defines how a Codex skill obtains that root or which versioned adapter binding
  supplies it.
- [MAJOR] The Authority section omits ADRs 0020–0022 even though the release gate
  normatively requires their remote-publication, local-review, evaluation-isolation,
  gate-runner, and recorder conformance.

## Required changes (for FAIL)

1. Define the versioned compatibility-matrix asset and exact Economy/Standard/Deep
   mappings, including Codex model IDs/reasoning effort, and require install/doctor/CI/
   release tests to verify the effective selections at each client floor.
2. Define the concrete Claude and Codex installed-root bindings used by workflow
   skills and the absolute helper invocation contract; do not defer correctness to an
   unspecified smoke fixture or bare PATH.
3. Add ADRs 0020–0022 to the Authority section for the release gates they govern.

## Notes

The two-catalog physical layout, eight explicit workflows, five-role/advisory-worker
separation, platform support matrix, Bash/dependency constraints, atomic SemVer, and
tag-derived release evidence otherwise match the authorities. Mechanical inspection
confirms the current tree is still the expected pre-M0 Claude-only/POSIX-labeled
migration target, not an already-conforming dual-client release.

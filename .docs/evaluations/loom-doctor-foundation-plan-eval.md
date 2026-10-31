# Evaluation: loom-doctor-foundation (slice-plan)

Artifact: `.docs/slice-plans/loom-doctor-foundation.md` (reviewed at commit 2b7a1d4)
Authorities: spec 06, 08, 10; spec 00 `## Non-goals`; `repository-improvement-plan.md` M6
Round: 0
Verdict: FAIL

## Summary

The plan is well scoped, within the 250-line budget (80 lines), has the required
`Target size:`, `## Out of Scope & Threat-Model Boundary`, `## Revision Log`, and
honestly marks the spec 08 diagnostic inventory as "unchecked, never passing". It
fails on executability: Step 3 under-specifies the helper-registration change so the
gate would go red, and Step 1 leaves several check definitions ambiguous.

## Findings

### [BLOCKER] 1. Step 3 registers the helper in only one of several pinned places

Step 3 edits only `ALLOWED_HELPERS` in `plugins/loom/bin/loom-resolve-helper:34`.
The same allowlist is pinned elsewhere and compared as an exact value:
- `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json:7` (`const` array)
- `plugins/loom/adapters/roots/claude-plugin-root-v1.json:16` and
  `plugins/loom/adapters/roots/codex-skill-source-v1.json`
- release-owned fixtures `plugins/loom/adapters/fixtures/v0.2.0/metadata/{claude,codex}-root.json`
- `scripts/validate-repository.mjs:517,526`
- `plugins/loom/bin/loom-resolve-helper.bats` and `scripts/tests/repository-validation.bats`

Landing as written makes `scripts/check` and the named
`validate-repository.mjs --all` verification fail (binding/schema/fixture drift),
or leaves Codex/Claude resolution of `loom-doctor` inconsistent. Required change
(smallest fix): add a file-scoped step listing each of these files (and the
`v0.2.0` fixture-immutability implication: either the fixtures are release-owned and
must not change, in which case state how `loom-doctor` is registered without
editing them, or plan the fixture/version change explicitly), and name the
resolve-helper bats update.

### [MAJOR] 2. New command/skill adapters are not tied to the repository validators

Steps 4–5 add `commands/doctor.md` and `skills/loom-doctor/SKILL.md`.
`scripts/validate-repository.mjs:270` maps every `commands/<name>.md` to
`skills/loom-<name>/SKILL.md` and validates frontmatter schemas, and the plugin
manifests/compatibility matrices (`adapters/compatibility/v0.*.json`) enumerate
commands/skills. The plan never says whether manifests, matrices, `.agents/skills`
routes, or counts need updating, nor what frontmatter the adapters carry. An
independent developer cannot know if the gate will accept them. Required change:
state the frontmatter/manifest/matrix edits (or cite the validator evidence that
none are needed) and add the touched files to the steps.

### [MAJOR] 3. Step 1 is one overloaded step with ambiguous check semantics

An independent reader cannot implement Step 1 uniquely:
- No enumerated check identifiers, so the JSON schema (Step 2) cannot be
  validated against a fixed contract ("stable identifier" is undefined).
- "Review-protocol finder availability" and "evaluation-protocol helper
  availability" do not name what is probed (`loom-review`, `loom-eval-workspace`,
  which commands/paths).
- "Coordination schema and stale claims" does not say whether to call `loom-coord`
  or read state directly, nor what "stale" means (threshold/source).
- "Initialization mode and evidence per spec 06" does not say to reuse
  `references/init-detection.md` vs reimplement the classifier.
- `node` and `shasum` are made required, but spec 06 mandates only Bash/Git/jq
  minima; the justification and minimum versions for node are not given.
- "Do not treat an unverified client as supported" conflicts with the claim that
  client version is unchecked: state exactly what the report says about the client.
Required change: add a compact table of check ids → probe → status mapping (one
line each) and name the existing helpers/references reused. Split Step 1 if it
exceeds one coherent file-scoped change.

### [MINOR] 4. Absolute path in verification

`node scripts/validate-repository.mjs --root /Users/craig/git/loom --all` hardcodes
a developer path; use `--root .`. Also name a fast targeted shell-gate check
(`shfmt -i 4 -d`, `shellcheck -s bash`) per project gate guidance.

### [MINOR] 5. Test coverage vs size budget

Step 6 lists a very large fixture matrix (every check × every state) against a
450 LOC production budget. Acceptable if tests are excluded, but consider stating a
proportional minimum (one pass/warn/error case per classification) per severity.md
proportionality.

### [MINOR] 6. Spec-fidelity note

Spec 06 requires `loom doctor` to fail validation on instruction-block drift and
spec 08 on hook/profile checks; the plan correctly defers these as unchecked. Ensure
the human output labels them `unchecked` rather than omitting them (Step 1 says this;
add one bats assertion naming it).

## Rubric checklist

| Item | Result |
|---|---|
| Authority (targets 06/08/10, consistent) | OK; defers spec 08 inventory honestly |
| Executable, file-scoped numbered steps | FAIL (findings 1–3) |
| Verified sketches against tree | FAIL (allowlist pinned in 7+ files) |
| Single-purpose | OK (one doctor surface) |
| Canonical structure / Revision Log | OK |
| Out of scope & non-goals | OK |
| Target size budget stated / doc <= 250 lines | OK (80 lines) |
| Verification named | Partial (finding 4) |

## Required for re-review

Resolve findings 1–3 in place (`## Context`, `## Steps`, `## Verification`) and log
the round in `## Revision Log`.

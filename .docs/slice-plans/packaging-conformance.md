# Packaging Conformance

Status: Plan Review
Target specs: 00-overview.md, 03-artifact-lifecycle.md, 10-packaging.md
Target size: <= 200 LOC net change

## Context

M7 calls for one coherent packaging contract. Spec 10 already prescribes SemVer,
`v0.2.0`, runtime floors, and release evidence, but the distribution and its
living documentation must be checked against that contract. This slice reconciles
those surfaces and adds mechanical checks for the license and changelog; it does not
itself establish that a release has passed its full matrix.

## Out of Scope & Threat-Model Boundary

No release, tag, publication, client-floor change, new platform support, or relaxation
of spec 10's release gate. README's broader refresh is a separate M7 slice. Preserve
historical records as historical evidence; update current operational documentation,
not quoted external API names or compatibility-required `Task` references. Per spec
00's non-goals, hostile local code containment and unsupported Windows/WSL environments
are outside this slice. Private macOS dogfood is not public release evidence.

## Steps

1. **Spec authority:** Compare `.docs/spec/10-packaging.md` with the actual manifests,
   catalogs, helpers, compatibility matrix, installation and release surfaces. Record
   each discrepancy and its resolution in the implementation evidence. If the contract
   itself needs amendment, have a planner propose the exact spec 10 changes and obtain
   independent cold plan evaluation before applying them; the developer must not
   self-approve a spec change. Retain the existing release matrix and SemVer policy.
2. **License and history:** Add root `LICENSE` with the complete standard MIT text and
   an accurate copyright holder and year established from repository evidence. Add
   root `CHANGELOG.md` with a `v0.2.0` section describing evidenced changes leading to
   that release, without claiming it has shipped or fabricating a release date.
3. **Version and metadata:** Reconcile both client manifests, catalogs, release
   metadata, helper version output, and current version documentation with spec 10's
   exact `0.2.0` product version and `v0.2.0` tag convention. Document the existing
   pre-1.0 SemVer policy and distinguish build SHA provenance from product version;
   preserve independent schema and protocol versions. Do not create a tag.
4. **Support and dependencies:** In current packaging documentation, declare Ubuntu
   22.04/24.04 x86-64 and macOS 14+ on Apple silicon and x86-64 where supported by the
   client, Bash 3.2+, Git 2.34+, jq 1.6+, Claude Code 2.1.216 and Codex CLI 0.144.6.
   Preserve spec 10's requirement for evidence before claiming newer clients supported.
   Inventory actual runtime and plugin dependencies, confirm whether M4 removed all
   external plugin dependencies, and document the result accurately, distinguishing
   client/system tools from plugins; resolve any remaining discrepancy rather than
   asserting zero without evidence.
5. **Terminology:** Search current documentation and plugin documentation for legacy
   `Task` terminology and replace references to agents with `Agent` where appropriate.
   Retain `Task` only for an actual compatibility alias or Orca API identifier, with
   context where needed; do not rewrite historical evidence or unrelated ordinary uses.
6. **Validation:** Extend `scripts/validate-repository.mjs` and
   `scripts/tests/repository-validation.bats` to require root `LICENSE` and
   `CHANGELOG.md` under `--all`. Check the complete canonical MIT license text with a
   nonempty copyright notice, and a nonempty `v0.2.0` changelog section with substantive
   entries. Add isolated fixture cases for valid files, absent files, altered license,
   missing version heading, and empty version section; ensure existing fixture setup
   provides conforming files. Errors must identify the offending file and condition.
7. **Finish:** Keep the total implementation net change at or below 200 LOC. If the
   inventory or required fixes exceed that bound, return the plan for rescoping rather
   than silently omitting discrepancies. Update the plan and index through the lifecycle
   in spec 03; obtain independent code evaluation and remote landing evidence as required.

## Verification

- For iteration: `bats scripts/tests/repository-validation.bats` exercises positive and
  negative packaging fixtures and existing repository-validation regression cases.
- Run `node scripts/validate-repository.mjs --root . --all` and `scripts/check` from the
  repository root; both must pass. Review the inventory and version surfaces against
  spec 10, including all remaining operational `Task` references and external plugin
  dependencies. Release matrix evidence remains a separate release prerequisite.

## Notes

None.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

# Evaluation: Reproducible local check and dual-platform CI baseline

Verdict: PASS
Round: 1
Reviewed against: approved specs 08 and 10; accepted ADRs 0018 and 0019;
repository improvement plan M0; approved dual-platform architecture research;
the current repository; prior verdict; exact revision diff `8495b84..1d46f27`;
current GitHub-hosted runner architecture labels; plan-evaluation rubric and
severity rules.

## Findings

Round-1 findings — all resolved (confirmed against the revision diff):

- [BLOCKER — RESOLVED] The required M0 static dual-client contract is now in this
  slice. The file scope and Steps 2–4 add both manifests/catalogs, the exact
  v0.2.0 release-owned compatibility matrix, its closed schema, both installed-root
  binding documents/schema, and release-owned metadata fixtures. The matrix records
  both exact client floors, all eight workflows, all five roles, `hook-wire-v1`,
  both root-binding references, and the literal approved profile map. Referential,
  schema, digest, release-provenance, semantic-drift, and real-tree checks make the
  static contract executable without misreporting it as install or behavior proof.

- [BLOCKER — RESOLVED] Malformed negative inputs can no longer poison the production
  scan. Every malformed JSON/JSON-Schema seed uses `.json.in`, malformed frontmatter
  uses `.md.in`, and allowlist overlays use `.allowlist.in`; tests materialize exactly
  one production-suffixed overlay only below a unique `mktemp -d` root and remove it
  in teardown. The plan mechanically asserts that the checked-in negative-source
  directory contains no eligible malformed `*.json` or shipped-frontmatter `*.md`,
  limits the real-tree candidate set to `git ls-files -z`, and requires a dedicated
  real-Git-root `--metadata` green test alongside the negative suite. Red-to-green
  proof and acceptance criteria repeat that coexistence explicitly.

- [BLOCKER — RESOLVED] The host/architecture and actual-shell matrix is now complete
  and reproducible. Step 8 requires Ubuntu 22.04 and 24.04 x86-64, macOS 14 arm64,
  and macOS 15 Intel x86-64, with pre-gate assertions for host, architecture, OS,
  physical shell, and `BASH_VERSION`. The current official hosted-runner table maps
  the chosen public-repository labels exactly that way. `scripts/run-bats-under`
  invokes the pinned Bats entrypoint with the selected absolute shell, controls
  `PATH` for every `#!/usr/bin/env bash` child, and exports the same absolute shell
  to every shipped-script test. A first-running canary verifies both the Bats process
  and an executable child report Bash 3.2.57 on both macOS architectures and Bash 5.x
  on both Ubuntu hosts. Missing or unavailable cells cannot pass or be allowed to
  fail.

- [MAJOR — RESOLVED] Link behavior now has an executable positive/negative regression
  suite. Temporary fixture trees cover valid targets and local/cross-file fragments,
  missing targets, bad fragments, exact historical-tree exclusions versus lookalike
  paths, malformed/duplicate/live/stale allowlist records, and code-block pseudo-links.
  The fixture suite is followed by the real-tree link gate.

No new BLOCKER, MAJOR, or MINOR findings.

## Required changes (for FAIL)

None — all Round-1 findings are resolved.

## Notes

Deferring live client behavior to the named `client-floor-adapter-smoke` slice is
consistent with the authority and does not prevent this baseline from being
independently green. ADR 0019 requires the exact-floor install/behavior matrix during
M0; it does not require every M0 obligation to land in one implementation slice.
Specs 08 and 10 distinguish the reproducible client-neutral/static gate from active
adapter and release-candidate evidence. This plan now makes that boundary unusually
clear: it neither calls M0 complete nor claims schema validity proves installation,
and it makes the later clean install/loading/invocation/cold-role/hook/profile/helper/
uninstall smoke release-blocking before M0 can close. Upgrade and fresh-clone evidence
remain correctly assigned to spec 10's release gate.

The revised slice stays independently executable and single-purpose: it establishes
the pinned local/CI baseline, migrates the existing shipped scripts and their tests to
the declared Bash runtime without product-logic changes, lands the minimum static
dual-client scaffolding needed by later adapters, and supplies mechanical proof for
each previously missing negative or cross-platform case.

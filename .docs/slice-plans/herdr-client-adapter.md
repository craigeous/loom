# Herdr client adapter

Status: Plan Review
Target specs: 00-overview.md, 10-packaging.md; ADRs 0018, 0027
Target size: <= 180 LOC net change (excluding tests and metadata)

## Context

M9 calls for a thin Herdr adapter to the shared Loom core. The existing matrix
maps five roles to three profiles, and the launcher and helper resolver enforce
client-specific contracts. The supplied authority does not specify Herdr's
manifest schema, minimum version, model identifiers, invocation API, or sandbox
capabilities. These are blocking contract inputs, not permission to guess: obtain
versioned Herdr primary documentation and an approved contract before development.
If that contract conflicts with an approved spec, stop for planner and cold plan
evaluation of a spec amendment; this plan cannot amend a spec.

## Out of Scope & Threat-Model Boundary

Native-app lifecycle hooks, identity and governance hooks, live installation or
release certification belong to later M9 slices. Do not change shared role policy,
other clients' behavior, or claim public support from fixtures. As in spec 00
Non-goals, a private directory is a trust boundary; hostile local inode swapping
and internal helper monkeypatching are not defended here.

## Steps

1. Before implementation, resolve and record in this plan, with versioned primary
   references, the Herdr plugin and marketplace schemas, minimum supported version,
   profile model/effort identifiers, role launch parameters, execution/return
   protocol, and sandbox/delegation controls. Specify exact manifest fields and
   launcher output/argv here, then submit the revised plan for cold evaluation.
   Stop if Herdr cannot enforce the required one-level, cold, non-delegating role
   boundary or if any required interface is undocumented. Do not invent a floor,
   flags, model IDs, schema, or assume Claude/Codex compatibility.
2. Add `plugins/loom/.herdr-plugin/plugin.json` and
   `.herdr-plugin/marketplace.json` using that pinned contract. Both identify Loom;
   the marketplace entry resolves to `./plugins/loom`. Add any schema fixture or
   validator required by the approved contract only if explicitly added to this
   file scope in a reviewed revision. Metadata must validate against the pinned
   Herdr schema and identify the same plugin and version as the root binding.
3. Add `plugins/loom/adapters/roots/herdr-plugin-root-v1.json`: schema
   `herdr-plugin-root/v1`, client `herdr`, binding `HERDR_PLUGIN_ROOT`, absolute
   input and invocation, canonical root and manifest
   `.herdr-plugin/plugin.json`, regular canonical manifest named `loom` version
   `0.2.0`, direct-child `bin`, and regular executable helpers restricted to
   `loom-coord`, `loom-verify-identity`, `loom-review`, `loom-eval-workspace`,
   `loom-doctor`, and `loom-profile`. Mirror the existing root descriptor's
   validation fields; no PATH or alternate-root fallback.
4. Extend `plugins/loom/adapters/compatibility/v0.3.0.json` with that root
   binding, the evidenced Herdr client floor, and explicit Herdr model/effort or
   equivalent fields for Economy, Standard and Deep review. Preserve existing
   consumers and mappings. Use the contract resolved in step 1; mapping values and
   schema changes must be written into this plan before implementation.
5. Extend `plugins/loom/bin/loom-resolve-helper` with
   `herdr <helper>` using `HERDR_PLUGIN_ROOT`, validating the canonical root,
   manifest identity/version, direct-child bin and allowlisted executable exactly
   as the Claude root path does. Fail closed on absent, relative, malformed,
   escaping, missing, or non-executable inputs; print only the absolute helper path
   on success. Retain existing clients and exit conventions.
6. Extend `plugins/loom/bin/loom-launch-role` for explicit `herdr` using the
   approved step-1 execution contract and matrix profile values. Preserve role
   mapping, fresh cold identity, `delegation:false`, one-level permissions and
   `LOOM_ROLE`; map tool sandbox and parameters to enforce that boundary. Reject
   unsupported model/effort or sandbox values and malformed arguments before any
   launch. Document exact emitted JSON and execution behavior in the revised plan;
   do not add Herdr to auto routing unless separately approved.
7. Add `scripts/tests/herdr-client-adapter.bats` (or update existing launcher and
   resolver Bats files) for every assertion below. No other files are in scope;
   stop and request a reviewed plan revision if schema, gate, or other files must
   change, or if the net production change exceeds the target.

## Verification

- Run targeted `bats scripts/tests/herdr-client-adapter.bats` (or the two updated
  existing Bats files), then `scripts/check` and
  `node scripts/validate-repository.mjs --root . --all`; all must exit 0.
- Validate both metadata documents against the pinned Herdr schema; assert the
  marketplace source is `./plugins/loom`, manifest name is `loom` and version is
  `0.2.0`, and the matrix floor, root ID/path, and all three profile mappings equal
  the exact values approved in step 1.
- Exercise all five roles: researcher selects Economy, developer Standard, and
  planner, plan-evaluator and code-evaluator Deep review. Assert each emitted
  Herdr parameter and sandbox value equals the approved contract, each cold ID is
  nonempty and differs across launches, delegation is false, and `LOOM_ROLE` is
  correct. A stub must capture exact argv/environment without a live client; invalid
  role, model, effort, sandbox and unsupported client fail before stub invocation.
- For each allowlisted helper, assert a valid absolute root returns its canonical
  absolute executable path. Assert nonzero exit and no path for unset/relative root,
  invalid JSON, wrong name/version, missing manifest, symlink escape for manifest,
  bin or helper, non-regular/non-executable helper, and unlisted helper. Test roots
  containing spaces. Existing Claude, Codex and Antigravity tests must pass unchanged.
- Stop on absent authoritative Herdr evidence, a failed gate, a capability mismatch,
  or a required change outside file scope; report the failure instead of weakening
  an assertion or presenting a fixture as live-client verification.

## Notes

Step 1 is a blocking clarification for a subsequent planner revision; the values
cannot be derived from the listed sources. Plan Review does not authorize coding
until those values are fixed and the revised plan passes cold evaluation.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft; Herdr contract evidence identified as a blocking input. |

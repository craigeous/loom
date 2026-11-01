# Herdr verification plan evaluation

Artifact: .docs/slice-plans/herdr-verification.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: 0f73e8b409429ca9fe49464e6ef113e8beebfb5a
Round: 0
Verdict: PASS

## Summary

The plan is 95 lines (budget <= 250) and states `Target size:`, an explicit
`## Out of Scope & Threat-Model Boundary`, and a `## Revision Log`. It cites spec 00 Non-goals
and keeps offline fixture evidence separate from live Herdr or native-app execution. Steps 1-4
are file-scoped, and the plan names the targeted and full-gate verification commands. It matches
the M9 `herdr-verification` acceptance criteria. The third criterion, an offline gate, is met.
The first two are scoped to Loom-side fixture evidence, and the plan says live proof stays
outstanding. Checks against the tree: the four existing Bats suites it lists exist, as do the
Herdr hook-wire fixtures (`pre-compact`, `pre-tool-use`), `.herdr-plugin/marketplace.json`, and
`loom-resolve-helper` support for `HERDR_PLUGIN_ROOT`. `scripts/check` enumerates tests with
`git ls-files -z -- '*.bats'` (line 525), so a tracked `scripts/tests/herdr-verification.bats`
is picked up automatically.

## Findings

- [MINOR] Step 4 and Verification: `scripts/check` fetches its pinned tools over the network.
  The plan notes the gate may provision tools separately, so the invariant holds. It still
  treats "network unavailable" as a property of the targeted suite alone and gives no mechanical
  way to prove it. The developer could add a cheap guard, such as a PATH stub for
  `curl`/`wget`/`nc` that fails, or an `rg` check that the new file contains no network
  invocations.
- [MINOR] Step 3: "Verify competing valid client roots fail closed" doesn't say which env vars
  collide (for example `HERDR_PLUGIN_ROOT` together with `CLAUDE_PLUGIN_ROOT`). The developer
  can read the hook source for this, so it is not blocking.
- [MINOR] The Verification section says the targeted `bats` runs need `TMPDIR=/private/tmp` on
  macOS, as in the project gate notes. The plan's commands omit it, and the full `scripts/check`
  command needs the same note.

No BLOCKER or MAJOR findings.

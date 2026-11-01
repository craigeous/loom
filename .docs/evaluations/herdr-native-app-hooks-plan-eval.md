# Plan evaluation — herdr-native-app-hooks

Artifact: .docs/slice-plans/herdr-native-app-hooks.md
Reviewed against: plugins/loom/skills/loom-playbook/references/plan-eval-rubric.md
Commit: 5ad484b
Round: 0
Verdict: FAIL

## Summary

The plan is well structured. It has the canonical sections, a `Target size:` budget, a threat-model boundary that cites spec 00, and it is 84 lines. It correctly gates implementation on a spec 08 amendment instead of editing the frozen spec. The fail-closed root-selection design (exactly one valid client root) fits the existing `_loom_hook_select_client` in `git-identity-guard.sh`.

It fails on one MAJOR finding: the Herdr hook wire contract is asserted without any upstream authority. The plan also omits the step that makes Herdr load the hooks at all. Two MINOR findings are listed for the revision.

## Findings

1. **[MAJOR] Herdr hook wire contract has no upstream authority.**
   - Step 1 fixes Herdr's wire as: allow is exit 0 with empty streams; block is exit 2, empty stdout, stderr `<reason>\n`. It applies this to both `PreToolUse` and `PreCompact`.
   - ADR 0029 covers manifest, root binding, matrix, helper resolution and launch. It says nothing about Herdr hook events, event names, payload shape, or block encoding.
   - The repository improvement plan (M9, lines 873-876) only says "implement lifecycle and event hooks compatible with Herdr's native app execution environment".
   - Nothing in the allowed reading set shows that Herdr emits `PreToolUse` or `PreCompact`, that its payloads match the normalized fields (`tool_input.command`, `trigger`, `session_id`), or that it honors exit 2 as a block.
   - Spec 08 says "No adapter may substitute another documented encoding" and requires exact current-event fixtures. The plan would freeze a guessed wire into a spec amendment and 24 byte-exact fixtures. The plan defers live verification to `herdr-verification`, so a wrong guess would pass the gate and fail only later.
   - Failure scenario: Herdr treats exit 2 as an ordinary hook error, or uses a different payload. The identity and write-ahead guards then silently do not block, while fixtures and docs claim a conformant adapter.
   - Fix: cite a research note or ADR 0029 amendment with sourced Herdr hook semantics (events, payload, block encoding, version floor). Alternatively state explicitly that the wire is a provisional assumption and say how it is validated. Make the spec amendment's authority that source.

2. **[MAJOR] Herdr hook loading and invocation environment are not in any step.**
   - Step 2 only changes `hooks.json` command strings to add `HERDR_PLUGIN_ROOT`. The plan never says how Herdr discovers `hooks/hooks.json`.
   - `plugins/loom/.herdr-plugin/plugin.json` contains no hooks reference (a grep for "hook" returns nothing).
   - Spec 10 has a Codex "root-relative `./hooks/hooks.json`" binding and says "Codex hooks ... hook-process-only `PLUGIN_ROOT`". Nothing equivalent exists for Herdr. The plan also does not say whether `HERDR_PLUGIN_ROOT` is injected into the hook process, as opposed to only skills and helpers (ADR 0029 §3).
   - An independent developer cannot tell whether the Herdr manifest needs a hooks pointer, whether `scripts/validate-repository.mjs` pins one the way it pins the Codex `hookManifest`, or whether the env var reaches the hook process.
   - Fix: add a file-scoped step (manifest field, root-binding schema or validator update if required). Alternatively cite the authority showing no manifest change is needed.

3. **[MINOR] Mirrored two-client enumerations are not listed.**
   - The Target specs list includes `10-packaging.md`, but no step amends it. Its "Installed-root and helper binding" section has only Claude and Codex hook binding text.
   - The `hooks.json` description and the `validate-repository.mjs` comment at ~line 608 say "both clients".
   - Project `CLAUDE.md` states "12-case (2 clients × 2 events × 3 outcomes; 48 fixture files)". This becomes 18 cases and 72 files, and the project rules require keeping that digest current.
   - `.bats` fixture enumeration (`git-identity-guard.bats:422-438`) hard-codes the fixture layout. Step 5's "adapt if needed" is vague.
   - Fix: name these touch points, or say explicitly that spec 10 is unchanged and why.

4. **[MINOR] Verification invariants are checkable by eye, and test breadth is large for the 180 LOC budget.**
   - "Existing Claude/Codex fixtures remain unchanged" should name a mechanical check, for example `git diff --exit-code <base> -- plugins/loom/hooks/fixtures/hook-wire-v1/{claude,codex}`.
   - The `hooks.json` quoting and root expression should be checked with `jq`. The "no remaining two-root-only selector" invariant should be checked with `rg`.
   - The required matrix (each pair, the triple, one valid among invalid roots, repeated across three scripts, plus space-in-path manifest execution) is heavy relative to the code change. Consider asserting the full matrix once, against one script's selector or a shared test helper, and keeping the others to smoke coverage (valid, invalid, block).

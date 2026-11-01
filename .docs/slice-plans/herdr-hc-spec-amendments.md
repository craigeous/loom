# Proposed spec amendments — Herdr as an hc-driven client

Status: Landed
Authority: ADR [0031](../ADR/0031-herdr-as-an-hc-driven-client.md) (Accepted)
Date: 2026-11-01

This is a **drafted diff for the plan evaluator**. Nothing here is applied. Specs 07,
08 and 10 are frozen (ADR 0005) and change only after this draft and ADR 0031 pass
cold plan evaluation. If ADR 0031 is not accepted, discard this file.

Target size: <= 90 changed spec lines. Scope: only text that mentions Herdr or must
change because Herdr is a host client rather than a plugin client.

## Out of Scope & Threat-Model Boundary

No code, schema, matrix or manifest edits (retirement is a later slice, ADR 0031 §7).
No claim that `hc` enforces blind review or delegation limits; both stay
defense-in-depth per spec 05 and `.docs/spec/00-overview.md` non-goals.

## Amendment A — `07-command-surface.md`

Add a new section after `## Role launch mapping`:

```diff
@@ ## Role launch mapping
 Claude launches one of five namespaced native role adapters: ...
 shared role contract. Neither surface exposes auxiliary finder workers as lifecycle
 commands; the orchestrator launches them only within `loom-local-review/v1`.
+
+## Host surfaces (Orca, Herdr `hc`)
+
+A **host** runs a role's inner client (`claude` or `codex`) in a persistent terminal;
+it is not a model client, plugin root or hook runtime. `loom-launch-role` emits the
+inner-client descriptor; a host adapter turns descriptor, worktree and brief into host
+commands. Host adapters are thin and add no policy.
+
+Herdr is driven only through the `hc` CLI (herdr-core; observed 0.1.16, with herdr-app
+0.1.11, not called by loom). Loom does not call `herdr-app do`, write Herdr config, ship a
+Herdr manifest, marketplace or mod, or install hooks through Herdr. The mapping is:
+
+| Loom input | `hc` form |
+|---|---|
+| role | `--name <role>-<opaque id>` (1–32 chars `a-z 0-9 - _`) |
+| inner client, model, effort | the program and flags in the command string; `codex` needs `--no-daemon` |
+| worktree | `--cwd <worktree>` |
+| `LOOM_ROLE` | `env LOOM_ROLE=<role> <program> …` |
+| brief | its own argv token, or `hc wait` then `hc send` |
+| readiness / completion | `hc wait` with a timeout, then read the committed artifact |
+| end of role | `hc kill` then `hc rm` |
+
+Behaviors identical on every host: cold fresh session (never `--resume`/`--continue`),
+only root delegates, no delegation capability, `LOOM_ROLE` set, handoff only through
+committed artifacts, bounded return, uniform commit identity. The artifact `Status:`
+is the dispatcher; terminal status (OSC 7501) and `hc wait` results are hints, and a
+wait timeout is reported as degraded, never as completion.
+
+Role support on `hc` is gated per role and client on owner-run live probes (ADR 0031
+§6) and is unsupported until recorded. Codex roles are not supported on `hc`: the
+current Codex launch is one-shot and read-only. Evaluator roles are not supported on
+`hc` until the blind-review requirement in spec 05 §Host isolation is resolved.
```

## Amendment B — `05-blind-evaluation.md` (consequential, not requested; needed to hold the §5 requirement)

```diff
+## Host isolation
+
+A host that lets processes under one account read each other's sessions cannot by
+itself keep an evaluator blind. For `hc` an evaluator launch MUST: use `--no-notify`;
+receive nothing derived from the author through `hc send`; be named `eval-<coldId>`
+with no labels and `--no-parent`; run in the ADR 0022 sanitized workspace; start only
+after every author-role terminal for the artifact is both killed and removed; and have
+all `hc` verbs denied by tool policy and the role-governance guard. These are
+necessary and not sufficient (the deny is evadable from Bash and the core socket has
+no per-client permission check). Evaluator roles therefore run on `hc` only after the
+owner records either account/socket isolation or an explicit degraded-blindness
+acceptance.
```

## Amendment C — `08-playbook.md`

```diff
@@ Authority list (line ~15)
-[0030](../ADR/0030-herdr-native-app-hooks.md).
+[0031](../ADR/0031-herdr-as-an-hc-driven-client.md).
@@ Hook normalization and output adapters
-Hook policy receives a normalized internal event. All three clients' current `PreCompact`
+Hook policy receives a normalized internal event. Claude's and Codex's current `PreCompact`
@@ wire table
-| Herdr `PreToolUse` | exit 0; empty stdout and stderr | exit 2; empty stdout; stderr `<reason>\n` |
-| Herdr `PreCompact` | exit 0; empty stdout and stderr | exit 2; empty stdout; stderr `<reason>\n` |
@@ conformance gate list (line 221)
-  and stderr results for all three clients and both supported events;
+  and stderr results for the `claude` and `codex` clients and both supported events;
@@ fixtures paragraph
-`claude`, `codex`, and `herdr`, events `pre-tool-use` and `pre-compact`, and cases
-`allow`, `block`, and `malformed`: 18 cases and 72 files across three clients.
-Conformance runs the same policy outcome through all three adapters and byte-compares
-all three outputs.
+`claude` and `codex`, events `pre-tool-use` and `pre-compact`, and cases
+`allow`, `block`, and `malformed`: 12 cases and 48 files across two clients.
+Conformance runs the same policy outcome through both adapters and byte-compares
+both outputs.
```

Also add, to the role-governance policy text of spec 08 where `LOOM_ROLE` guard rules
are specified (planner to locate the exact paragraph during revision): "For any
non-orchestrator `LOOM_ROLE`, every `hc` invocation is refused (deny by default, no
allowlist; covers `exec`, `label`, `keep`, `put`, `connect` and any later verb as well as
`run`, `send`, `kill`, `rm`, `keys`, `interrupt`, `attach`, `file`, `machine`, `server`,
`update`, and the read verbs); only the orchestrator calls `hc`. Defense in depth,
evadable, not a boundary."

## Amendment D — `10-packaging.md`

```diff
@@ Authority (line 14)
-[0030](../ADR/0030-herdr-native-app-hooks.md), informed by the
+[0031](../ADR/0031-herdr-as-an-hc-driven-client.md), informed by the
@@ Installed-root and helper binding (lines 167-169)
-- **Herdr hooks.** The manifest declares root-relative `hooks/hooks.json`; hook commands
-  may use Herdr's hook-process `HERDR_PLUGIN_ROOT` to invoke the shared hook dispatcher
-  absolutely.
+- **Herdr.** Herdr has no installed root, manifest, marketplace or hook binding. It is a
+  host driven through `hc` (spec 07 §Host surfaces); roles it launches resolve helpers
+  through their own client's root above. Herdr does not install, host or intercept hooks;
  Claude Code and Codex hooks keep running in their own plugin systems under the
  existing wires of spec 08.
@@ Versioned compatibility and capability mapping (append)
+The matrix records `hc` as a host with a floor of `0.1.16` (the only observed
+version) and does not floor herdr-app, which loom does not call. It carries no Herdr
+root binding and no per-profile Herdr entry. A host entry never changes the profile
+map; model and effort are carried in the inner client's command string.
```

## Steps (for the evaluator's checklist)

1. Confirm every amended line traces to an ADR 0031 decision (§1, §3, §4, §5, §7).
2. Confirm no amendment re-authorizes a plugin, manifest, hook-install or
   `HERDR_PLUGIN_ROOT` concept.
3. Confirm Amendment B/C extras are warranted or should be dropped to keep the diff to
   specs 07 and 10 only.
4. Confirm the parity claims name no Orca verb the repo does not define.

## Verification

After acceptance and merge by the planner: `rg -n -i "herdr" .docs/spec` must show only
the `hc` host text; `scripts/check` passes (docs, links, instruction invariants).

## Revision Log

- 2026-11-01 — Applied A, C, D to specs 07, 08, 10 (eaf1374). B (spec 05) not applied: outside owner scope.
- 2026-11-01 — initial draft.
- 2026-11-01 — Round 1 FAIL fixes: spec 08 line 221 amended; hook text no longer
  mentions Codex wiring; `hc` guard is deny-by-default; herdr-app wording neutral.
- 2026-11-01 — Round 2 FAIL fix (owner reading A): Herdr takes no part in hooks;
  Claude and Codex hook wires stay governed by spec 08. The two-client fixture set
  (12 cases / 48 files) only drops the retired Herdr fixtures.

# Herdr `hc` Client: Host Adapter, Deny Policy, Retirement, Live Probe

Status: Plan Review
Target specs: 07-command-surface.md (§Host surfaces), 08-playbook.md (hook wire, `hc` deny), 10-packaging.md (host floor, no Herdr root)
Authority: ADR [0031](../ADR/0031-herdr-as-an-hc-driven-client.md) (Accepted), `.docs/research/2026-11-01-hc-agent-runtime-reference.md`
Target size: <= 450 LOC added (deletions of retired Herdr files and fixtures are not counted); keep this plan <= 250 lines

## Context

ADR 0031 reframes Herdr as a host driven only through `hc`; the amended specs 07, 08
and 10 are applied. The tree still carries the retired plugin framing: two Herdr
manifests, the `herdr-plugin-root/v1` binding, `herdr` branches in `loom-launch-role`,
`loom-resolve-helper`, the three hook scripts, `hooks.json`, `validate-repository.mjs`,
the `v0.3.0` matrix and schemas, 24 `herdr` hook fixtures, and
`scripts/tests/herdr-verification.bats`. There is no `hc` code at all. This slice does
ADR §8 items 1–4 together (retire, host adapter, role-governance `hc` deny, stub-`hc`
tests; they share files) plus one cheap live probe.

Release state (ADR 0031 §7): no git tag, manifests say `0.2.0`, and the schema and
validator bind only `v0.2.0.json`, so `v0.3.0.json` is unreleased and is **edited in
place**; `v0.2.0.json` and its fixtures stay byte-identical.

## Out of Scope & Threat-Model Boundary

- **Codex on `hc`** and **evaluator roles (`plan-evaluator`, `code-evaluator`) on `hc`
  stay unsupported** (ADR 0031 §5, §6; spec 07 §Host surfaces). The adapter refuses
  them (exit 2). No Codex interactive contract is written here.
- **Blind-review sender-tag enforcement stays an explicit open item.** ADR 0031 §5
  resolves nothing beyond four necessary-not-sufficient items and a follow-up ADR
  (account/socket isolation or recorded degraded blindness). This slice adds no
  isolation, tag-stripping or screen-hiding mechanism. The only evaluator-facing
  change is that the `hc` deny (below) covers evaluator roles too.
- **Role support is not recorded.** The live probe verifies generic `hc` plus `claude`
  mechanics only. It does not answer Q4 (agent definition and `Agent` tool exclusion),
  Q5 (`HC_TERMINAL_ID`) or Q6 (parent lifetime). The adapter stays behind an explicit
  `LOOM_HC_UNVERIFIED=1` acknowledgement, so nothing is "supported" until a later
  owner-recorded slice flips it (ADR 0031 §6).
- No `herdr-app do`, Herdr config writes, mod, Herdr-installed hooks, GUI control,
  `hc` templates, machines or remote runs.
- `hc` does not enforce delegation limits; the deny is defense in depth, evadable via
  a wrapper or the core socket, not a boundary (spec 08; `00-overview.md` Non-goals).
- Herdr research, ADRs 0029/0030, archived plans and evaluations are kept as history.

## Steps

### A. Host adapter (new)

1. **`plugins/loom/bin/loom-host-hc`** (new, mode 755). `loom-launch-role` is unchanged
   as the descriptor source. Subcommands:
   - `launch --cwd <abs worktree> --brief-file <abs file>`: reads one
     `loom-role-launch/v1` descriptor line on stdin. Fails closed (exit 2) unless
     `LOOM_HC_UNVERIFIED=1`, `.client == "claude"` (codex descriptors refused),
     `.role` in `researcher|planner|developer`, `cold == true`, `delegation == false`,
     `permissions == "one-level"`, `claude.agentCapability == false`, `--cwd` is an
     existing absolute directory, and the brief is a regular file of 1..4096 bytes with
     no NUL. Name is `<role>-<first 12 chars of coldId, lowercased, non-[a-z0-9_-]
     removed>` and must match `^[a-z0-9_-]{1,32}$`. It runs, with the brief as its
     own argv token and no shell string:
     `hc run --bg --name <name> --cwd <cwd> env LOOM_ROLE=<role> claude --model <selector> <brief>`.
     It never passes `--resume`, `--continue`, `--outlive-parent`, labels or a template.
     Prints one JSON line (schema below) from `hc`'s `RunResult`. Model/effort ride in
     the command string only; Claude has no effort flag (spec 10).
   - `status <name>`: `hc get <name> --json`; prints compact
     `{"name","state","status","reported","exitCode"}` (absent fields `null`); read-only.
   - `wait <name> --timeout <1..3600>`: `hc wait <name> --timeout <S>`. `--timeout` is
     mandatory. hc exit 0 prints `returned: read the committed artifact` and exits 0;
     any nonzero hc exit prints `degraded: wait did not return (hc exit <n>); not completion`
     and exits 4. Neither result is completion; the artifact `Status:` is.
   - `events <name> --lines <1..500>`: `hc events --terminal <name>` truncated after N
     lines (pipe closed); read-only.
   - `end <name>`: `hc kill <name>` (hc exit 11 "finished" accepted) then `hc rm <name>`;
     then `hc ls --all --json` must not contain the name, else exit 2.
   - `hc` binary: `${LOOM_HC_BIN:-hc}` (PATH lookup; tests put a stub on PATH). Every
     name argument is validated against the name regex before any `hc` call. Any
     other verb or `hc` subcommand is not reachable. Exit codes: 0, 1 usage, 2
     fail-closed, 4 degraded wait.
2. **`plugins/loom/schemas/loom-host-hc-v1.schema.json`** (new): closed schema for the
   `launch` output `{"schema":"loom-host-hc/v1","host":"hc","name","address","role","coldId","cwd"}`.
   Register it wherever `validate-repository.mjs` enumerates schemas.
3. **`plugins/loom/bin/loom-resolve-helper`**: add `loom-host-hc` to `ALLOWED_HELPERS`,
   and to the `allowedHelpers` arrays in `scripts/validate-repository.mjs` and in
   `plugins/loom/adapters/roots/{claude-plugin-root-v1,codex-skill-source-v1}.json`,
   `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`; find every site
   with `rg -l loom-profile`. Fixtures under `adapters/fixtures/v0.2.0/` stay unchanged;
   if the check forces a conflict, stop and add a Note.

### B. Deny-by-default `hc` policy

4. **`plugins/loom/hooks/role-governance-guard.sh`**: after the existing de-quote
   transform and before the `case "$LOOM_ROLE"`, when `LOOM_ROLE` is non-empty and not
   `orchestrator`, block if `STRIPPED` matches
   `${START}((env|command|exec|nohup|time)[[:space:]]+)*${PATHPFX}hc([[:space:]]|$)`.
   No allowlist, no verb parsing (covers `run send kill rm keys interrupt attach file
   machine server update exec label keep put connect` and read verbs and later verbs).
   Reason (<= 512 bytes, one line): `Loom policy: hc is orchestrator-only; role sessions cannot call hc.`
   Quoted arguments are already stripped, so `git commit -m "hc run"` is allowed. Unset
   or empty `LOOM_ROLE` still fails open; `orchestrator` is unaffected. Update the
   header POLICY comment only.

### C. Retirement (ADR 0031 §7)

5. Delete: `.herdr-plugin/marketplace.json`, `plugins/loom/.herdr-plugin/plugin.json`,
   `plugins/loom/adapters/roots/herdr-plugin-root-v1.json`,
   `plugins/loom/hooks/fixtures/hook-wire-v1/herdr/` (24 files),
   `scripts/tests/herdr-verification.bats`. Before deleting the bats, list its tests
   that assert non-Herdr invariants (for example skills discoverable from the Claude
   manifest) and confirm another test covers each; port any uncovered one into its
   natural bats file.
6. **`plugins/loom/adapters/compatibility/v0.3.0.json`**: remove `clientFloors.herdr`,
   the `herdr-plugin-root/v1` root binding and the three per-profile `herdr` keys; add
   `"hostFloors": { "hc": "0.1.16" }` (no herdr-app floor, no host in `profiles`).
   `plugins/loom/schemas/loom-installed-root-binding-v1.schema.json`: remove the
   `herdr-plugin-root/v1` branch (lines ~95-102 plus the `oneOf` entry).
7. **`plugins/loom/bin/loom-launch-role`**: remove `herdr` from `CLIENTS`, `_usage`,
   `_valid_model`, the `herdr)` dispatch arm, and `_launch_herdr`; remove `herdr` from
   the `--author-client` accepted set. **`plugins/loom/schemas/loom-role-launch-v1.schema.json`**:
   drop the `herdr` oneOf branch and `herdr` from every `authorClient` enum.
8. **`plugins/loom/bin/loom-resolve-helper`**: remove `_resolve_herdr`, the `herdr)`
   arm and usage lines (header lines 17-19, 41, 172-182, 274-276).
9. **Hooks** (`git-identity-guard.sh`, `precompact-write-ahead-backstop.sh`,
   `role-governance-guard.sh`): drop the `HERDR_PLUGIN_ROOT` validation line, the
   `herdr` branch of `_loom_hook_select_client` (selection stays "exactly one valid
   root of Claude/Codex", else fail closed), and `herdr` from `claude | herdr | *)`
   in the block adapters. **`plugins/loom/hooks/hooks.json`**: commands use
   `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}`. Claude and Codex wires are unchanged.
10. **`scripts/validate-repository.mjs`**: remove the Herdr manifest paths (lines ~248,
    326-360, 377, 412, 532, 597-599), `validateHerdrMetadata` and its call, and Herdr
    entries in fixture-path enumeration; fixture expectation becomes 2 clients, 12
    cases, 48 files. **`scripts/validation/relative-link-allowlist.txt`**: touch only
    if the check demands (line 56 is a history link, kept).

### D. Tests (offline, stub `hc` on PATH)

11. **`plugins/loom/bin/loom-host-hc.bats`** (new): each test builds
    `$BATS_TEST_TMPDIR/bin/hc`, a stub that appends `"$@"` one arg per line to a log,
    prints canned JSON per verb, and exits per `STUB_*` variables; `PATH` is prefixed.
    Tests: launch argv is exactly the line sequence above (brief a single token, even
    with spaces, quotes and `$()`); `LOOM_ROLE` equals the role; no `--resume`,
    `--continue`, `--outlive-parent` or `--label`; refuses without
    `LOOM_HC_UNVERIFIED`; refuses codex descriptor, `plan-evaluator`,
    `code-evaluator`, `delegation:true`, `agentCapability:true`, relative cwd, empty,
    NUL, oversize brief, bad name; name length <= 32 and charset; `status` JSON
    shape and read-only argv (only `get --json`); `wait` requires `--timeout`, exit 0
    prints "returned", nonzero hc maps to exit 4 "degraded" and never prints
    "complete"; `events` truncates; `end` order is `kill` then `rm`, accepts kill
    exit 11, fails closed when the name remains in `ls --all`; only `run get wait
    events kill rm ls` ever appear in any stub log; `launch` output validates against
    the new schema.
12. **`plugins/loom/hooks/role-governance-guard.bats`**: add cases for each of the
    five roles plus an unknown role `foo`, Claude wire (exit 2, reason) and Codex wire
    (deny JSON): `hc ls`, `hc run --bg x claude`, `/usr/local/bin/hc kill t1`,
    `env A=1 hc get t1`, `command hc read t1`, `ls && hc send t1 x`, `nohup hc wait`.
    Allowed: `orchestrator` running `hc run ...`; unset `LOOM_ROLE`; `echo hc`,
    `git commit -m "hc run"`, `which-hc`.
13. **Retired-surface tests**: update `loom-launch-role.bats` (delete the `herdr`
    block at ~lines 600-640 and add: `herdr` client is a usage error;
    `--author-client herdr` rejected), `loom-resolve-helper.bats` (`herdr` is a usage
    error), the three hook bats files and `scripts/tests/repository-validation.bats`
    (remove Herdr cases; assert 2 clients / 12 cases / 48 files and absence of every
    retired path).

### E. Live probe

14. **`scripts/hc-live-probe`** (new, Bash 3.2, not run by `scripts/check`): refuses
    unless `LOOM_HC_LIVE_PROBE=1`; takes `--evidence-file <abs path>`; performs only the
    commands below and writes each command, exit code and output to the evidence
    file. It always cleans up (trap) once it launched a terminal.
    **`scripts/tests/hc-live-probe.bats`** (new) drives it with a stub `hc` through
    PASS, FAIL (no OSC status, wrong state, missing reply, kill failure, leftover name)
    and BLOCKED, checking the exact command sequence and cleanup.
15. **Probe run** (owner or an owner-authorized orchestrator step, after the offline
    gate is green; no GUI). Let `<id>` be 8 random lowercase hex digits; run from an
    empty scratch directory under `/private/tmp`:
    1. `hc --version` prints `0.1.16`; `hc ls --all` shows no `probe-<id>`.
    2. `hc run --bg --name probe-<id> claude "What is 37+5? Reply with only the number, then stop. Use no tools."`
    3. `hc wait probe-<id> --timeout 120`
    4. `hc get probe-<id> --json`
    5. `hc read probe-<id> --lines 60`
    6. `hc kill probe-<id>`, then `hc rm probe-<id>`, then `hc ls --all`.
16. **Docs (finalize pass)**: `CLAUDE.md` Map: fixture line becomes "12-case (2 clients
    × 2 events × 3 outcomes; 48 fixture files at 4/case)", add `loom-host-hc` to the
    `bin/` list, stay <= ~100 lines. `.docs/status/` (roadmap M9, progress, handoff):
    items (1)–(4) landed, `hc` roles still "designed, unverified"; the probe result is
    recorded as evidence, not role support. Update `.docs/slice-plans/README.md`.

## Acceptance Criteria

1. `loom-host-hc launch` produces exactly the `hc run` argv in Step 1 for researcher,
   planner and developer on Claude, and refuses everything else listed in Step 1
   without invoking `hc`.
2. Observation calls only `hc get|wait|events`; a wait that does not return is
   `degraded` (exit 4), never completion.
3. Every `hc` command is blocked by the role-governance guard for every non-orchestrator
   `LOOM_ROLE` on both wires and allowed for `orchestrator`.
4. `rg -n -i "herdr" plugins scripts .claude-plugin .agents` finds nothing; no retired
   path exists; `HERDR_PLUGIN_ROOT` appears nowhere outside `.docs/`.
5. `hook-wire-v1` has exactly 12 cases, 48 files; Claude/Codex fixtures are byte-identical.
6. `v0.2.0.json` and `adapters/fixtures/v0.2.0/` are unchanged; `v0.3.0.json` has
   `hostFloors.hc == "0.1.16"` and no Herdr key.
7. `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` passes on the candidate
   commit, including format, lint, syntax, metadata, links and client validation.
8. The live probe result is recorded as PASS per the criteria below.

### Probe pass and fail criteria

All must hold for **PASS**; the evidence file records each:

- P1 `hc --version` is `0.1.16` and `probe-<id>` was absent before launch.
- P2 `hc run` exits 0, returns an address, and the run result has no `first_message`
  (Q3: positional prompt, tracking unset).
- P3 `hc wait` exits 0 within 120 s (Q1: the session reported OSC 7501 and left
  `working`).
- P4 `hc get --json`: `name == "probe-<id>"`, `reported == true`, status state is `done`
  or `idle`, `foreground.argv` contains no `--resume` or `--continue` and contains the
  prompt as one token.
- P5 `hc read` output has a line, not containing `37+5`, with `42` as a standalone token.
- P6 `hc kill` and `hc rm` each exit 0 (kill may exit 11 if already finished) and the
  final `hc ls --all` has no `probe-<id>`.

**FAIL**: any of P1–P6 unmet (except BLOCKED). A wait timeout or `reported == false`
records Q1 = no (no OSC status at launch). **BLOCKED (inconclusive, not PASS)**: `hc get`
shows `blocked` (for example a folder-trust or auth prompt); the owner pre-trusts the
scratch directory and reruns; the probe never sends keys or `--force` past a prompt.
Cleanup (P6) runs for every outcome. A PASS covers only generic `hc` + Claude
mechanics (Q1, Q3, launch/read/kill); it records no role as supported.

## Verification

- Iteration: `shfmt -i 4 -d` and `shellcheck -s bash` on `loom-host-hc` and
  `scripts/hc-live-probe`, then `TMPDIR=/private/tmp bats` on `loom-host-hc.bats`,
  `role-governance-guard.bats`, `scripts/tests/hc-live-probe.bats` and the Step 13 files.
- Regression proof (unchanged and passing): Claude/Codex hook fixtures, `loom-profile.bats`,
  the Claude/Codex halves of `loom-launch-role.bats` and `loom-resolve-helper.bats`.
- Full gate once on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
- Then the live probe (Step 15) and its evidence summary in `progress.md`.

## Notes

- Evaluator question: is `LOOM_HC_UNVERIFIED=1` an acceptable fail-closed form of
  "unsupported until probes are recorded" (ADR 0031 §6)? The ADR names no mechanism;
  the flip is left to a later owner-recorded slice.
- The `hc wait` timeout exit code is undocumented; every nonzero exit is degraded.
- Flags to load `agents/<role>.md` or drop the `Agent` tool in an interactive session
  are unresolved (Q4); the adapter passes `--model` only, so ADR §6 non-delegation stays
  open. That is why launch is gated.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

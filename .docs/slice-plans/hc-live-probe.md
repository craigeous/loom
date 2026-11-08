# Herdr `hc` Client (3 of 4): Generic Live Probe

Status: Landed
Un-shelved: 2026-11-08 per ADR 0034 §5 (Accepted) — requirements below unchanged; review history kept.
Target specs: 07-command-surface.md (Host surfaces, probes before role support), 08-playbook.md
Authority: ADR 0031 §6 (Accepted)
Target size: <= 260 LOC added (script + Bats; deletions not counted); keep this plan <= 250 lines

## Context

ADR [0031](../ADR/0031-herdr-as-an-hc-driven-client.md) §6 and spec 07 require live
probes of the real `hc` before any role may run on it. Open questions in the
[hc runtime reference](../research/2026-11-01-hc-agent-runtime-reference.md): Q3 (prompt
delivery), Q4 (role agent definition), Q5 (`HC_TERMINAL_ID`), Q6 (parent lifetime), Q1
(status at launch). This slice adds one cheap, **generic** probe script and its offline
tests, and records one real run as evidence. It needs no code from slices 1, 2 or 4;
the run itself happens only after this slice's own offline gate is green.
The v0.3.0 matrix registration (`hostFloors.hc`, floor `0.1.16`) is owned by slice 2
(`hc-host-adapter`); this slice does not read or edit the matrix. Codex roles and
evaluator roles on `hc` stay unsupported.

The probe is not a role launch: it uses a throwaway Claude session with no role, no
`LOOM_ROLE`, no loom agent file. A PASS says only that generic `hc` + Claude
mechanics work (Q3, launch/read/kill, a status report after a turn, the
`--disallowedTools` flag). It records no role as supported and does not enable one.

## Out of Scope & Threat-Model Boundary

- **No role launch, no role definition (Q4), no `HC_TERMINAL_ID` (Q5), no parent
  lifetime (Q6).** Those stay open and gate any later role slice.
- **Open gates (retained, unresolved):** blind review through `hc` is an owner decision pending a follow-up ADR (ADR 0031 §5 and Consequences); the probe does not enforce blind review, and no evaluator role runs on `hc` until that ADR records isolation or explicit degraded blindness. A PASS here never lifts either gate.
- **Q1 (status at launch) is not answered.** A wait that returns after a prompt was
  sent proves only that a report arrived by then. A timeout or `reported == false`
  is recorded as "no report observed within 120 s", cause undetermined; a pre-turn
  observation is a separate later probe.
- The script never sends keys, uses `--force`, or answers a prompt. `blocked` is
  BLOCKED (inconclusive), never PASS. No GUI, no `herdr-app`.
- The probe and its evidence are **not** release conformance or public support
  (`CLAUDE.md`: private dogfood is not public support). Not run by `scripts/check`.
- `hc` enforces nothing about blind review (spec 08; `00-overview.md` Non-goals).

## Steps

1. **`scripts/hc-live-probe`** (new, mode 755, Bash 3.2). Refuses (exit 2) unless
   `LOOM_HC_LIVE_PROBE=1` and `--evidence-file <absolute path>` is given (the caller
   chooses `/private/tmp/hc-probe-evidence/<id>.txt`; parent directory created
   `0700`). It performs only the commands in Step 3 and appends each command, exit
   code and output to the evidence file. After it launches any terminal, an `EXIT`
   trap runs `hc kill` then `hc rm` for each probe name and then `hc get <name>`, which
   must exit 3 (not_found). Model selector is the constant `claude-haiku-5-5`, passed as
   `--model` in both runs. `<id>` is 8 random lowercase hex digits; names are
   `probe-<id>` and `probe-nd-<id>`. Binary `${LOOM_HC_BIN:-hc}`. Exit codes: 0
   PASS, 1 FAIL, 2 refused/usage, 3 BLOCKED. It runs in an empty scratch directory
   under `/private/tmp` and `cd`s into it before launching.
2. **Judging**, in the script (jq over `hc get --json` and `hc read`), exactly the
   P1–P7 criteria under *Pass and fail criteria*; the final evidence line is
   `RESULT PASS|FAIL|BLOCKED` plus the failed criterion ids.
3. **Command sequence** (stub tests assert it verbatim, including the model):
   1. `hc --version` prints `0.1.16`; `hc get probe-<id>` and `hc get probe-nd-<id>`
      both exit 3 (names absent). (`hc ls --all` rows carry no `name`.)
   2. A (liveness): `hc run --bg --name probe-<id> claude --model claude-haiku-5-5
      "What is 37+5? Reply with only the number, then stop. Use no tools."`
   3. `hc wait probe-<id> --timeout 120`, `hc get probe-<id> --json`, `hc read probe-<id> --lines 60`.
   4. B (non-delegation): `hc run --bg --name probe-nd-<id> claude --model
      claude-haiku-5-5 --disallowedTools Agent "If you have a tool named Agent, call it
      once with the prompt 'say hi'. If you do not have it, reply with only
      TOOL_ABSENT, then stop."`
   5. `hc wait probe-nd-<id> --timeout 120`, `hc get probe-nd-<id> --json`, `hc read probe-nd-<id> --lines 60`.
   6. Cleanup (trap) for each name as in Step 1.
4. **`scripts/tests/hc-live-probe.bats`** (new). A stub `hc` on `PATH` (call log, canned
   JSON, `STUB_*` exits) drives: refusal without `LOOM_HC_LIVE_PROBE=1` or without an
   absolute evidence path (log empty); PASS; FAIL for each of: no report (`reported
   false`), wrong `status.state`, missing `42`, `37+5` echoed only, `--resume` in argv, missing
   `--model claude-haiku-5-5`, Agent tool present (a sub-agent line in the read),
   `kill` failure, name still present after cleanup (`hc get` exit 0); BLOCKED when
   `hc get` shows `blocked` (and no keys or `--force` appear in any log); cleanup runs
   on every outcome including a mid-run signal; the exact command sequence including
   `--model claude-haiku-5-5` in both runs; only `get run wait read kill rm --version` appear.
5. **Probe run** (owner, or an owner-authorized orchestrator step, only after the
   candidate commit's full gate is green; no GUI): `LOOM_HC_LIVE_PROBE=1
   scripts/hc-live-probe --evidence-file /private/tmp/hc-probe-evidence/<id>.txt`.
   On BLOCKED the owner pre-trusts the scratch directory and reruns. Record the
   result (PASS/FAIL/BLOCKED, the evidence path, criterion ids) as private evidence
   in `.docs/status/progress.md` (orchestrator-owned on `main`); `hc` roles stay
   "designed, unverified".
6. **Docs (finalize pass)**: no `CLAUDE.md` change unless the Map must list the script
   (one clause; stay <= ~100 lines). `.docs/slice-plans/README.md` index.

## Pass and fail criteria

All must hold for **PASS**; the evidence file records each:

- P1 `hc --version` is `0.1.16`; both probe names were absent before launch.
- P2 Both `hc run` calls exit 0, return an address, and have no `first_message`
  (Q3: positional prompt, delivery untracked).
- P3 Run A `hc wait` exits 0 within 120 s (a report arrived by then; nothing about
  launch status).
- P4 Run A `hc get --json`: `name == "probe-<id>"`, `reported == true`, `status.state` is `done`
  or `idle` (the reported-status object, research §4; the top-level terminal `state` is a
  different field and stays live for an interactive session, so it is not judged), `foreground.argv` has `--model` followed by `claude-haiku-5-5`, no
  `--resume` or `--continue`, the prompt as one token.
- P5 Run A `hc read` has a line, not containing `37+5`, with `42` as a standalone token.
- P6 Run B `hc get --json` matches P4 for `probe-nd-<id>` (argv also contains
  `--disallowedTools` and `Agent`), and `hc read` has a line equal to `TOOL_ABSENT`
  and no sub-agent launch or result line (generic tool-restriction evidence for the
  Claude CLI flag only; no role's agent definition is validated).
- P7 Each `hc kill` and `hc rm` exits 0 (kill may exit 11 if already finished) and
  `hc get <name>` exits 3 for both names.

**FAIL**: any of P1–P7 unmet, except BLOCKED. **BLOCKED (inconclusive, not PASS)**:
`hc get` shows `blocked` (for example a folder-trust or auth prompt). Cleanup (P7)
runs for every outcome.

## Verification

- Iteration: `shfmt -i 4 -d -ln bash`, `shellcheck -s bash`, `bash -n` on
  `scripts/hc-live-probe`; `TMPDIR=/private/tmp bats scripts/tests/hc-live-probe.bats`.
- No real `hc` and no Claude session is started by any test (stub only).
- Full gate once on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
  Only the known unrelated `INT during a mutation yields exit 130` dogfood race may
  be recorded and rerun once (owner-declared out of scope); any other failure blocks.
- Then Step 5 (live run) and its evidence summary; the slice's code review does not
  depend on the live result, which is recorded as evidence, not support.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 2 | Plan-eval round 2 (MINOR): matrix ownership stated (slice 2 owns v0.3.0 `hostFloors`); Codex/evaluator roles unsupported |
| 1 | Plan-eval round 1: P4/P6 judge `status.state` (research §4), not terminal `state`; blind-review and evaluator-exclusion listed as open gates |
| 0 | Split from `herdr-hc-client` (owner decision): probe only; absence/cleanup checked with `hc get` not_found (not `hc ls --all`); evidence path named; model constant kept; Q1 not claimed |

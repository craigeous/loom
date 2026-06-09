# Gate Learning (Unknown Stack)

The mechanism the orchestrator runs when an init body encounters a stack with
no known `gates/<stack>.md` — i.e. any stack other than the verified Rust gate.

Authority: [`../../../../../.docs/spec/06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md)
*Gate establishment* (2nd + 3rd bullets).
Spec `06-init-modes.md` wins on any conflict.

Precondition: an init body (Greenfield Step E / Unaligned Step 2 / Initialized
re-application) has detected a non-Rust or otherwise unknown stack and has not
found a corresponding `gates/<stack>.md` in the playbook. The **verified Rust
gate** (`Cargo.toml` at repo/workspace root → [`../gates/rust.md`](../gates/rust.md))
short-circuits this body entirely — gate-learning only runs for stacks the
playbook does not yet know.

---

## Step 1 — Inspect the toolchain (read-only)

Inspect the project's existing tooling to discover what format, lint, and test
tooling is already in use. This step is **read-only** — no files are written yet.

If an Unaligned Step 1 survey has already run in this session, reuse its findings
(see [`unaligned.md`](unaligned.md) Step 1) rather than re-surveying.

Concrete signals to enumerate, by category:

**Package manifests and script blocks:**
- `package.json` — look at the `scripts` block for `format`, `lint`, `test`
  entries and the `devDependencies` for tooling (prettier, eslint, jest, vitest,
  mocha, etc.)
- `pyproject.toml` / `setup.cfg` / `tox.ini` — tool sections for black/ruff/flake8/pytest
- `Cargo.toml` — Rust; short-circuits to the verified gate (do not reach this step)
- `go.mod` — Go; look for `gofmt`/`golangci-lint`/`go test` conventions
- `Gemfile` — Ruby; look for rubocop, rspec, minitest

**Build files and task runners:**
- `Makefile` — scan targets named `fmt`, `format`, `lint`, `test`, `check`, `ci`
- `justfile` — same target names
- `Taskfile.yml` — task definitions for format/lint/test

**CI definitions (reveal what the project actually runs):**
- `.github/workflows/*.yml` — look for steps named format/lint/test; these are
  ground truth for what the CI enforces
- `.gitlab-ci.yml` — job definitions for the same
- `circle.yml` / `.circleci/config.yml`, `Jenkinsfile`, etc.

**Goal:** identify the project's *existing* tooling rather than inventing it.
Prefer a tool the project already uses over the "conventional default" for the
stack. If CI definitions exist, they are the most authoritative signal.

---

## Step 2 — Propose `format → lint → test` commands

From Step 1's findings, produce **one concrete command per gate step** in order:
`format → lint → test`. The gate always has all three steps — never drop a step.

**Worked examples (illustrative — the actual commands come from the real project's
tooling, not these defaults):**

| Stack  | format                              | lint                  | test           |
|--------|-------------------------------------|-----------------------|----------------|
| Node   | `npm run format` (or `prettier --check .`) | `npm run lint` (or `eslint .`) | `npm test` |
| Python | `ruff format --check .` (or `black --check .`) | `ruff check .` (or `flake8`) | `pytest` |
| Go     | `gofmt -l .` (exit non-zero if any output) | `golangci-lint run` | `go test ./...` |
| Ruby   | `rubocop --no-color` (format mode)  | `rubocop`             | `bundle exec rspec` |

These are **illustrative only** — do not use them as defaults without first
finding the real commands in Step 1. Flag every command sourced from a convention
rather than from the project's own config, so the owner knows which ones to
confirm carefully.

**If a gate step has no discovered tool:** propose the conventional tool for that
stack, mark it clearly as unverified (e.g. "no formatter found — proposing
`prettier --check .`, pending owner confirmation"), and present it to the owner in
Step 3. Never silently drop a gate step. The gate is always `format → lint →
test` per spec `08` and root `CLAUDE.md`.

---

## Step 3 — Confirm with the owner (owner-gated)

This step is **owner-gated** — the orchestrator presents the proposed commands and
the owner approves or adjusts them before anything is recorded as live.

The orchestrator presents:
1. The proposed `format → lint → test` command table.
2. For each command sourced from convention (not found in the project's own config),
   a note flagging it as unconfirmed.
3. A prompt for the owner to approve the table as-is, adjust individual commands,
   or replace any command entirely.

**loom never auto-adopts an unverified gate as live.** Until the owner confirms
the commands, the proposal is just that — a proposal. The init body may have
already recorded a marked-UNVERIFIED placeholder in the project `CLAUDE.md` (the
placeholder the init bodies write before gate-learning runs); that placeholder
is the UNVERIFIED entry state of this lifecycle, not a permanent state. It is not
treated as a live gate by any role.

The orchestrator owns all owner-facing prompts (consistent with how the other init
bodies hand back to the orchestrator for owner decisions).

---

## Step 4 — Run green once → flip UNVERIFIED to verified

A proposed and owner-confirmed gate is still **UNVERIFIED** until it runs.

**State machine (explicit):**

```
proposed → (owner-confirmed) → UNVERIFIED → (runs green once) → verified/recorded
```

**Run the confirmed commands:**

loom runs the confirmed `format → lint → test` sequence on the real project. All
three steps must pass (green). Run them in order; stop at first failure.

**If all three pass (green):** the gate is now trusted. Proceed to Step 5 to
record it.

**If any step fails (non-green):** the gate stays UNVERIFIED. Do **not** record a
non-green gate into the playbook. Loop back to Step 2/3 with the owner: show which
step failed, propose an adjusted command, re-confirm, re-run. Repeat until green
or the owner explicitly decides to skip gate-recording for this project.

The run-green-once requirement is spec `06` 3rd bullet: "a detected-but-unverified
gate is marked as such until it has actually run green at least once." Recording a
gate that has never run green would bypass the verification step this mechanism
exists to enforce.

---

## Step 5 — Record the gate in two places

After a green run, record the verified gate in both locations:

### Project `CLAUDE.md`

Write the confirmed `format → lint → test` commands into the project's Gate
section, replacing any UNVERIFIED placeholder the init body recorded earlier.
The Gate section format matches the Rust example: a table with `format / lint /
test` rows and their commands.

### Playbook `gates/<stack>.md`

Record the new gate file using the **same shape as
[`../gates/rust.md`](../gates/rust.md)** — that file is the format template.
Required fields to mirror:

- **`# Gate: <Stack>`** title (e.g. `# Gate: Node`)
- **`Status: Verified`** — set to Verified because recording only happens
  post-green (Step 4 ensures this; a non-green gate is never recorded)
- **`Detected by:`** the detection signal (e.g. "a `package.json` at the repo
  root")
- **The `format / lint / test` command table** — the same three-column format
  as `rust.md`
- **Notes section** — carry forward the generalizable notes from `rust.md`:
  the code evaluator **re-runs** this gate and does not trust the recorded result.
  Add any stack-specific notes (e.g. "run from the workspace root," "requires
  `node_modules` installed").

**The payoff (spec `06` + spec `08` Gate learning):** once `gates/<stack>.md` is
recorded, the next project on that stack is detected and inherits this gate via
the normal verified-gate path — loom learns gates over time. The gate-learning
mechanism does not need to run again for that stack.

---

## Idempotence / scope note

Re-running gate-learning on a stack that now **has** a recorded `gates/<stack>.md`
is a no-op for the learning path — that stack is now a known gate and takes the
verified-gate path in the init body (same short-circuit that applies to
`../gates/rust.md`). Gate-learning never clobbers a confirmed gate that is already
recorded in the project `CLAUDE.md` (never-clobber, consistent with
`initialized.md` re-application).

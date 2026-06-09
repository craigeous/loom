# Gate-learning for unknown stacks

Status: In Progress
Target specs: 06-init-modes.md (Gate establishment, 2nd + 3rd bullets), 08-playbook.md (Gate learning)

## Context

M2's per-mode init trio (Greenfield, Unaligned, Initialized) has all landed. Each
body handles a **verified Rust gate** directly, but for **any other / unknown
stack** it stops at a marked-UNVERIFIED placeholder and forward-points at a
"forthcoming / deferred *gate-learning* slice." This is the last remaining M2
behavior.

Spec `06-init-modes.md` *Gate establishment* (2nd bullet) makes gate creation for
an unknown stack an **init responsibility**: loom inspects the project's tooling,
proposes `format → lint → test` commands, confirms with the owner, writes the
commands into the project's `CLAUDE.md`, and **records the new gate back into the
playbook** (`gates/<stack>.md`) so the next project on that stack inherits it —
"loom *learns* gates over time." The 3rd bullet adds the lifecycle invariant: a
detected-but-unverified gate is **marked as such until it has actually run green
at least once.**

There is currently **no authoritative body** that defines this mechanism — only
forward pointers. This slice delivers the single authoritative body and repoints
the three init references at it.

**What exists today (verified against the tree):**

- `plugins/loom/skills/loom-playbook/gates/rust.md` is the only gate, `Status:
  Verified`; its line 21 already says "New stacks get a gate created during init
  and recorded as `gates/<stack>.md`." This file is the **format template** a
  learned gate must match.
- Forward pointers to repoint:
  - `references/greenfield.md` Step E (lines 105–116): "deferred gate-learning
    procedure … not implemented here … the subject of the follow-up *gate-learning*
    slice."
  - `references/unaligned.md` Step 2 (lines 60–67): "learn-a-new-gate path, which
    is a **deferred** slice … the subject of the forthcoming *gate-learning*
    slice" (also a passing mention at line 149).
  - `references/initialized.md` (lines 94–110): "defers gate *learning* to the
    deferred gate-learning slice" and the scope-boundary note "remains a forward
    pointer (deferred *gate-learning* slice)."
- `SKILL.md` References list (lines 43–58) has no `gate-learning.md` entry; its
  Gates section (lines 59–64) describes the unknown-stack flow inline but points
  at no body.
- Root `CLAUDE.md` Gate section says "for other stacks, loom identifies and
  creates the gate during init and records it back into the playbook" but names no
  body; the Repo layout section lists each init body but not gate-learning.

**In scope:** author `references/gate-learning.md`; repoint the three init bodies'
forward pointers; add the reference to `SKILL.md`; note the body in root
`CLAUDE.md`.

**Out of scope (explicit):**

- **Editing `.docs/spec/` or `.docs/ADR/`.** This slice is playbook-only; the spec
  already authorizes the mechanism.
- **Authoring a concrete learned gate** (e.g. `gates/shell.md` for `shellcheck`).
  See the decision below.
- Changing the verified-Rust path in any init body (it already works).

### Decision: `gates/shell.md` is a follow-up, not part of this slice

This slice ships the gate-learning **mechanism only**, single-purpose. A concrete
first learned gate (`gates/shell.md` for `shellcheck`) is **deferred to an explicit
follow-up**, recorded in `status/handoff.md` (it is already noted there as a
deferred candidate). Rationale: (a) single purpose — the mechanism and a concrete
gate are two distinct goals; (b) reviewability does **not** require shipping a
real gate, because `gates/rust.md` already serves as the shape template the
mechanism cites, so an evaluator can check the "recorded gate matches rust.md
format" obligation against the existing file; (c) a genuinely-learned gate should
be produced by *running* the mechanism on a real shell-stack project (run-green-
once is part of the lifecycle), not hand-authored alongside the mechanism, which
would bypass the very verification step this body defines.

## Steps

1. **Create `plugins/loom/skills/loom-playbook/references/gate-learning.md`** — the
   single authoritative gate-learning body. Match the structure/voice of the
   sibling reference bodies (`greenfield.md`, `unaligned.md`, `initialized.md`):
   a title, an authority line citing spec `06` Gate establishment (2nd + 3rd
   bullets) and stating the spec wins on conflict, a precondition, then ordered
   steps. Contents, with each spec-06 obligation mapped to a concrete step:

   - **Header / authority.** Authority line:
     `[../../../../../.docs/spec/06-init-modes.md](../../../../../.docs/spec/06-init-modes.md)`
     *Gate establishment* (2nd + 3rd bullets). State: spec `06` wins on conflict.
     (Match the relative depth used by `greenfield.md` line 6 — verified five
     `../` segments from `references/` to repo root.)

   - **When this runs.** Invoked from an init body (Greenfield Step E / Unaligned
     Step 2 / Initialized re-application) **when the detected stack has no known
     `gates/<stack>.md`** — i.e. anything other than the verified Rust gate. The
     verified-Rust path short-circuits this body (cite `../gates/rust.md`).

   - **Step 1 — Inspect the toolchain** (spec-06 2nd bullet, "inspects the
     project's tooling (config files, scripts, CI)"). Read-only. Enumerate concrete
     signals to look for, with examples spanning stacks so a future Node/Python run
     can follow it: package manifests + script blocks (`package.json` `scripts`,
     `pyproject.toml` / `setup.cfg` / `tox.ini`, `Cargo.toml`, `go.mod`,
     `Gemfile`), build files (`Makefile` targets, `justfile`, `Taskfile.yml`), and
     CI definitions (`.github/workflows/*.yml`, `.gitlab-ci.yml`, etc.). Goal:
     identify the project's existing format / lint / test tooling rather than
     inventing it. Note: reuse the Unaligned Step 1 survey when one already ran
     (cite `unaligned.md` Step 1) instead of re-surveying.

   - **Step 2 — Propose `format → lint → test` commands** (spec-06 2nd bullet,
     "proposes the format/lint/test commands"). Produce one concrete command per
     gate step in that order, drawn from Step 1's findings. Give worked examples
     for at least two stacks to make it concrete, e.g.:
     - Node: `npm run format` (or `prettier --check .`) → `npm run lint` (or
       `eslint .`) → `npm test`.
     - Python: `ruff format --check .` (or `black --check .`) → `ruff check .` (or
       `flake8`) → `pytest`.
     Mark these as **illustrative** — the actual commands come from the real
     project's tooling, not these defaults. If a step has no tool, say how to
     handle it (propose the conventional tool for the stack and flag it for owner
     confirmation; never silently drop a gate step — the gate is always
     `format → lint → test`, per spec `08` and root `CLAUDE.md`).

   - **Step 3 — Confirm with the owner (owner-gated).** (spec-06 2nd bullet,
     "confirms with the owner.") State explicitly: this is **owner-gated** — the
     orchestrator presents the proposed commands and the owner approves/adjusts.
     loom **never auto-adopts an unverified gate as live**. Until confirmed, the
     proposal stays a marked-UNVERIFIED placeholder (the same placeholder the init
     bodies already record). Cross-reference that the orchestrator owns
     owner-facing prompts (consistent with the other init bodies handing back to
     the orchestrator).

   - **Step 4 — Run green once → flip UNVERIFIED to verified** (spec-06 3rd bullet,
     "a detected-but-unverified gate is marked as such until it has actually run
     green at least once"). Make the lifecycle **explicit**:
     - A proposed/confirmed gate is **UNVERIFIED** until it runs.
     - loom runs the confirmed `format → lint → test` sequence on the **real
       project**; all three must pass (green).
     - Only after a green run does the gate become trusted; record it. If it does
       not pass, it stays UNVERIFIED and loops back to Step 2/3 with the owner (do
       not record a non-green gate into the playbook).
     - State the state machine plainly: `proposed → (owner-confirmed) →
       UNVERIFIED → (runs green once) → verified/recorded`.

   - **Step 5 — Record the gate in two places** (spec-06 2nd bullet, "writes them
     into the project's `CLAUDE.md`" + "records the new gate back into the playbook
     so the next project on that stack inherits a known gate"):
     - **Project `CLAUDE.md`:** write the confirmed `format → lint → test` commands
       into the project's Gate section (replacing any UNVERIFIED placeholder the
       init body recorded).
     - **Playbook `gates/<stack>.md`:** record the new gate using the **same shape
       as [`../gates/rust.md`](../gates/rust.md)** — cite it as the format
       template. Required fields to mirror: a `# Gate: <Stack>` title; a `Status:`
       line (`Verified` once it has run green, since recording only happens
       post-green per Step 4); a `Detected by:` signal (e.g. "a `package.json` at
       the repo root"); the ordered `format / lint / test` command table; and a
       Notes section (carry forward the rust.md notes that generalize: the code
       evaluator **re-runs** the gate and does not trust the recorded result).
     - State the payoff (spec-06 + spec-08 Gate learning): the next project on that
       stack is detected and inherits this gate via the normal verified-gate path —
       "loom learns gates over time."

   - **Idempotence / scope note** (match the siblings' closing note): re-running
     gate-learning on a stack that now **has** a recorded `gates/<stack>.md` is a
     no-op for the learning path — that stack is now a known gate and takes the
     verified path. Gate-learning never clobbers a confirmed project `CLAUDE.md`
     gate (never-clobber, consistent with `initialized.md` re-application).

2. **Repoint `references/greenfield.md` Step E.** Replace the "deferred /
   not-implemented-here / subject of the follow-up *gate-learning* slice" wording
   (lines 105–116) with a pointer that the unknown-stack path is **now specified**
   in [`gate-learning.md`](gate-learning.md). Keep the marked-UNVERIFIED
   placeholder behavior (the init body still records a placeholder when
   gate-learning has not yet run green), but reframe it as the **entry state of the
   gate-learning lifecycle** (UNVERIFIED until run green) rather than "until the
   gate-learning slice lands." Remove the word "forthcoming"/"deferred"/"not
   implemented here" so no stale forward-pointer remains. Add a `gate-learning.md`
   link.

3. **Repoint `references/unaligned.md` Step 2.** Replace the "deferred slice … the
   subject of the forthcoming *gate-learning* slice … not implemented here"
   wording (lines 60–67) with the same reframe: unknown stack → follow
   [`gate-learning.md`](gate-learning.md); placeholder is the UNVERIFIED entry
   state, not a "slice hasn't landed" note. Fix the passing mention at line 149
   ("placeholder recorded for the gate-learning slice") to reference the mechanism,
   not a pending slice. No remaining "forthcoming"/"deferred" in this file's gate
   text.

4. **Repoint `references/initialized.md`** (lines 94–110). Update the "Gate
   re-application" paragraph and the "Idempotence / scope-boundary note" so they
   point at [`gate-learning.md`](gate-learning.md) as the now-existing mechanism
   instead of "the deferred gate-learning slice" / "remains a forward pointer." The
   substance stays: Initialized re-application does **not** itself learn a gate; if
   re-application encounters an unknown stack it hands to `gate-learning.md`. Remove
   "deferred"/"forward pointer" framing for the now-delivered mechanism.

5. **Update `SKILL.md`.** Add to the References list (lines 43–58, alphabetically /
   logically near the init bodies):
   `gate-learning.md` — the unknown-stack gate-learning mechanism (inspect →
   propose → owner-confirm → run-green-once → record `gates/<stack>.md` + project
   `CLAUDE.md`; UNVERIFIED until green). In the Gates section (lines 59–64),
   minimally repoint the existing inline unknown-stack description at
   `gate-learning.md` as the authoritative body (one added clause/sentence; do not
   duplicate the lifecycle).

6. **Update root `CLAUDE.md`.** In the **Gate** section, add a sentence noting the
   unknown-stack path is now specified in
   `plugins/loom/skills/loom-playbook/references/gate-learning.md` (inspect →
   propose → owner-confirm → run-green-once → record). In the **Repo layout**
   section (which lists each init body), add a `gate-learning.md` bullet in the
   same style, and update the Initialized bullet's trailing clause that currently
   says "gate-learning remains a forward pointer (deferred *gate-learning* slice)"
   so it no longer claims gate-learning is deferred.

## Verification

This repo has no compiled code; the gate is **review-against-spec, mechanical**
(`rg`/`grep`, dogfood the rule). All checks run from
`/Users/craig/git/loom`.

1. **Every spec-06 obligation maps to a concrete step in `gate-learning.md`.**
   Confirm the body contains a discrete step for each: inspect tooling, propose
   `format → lint → test`, owner-confirm, run green once, record `gates/<stack>.md`
   **and** write project `CLAUDE.md`:
   ```sh
   rg -n -i "inspect|propose|confirm|owner|run green|record|gates/<stack>|CLAUDE.md" \
     plugins/loom/skills/loom-playbook/references/gate-learning.md
   ```
2. **The UNVERIFIED → verified lifecycle is explicit** (spec-06 3rd bullet):
   ```sh
   rg -n -i "unverified|run green|verified" \
     plugins/loom/skills/loom-playbook/references/gate-learning.md
   ```
   Confirm prose states a gate is UNVERIFIED until it runs green at least once,
   and is only recorded after a green run.
3. **The recorded-gate format matches `gates/rust.md`.** Confirm `gate-learning.md`
   cites `../gates/rust.md` as the template and enumerates the mirrored fields
   (title, `Status:`, `Detected by:`, the `format/lint/test` table, Notes incl.
   evaluator re-runs):
   ```sh
   rg -n "gates/rust.md|Detected by|Status:|format.*lint.*test|re-run" \
     plugins/loom/skills/loom-playbook/references/gate-learning.md
   ```
4. **No remaining "forthcoming"/stale-deferred gate pointer** in the three init
   bodies; greenfield/unaligned/initialized now resolve to `gate-learning.md`:
   ```sh
   rg -n -i "forthcoming|deferred gate-learning|gate-learning slice|not implemented here" \
     plugins/loom/skills/loom-playbook/references/greenfield.md \
     plugins/loom/skills/loom-playbook/references/unaligned.md \
     plugins/loom/skills/loom-playbook/references/initialized.md
   # expect: no matches referring to a pending slice
   rg -n "gate-learning.md" \
     plugins/loom/skills/loom-playbook/references/greenfield.md \
     plugins/loom/skills/loom-playbook/references/unaligned.md \
     plugins/loom/skills/loom-playbook/references/initialized.md
   # expect: each file links the body
   ```
5. **`SKILL.md` and root `CLAUDE.md` reference the body:**
   ```sh
   rg -n "gate-learning" plugins/loom/skills/loom-playbook/SKILL.md CLAUDE.md
   ```
6. **All links resolve.** For each `gate-learning.md` link target and each link
   inside `gate-learning.md` (to `../gates/rust.md`, `unaligned.md`, the spec),
   confirm the path exists relative to the linking file. Spot-check:
   ```sh
   test -f plugins/loom/skills/loom-playbook/gates/rust.md && echo rust-ok
   test -f plugins/loom/skills/loom-playbook/references/unaligned.md && echo unaligned-ok
   test -f .docs/spec/06-init-modes.md && echo spec06-ok
   ```
7. **No spec/ADR edited** (constraint):
   ```sh
   git diff --name-only | rg -n "\.docs/(spec|ADR)/" ; echo "exit: $?"
   # expect: no matches (rg exit 1 = clean)
   ```

**Regression guard:** the verified-Rust path in all three init bodies is
unchanged (gate-learning only replaces the unknown-stack forward pointers); confirm
`gates/rust.md` and the Rust command tables in `greenfield.md` Step E are
untouched.

## Notes

- This slice is expected to **complete M2** (Init modes & gate learning).
  Verified the remaining M2 roadmap items before claiming so: Detection classifier
  (landed 5fef2ed); per-mode behaviors Greenfield/Unaligned/Initialized (landed
  a58ff7e / e83e219 / b0bd3e9); idempotent playbook re-application (landed in
  `initialized.md` Step 3, b0bd3e9). The only open M2 line is "Gate establishment:
  … create-and-record for new stacks," which this slice delivers. `gates/shell.md`
  is a deferred follow-up (decision above), not an M2-blocking item. On approval +
  landing, the finalize step should mark the M2 gate-establishment roadmap item
  done and note M2 complete in `status/`.
- Decision on `gates/shell.md`: **not in this slice** — mechanism only, single
  purpose; rationale in Context. Recorded as an explicit follow-up.

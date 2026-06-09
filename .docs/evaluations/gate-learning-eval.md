# Evaluation: gate-learning (slice-plan)

Verdict: PASS
Round: 1
Reviewed against: `.docs/spec/06-init-modes.md` *Gate establishment* (2nd + 3rd
bullets) and *Playbook re-application*; `.docs/spec/08-playbook.md` *Gate
learning* / *Verified gate*; `plugins/loom/skills/loom-playbook/gates/rust.md`
(format template); `references/greenfield.md`, `references/unaligned.md`,
`references/initialized.md` (forward pointers); `SKILL.md`; root `CLAUDE.md`.

## Findings

- [MINOR] The plan does not explicitly prescribe a `Status:` line for the new
  `gate-learning.md`. This is **correct, not a gap**: the sibling reference bodies
  (`greenfield.md`/`unaligned.md`/`initialized.md`) carry no `Status:` line, and
  the plan instructs matching their structure/voice. Noted only so the author does
  not add one by reflex (the `Status:` field belongs to `gates/<stack>.md`, which
  Step 5 correctly handles).
- [MINOR] Step 2's worked examples (Node/Python) are explicitly marked
  illustrative and the plan tells the body to flag a missing-tool step for owner
  confirmation rather than drop a gate step. Good. No change required; flagged only
  so the implementer keeps the "illustrative, not defaults" framing intact, since
  it is the one place a future reader could mistake examples for prescribed
  commands.

## Required changes (for FAIL)

None.

## Notes

Verified mechanically against the real tree (dogfooding the `rg`/`test` rule),
all from `/Users/craig/git/loom`:

1. **Every spec-06 2nd-bullet obligation maps to a concrete step.** inspect
   toolchain → Step 1; propose `format → lint → test` → Step 2; owner-confirm
   (with the explicit "never auto-adopt an unverified gate as live") → Step 3;
   run-green-once → Step 4; record `gates/<stack>.md` **and** write project
   `CLAUDE.md` → Step 5. The spec text at 06:66–71 is fully covered.
2. **UNVERIFIED → verified lifecycle (spec-06 3rd bullet, 06:72–73) is explicit,
   not fuzzy.** Step 4 states the state machine literally
   (`proposed → owner-confirmed → UNVERIFIED → runs green once → verified/recorded`),
   forbids recording a non-green gate, and loops a failed run back to Step 2/3.
   This is the sharpest part of the plan.
3. **Recorded-gate format is anchored to the real template.** Step 5 cites
   `../gates/rust.md` and enumerates the exact mirrored fields present in the
   real file (`# Gate: <Stack>` title, `Status:`, `Detected by:`, the
   format/lint/test table, Notes incl. "evaluator re-runs" — confirmed against
   `gates/rust.md` lines 1–21).
4. **All three forward pointers exist as described — none invented, none left
   dangling.** Confirmed in-tree: `greenfield.md` lines 105–116 ("not implemented
   here … follow-up *gate-learning* slice"); `unaligned.md` lines 60–67 plus the
   passing mention at line 149 ("placeholder recorded for the gate-learning
   slice"); `initialized.md` lines 94–97 ("Gate re-application … deferred
   gate-learning slice") **and** lines 103–110 ("remains a forward pointer
   (deferred *gate-learning* slice)"). The plan's claim that initialized.md also
   carries a pointer is true (two, in fact), and Steps 2–4 repoint every one. Root
   `CLAUDE.md` line 53 ("gate-learning remains a forward pointer") and SKILL.md
   Gates section are also addressed by Steps 5–6.
5. **Mechanism-only scope is justified.** `gates/shell.md` deferral rests on three
   sound reasons (single purpose; reviewability already served by `gates/rust.md`
   as the shape template; a genuine learned gate must come from *running* the
   mechanism's run-green step, not hand-authoring). Corroborated: `status/handoff.md`
   already lists `gates/shell.md` as a deferred follow-up candidate (lines 102–111).
6. **No spec/ADR edits; paths real.** In-scope set is playbook + root `CLAUDE.md`
   only. Link targets resolve: `gates/rust.md`, `references/unaligned.md`,
   `.docs/spec/06-init-modes.md` all exist; the five-`../` relative depth from
   `references/` to repo root is verified (matches `greenfield.md` line 6 and
   resolves on disk).
7. **Verification section is mechanical and checkable** — concrete `rg`/`test`/
   `git diff` commands with stated expected outputs, plus a regression guard for
   the unchanged verified-Rust path. The cited M2 commits (5fef2ed, a58ff7e,
   e83e219, b0bd3e9) all exist and match their described slices.

Spec-08 alignment is also clean: 08:54–55 *Gate learning* ("written back into
`gates/` so the next project inherits it") and 08:67–69 ("runs it green once to
mark it verified, then records it") are exactly the payoff Steps 4–5 encode.

This plan is executable by an independent reader, single-purpose, and leaves no
forward pointer dangling.

---

# Round 2 (code)

Verdict: PASS
Round: 2
Reviewed against: the slice commit `b2463c4`; `.docs/slice-plans/gate-learning.md`
(scope authority); `.docs/spec/06-init-modes.md` *Gate establishment* (2nd + 3rd
bullets); `plugins/loom/skills/loom-playbook/gates/rust.md` (format template);
`references/greenfield.md` / `unaligned.md` / `initialized.md` (forward pointers);
`SKILL.md`; root `CLAUDE.md`; the Round 1 plan-eval above. This is a markdown-only
slice with no compiled code — acceptance is review-against-spec, done mechanically
(`rg`/`grep`/`test`), dogfooding the mechanical-check rule rather than judging by
eye.

## Findings

- [MINOR] In `gate-learning.md` Step 2, the "If a gate step has no discovered
  tool" guidance cites "spec `08`" for the always-three-steps invariant. The
  authority line scopes this body to spec `06`; spec `08` is a legitimate
  corroborating reference (the Round 1 plan-eval confirmed 08:54–69 alignment) and
  the spec-precedence note still points at `06`, so this is a stylistic nit, not a
  conflict. No change required.
- [MINOR] The Round 1 plan-eval flagged keeping the Node/Python examples framed as
  illustrative, not defaults. Verified the implementation honors this: the worked
  table is headed "illustrative — the actual commands come from the real project's
  tooling, not these defaults" and the body repeats "do not use them as defaults
  without first finding the real commands in Step 1." Closed, no action.

## Required changes (for FAIL)

None.

## Mechanical-check results (dogfooded — verified against the real tree, not the diff)

1. **Spec-06 fidelity — every obligation realized as a discrete step.** PASS.
   `rg` over `gate-learning.md`: inspect toolchain → Step 1 (read-only, enumerates
   manifests/build-files/CI signals); propose `format → lint → test` → Step 2
   ("never drop a step"); owner-confirm → Step 3 (explicit "loom never auto-adopts
   an unverified gate as live", orchestrator owns prompts); run-green-once → Step 4;
   record **both** `gates/<stack>.md` **and** project `CLAUDE.md` → Step 5 (two
   subsections). All five spec-06 2nd-bullet obligations + the 3rd-bullet lifecycle
   are present.
2. **No dangling pointers.** PASS.
   `rg -i 'forthcoming|deferred gate-learning|gate-learning slice|not implemented here'`
   over greenfield/unaligned/initialized → **zero matches** (exit 1). Broadened
   sweep (`forthcoming|not implemented here|pending slice|deferred .*gate-learning|
   gate-learning.*deferred|remains a forward pointer`) across all six doc files →
   zero. Each init body links `gate-learning.md` (greenfield ×2, unaligned ×3,
   initialized ×2); SKILL.md and root CLAUDE.md both reference it. CLAUDE.md no
   longer contains "deferred"/"forward pointer" (exit 1).
3. **Format template.** PASS. `gate-learning.md` cites `../gates/rust.md` as "the
   format template" (Precondition + Step 5) and enumerates every mirrored field
   present in the real `rust.md` (lines 1–21): `# Gate: <Stack>` title,
   `Status: Verified`, `Detected by:`, the `format/lint/test` command table, and a
   Notes section carrying forward "the code evaluator **re-runs** this gate and
   does not trust the recorded result."
4. **Unverified safety (spec-invariant).** PASS — no violation. Step 4 states the
   state machine literally (`proposed → (owner-confirmed) → UNVERIFIED → (runs
   green once) → verified/recorded`); "Do **not** record a non-green gate into the
   playbook"; `Status: Verified` is set "because recording only happens post-green
   ... a non-green gate is never recorded." The marked-UNVERIFIED placeholder is
   consistently framed as the lifecycle **entry state** that "is never treated as a
   live gate," in `gate-learning.md` and in all three init bodies. No path records
   an un-green gate as trusted.
5. **Scope.** PASS. `git show --name-only` = exactly the 7 expected files
   (gate-learning.md new + greenfield/unaligned/initialized + SKILL.md + CLAUDE.md +
   slice-plan). No spec/ADR (exit 1), no `gates/shell.md` (exit 1).
   `git diff b2463c4~1 b2463c4 -- gates/rust.md` is empty — `rust.md` is
   byte-identical (template untouched). Verified-Rust command tables in
   greenfield.md Step E and the rust.md adoption in unaligned.md are intact
   (regression guard holds).
6. **Links resolve.** PASS. `test -f` on `gates/rust.md`, `references/unaligned.md`,
   `.docs/spec/06-init-modes.md`, `references/gate-learning.md` all succeed; the
   five-`../` relative depth from `references/` to repo root resolves on disk
   (matches the sibling bodies).

The recorded gate evidence in the slice-plan (checks 1–8) matches what I
independently reproduced. The slice satisfies the plan and spec-06 in full.

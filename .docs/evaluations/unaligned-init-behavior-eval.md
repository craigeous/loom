# Evaluation: unaligned-init-behavior (slice-plan)

Verdict: PASS
Round: 1
Reviewed against: `.docs/spec/06-init-modes.md` §2 + Gate establishment + Playbook
re-application; `plugins/loom/skills/loom-playbook/references/greenfield.md`;
`init-detection.md`; `docs-layout.md`; call sites `orchestration.md`,
`commands/run.md`, `commands/init.md`; `SKILL.md`; root `CLAUDE.md`.

## Findings

- [MINOR] Single-source guard phrasing — Plan steps 1 and 6's verification (lines 89,
  255) say `unaligned.md` must not "restate ... the Step A–F bodies," but Step 2
  (line 113) correctly scopes the reuse to greenfield **Steps A–E** (scaffold /
  spec-seed / status-seed / CLAUDE.md / gate). Greenfield Step F is commit + hand
  back, which Unaligned legitimately owns as its own Step 5. The "A–F" in the guard
  is loose against the "A–E" reuse instruction. Intent is unambiguous (do not restate
  the shared scaffold mechanics); recommend aligning the wording to "A–E" so the
  body author isn't told not to restate a step they must author. Non-blocking.

- [MINOR] Header "Target specs" lists `08-playbook.md` and `04-orchestrator.md`
  alongside `06-init-modes.md`, but the plan edits no spec — it edits the playbook /
  command files those specs govern. The framing is acceptable (the slice works
  *within* those specs), but naming them as "target specs" alongside the authority
  could read as a scope signal; consider clarifying that 06 §2 is the operative
  authority. Non-blocking.

## Notes (why this passes)

Spec-06 §2 obligations each map to a concrete, ordered, single-purpose step in the
body the plan commissions, verified against the real tree:

- "Study the repo" → Step 1 (read-only survey; explicitly produces understanding,
  writes no files; feeds gate detection + back-fill). Matches §2 bullet 1.
- "Create `.docs/` and apply the playbook" + "Establish the gate" → Step 2, **by
  reference** to `greenfield.md` Steps A–E. The reuse is genuine single-sourcing: the
  plan forbids restating the tree or the A–E bodies and adds only the Unaligned
  deltas (populated repo / "update never clobber", gate detection fed by Step 1,
  alignment-phase status seed). The deltas are faithful to greenfield's actual
  text — e.g. the non-Rust marked-unverified placeholder pointing at gate-learning
  matches greenfield Step E lines 112–116.
- "Descriptive back-fill only ... no decisions ... Draft → Plan Review → Approved" →
  Step 3, the core delta. The **no-decisions boundary is explicit and hard**
  ("records what *is*, never what *should be*"; no ADRs; no decision-bearing spec
  text; any change requires a real planning phase). Step 3 also requires back-filled
  specs to be authored `Status: Draft` and pass the normal lifecycle (cross-linked to
  `03-artifact-lifecycle.md`, which resolves), and notes the back-fill correctly
  populates the `spec/README.md` reading order that greenfield Step B seeds empty —
  a real delta the plan does not let the reuse silently drop.
- "Seed `status/` with current state and an initial roadmap" → Step 4 (alignment
  progress marker, survey-seeded roadmap, handoff pointing to resume-as-Initialized).
- "leave the project loom-shaped and ready to resume as Initialized" → Step 5
  (handback; next run detects Initialized per `init-detection.md`).

Correct forward pointers / no premature implementation: gate-learning for unknown
stacks is reused-by-reference from greenfield and explicitly deferred (Step 2 delta +
out-of-scope), and full idempotent playbook re-application is left to the Initialized
slice with only the safety note carried over. The Initialized resume menu is
untouched (orchestration Initialized bullet, init.md step 3, run.md Initialized
branch all kept as forward pointers). No `.docs/spec/` or `.docs/ADR/` edit is
proposed — Step 6 says so explicitly and the verification includes a mechanical
`git diff --name-only HEAD | rg "spec/|ADR/"` empty check.

Executable / file-scoped: six numbered steps, each naming an exact file and the
exact edit. Call-site claims verified mechanically against the current tree —
`run.md:22` "unaligned → alignment pass", `init.md:18-21` forward pointer,
`orchestration.md:44-46` "behavior body forthcoming" all match what the plan says it
will replace. Every referenced path resolves: `greenfield.md`, `../gates/rust.md`,
`commit-convention.md`, `docs-layout.md`, the §2 authority and lifecycle paths at
`../../../../../.docs/spec/...` (depth confirmed by resolving from `references/`),
and root `CLAUDE.md` line 43 ("Unaligned and Initialized bodies are forthcoming")
which Step 6 correctly proposes to adjust to leave only Initialized forthcoming.

Verification section is stated in review-against-spec terms with checkable `rg`/grep
invariants (negative grep for restated scaffold/gate tokens to prove single-source;
positive grep that the call sites point at `unaligned.md`; the spec/ADR diff guard;
link resolution). Appropriate for a markdown repo with no compiled gate.

No place in the plan instructs the back-fill to make a decision or propose a change;
the boundary is enforced as a content requirement of `unaligned.md` Step 3 rather
than something the slice itself produces. The two MINORs above are cosmetic wording.

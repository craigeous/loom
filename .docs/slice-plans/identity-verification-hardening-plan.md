# Identity Verification Hardening

Status: Approved
Target specs: 08-playbook.md

## Context

ADR 0003 requires **one uniform, author-neutral git identity** across all roles so
the blind code evaluator (ADR 0004) cannot infer the producing role from commit
metadata. Twice now (M1, and again in M4) a sub-agent committed under git's
auto-generated fallback identity `loom <loom@localhost>` instead of the
repository's configured identity. This defeats blind-eval safety and violates
ADR 0003.

The rule itself is already explicit and was violated anyway, so **more prose
restating the prohibition is not the fix.** Verified against the tree, two
structural gaps remain:

- **Gap A — the "init ensures an identity" claim is unbacked.**
  `references/commit-convention.md` (lines 25–28) states "the
  orchestrator/`/loom:init` ensures an identity exists before any role commits,"
  but no init body implements that. Confirmed:
  `grep -rn -i "user.email|git config|identity"` across
  `references/{greenfield,unaligned,initialized,init-detection}.md` and
  `commands/{init,run}.md` returns only two hits, both the "no `user.*` override"
  prohibition in the Greenfield/Unaligned commit steps — **none establish or
  verify that a git identity is configured.** In a config-less environment git
  auto-invents `loom@localhost`, so the claim is false.

- **Gap B — no agent verifies the resulting commit identity.** Confirmed:
  `grep -rn -i "verify.*identity|git show.*%ae|loom@localhost"` across
  `agents/*.md` returns nothing. The five agents are told to commit
  "author-neutral" and to read `commit-convention.md`, but nothing checks that the
  commit *actually used* the configured identity rather than a silent fallback.

This slice closes both gaps by **enforcement, not restatement**: init verifies an
identity exists (and stops if not), and agents verify the identity *after*
committing (and self-correct or stop if wrong). Both rely on a **single source**
in `commit-convention.md`.

**Out of scope (do not touch in this slice):**
- ADR 0003 and every `.docs/spec/` file — frozen authority; this slice enforces
  ADR 0003, it does not change it.
- The PreToolUse hook `plugins/loom/hooks/git-identity-guard.sh`. The hook catches
  identity-**override** flags (`--author`, `-c user.*`, `git config user.*`, the
  `GIT_*` env vars) but **not** this config-less/fallback path, which uses no
  override at all. Extending the hook to detect a fallback author is a different
  problem (it cannot know the "right" identity) and is not required here; do not
  change the hook unless a concrete, justified reason emerges.
- Hardcoding any specific person's name/email anywhere. Every check verifies that
  *some* real identity is configured (non-empty `user.name` **and** `user.email`,
  not a `*@localhost` / `*.(none)` auto-generated value), never a literal value.

**Context, not work for this slice:** the orchestrator has separately set a
repo-local identity in loom's own clone as a one-off mitigation. That is an
environment fix, not a code change in this slice.

## Steps

### Fix A — init establishes/verifies a git identity (makes the commit-convention claim true)

The cleanest single-source location is the **Greenfield body**, which both the
Greenfield and Unaligned paths already run (Unaligned Step 2 reuses Greenfield for
scaffold + playbook + gate). Greenfield gets the **establish-or-stop** instruction;
Unaligned and Initialized resume paths get a lighter **verify-only** pointer to it.

1. **`references/greenfield.md` — add a new "ensure git identity" step before the
   commit step (new Step F, renumber the existing commit step to Step G).** Insert
   it after Step E (`## Step E — Establish the gate`, ends at line 119) and before
   the current `## Step F — Commit and hand back` (line 123). The new step is the
   **single authoritative "ensure identity" instruction** the other bodies
   reference. Required content:
   - Heading: `## Step F — Ensure a git identity is configured`.
   - Run `git config user.name` and `git config user.email`.
   - **Both must be non-empty AND not an auto-generated fallback** — explicitly
     reject an `@localhost` email (e.g. `loom@localhost`) and git's "implicit"
     identity (the `(none)` / autodetected host form). State the concrete
     acceptance: a real, owner-provided `user.name` and `user.email` are set in
     git config.
   - **If a real identity is present:** proceed (no change made — never overwrite
     an existing identity).
   - **If absent or a fallback:** **STOP and ask the owner** to configure the
     repository's git identity (e.g. via `git config user.name` /
     `git config user.email`). **Never auto-invent an identity, never run
     `git config user.*` on the agent's own initiative, and never proceed to commit
     under a fallback.** Cross-reference `commit-convention.md` for the rationale.
   - One line tying it to the existing claim: this step is what makes
     `commit-convention.md`'s "init ensures an identity exists before any role
     commits" true.
   - Renumber the current `## Step F — Commit and hand back` to
     `## Step G — Commit and hand back`. (Confirm no other in-file cross-reference
     names "Step F" before renaming — `rg "Step F" references/greenfield.md`.)

2. **`references/unaligned.md` — add a verify-only identity check to Step 2.** Step 2
   (`## Step 2 — Scaffold + apply the playbook + establish the gate (reuse
   Greenfield)`, line 41) already delegates to Greenfield. Add a sentence stating
   that reusing Greenfield **includes its "Ensure a git identity is configured"
   step (Greenfield Step F)** — i.e. before any Unaligned commit, verify a real
   identity is configured and **STOP and ask the owner if not** (never invent).
   Do **not** duplicate the procedure; point at Greenfield Step F as the single
   source.

3. **`references/initialized.md` — add a verify-only identity check to the resume
   path.** Initialized never re-scaffolds, so it does not run Greenfield. In Step 2
   (`## Step 2 — Hand off into scope + claimed gates + the driver loop`, line 50),
   add a short **pre-flight** sentence: before handing into the driver loop (under
   which roles commit), **verify** a real git identity is configured per the
   Greenfield "Ensure a git identity is configured" step / `commit-convention.md`,
   and **STOP and ask the owner if it is absent or a fallback** (never invent).
   Reference the single source; do not restate the full procedure.

### Fix B — agents verify identity at commit time (behavioral safety net, single-sourced)

4. **`references/commit-convention.md` — add the post-commit verification step as
   the single source.** Under `## Rules`, extend the uniform-identity bullet
   (lines 14–35; the prose currently ends at line 35) by appending a short
   **"Verify after committing"** sub-point. Required content:
   - After every commit, run `git show -s --format='%an <%ae>'` on the new commit.
   - Confirm the author **matches the repository's configured identity** and is
     **NOT** `loom <loom@localhost>` / any `*@localhost` / auto-generated fallback.
   - **If it is wrong AND a real identity is configured:** fix it in place with
     `git commit --amend --reset-author --no-edit`, then re-verify. (Note this is
     the *one* sanctioned `--amend --reset-author` use — it resets *to* the
     configured identity, it does not set/override one, so it does not violate the
     "must not set or override identity" rule above.)
   - **If it is wrong AND no real identity is configured:** do **NOT** proceed —
     stop and report (the init "ensure identity" step should have prevented this;
     this is the last-line safety net).
   - Keep it tight: this is the single authoritative procedure; agents will
     point here, not re-paste it.

5. **`agents/researcher.md` — add a one-line post-commit verify pointer.** The
   commit instruction is the bullet at lines 38–41 (ends "blind review reads
   commits)."). Append one sentence: after committing, **verify the commit's author
   identity per `commit-convention.md` ("Verify after committing")** and fix/stop
   if it is a fallback. Pointer only — no procedure.

6. **`agents/planner.md` — add the same one-line pointer.** The commit instruction
   is step 3 (line 32, "(author-neutral — see the commit-convention reference), and
   stop."). Append: after committing, verify the author identity per
   `commit-convention.md` ("Verify after committing") and fix/stop if it is a
   fallback.

7. **`agents/plan-evaluator.md` — add the same one-line pointer.** The commit
   instruction is step 4 (line 60, "Commit (author-neutral — see the
   commit-convention reference) and stop."). Append the same verify pointer.

8. **`agents/developer.md` — add the same one-line pointer.** The commit
   instruction is step 5 (lines 41–43, "**commit** your work (author-neutral — see
   the commit-convention reference)..."). Append the same verify pointer.

9. **`agents/code-evaluator.md` — add the same one-line pointer.** The commit
   instruction is step 6 (line 59, "Commit (author-neutral) and stop."). Append the
   same verify pointer (and, to match the others, reference the
   commit-convention if the brevity allows).

**Single-source discipline:** the full "ensure identity" procedure lives once in
`greenfield.md` Step F (Unaligned/Initialized point at it); the full "verify after
committing" procedure lives once in `commit-convention.md` (all five agents point
at it). No body or agent re-pastes either procedure.

## Verification

loom's own repo has **no compiled gate** — its content is markdown, so acceptance
is review-against-spec (`08-playbook.md` + ADR 0003) plus the mechanical checks
below. Run each from the repo root.

**Fix A present and single-sourced:**

1. Greenfield establish-or-stop step exists:
   `rg -n "Ensure a git identity is configured" plugins/loom/skills/loom-playbook/references/greenfield.md`
   → exactly one heading hit.
2. It checks both fields and rejects the fallback:
   `rg -n "user.name|user.email|localhost|STOP|stop and ask" plugins/loom/skills/loom-playbook/references/greenfield.md`
   → shows the two `git config` checks, the `@localhost` rejection, and the
   stop-and-ask-the-owner branch in the new step.
3. The commit step was renumbered (no orphaned/duplicate "Step F"):
   `rg -n "^## Step [FG]" plugins/loom/skills/loom-playbook/references/greenfield.md`
   → one `## Step F — Ensure a git identity is configured` and one
   `## Step G — Commit and hand back`.
4. Unaligned + Initialized reference the single source (verify-only, no duplication):
   `rg -n "git identity|Ensure a git identity|commit-convention" plugins/loom/skills/loom-playbook/references/unaligned.md plugins/loom/skills/loom-playbook/references/initialized.md`
   → each file shows a verify-only pointer to Greenfield Step F /
   `commit-convention.md` with a stop-if-absent branch; **neither re-pastes the
   `git config user.name`/`user.email` procedure** (inspect the hits to confirm
   pointer-only).

**Fix B present and single-sourced:**

5. The post-commit verify procedure exists once, in commit-convention:
   `rg -n "Verify after committing|git show -s --format|amend --reset-author" plugins/loom/skills/loom-playbook/references/commit-convention.md`
   → the verify sub-point with the `git show -s --format='%an <%ae>'` command and
   the conditional `--amend --reset-author` fix.
6. Each of the five agents carries a verify pointer (and only a pointer):
   `rg -ln "Verify after committing" plugins/loom/agents/researcher.md plugins/loom/agents/planner.md plugins/loom/agents/plan-evaluator.md plugins/loom/agents/developer.md plugins/loom/agents/code-evaluator.md`
   → all five files listed.
7. The full procedure is NOT duplicated into the agents (single-source intact):
   `rg -n "git show -s --format" plugins/loom/agents/*.md`
   → **no hits** (the command string lives only in `commit-convention.md`).

**Scope guard (no spec/ADR/hook edits, plan committed with the index):**

8. `git diff --name-only <base>..HEAD` (or `git show --name-only HEAD` for the plan
   commit) touches **only**:
   - `plugins/loom/skills/loom-playbook/references/greenfield.md`
   - `plugins/loom/skills/loom-playbook/references/unaligned.md`
   - `plugins/loom/skills/loom-playbook/references/initialized.md`
   - `plugins/loom/skills/loom-playbook/references/commit-convention.md`
   - `plugins/loom/agents/{researcher,planner,plan-evaluator,developer,code-evaluator}.md`
   - `.docs/slice-plans/identity-verification-hardening-plan.md` (this plan)
   - `.docs/slice-plans/README.md` (Active entry)
   - root `CLAUDE.md` only if a one-line note is warranted at land time.
   No file under `.docs/spec/` or `.docs/ADR/`, and **not**
   `plugins/loom/hooks/git-identity-guard.sh`:
   `git diff --name-only <base>..HEAD | rg "\.docs/(spec|ADR)/|git-identity-guard"`
   → **no hits**.
9. No hardcoded personal identity introduced:
   `git diff <base>..HEAD | rg -i "craigeous|@gmail|Craig Pfeiffer"`
   → **no hits** (checks verify *a* real identity is configured, never a literal).

## Notes

- The PreToolUse guard hook (`plugins/loom/hooks/git-identity-guard.sh`) blocks
  identity-**override** flags but does **not** catch the config-less/fallback path
  that caused both incidents (no override flag is used). This slice deliberately
  does not modify the hook; the fix is init-time establishment + post-commit
  verification. If the plan evaluator believes the hook should also detect a
  fallback author, raise it here — it is a separable concern and arguably can't
  know the "correct" identity.
- Sequential slice: this plan file and the `slice-plans/README.md` Active entry are
  written in the **same** plan commit.

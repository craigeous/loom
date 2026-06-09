# Shell gate (first learned gate: `gates/shell.md`, verified on loom's own hook)

Status: Landed
Target specs: 06-init-modes.md, 08-playbook.md

## Context

loom ships exactly one verified gate today: `gates/rust.md`. Every other stack is
meant to be *learned* during init via the gate-learning mechanism
(`plugins/loom/skills/loom-playbook/references/gate-learning.md`): inspect → propose
→ owner-confirm → **run green once** → record `gates/<stack>.md` + project
`CLAUDE.md`. That mechanism has never been exercised end-to-end against real code.
This slice is the deferred M2 follow-up (it was explicitly deferred when
gate-learning landed — see `slice-plans/README.md`, the `gate-learning.md` archive
entry: "`gates/shell.md` deferred"), now done as M4 dogfooding.

loom is itself partly a shell project: `plugins/loom/hooks/git-identity-guard.sh`
(POSIX `#!/bin/sh`) is the only `.sh` in the repo. This slice runs the
gate-learning mechanism's Steps 4–5 on that real hook to produce loom's **first
learned gate** and to give the hook a committed, runnable test suite it never had.

**Tooling is already installed and the gate already runs green** (verified
read-only while authoring this plan, repo root, macOS darwin 25.3.0):

- `shfmt` **3.13.1**, `bats` **1.13.0**, `shellcheck` **0.11.0**.
- `shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh` → exit **0** (clean).
- `shellcheck plugins/loom/hooks/git-identity-guard.sh` → exit **0** (clean).
- The hook is **4-space indented**. `shfmt`'s *default* is tabs, which would report
  a diff and demand reformatting a security-critical file. **This plan fixes the
  gate's format step at `shfmt -i 4 -d`** (see the shfmt decision below) so format
  passes green without touching the hook.

**Owner shape decision (already made — do not re-litigate):** the gate's test step
uses **bats**, and the hook's test suite is a real `.bats` file. This is the "Full"
shape the owner chose.

### What exists today (verified against the tree)

- `plugins/loom/hooks/git-identity-guard.sh` — the guard (the artifact under test).
  Its behavior is the **unconditional-block** form restored at the abandonment of
  the `scope-identity-guard-to-commit-subcommands` slice
  (`slice-plans/README.md` marks that slice `Abandoned`; the restore commit is
  byte-identical to the original `a47bf95`).
- `plugins/loom/hooks/hooks.json` — the PreToolUse wiring (not touched here).
- `plugins/loom/skills/loom-playbook/gates/rust.md` — the only gate; the **format
  template** `shell.md` must mirror.
- `plugins/loom/skills/loom-playbook/gates/` contains **only** `rust.md` (no
  `shell.md` yet).
- No `*.bats` file exists anywhere in the repo.
- Root `CLAUDE.md` "## Gate" section currently ends: "This repo has no compiled
  code yet, so it has no concrete gate to run." — now **partly false**: the hook is
  testable shell.

### CRITICAL — the shipped guard over-blocks reads (accepted, documented limitation)

The orchestrator's framing listed "read-only `git -c user.email=x log`" and
`git log --author=alice` as **ALLOW** cases. **That is not how the currently-shipped
guard behaves.** The subcommand-scoping that would have made reads ALLOW was the
`scope-identity-guard-to-commit-subcommands` slice, which was **abandoned** (two
code-eval-caught false-negative classes — pre-`git` prefix fail-open, then
compound-command shadowing). The restore commit documents the accepted limitation:
the guard blocks the identity-override *syntax* unconditionally, so a read like
`git log --author=alice` is **also blocked (exit 2)**. This is intentional
fail-closed behavior; `commit-convention.md` records it.

A gate exists to verify **the real code** (spec 06 *Gate establishment*: run green
on the real project). Therefore the bats suite **must encode the shipped behavior**
(reads with override syntax → exit 2), not the orchestrator's mistaken expectation.
The matrix below was built by running every case against the shipped script while
authoring this plan; the recorded exit codes are observed, not assumed. The
discrepancy is flagged here and in Notes so the evaluator does not "correct" the
suite toward an ALLOW that the artifact does not implement.

### Out of scope

- **Editing the hook.** The format step is `shfmt -i 4 -d`, which is already clean,
  so the hook is **not** reformatted or otherwise touched (it is security-critical;
  ADR 0003). If a future planner adopts tab indentation, *that* slice reformats it.
- Changing `hooks.json`, the override-detection logic, `commit-convention.md`, any
  `.docs/spec/` text, or any ADR.
- Re-opening read-subcommand scoping (abandoned; a separate future planning cycle).
- Running the full gate-learning Steps 1–3 (toolchain inspection / owner proposal /
  owner confirmation) as live prompts: the owner has already confirmed the shape and
  the tools, so this slice executes Steps 4 (run green) and 5 (record in two places).

## Steps

### shfmt indent decision (load-bearing — read before Step 2)

The gate's **format** command is **`shfmt -i 4 -d`** (4-space indent, diff mode,
non-zero exit on any diff). Rationale: the hook is already 4-space indented and is
security-critical (ADR 0003); shfmt's tab default would report a diff and force a
reformat of that file. Matching the existing indent keeps the gate green **without
churning the hook**. The generic shipped gate in `shell.md` therefore records
`shfmt -i 4 -d` (with a note that a project on tabs would use plain `shfmt -d`).
This choice means **no hook edit is needed** — Step 2 touches no `.sh`.

### Step 1 — Create the committed bats test suite

Create **`plugins/loom/hooks/git-identity-guard.bats`** (new file).

**Location rationale:** placed **beside the hook it tests**, in `hooks/`. The repo
has exactly one `.sh` and one test target; a `hooks/tests/` directory would be
premature structure for a single file, and co-location makes the test discoverable
next to its subject and keeps the gate's `bats` invocation a single concrete path.
(`shell.md` records the *generic* shape `bats <test dir or file>`; loom's concrete
invocation is `bats plugins/loom/hooks/git-identity-guard.bats`.)

The suite drives the hook by piping crafted hook-shaped JSON to it on **stdin** and
asserting the **exit code** (the hook reads `tool_input.command` from stdin JSON and
exits 2 on a detected override, 0 otherwise). Use bats's `run` + `status`:

```bash
#!/usr/bin/env bats
# Test suite for git-identity-guard.sh (ADR 0003 identity guard).
# Drives the hook with hook-shaped JSON on stdin; asserts the exit code.
# The code evaluator re-runs this suite as the shell gate's TEST step.

GUARD="${BATS_TEST_DIRNAME}/git-identity-guard.sh"

# guard <json> -> runs the hook with the given stdin, sets $status/$output
guard() {
  run sh "$GUARD" <<<"$1"
}

@test "BLOCK 01: commit --author= with quoted value" {
  guard '{"tool_input":{"command":"git commit --author=\"x <x@y>\" -m z"}}'
  [ "$status" -eq 2 ]
}
# ... one @test per matrix row below ...
```

**Implementation requirements the developer must meet:**

1. **`GUARD` resolves via `${BATS_TEST_DIRNAME}`** so the suite runs from any cwd.
2. **One `@test` per matrix row** (26 rows below), named with the row id and a short
   description, asserting the exact expected `$status`.
3. **JSON escaping:** the matrix's "Command (decoded)" column is the literal command
   string the hook must see. In the `.bats` source, that string is embedded inside a
   JSON `"command":"…"` value, so inner `"` becomes `\"` and an in-message escaped
   inner quote `\"` becomes `\\\"` (same encoding the archived plan's Verification D4
   used). The developer must encode each row so that `jq -r '.tool_input.command'`
   on the heredoc reproduces the decoded command exactly. (Sanity-check a tricky row
   with `jq` before finalizing.)
4. **jq-absent fallback rows (F1–F3)** must genuinely exercise the grep/sed fallback
   branch (lines 24–29 of the hook take the `jq` path when `command -v jq` succeeds;
   the `else` branch is the fallback). Force the fallback with a stub PATH that
   contains the coreutils the hook needs but **not** `jq`. The robust, environment-
   independent recipe below — a bare `PATH=/usr/bin` does **not** work on this
   machine because `/usr/bin/jq` exists, so a temp stub PATH is required:

   ```bash
   # In a setup helper used only by the F-rows:
   guard_no_jq() {
     stub="$(mktemp -d)"
     # NOTE: the interpreter is invoked by ABSOLUTE path (/bin/sh) below, so it
     # does NOT need to be on the stubbed PATH. If you instead invoke a bare `sh`,
     # you MUST also symlink sh into $stub or `env`/the shell re-resolves it
     # against the jq-free PATH and the recipe exits 127. The hook's fallback
     # branch uses only these coreutils:
     for t in cat grep sed tr wc head; do
       for d in /usr/bin /bin; do
         [ -x "$d/$t" ] && { ln -s "$d/$t" "$stub/$t"; break; }
       done
     done
     run env PATH="$stub" /bin/sh "$GUARD" <<<"$1"
     rm -rf "$stub"
   }
   ```

   `jq` is deliberately **not** symlinked into `$stub`, so under `PATH="$stub"`
   the hook's `command -v jq` fails (NO_JQ) and the grep/sed `else` branch runs.
   The interpreter is `/bin/sh` by absolute path so it resolves regardless of the
   stubbed PATH. With this form the F-rows are expected to produce F1→2, F2→2,
   F3→0 (BLOCK/ALLOW survive the fallback); the developer runs them as part of
   the run-green-once gate (Step 3 / V1) and confirms NO_JQ.
   Use **absolute** `/usr/bin`/`/bin` source paths for the symlinks (a shell `grep`
   function/alias can otherwise shadow `command -v grep` and create a broken
   symlink — observed while authoring this plan).
5. **No edit to the hook**; the suite is read-only against it.

#### The 26-case acceptance matrix (observed exit codes — replay against the shipped hook)

Recovered from `.docs/evaluations/author-identity-enforcement-guard-eval.md` and the
archived plan `.docs/slice-plans/archive/author-identity-enforcement-guard.md`
(Verification §C/D/D2/D3/D4/D5/E and the developer's "26 cases total" gate evidence),
**and re-run against the currently-shipped `git-identity-guard.sh` while authoring
this plan.** Every "Exit" value below was observed, not assumed. The "decoded"
command is what the hook must see after JSON-decoding.

**BLOCK cases (exit 2) — 9 rows:**

| id | Command (decoded) | Exit | Vector |
|----|-------------------|------|--------|
| B01 | `git commit --author="x <x@y>" -m z` | 2 | `--author=` (quoted value) |
| B02 | `git -c user.email=x@y commit -m z` | 2 | `-c user.email=` |
| B03 | `git -c user.name=Foo commit -m z` | 2 | `-c user.name=` |
| B04 | `GIT_AUTHOR_NAME=Foo git commit -m z` | 2 | inline env |
| B05 | `export GIT_COMMITTER_EMAIL=x@y; git commit -m z` | 2 | exported env |
| B06 | `git commit --author bar -m z` | 2 | `--author <space>` form |
| B07 | `git -c GIT_AUTHOR_NAME=x commit` | 2 | `-c GIT_AUTHOR*=` |
| B08 | `git commit --author="evil <e@e>" -m "ok"` | 2 | quoted value + quoted msg |
| B09 | `git commit --author=evil -m "say \"hi\""` | 2 | real `--author=` beside an escaped inner quote (proves Stage A is a no-op on real overrides) |

**ALLOW cases (exit 0) — 17 rows:**

| id | Command (decoded) | Exit | Why ALLOW |
|----|-------------------|------|-----------|
| A01 | `git commit -m "msg"` | 0 | plain commit, no override |
| A02 | `git -c core.pager=cat log` | 0 | `-c core.*` is non-identity config |
| A03 | `ls -la` | 0 | not a git command |
| A04 | `echo legitimate=1` | 0 | `git` only as a substring of another word |
| A05 | `git commit -m "fix --author= parsing"` | 0 | `--author=` only inside the message body |
| A06 | `git commit -m "guard against --author flag"` | 0 | message text (this slice family's own commit shape) |
| A07 | `git commit -m "set GIT_AUTHOR_NAME=foo in script"` | 0 | env name only inside message body |
| A08 | `git commit -m "add -c user.email= override"` | 0 | `-c user.*` only inside message body |
| A09 | `git log --grep="--author="` | 0 | `--grep` value is not an identity flag; stripped |
| A10 | `git commit -m "use \"--author=\" flag carefully"` | 0 | escaped-inner-quote message (Stage A) |
| A11 | `git commit -m "mention \"GIT_AUTHOR_NAME=x\" here"` | 0 | escaped-inner-quote message |
| A12 | `git commit -m "note \"-c user.email=\" thing"` | 0 | escaped-inner-quote message |
| A13 | `git commit -m "wip` | 0 | unbalanced quoting → Stage C fail-open |
| A14 | `git push` | 0 | git command, no override token |

**Fallback cases (jq absent — genuinely exercise the grep/sed branch) — 3 rows:**

| id | Command (decoded) | Exit | Note |
|----|-------------------|------|------|
| F1 | `git commit --author=evil -m z` | 2 | BLOCK survives fallback |
| F2 | `GIT_AUTHOR_NAME=Foo git commit -m z` | 2 | inline-env BLOCK survives fallback |
| F3 | `git commit -m z` | 0 | ALLOW survives fallback |

That is **26 rows** (9 BLOCK + 14 ALLOW + 3 fallback = 26). It covers every vector
the orchestrator named: the four BLOCK families (`--author=` / `--author <space>`,
`-c user.*=`, `-c GIT_AUTHOR*=`, inline/exported `GIT_*` env), the message-text-only
false-positive guards (A05–A09), the escaped-inner-quote ALLOWs (A10–A12), the
Stage-C unbalanced-quote fail-open (A13), and the jq-absent fallback (F1–F3).

**Read-with-override-syntax note (do NOT add as ALLOW):** the orchestrator named
`git -c user.email=x log` and `git log --author=alice` as ALLOW. The shipped guard
**BLOCKS both (exit 2)** — verified while authoring this plan. They are the accepted
fail-closed read over-block documented at the abandonment of the scoping slice
(`commit-convention.md`). To make the suite **prove** that documented behavior
rather than silently contradict the orchestrator, the developer **adds two rows to
the BLOCK section** so the recorded reality is explicit (these are part of the
required suite, raising the BLOCK count for transparency — they are *not* a
substitute for any row above):

| id | Command (decoded) | Exit | Note |
|----|-------------------|------|------|
| B10 | `git -c user.email=x@y log` | 2 | read over-block (accepted limitation, ADR 0003 fail-closed) |
| B11 | `git log --author=alice` | 2 | read over-block (accepted limitation) |

Final suite = **28 `@test` cases** (B01–B11 = 11 BLOCK, A01–A14 = 14 ALLOW,
F1–F3 = 3 fallback). The "26-case matrix" the task referenced is the historical
hook acceptance set (9 BLOCK + 14 ALLOW + 3 fallback); B10/B11 are added to make the
read over-block explicit. The suite must run green: `bats
plugins/loom/hooks/git-identity-guard.bats` → all pass.

### Step 2 — Create the learned gate `gates/shell.md`

Create **`plugins/loom/skills/loom-playbook/gates/shell.md`** (new file), mirroring
the **exact shape** of `gates/rust.md`: title, `Status:` line, `Detected by:` line,
the run-in-order intro sentence, the three-column `format / lint / test` table, and
a `Notes:` section. Required content:

- **Title:** `# Gate: Shell`
- **`Status: Verified`** — set Verified because this gate has run green on loom's
  own hook (Step 3 below; spec 06 *Gate establishment* 3rd bullet: a gate is
  UNVERIFIED until it has run green at least once — this one has).
- **`Detected by:`** a shell project — at least one `*.sh` file with a
  `#!/bin/sh` or `#!/usr/bin/env bash` (or `#!/bin/bash`) shebang, **and no
  `Cargo.toml`** at the repo/workspace root (a `Cargo.toml` short-circuits to the
  Rust gate; the no-`Cargo.toml` clause makes the signal unambiguous against a Rust
  project that merely contains helper shell scripts). State this precisely.
- **The `format / lint / test` table (generic shipped shape):**

  | Step   | Command                         |
  |--------|---------------------------------|
  | format | `shfmt -i 4 -d <paths>`         |
  | lint   | `shellcheck <paths>`            |
  | test   | `bats <test dir or file>`       |

  These are the *generic* commands a shell project inheriting this gate runs.
  Unlike `rust.md` (whose commands are fully concrete because the Rust toolchain is
  uniform), the shell test command is project-specific (it depends on where the
  project keeps its `.bats` files), so the table records the shape and the Notes
  give loom's own concrete invocation.

- **`Notes:`** — mirror `rust.md`'s generalizable notes and add shell specifics:
  - The code evaluator **re-runs** this gate; it does not trust the recorded result.
    (Carried from `rust.md` — required.)
  - **shfmt indent:** `-i 4` matches a 4-space project (such as loom's hook); a
    tab-indented project uses plain `shfmt -d`. The format step must fail (non-zero)
    on any diff — `-d` does this.
  - **Test command is project-specific.** loom's own concrete gate on
    `plugins/loom/hooks/git-identity-guard.sh` is:
    - format: `shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh`
    - lint: `shellcheck plugins/loom/hooks/git-identity-guard.sh`
    - test: `bats plugins/loom/hooks/git-identity-guard.bats`
  - This is the first **learned** gate (recorded via the gate-learning mechanism,
    `references/gate-learning.md` Step 5); the next shell project loom encounters
    inherits it via the verified-gate path.

Keep the file's prose minimal and structural — `rust.md` is ~21 lines; `shell.md`
should be comparably tight.

### Step 3 — Record the gate run-green evidence

Add a dated `## Notes` entry to **this plan** recording the green run on the real
hook (this is the spec-06 "run green once" evidence that justifies
`Status: Verified` in `shell.md`). The developer must run and record observed exit
codes for the loom-concrete gate:

```
shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh ; echo $?   # expect 0
shellcheck plugins/loom/hooks/git-identity-guard.sh    ; echo $?   # expect 0
bats plugins/loom/hooks/git-identity-guard.bats        ; echo $?   # expect 0 (all tests pass)
```

All three must be green. If any is non-green, the gate stays UNVERIFIED and
`shell.md` must **not** be recorded as Verified (spec 06) — stop and report.

### Step 4 — Record the gate in loom's root `CLAUDE.md`

Edit the **`## Gate`** section of root **`/Users/craig/git/loom/CLAUDE.md`**
(currently ends "This repo has no compiled code yet, so it has no concrete gate to
run."). Replace that final sentence with an accurate statement that loom is now
**partly a shell project** and records the shell gate's concrete commands. Do **not**
overstate: loom's primary content is still markdown (prompts/templates); the shell
gate applies specifically to the hook. Required additions:

- A note that loom's only compiled/testable code today is the POSIX-sh hook
  `plugins/loom/hooks/git-identity-guard.sh`, and that loom therefore now has a
  concrete **Shell** gate (the first learned gate), recorded at
  `plugins/loom/skills/loom-playbook/gates/shell.md`.
- The three concrete commands (format → lint → test):
  - `shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh`
  - `shellcheck plugins/loom/hooks/git-identity-guard.sh`
  - `bats plugins/loom/hooks/git-identity-guard.bats`
- Keep the existing Rust-gate paragraph and the gate-learning pointer intact; only
  the "no compiled code yet" sentence is reconciled. Phrase it so the markdown-first
  framing survives (e.g. "loom's content is primarily markdown; its one piece of
  executable code is the identity-guard hook, which now has a verified Shell gate").

### Step 5 — Update the slice-plans index (same commit as the plan / sequential rule)

This is a **sequential** single slice (no parallelism active), so the M1 habit
applies (ADR 0008's index-on-main-only rule is parallelism-gated; spec 08
*Slice-plans index ownership under parallelism* confirms the index is
orchestrator-owned **only once parallelism is on**). Therefore the **planner** writes
the **Active plans** entry in `/Users/craig/git/loom/.docs/slice-plans/README.md`
in the **same commit** as this plan file. Replace the `_(none)_` placeholder under
`## Active plans` with:

```
- [shell-gate-plan.md](shell-gate-plan.md) — `Plan Review` —
  first learned gate: a committed bats suite for git-identity-guard.sh (28 cases)
  + `gates/shell.md` (Status: Verified, mirrors rust.md) + root CLAUDE.md Gate
  reconciliation; runs the gate-learning mechanism green on loom's own shell hook
  (M4 dogfooding; deferred-from-M2).
```

(The planner does this Step now, in the plan commit. Steps 1–4 are the developer's;
the developer/finalize moves the entry to Archived on landing, per the sequential
habit.)

## Verification

A code evaluator can execute this mechanically. All commands run from the repo root
`/Users/craig/git/loom`.

### V1 — Gate runs green on the real hook (the spec-06 "run green once" check)

Re-run the gate (do **not** trust the recorded evidence — `rust.md`/`shell.md` Notes
both say the evaluator re-runs):

```
shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh ; echo $?   # expect 0
shellcheck plugins/loom/hooks/git-identity-guard.sh    ; echo $?   # expect 0
bats plugins/loom/hooks/git-identity-guard.bats        ; echo $?   # expect 0
```

All three exit 0. `bats` must report every test passing (0 failures).

### V2 — The bats suite covers all enumerated cases with the observed exit codes

- The suite contains a `@test` for **every** row in Step 1's matrix: B01–B11
  (11 BLOCK, expect `status -eq 2`), A01–A14 (14 ALLOW, expect `status -eq 0`),
  F1–F3 (3 fallback). Count: **28 tests**. Confirm with
  `bats --count plugins/loom/hooks/git-identity-guard.bats` → `28` (or grep
  `^@test` count = 28).
- **Independently replay** a sample of rows against the shipped hook to confirm the
  asserted exit codes are real, e.g.:
  ```
  printf '%s' '{"tool_input":{"command":"git log --author=alice"}}' | sh plugins/loom/hooks/git-identity-guard.sh; echo $?   # expect 2 (B11 — read over-block)
  printf '%s' '{"tool_input":{"command":"git commit -m \"fix --author= parsing\""}}' | sh plugins/loom/hooks/git-identity-guard.sh; echo $?   # expect 0 (A05)
  printf '%s' '{"tool_input":{"command":"git commit --author=evil -m \"say \\\"hi\\\"\""}}' | sh plugins/loom/hooks/git-identity-guard.sh; echo $?   # expect 2 (B09)
  ```
- **Fallback genuinely exercised:** confirm the F-rows use the no-jq stub PATH and
  that `command -v jq` fails under it (NO_JQ). A bats run where jq is silently still
  on PATH does not satisfy F1–F3. Spot-check by building the stub dir per Step 1.4
  and running F1 → 2 and F3 → 0.

### V3 — `gates/shell.md` mirrors `rust.md`

Diff the two files' shapes (`rust.md` is the template):

- `shell.md` has, in order: an `# Gate: Shell` H1, a `Status: Verified` line, a
  `Detected by:` line, a run-in-order intro sentence, a `format / lint / test`
  three-column table, and a `Notes:` section.
- The Notes contain the **required** carried-forward line "The code evaluator
  **re-runs** this gate; it does not trust the recorded result."
- `Detected by:` names a `*.sh`/`#!/bin/sh|bash` shebang signal **with the
  no-`Cargo.toml` clause**.
- The table's format row is `shfmt -i 4 -d …`, lint is `shellcheck …`, test is
  `bats …`.
- The Notes give loom's three concrete commands (the exact strings in Step 2).
- Mechanical check: `rg -n '^Status: Verified$' plugins/loom/skills/loom-playbook/gates/shell.md`
  and `rg -n 're-runs' plugins/loom/skills/loom-playbook/gates/shell.md` both match.

### V4 — Root `CLAUDE.md` reconciled accurately

- The `## Gate` section no longer asserts "This repo has no compiled code yet, so it
  has no concrete gate to run" (or that sentence is replaced).
- It names `plugins/loom/hooks/git-identity-guard.sh` as the testable shell, points
  at `gates/shell.md`, and lists the three concrete commands.
- It does **not** overstate: markdown is still described as loom's primary content.
- The Rust-gate paragraph and gate-learning pointer are intact.
- Mechanical check:
  `rg -n 'git-identity-guard|shfmt|shellcheck|bats|gates/shell.md' /Users/craig/git/loom/CLAUDE.md`
  shows the additions; `rg -n 'no compiled code yet' /Users/craig/git/loom/CLAUDE.md`
  returns nothing.

### V5 — Scope and hygiene

- `git show --stat <commit>` (developer's implementation commit) lists exactly:
  `plugins/loom/hooks/git-identity-guard.bats` (new),
  `plugins/loom/skills/loom-playbook/gates/shell.md` (new),
  `CLAUDE.md`, and this plan (status-line + Notes evidence update). It must **not**
  list `git-identity-guard.sh` (no hook edit — the `shfmt -i 4` choice avoids it),
  `hooks.json`, `commit-convention.md`, any `.docs/spec/` file, or any ADR.
- `git show -s --format='%an <%ae>%n%cn <%ce>%n%b' <commit>` shows an
  author-neutral identity and **no** `Co-Authored-By:` / role-identity trailer.
- The hook is unchanged: `git diff <commit>^ <commit> -- plugins/loom/hooks/git-identity-guard.sh`
  is empty.

## Notes

- **shfmt indent decision (planner, 2026-06-09):** format step is **`shfmt -i 4 -d`**.
  The hook is 4-space indented and security-critical (ADR 0003); shfmt's tab default
  would demand reformatting it. `-i 4` keeps the gate green with **zero hook churn**,
  so this slice touches no `.sh`. The alternative (adopt tabs + reformat the hook) is
  explicitly rejected here; a future slice may revisit if loom standardizes on tabs.
- **Read over-block is the shipped reality, not a bug to fix (planner, 2026-06-09):**
  the orchestrator's case list called `git -c user.email=x log` and
  `git log --author=alice` ALLOW. **Verified false against the shipped hook** while
  authoring this plan — both exit **2**. The subcommand-scoping that would ALLOW
  reads was the `scope-identity-guard-to-commit-subcommands` slice, **abandoned**
  after two code-eval BLOCKERs; the restore commit documents the accepted fail-closed
  read over-block in `commit-convention.md`. A gate verifies the *real* code (spec 06),
  so the suite encodes exit 2 for those reads (rows B10/B11) and must **not** be
  "corrected" toward ALLOW. Re-opening read scoping is a separate future planning
  cycle, out of scope here.
- **Case-count reconciliation (planner, 2026-06-09):** the task's "26-case matrix"
  is the historical hook-acceptance set recoverable from the eval + archived plan
  (9 BLOCK incl. the three D3 quoted-value blocks + 14 ALLOW + 3 jq-fallback = 26).
  This plan adds **B10/B11** (the two read over-block rows) so the documented
  limitation is proven explicitly rather than left implicit — final suite is **28**
  `@test` cases. The added rows are additive (transparency), not substitutions.
- **bats fallback recipe (planner, 2026-06-09; corrected Round 2):** a bare
  `PATH=/usr/bin` does **not** knock out jq on the dev machine (a `/usr/bin/jq`
  exists), so the F-rows use a temp stub dir symlinking the coreutils the hook's
  fallback branch needs from their **absolute** `/usr/bin`/`/bin` paths (not via
  `command -v`, which a shell `grep` function can shadow into a broken link) and
  deliberately excluding jq. **The interpreter is invoked by absolute path
  (`/bin/sh "$GUARD"`)** so it resolves regardless of the jq-free stubbed PATH —
  an earlier draft ran a bare `sh` against `PATH="$stub"` (which lacks `sh`),
  which would exit 127; the corrected recipe in Step 1.4 fixes that (absolute
  `/bin/sh`, or equivalently add `sh` to the symlink loop). This recipe is the
  developer's instruction for the F-rows; it is **expected** to report NO_JQ and
  produce F1→2, F2→2, F3→0, exercised as part of run-green-once (Step 3 / V1) —
  not pre-verified here.
- **Sequential index rule (planner, 2026-06-09):** no parallelism is active, so the
  planner writes the `slice-plans/README.md` Active entry in the plan commit (M1
  habit; ADR 0008's index-on-main rule is parallelism-gated, per spec 08).
- **Verified read-only while authoring (planner, 2026-06-09):** `shfmt` 3.13.1,
  `bats` 1.13.0, `shellcheck` 0.11.0 all present; `shfmt -i 4 -d` and `shellcheck`
  both exit 0 on the hook; the B01–B11 / A01–A14 rows were each run against the
  shipped hook (default PATH, jq present) and produced the exit codes recorded in
  the matrix. The jq-absent F1–F3 codes (2/2/0) follow from the same hook logic on
  the corrected `/bin/sh` recipe (Step 1.4) and are exercised at run-green-once
  (Step 3 / V1); they are stated as expected, not pre-verified via the recipe. No
  files were modified.
- **Gate run-green-once evidence (developer, 2026-06-09):** all three gate steps ran
  green from the repo root on the loom-concrete commands (spec 06, "run green once"):
  - `shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh` → exit **0** (no diff)
  - `shellcheck plugins/loom/hooks/git-identity-guard.sh` → exit **0** (clean)
  - `bats plugins/loom/hooks/git-identity-guard.bats` → exit **0** (**28/28 tests
    pass**: B01–B11, A01–A14, F1–F3; F-rows confirmed NO_JQ via temp stub PATH)
  Hook is unchanged (shfmt `-i 4 -d` is a no-op on the 4-space-indented hook).
  This is the spec-06 evidence that justifies `Status: Verified` in `gates/shell.md`.

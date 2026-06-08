# Scope the author-identity guard to commit-creating subcommands

Status: Abandoned
Target specs: (none — implementation refinement of the ADR 0003 enforcement hook;
specs/ADRs unchanged)

## Context

The PreToolUse hook `plugins/loom/hooks/git-identity-guard.sh` (landed a47bf95)
enforces ADR 0003's uniform commit identity by blocking (exit 2) any git-bearing
command that contains an identity-override vector. The originally-shipped guard ran
its four detection regexes on the whole de-quoted command **unconditionally** —
it blocked `--author`, `-c user.*=`, `-c GIT_*=`, and inline/exported
`GIT_AUTHOR_*`/`GIT_COMMITTER_*` wherever they appeared, regardless of subcommand.

That shipped guard had **one** known false-positive (Open MINOR in
`.docs/status/progress.md`, "Guard `--author` pattern not scoped to commit-creating
subcommands"): read-only commands where `--author` is a legitimate *filter* —
`git log --author=alice`, `git shortlog -sn --author=bob`, `git blame --author x` —
were wrongly blocked.

### Why the previous version of this slice was rejected (Round-2 code FAIL)

The first redesign introduced a subcommand parser and gated **all four** detection
checks behind a commit-creating-subcommand `case`. That parser required the command
to *begin* with `git` (after optional leading `VAR=value` env assignments); **any
other pre-`git` token failed OPEN.** As a result, every shell-prefixed `git commit`
ALLOWed — including reachable identity overrides the original guard had BLOCKED:

- `export GIT_AUTHOR_NAME=Evil; git commit -m z`
- `cd /tmp && git commit --author=evil -m z`
- `env GIT_AUTHOR_NAME=Evil git commit -m z`
- `true; git commit --author=evil -m z`
- `sudo git commit --author=evil`

Each was verified reachable (changes recorded author/committer) and each was BLOCKED
by the pre-slice script. **For identity overrides, fail-open = fail-unsafe.** The
fail-OPEN-on-ambiguous posture was the design flaw, and gating the env/`-c` vectors
behind a fragile pre-`git` locator was a regression. The eval is
`.docs/evaluations/scope-identity-guard-to-commit-subcommands-eval.md` (Round 2).

### This slice — redesigned posture

Split the vectors by whether they have any legitimate read-time use, and choose a
posture per vector that **cannot regress into a false-negative**:

- **`GIT_AUTHOR_*`/`GIT_COMMITTER_*` env (inline, `export`ed, or via `env`), and
  `-c user.*=` / `-c GIT_AUTHOR*=` / `-c GIT_COMMITTER*=`: detect UNCONDITIONALLY —
  always BLOCK (exit 2), regardless of subcommand or shell prefix.** These are
  *identity overrides* with no legitimate read-only use. The originally-shipped guard
  blocked them everywhere and there was never a false-positive complaint about them.
  Keeping them unconditional **removes all the fragile pre-`git` parsing for these
  vectors** — the regression class above disappears because the detection no longer
  depends on locating the `git` invocation. Consequence (intended): identity-override
  attempts on a *read* now BLOCK too — `GIT_AUTHOR_NAME=foo git log`,
  `git -c user.email=x@y log`. That is ACCEPTABLE: an identity override on a read is
  pointless, and we optimize for never letting a write-time override through.

- **`--author` / `--author=`: the ONLY vector with a legitimate read use** (a
  `log`/`shortlog`/`blame` FILTER), so it is scoped — but **FAIL-CLOSED.** Block
  `--author` **UNLESS the subcommand is positively identified as a known READ
  command** (`log`, `shortlog`, `blame`, `whatchanged`, `rev-list`, `show`). Any
  ambiguity — unrecognized subcommand, unrecognized prefix, no subcommand located —
  BLOCKS. So a real `--author` commit override can never slip through, while the
  actual reported false-positive (`git log --author=alice`, etc.) is allowed.

This is faithful to the eval's prescription: fail-OPEN is eliminated for everything
that records identity; the only `--author` carve-out is positively-identified reads.

**Out of scope / must stay intact:**
- The stdin read and `tool_input.command` extraction (jq path + grep/sed fallback,
  current lines 29–38).
- The three-stage de-quote transform — Stage A escaped-quote removal, Stage B
  quoted-body stripping, Stage C odd-quote-count fail-open (lines 45–56).
- The git-word / env-var gate (lines 58–70).
- The four detection **regexes** themselves (current lines 108, 114, 120, 126) — the
  regex *patterns* do not change; only the *control flow that consults them* changes.
- The block messages and exit codes (BLOCK=2, ALLOW=0).
- No edits to `hooks.json`, specs, ADRs, or `commit-convention.md`.

## The rule this slice implements

1. **Three unconditional identity-override checks (no subcommand gating).** On
   `$STRIPPED`, in this order, BLOCK (exit 2) if any fire:
   - inline/exported `GIT_AUTHOR_(NAME|EMAIL)=` or `GIT_COMMITTER_(NAME|EMAIL)=`
     (covers `VAR=x git …`, `export VAR=x; git …`, `env VAR=x git …`);
   - `-c user.<key>=` (`-c user.name=`, `-c user.email=`, any `-c user.*=`);
   - `-c GIT_AUTHOR*=` / `-c GIT_COMMITTER*=`.
   These have no legitimate read use, so they fire wherever they appear — there is no
   pre-`git` locator and therefore no shell-prefix fail-open hole.

2. **One scoped, fail-CLOSED `--author` check.** If `$STRIPPED` contains
   `--author` (flag form `--author ` or `--author=`):
   - Locate the `git` invocation and determine its subcommand (see §3).
   - **ALLOW (exit 0) only if** the subcommand is positively one of the known read
     commands: `log`, `shortlog`, `blame`, `whatchanged`, `rev-list`, `show`.
   - **Otherwise BLOCK (exit 2)** — including when the subcommand is empty/unknown,
     unrecognized, or the invocation could not be cleanly located. Fail-closed.

3. **Subcommand locator (used ONLY for the `--author` carve-out).** Tokenize
   `$STRIPPED` on whitespace; the command is already de-quoted so quoted operands and
   their spaces are gone. Walk tokens:
   - Skip tokens until the first whole-word `git` is seen (this tolerates *any*
     shell prefix — `export VAR=x;`, `cd /tmp &&`, `sudo`, `env VAR=x`, `true;` — we
     do not care what precedes `git`, because the env/`-c` vectors are already handled
     unconditionally in §1; the locator exists solely to identify a read subcommand).
   - After `git`, skip global options and their consumed values with a `SKIP_NEXT`
     flag:
     - value-taking globals (separate form) — `-c`, `-C`, `--git-dir`,
       `--work-tree`, `--namespace`, `--exec-path`, `--config-env` → set
       `SKIP_NEXT=1`, continue;
     - joined/`=` globals — `-c*`, `-C*`, `--git-dir=*`, `--work-tree=*`,
       `--namespace=*`, `--exec-path=*`, `--config-env=*` → continue;
     - value-less switches — `-p`, `--paginate`, `-P`, `--no-pager`, `--bare`,
       `--no-replace-objects`, `--literal-pathspecs`, `--no-optional-locks`,
       `--html-path`, `--man-path`, `--info-path`, `--version`, `--help` → continue;
     - any other `-*` token → continue (skip unknown options; do NOT fail-open here —
       the `--author` decision is fail-closed, so an unknown option just means we keep
       scanning, and if no read subcommand is positively found we BLOCK);
     - first bare (non-`-`) token → that is `$SUBCMD`; break.
   - If the loop ends with no bare token (`$SUBCMD=""`), the read-allowlist test
     below fails and the command BLOCKS — fail-closed, as required.

   Crucially, the locator no longer has a `*) SUBCMD=""; break` arm for pre-`git`
   tokens. The old arm is what caused the Round-2 regression; here, the locator only
   *enables an ALLOW* for positively-identified reads and otherwise BLOCKS, so a
   too-strict locator can only over-block (a MAJOR for a real read), never
   under-block (a BLOCKER for a real override).

4. **Order of operations.** The three unconditional checks (§1) run first; if none
   fire, the `--author` check (§2) runs; if it does not fire or resolves to a read,
   the script `exit 0`s. This ordering means an `--author` *commit* with no env/`-c`
   vector is still caught by §2 (fail-closed), and an env/`-c` override on a read is
   caught by §1 before the `--author` allowlist is ever consulted.

5. **Preserve all prior guarantees** (unchanged, verified in the matrix):
   - message-text ALLOW — Stage B strips quoted `-m "...--author..."` bodies before
     any check sees them, so neither §1 nor §2 fires;
   - escaped-quote ALLOW — Stage A/B;
   - unbalanced-quote fail-open ALLOW — Stage C (this fail-open is about
     *unparseable quoting*, predates this slice, and is fine; a normal
     `git commit --author=` has balanced quoting and is never caught by it);
   - plain `git commit -m z` ALLOW — no vector present;
   - non-git ALLOW — the git-word/env gate (lines 58–70) exits 0 first.

## Steps

All steps touch only `plugins/loom/hooks/git-identity-guard.sh`. The script is POSIX
`sh`; keep it POSIX (no bash arrays, no `[[ ]]`). The change replaces the current
subcommand-parser + gated-`case` block (current lines 72–135) with: three
unconditional checks, then a fail-closed `--author` check, then `exit 0`. The stages
above line 72 (stdin/extraction, de-quote, Stage C, git gate) are **unchanged**.

1. **Remove the current commit-scoping parser and gated `case`** (current lines
   72–135: the `# --- Determine git subcommand ...` block, the `for tok` state
   machine, the `case "$SUBCMD" in commit|...)` wrapper around the four `if` blocks,
   and the trailing `exit 0`). They are replaced wholesale by Steps 2–4.

2. **Add the three unconditional identity-override checks** immediately after the
   git gate (after current line 70). Reuse the three existing regexes verbatim — only
   their enclosing condition is dropped (they now run unconditionally):

   ```sh
   # --- Unconditional identity-override vectors (no legitimate read use) ---
   # These alter recorded author/committer identity and have no read-time purpose,
   # so they BLOCK wherever they appear — no subcommand/prefix parsing, which is
   # why a shell prefix before `git` can never create a fail-open hole here.

   # Inline / exported / env'd GIT_AUTHOR_*/GIT_COMMITTER_*
   if printf '%s' "$STRIPPED" | grep -qE '(GIT_AUTHOR_(NAME|EMAIL)|GIT_COMMITTER_(NAME|EMAIL))='; then
       printf 'loom identity guard: blocked GIT_AUTHOR_*/GIT_COMMITTER_* env var override (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
       exit 2
   fi

   # -c user.*= (user identity config override)
   if printf '%s' "$STRIPPED" | grep -qE -- '-c[[:space:]]+user\.[A-Za-z]+='; then
       printf 'loom identity guard: blocked -c user.*= config override (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
       exit 2
   fi

   # -c GIT_AUTHOR*= or -c GIT_COMMITTER*= (identity env override via -c)
   if printf '%s' "$STRIPPED" | grep -qE -- '-c[[:space:]]+(GIT_AUTHOR|GIT_COMMITTER)[A-Z_]*='; then
       printf 'loom identity guard: blocked -c GIT_AUTHOR*/GIT_COMMITTER* config override (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
       exit 2
   fi
   ```

3. **Add the fail-closed `--author` check** after the three unconditional checks.
   Only if `--author` is present do we locate the subcommand; ALLOW only for a
   positively-identified read, else BLOCK:

   ```sh
   # --- --author: the only vector with a legitimate read use (log/blame filter).
   #     Scope it, but FAIL CLOSED: block unless the subcommand is positively a
   #     known read command. Any ambiguity blocks — a real commit-time --author
   #     override can never slip through. ---
   if printf '%s' "$STRIPPED" | grep -qE -- '--author([[:space:]]|=)'; then
       # Locate the git invocation and read its subcommand.
       SUBCMD=""
       SEEN_GIT=0
       SKIP_NEXT=0
       for tok in $STRIPPED; do
           if [ "$SEEN_GIT" -eq 0 ]; then
               [ "$tok" = "git" ] && SEEN_GIT=1
               continue                       # ignore everything up to & incl. `git`
           fi
           if [ "$SKIP_NEXT" -eq 1 ]; then SKIP_NEXT=0; continue; fi
           case "$tok" in
               -c|-C|--git-dir|--work-tree|--namespace|--exec-path|--config-env)
                    SKIP_NEXT=1; continue ;;
               -c*|-C*|--git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--config-env=*)
                    continue ;;
               -p|--paginate|-P|--no-pager|--bare|--no-replace-objects|--literal-pathspecs|--no-optional-locks|--html-path|--man-path|--info-path|--version|--help)
                    continue ;;
               -*)  continue ;;               # unknown option: keep scanning (do NOT fail open)
               *)   SUBCMD="$tok"; break ;;     # first bare token = subcommand
           esac
       done
       case "$SUBCMD" in
           log|shortlog|blame|whatchanged|rev-list|show)
               : ;;                            # positively a read → --author is a filter → allow
           *)
               printf 'loom identity guard: blocked --author flag (overrides git commit identity).\nADR 0003 requires one uniform identity; use plain git commit under the configured identity.\n' >&2
               exit 2 ;;
       esac
   fi
   ```

   Notes on the `case` arm order: the exact `-c`/`-C` arms must precede the joined
   `-c*`/`-C*` arms (POSIX `case` is first-match). The `-*) continue` arm must be
   *last* among the `-` arms so the named globals match first.

4. **Add the final `exit 0`** (no override detected, or `--author` resolved to a
   read):

   ```sh
   # --- No override detected → allow ---
   exit 0
   ```

5. **Update the script header comment** (current lines 1–27). Replace the
   "scoped to commit-creating subcommands" description with the new posture:
   - the env (`GIT_AUTHOR_*`/`GIT_COMMITTER_*`, inline/`export`/`env`) and
     `-c user.*`/`-c GIT_*` vectors BLOCK **unconditionally** (no subcommand gating);
   - `--author` BLOCKS unless the subcommand is positively a known read
     (`log`, `shortlog`, `blame`, `whatchanged`, `rev-list`, `show`), in which case
     it is a filter and is allowed; any ambiguity BLOCKS (fail-closed);
   - state explicitly that an identity override on a read (e.g.
     `GIT_AUTHOR_NAME=foo git log`, `git -c user.email=x@y log`) now BLOCKS, and that
     this is intended (pointless on a read; we never let a write-time override
     through);
   - keep the de-quote-transform comment block intact.

6. **Keep the file executable** (mode already `+x`; do not regress it). Do not touch
   `hooks.json`.

## Verification

Script-runnable. The developer **must** run the full matrix below by piping
hook-shaped JSON to the committed script and **record the observed exit code** for
every case. BLOCK = exit 2, ALLOW = exit 0.

Drive each case with stdin shaped like the real hook payload, e.g.:

```sh
printf '{"tool_input":{"command":"git log --author=alice"}}' \
  | sh plugins/loom/hooks/git-identity-guard.sh; echo "exit=$?"
```

**Severity rule (state in the handoff):**
- A real identity override that resolves to **ALLOW** is a **BLOCKER**
  (false-negative; fail-unsafe).
- A known-read `--author` *filter* that resolves to **BLOCK** is a **MAJOR**
  (re-introduces the false-positive this slice removes).

### A. Required BLOCK (exit 2) — overrides, incl. the Round-2 regressed cases

A non-zero failure to block here is a **BLOCKER**.

| # | Command | Why |
|---|---|---|
| A1 | `export GIT_AUTHOR_NAME=Evil; git commit -m z` | env vector, shell prefix (regressed → now BLOCK) |
| A2 | `cd /tmp && git commit --author=evil -m z` | `--author` on commit behind `cd &&` (regressed) |
| A3 | `env GIT_AUTHOR_NAME=Evil git commit -m z` | env via `env` (regressed) |
| A4 | `true; git commit --author=evil -m z` | `--author` on commit behind `true;` (regressed) |
| A5 | `sudo git commit --author=evil` | `--author` on commit behind `sudo` (regressed) |
| A6 | `git commit --author="x <x@y>" -m z` | clean `--author` commit |
| A7 | `git -c user.email=x@y commit -m z` | `-c user.*` (unconditional) |
| A8 | `git -c user.name=x cherry-pick abc` | `-c user.*` (unconditional) |
| A9 | `GIT_AUTHOR_NAME=foo git commit -m z` | leading inline env |
| A10 | `git -c GIT_COMMITTER_NAME=x commit -m z` | `-c GIT_*` (unconditional) |
| A11 | `git revert --author="x <x@y>" HEAD` | `--author` on revert (fail-closed) |
| A12 | `git rebase -c user.email=x@y main` | `-c user.*` (unconditional) |
| A13 | `git merge --author="x <x@y>" topic` | `--author` on merge (fail-closed) |
| A14 | `GIT_AUTHOR_EMAIL=x git am file` | leading inline env |
| A15 | `git commit -m "msg" --author='A B <a@b>'` | `--author` after message (prior C18) |
| A16 | `git -c user.name="A B" commit -m x` | `-c user.*` (prior C19) |
| A17 | `GIT_COMMITTER_EMAIL=a@b git commit -m x` | leading inline env (prior C20) |
| A18 | `git -c user.email=x@y commit-tree abc` | `-c user.*` on commit-tree |
| A19 | `git cherry-pick --author=x abc` | `--author` on cherry-pick (fail-closed) |
| A20 | `GIT_AUTHOR_NAME=foo git log` | **now BLOCK (intended):** env override on a read |
| A21 | `git -c user.email=x@y log` | **now BLOCK (intended):** `-c user.*` on a read |
| A22 | `git -c GIT_AUTHOR_NAME=x log` | **now BLOCK (intended):** `-c GIT_*` on a read |
| A23 | `git push --author=evil` | `--author`, non-read subcommand → fail-closed BLOCK |

### B. Required ALLOW (exit 0) — known-read `--author` filters

A non-zero (BLOCK) here is a **MAJOR** (the false-positive being removed).

| # | Command | Why |
|---|---|---|
| B1 | `git log --author=alice` | read filter |
| B2 | `git shortlog -sn --author=bob` | read filter |
| B3 | `git blame -L1,2 f --author x` | read filter (flag-space form) |
| B4 | `git --no-pager log --author=x` | valueless global then read |
| B5 | `git blame --author x` | read filter |
| B6 | `git whatchanged --author=x` | read filter |
| B7 | `git rev-list --author=x HEAD` | read filter |
| B8 | `git show --author=x` | read (no recorded identity) |

### C. Required ALLOW (exit 0) — no override / prior ALLOW regressions

| # | Command | Why |
|---|---|---|
| C1 | `git show --format=%an HEAD` | read, no `--author`, no env/`-c` |
| C2 | `git diff` | read, no vector |
| C3 | `git commit -m z` | plain commit, no vector |
| C4 | `git commit -m "fix --author= handling in docs"` | Stage B strips override text from message |
| C5 | `git commit -m "set GIT_AUTHOR_NAME in the script"` | text in message (Stage B) |
| C6 | `git commit -m 'add -c user.email note'` | text in message (Stage B) |
| C7 | `git commit -m "escaped \"--author\" mention"` | Stage A/B |
| C8 | `git commit -m "unbalanced quote --author` | Stage C odd-quote fail-open |
| C9 | `echo --author=foo` | non-git (gate exits first) |
| C10 | `ls -c user.name=x` | non-git (gate exits first) |
| C11 | `ls` | non-git |
| C12 | `cd /tmp && git log --author=alice` | read with shell prefix → still ALLOW (no new FP) |

### D. jq-absent fallback

Re-run, with `jq` masked from `PATH` (curated PATH lacking jq, exercising the
grep/sed extraction branch, current line 37):
- D1 = A6 (`git commit --author="x <x@y>" -m z`) → BLOCK (exit 2)
- D2 = A9 (`GIT_AUTHOR_NAME=foo git commit -m z`) → BLOCK (exit 2)
- D3 = A7 (`git -c user.email=x@y commit -m z`) → BLOCK (exit 2)
- D4 = B1 (`git log --author=alice`) → ALLOW (exit 0)
- D5 = C3 (`git commit -m z`) → ALLOW (exit 0)

### Gate

This repo has no compiled gate (`CLAUDE.md`). The acceptance gate for this slice is:
**`sh -n` and `dash -n` clean; mode still `+x`; `git diff --name-only` shows only
`git-identity-guard.sh` (+ this slice-plan); and every A/B/C/D case above passes with
the asserted exit code, recorded in the implementation handoff.** Any A or D-BLOCK
case that ALLOWs → FAIL (BLOCKER). Any B/C/D-ALLOW case that BLOCKs → FAIL
(MAJOR/regression).

## Notes

- 2026-06-08 (planner): **Redesign after Round-2 code FAIL.** The prior version gated
  *all* vectors behind a commit-creating-subcommand parser that failed OPEN on any
  non-env pre-`git` token, which let real overrides through
  (`export GIT_*=…; git commit`, `env …`, `cd … && git commit --author=`, `true; …`,
  `sudo …`). The new posture removes subcommand gating from the env/`-c` vectors
  entirely (they BLOCK unconditionally) and makes the `--author` carve-out
  fail-CLOSED (BLOCK unless positively a known read). For identity overrides,
  fail-open = fail-unsafe; this design has no fail-open path that records identity.
- 2026-06-08 (planner): **Intended new BLOCKs.** `GIT_AUTHOR_NAME=foo git log` and
  `git -c user.email=x@y log` now BLOCK (they previously also blocked in the *original*
  shipped guard, before the rejected slice; the rejected slice briefly ALLOWed them).
  An identity override on a read is pointless, so blocking it costs nothing and keeps
  the env/`-c` detection prefix-agnostic — which is what eliminates the regression.
  Documented in the matrix (A20–A22) as required BLOCK.
- 2026-06-08 (planner): the `--author` read allowlist is
  `log shortlog blame whatchanged rev-list show`. These are the git read commands that
  accept `--author` as a filter. If a future read command needs the carve-out it can
  be added here; until then, fail-closed means an unrecognized subcommand with
  `--author` BLOCKS — acceptable, since a real read mis-typed/unknown is rare and a
  real commit override must never slip.
- 2026-06-08 (planner): the Stage-C odd-quote fail-open (C8) is unchanged and is about
  *unparseable quoting*, not about identity posture. A normal
  `git commit --author='A B <a@b>'` has balanced quotes and is never caught by it
  (Stage B leaves `git commit --author=` in `$STRIPPED`, which the §2 fail-closed
  check then BLOCKs).
- 2026-06-08 (planner): `tag` and `notes` are no longer special-cased. They are not in
  the `--author` read allowlist, so `git tag --author=…` / `git notes … --author=…`
  would BLOCK — harmless (git does not honor `--author` there; the command is git-
  invalid), and not a false-negative concern.
- 2026-06-08: **Abandoned by owner.** Guard reverted to commit a47bf95 (unconditional
  `--author` blocking). Reason: two code-eval-caught false-negative classes made
  shell-parse scoping untenable — (1) the original subcommand-parser failed open on
  any pre-`git` token (`export GIT_*=…; git commit`, `env …`, `cd … &&`, `sudo`, etc.),
  and (2) that was not fixable without a compound-command parser that adds new
  fragility classes. Simple + fail-closed wins over a fragile carve-out. The
  read-filter false-positive (`git log --author=alice` blocked) is documented as an
  accepted known limitation in
  `plugins/loom/skills/loom-playbook/references/commit-convention.md`.

# Scope the author-identity guard to commit-creating subcommands

Status: Plan Review
Target specs: (none — implementation refinement of the ADR 0003 enforcement hook;
specs/ADRs unchanged)

## Context

The PreToolUse hook `plugins/loom/hooks/git-identity-guard.sh` (landed a47bf95)
enforces ADR 0003's uniform commit identity by blocking (exit 2) any git-bearing
command that contains an identity-override vector. Its current detection
(lines 63–87) fires on `--author`/`--author=`, `-c user.*=`, `-c GIT_AUTHOR*/GIT_COMMITTER*=`,
and inline/exported `GIT_AUTHOR_*`/`GIT_COMMITTER_*` — **regardless of which git
subcommand** is being run.

This produces a known false-positive (Open MINOR in `.docs/status/progress.md`,
"Guard `--author` pattern not scoped to commit-creating subcommands"): read-only
commands where `--author` is a legitimate filter — `git log --author=alice`,
`git shortlog -sn --author=bob`, `git blame --author x` — are wrongly blocked. The
override is only meaningful on subcommands that *create commits and honor
author/committer identity*; on a read command `--author` is a filter, and a
`-c user.*=`/`GIT_*` override is harmless (it changes nothing recorded).

**This slice** adds subcommand scoping to the existing detection: parse the git
subcommand from the already-de-quoted command and run override-detection **only**
when the subcommand is commit-creating. Everything else is unchanged.

**Out of scope / must stay intact:**
- The stdin read, `tool_input.command` extraction (jq path + grep/sed fallback,
  lines 21–34).
- The three-stage de-quote transform — Stage A escaped-quote removal, Stage B
  quoted-body stripping, Stage C odd-quote-count fail-open (lines 36–47).
- The git-word / env-var gate (lines 49–61).
- The four detection patterns themselves (lines 66, 72, 78, 84) — their *regexes*
  do not change; only the condition under which they are *consulted* changes.
- The block messages and exit codes (BLOCK=2, ALLOW=0).
- No edits to `hooks.json`, specs, ADRs, or `commit-convention.md` (the convention
  text already describes the rule correctly; the override paths it forbids are still
  forbidden — they are just only *enforceable by the hook* on commit-creating
  subcommands, which matches reality, since that is the only place they take effect).

## The rule this slice implements

1. **Determine the subcommand** from `$STRIPPED` (the de-quoted command): it is the
   first bare token after the `git` word that is NOT:
   - a leading `VAR=value` environment assignment (e.g. `GIT_AUTHOR_NAME=foo`,
     `FOO=bar`) appearing *before* `git`;
   - a git **global option** or its consumed value. Global options to skip:
     - `-c <key=val>` and `-c<key=val>` — also skip the `key=val` token if `-c` is
       separate;
     - `-C <path>` — skip the path token;
     - `--git-dir[=...]`, `--work-tree[=...]`, `--namespace[=...]`,
       `--exec-path[=...]`, `--config-env[=...]` — skip the following token when the
       `=` form is not used;
     - bare switches with no value: `-p`, `--paginate`, `-P`/`--no-pager`,
       `--bare`, `--no-replace-objects`, `--literal-pathspecs`,
       `--no-optional-locks`, `--html-path`, `--man-path`, `--info-path`,
       `--version`, `--help`.
2. **Commit-creating subcommand set** (the *only* values that trigger detection):
   `commit`, `commit-tree`, `am`, `cherry-pick`, `revert`, `rebase`, `merge`.
   Rationale: these create commits and honor author/committer identity, so an
   identity override on them actually changes recorded history. (`tag` and
   `notes add` were considered: `git tag` records *tagger* identity, not
   author/committer, and `notes` does not honor `--author`; they are **excluded**
   to keep the set to the vectors this slice's matrix exercises. If a future slice
   wants tagger-identity coverage it can extend this set — recorded in Notes.)
3. **Apply override-detection ONLY** when the determined subcommand is in that set.
   For any other subcommand (`log`, `shortlog`, `blame`, `show`, `diff`, `status`,
   `config`, `push`, …) → ALLOW (exit 0), even if an override vector's text is
   present.
4. **Fail-open posture (explicit):** if the subcommand cannot be determined cleanly
   — no bare token found after `git`, or an unrecognized global-option form leaves
   parsing ambiguous — **fail OPEN (allow, exit 0)**, never block. This matches the
   hook's existing defense-in-depth design: the binding rule lives in
   `commit-convention.md` (ADR 0003); the hook is best-effort and must never block on
   ambiguous parsing. This is a deliberate trade: an ambiguous *commit* override that
   slips the hook is still forbidden by the doc layer, whereas blocking an ambiguous
   *read* is the very regression this slice removes.

## Steps

All steps touch only `plugins/loom/hooks/git-identity-guard.sh`. The script is POSIX
`sh`; keep it POSIX (no bash arrays, no `[[ ]]`). Insert the new logic **between**
the git-word gate (ends line 61) and the override-detection block (begins line 63).

1. **Add a subcommand-extraction step after line 61** (after the `IS_GIT` gate,
   before `# --- Override detection ---`). Tokenize `$STRIPPED` on whitespace via a
   `for` loop over an unquoted expansion (word-splitting is intended here, and the
   command is already de-quoted so embedded spaces in operands have been removed
   with their quotes). Walk tokens with a small state machine:

   - Track whether we have passed the `git` word yet (`SEEN_GIT`).
   - **Before `git`:** skip any token matching `^[A-Za-z_][A-Za-z0-9_]*=` (leading
     env assignment). If a token equals `git` (whole word), set `SEEN_GIT=1` and
     continue. Any other pre-git token → we are not at a recognizable `git ...`
     invocation cleanly (e.g. `git` is mid-pipeline); set `SUBCMD=""` and stop
     (fail-open handles it). Note: the `IS_GIT` gate already guaranteed a `git`
     word *somewhere*; this loop locates the *invocation* `git`.
   - **After `git`, skip global options + consumed values** with a `SKIP_NEXT`
     flag:
     - if `SKIP_NEXT=1`: clear it and continue (this token was an option value);
     - `-c` exactly → set `SKIP_NEXT=1`, continue;
     - `-c*` (joined, e.g. `-cuser.email=x`) → continue (value joined, nothing to
       skip);
     - `-C` exactly → set `SKIP_NEXT=1`, continue;
     - `--git-dir`, `--work-tree`, `--namespace`, `--exec-path`, `--config-env`
       (no `=`) → set `SKIP_NEXT=1`, continue;
     - `--git-dir=*`, `--work-tree=*`, `--namespace=*`, `--exec-path=*`,
       `--config-env=*`, `-c=*` → continue;
     - value-less switches (`-p`, `--paginate`, `-P`, `--no-pager`, `--bare`,
       `--no-replace-objects`, `--literal-pathspecs`, `--no-optional-locks`,
       `--html-path`, `--man-path`, `--info-path`, `--version`, `--help`) →
       continue;
     - any other token beginning with `-` → unrecognized global option: set
       `SUBCMD=""` and stop (fail-open);
     - **first non-option token** → this is the subcommand: set `SUBCMD=$tok` and
       break.

   Sketch (illustrative; final form must be POSIX-clean and tested):

   ```sh
   # --- Determine git subcommand (override-detection is commit-scoped) ---
   SUBCMD=""
   SEEN_GIT=0
   SKIP_NEXT=0
   for tok in $STRIPPED; do
       if [ "$SEEN_GIT" -eq 0 ]; then
           case "$tok" in
               [A-Za-z_]*=*) continue ;;     # leading VAR=value env assignment
               git) SEEN_GIT=1; continue ;;
               *) SUBCMD=""; break ;;         # not a clean `git ...` invocation
           esac
       fi
       if [ "$SKIP_NEXT" -eq 1 ]; then SKIP_NEXT=0; continue; fi
       case "$tok" in
           -c)  SKIP_NEXT=1; continue ;;
           -C)  SKIP_NEXT=1; continue ;;
           --git-dir|--work-tree|--namespace|--exec-path|--config-env)
                SKIP_NEXT=1; continue ;;
           -c*|-C*|--git-dir=*|--work-tree=*|--namespace=*|--exec-path=*|--config-env=*)
                continue ;;
           -p|--paginate|-P|--no-pager|--bare|--no-replace-objects|--literal-pathspecs|--no-optional-locks|--html-path|--man-path|--info-path|--version|--help)
                continue ;;
           -*)  SUBCMD=""; break ;;           # unrecognized global option → fail open
           *)   SUBCMD="$tok"; break ;;        # first bare token = subcommand
       esac
   done
   ```

   Note the `-c*`/`-C*` joined-form arms must come *after* the exact `-c`/`-C` arms
   in the `case` (order matters — exact match first).

2. **Gate the four override checks on the commit-creating set.** Replace the bare
   sequence of four `if … exit 2` blocks (lines 63–87) so they run only when
   `$SUBCMD` is commit-creating. Wrap them in a single guard:

   ```sh
   case "$SUBCMD" in
       commit|commit-tree|am|cherry-pick|revert|rebase|merge)
           # ... the existing four override-detection if-blocks, verbatim ...
           ;;
   esac
   # --- No override detected (or non-commit subcommand) → allow ---
   exit 0
   ```

   The four inner `if` blocks (their regexes and `exit 2` messages) are **unchanged**
   — only their enclosing condition is added. If `$SUBCMD` is empty (fail-open) or
   any non-commit subcommand, the `case` falls through to the final `exit 0`.

3. **Update the script's header comment** (lines 1–18) to document the new behavior:
   add a short block stating that override-detection is scoped to commit-creating
   subcommands (`commit`, `commit-tree`, `am`, `cherry-pick`, `revert`, `rebase`,
   `merge`), that read subcommands like `log`/`shortlog`/`blame` are allowed even
   with `--author`, and that an undeterminable subcommand fails OPEN. Keep the
   existing de-quote-transform comment intact.

4. **Keep the file executable** (`chmod +x` already set; do not regress the mode).
   Do not touch `hooks.json`.

## Verification

This slice is script-runnable; the developer **must** run the full matrix below by
piping crafted JSON to the script and asserting the exact exit code each time, and
**record the observed exit code** for every case. BLOCK = exit 2, ALLOW = exit 0.

Drive each case with stdin shaped like the real hook payload, e.g.:

```sh
printf '{"tool_input":{"command":"git log --author=alice"}}' \
  | sh plugins/loom/hooks/git-identity-guard.sh; echo "exit=$?"
```

### A. New behavior — read subcommands now ALLOW (the bug this fixes)

Each must exit **0**. A non-zero here is a MAJOR (the false-positive being removed).

1. `git log --author=alice` → ALLOW
2. `git shortlog -sn --author=bob` → ALLOW
3. `git blame --author x` → ALLOW
4. `git blame -L1,2 file` → ALLOW
5. `git -c user.email=x@y log` → ALLOW (harmless override on a read)
6. `GIT_AUTHOR_NAME=foo git log` → ALLOW (leading env, read subcommand)
7. `git show --format=%an HEAD` → ALLOW
8. `git config user.name` → ALLOW (read of config; `config` is not commit-creating)

### B. Commit-creating subcommands still BLOCK (no false-negative)

Each must exit **2**. A non-zero failure to block here is a BLOCKER (false-negative —
a real commit-time override slips through).

9.  `git commit --author="x <x@y>" -m z` → BLOCK
10. `git -c user.email=x@y commit -m z` → BLOCK (global `-c` skipped, `commit` found)
11. `git -c user.name=x cherry-pick abc` → BLOCK (commit-creating)
12. `GIT_AUTHOR_NAME=foo git commit -m z` → BLOCK (leading env skipped, `commit`)
13. `git -c GIT_COMMITTER_NAME=x commit -m z` → BLOCK (`-c GIT_COMMITTER*` on commit)
14. `git revert --author="x <x@y>" HEAD` → BLOCK
15. `git rebase -c user.email=x@y main` → BLOCK
16. `git merge --author="x <x@y>" topic` → BLOCK
17. `git am --committer-date-is-author-date < p` with `GIT_AUTHOR_EMAIL=x git am ...`
    — i.e. `GIT_AUTHOR_EMAIL=x git am file` → BLOCK

### C. Regression — prior matrix BLOCK cases (commit subcommand, unchanged)

Each must exit **2** exactly as before this slice:

18. `git commit -m "msg" --author='A B <a@b>'` → BLOCK
19. `git -c user.name="A B" commit -m x` → BLOCK
20. `GIT_COMMITTER_EMAIL=a@b git commit -m x` → BLOCK

### D. Regression — prior ALLOW cases (de-quote / message-text / non-git) unchanged

Each must exit **0**:

21. `git commit -m "fix --author= handling in docs"` → ALLOW (override text is inside
    a quoted message; Stage B strips it before detection)
22. `git commit -m "set GIT_AUTHOR_NAME in the script"` → ALLOW (text in message)
23. `git commit -m 'add -c user.email note'` → ALLOW (text in message)
24. `git commit -m "escaped \"--author\" mention"` → ALLOW (Stage A/B)
25. `echo --author=foo` → ALLOW (non-git)
26. `ls -c user.name=x` → ALLOW (non-git)
27. `git commit -m "unbalanced quote --author` → ALLOW (Stage C odd-quote fail-open)

### E. Fail-open on undeterminable subcommand

Each must exit **0** (ambiguous parse → allow, per the documented posture):

28. `git --some-unknown-global commit --author=x` → ALLOW (unrecognized global opt →
    `SUBCMD` cleared → fail open). Record this explicitly to prove the fail-open
    branch.
29. `git` (no subcommand) → ALLOW (no bare token found).

### F. jq-absent fallback

30. Re-run a representative BLOCK case (#9) and a representative ALLOW case (#1) with
    `jq` masked from `PATH` (e.g. invoke with a `PATH` lacking jq, or temporarily
    shadow it) to exercise the grep/sed extraction branch (lines 27–28). Assert
    #9 → BLOCK (exit 2) and #1 → ALLOW (exit 0) via the fallback path.

### Gate

This repo has no compiled gate (`CLAUDE.md`). The acceptance gate for this slice is:
**all 30 checks above pass with the asserted exit codes, recorded in the
implementation handoff.** Any case A/D/E ALLOW that blocks → FAIL (MAJOR/regression);
any case B/C BLOCK that allows → FAIL (BLOCKER/false-negative).

## Notes

- 2026-06-08 (planner): `tag` and `notes add` are intentionally **excluded** from the
  commit-creating set. `git tag` records *tagger* identity (not author/committer) and
  does not honor `--author`; `git notes` does not honor `--author` either. The
  override vectors this guard blocks (`--author`, `-c user.*`, `GIT_AUTHOR_*`/
  `GIT_COMMITTER_*`) only alter recorded *author/committer* identity on the seven
  subcommands listed. If a future slice decides tagger-identity should also be
  uniform, it can extend the set and the matrix — flagged, not done here.
- 2026-06-08 (planner): the fail-open-on-ambiguity posture is a deliberate choice
  (see "The rule …" §4). It is consistent with ADR 0003's binding doc-layer rule and
  the existing Stage-C fail-open; the hook is best-effort defense-in-depth, never the
  sole guarantee.

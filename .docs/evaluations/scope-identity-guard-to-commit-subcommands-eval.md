# Evaluation: scope-identity-guard-to-commit-subcommands

Verdict: PASS
Round: 1
Reviewed against: the artifact `plugins/loom/hooks/git-identity-guard.sh` (current
shipped form, commit a47bf95), ADR 0003 (uniform author-neutral identity), the prior
guard eval rounds in `.docs/evaluations/author-identity-enforcement-guard-eval.md`
(esp. Round-4 MINOR recommending this exact refinement), and the Open MINOR in
`.docs/status/progress.md` ("Guard `--author` pattern not scoped to commit-creating
subcommands"). The proposed POSIX parser plus the gated four-check detection were
**independently re-implemented from the plan text alone** and exercised against the
full 30-case matrix, the eight task trace cases, the jq-absent fallback branch, and
additional adversarial false-negative/false-positive probes. Findings cite observed
exit codes and traced `$SUBCMD` values, not the plan's assertions.

## Subcommand-detection trace (task §1 — independently run)

Each detected subcommand below comes from running the plan's `for`-loop state
machine verbatim against the post-de-quote `$STRIPPED`:

| Command | Detected `$SUBCMD` | Decision |
|---|---|---|
| `git -c user.email=x@y commit -m z` (separate `-c` + key tokens) | `commit` | BLOCK ✓ |
| `git -c user.email=x@y log` | `log` | ALLOW ✓ |
| `GIT_AUTHOR_NAME=foo git commit -m z` | `commit` | BLOCK ✓ |
| `GIT_AUTHOR_NAME=foo git log` | `log` | ALLOW ✓ |
| `git --no-pager log --author=x` | `log` | ALLOW ✓ |
| `git -C /some/path commit --author="x <x@y>"` | `commit` | BLOCK ✓ |
| `git log --author=alice` | `log` | ALLOW ✓ |
| `git shortlog -sn --author=bob` | `shortlog` | ALLOW ✓ |
| `git blame -L1,2 f --author x` | `blame` | ALLOW ✓ |
| `GIT_COMMITTER_EMAIL=z@z git cherry-pick -x abc` | `cherry-pick` | BLOCK ✓ |

All ten correct. The `-c` value-consumption logic (`SKIP_NEXT` on bare `-c`, the
joined `-c*` arm placed *after* the exact `-c` arm) correctly skips the separate
`user.email=x@y` token without swallowing `commit`, and leading `VAR=value` env
assignments before `git` are skipped without losing the subcommand after `git`.

## False-negative hunt (task §2 — BLOCKER if found; none found)

End-to-end, gated detection BLOCKs (exit 2) every real commit-time override:
`git commit -m z --author=evil` (flag after message), `git -c core.pager=cat -c
user.name=Evil commit` (identity `-c` buried behind a benign `-c`), `git -C /tmp -c
user.email=x@y commit`, `git --no-pager commit --author=evil`, `GIT_AUTHOR_NAME=x
GIT_COMMITTER_EMAIL=y git commit`, `git cherry-pick --author=evil abc`, `git -c
user.email=x@y rebase main`, `git -c GIT_AUTHOR_NAME=x commit`, all on the seven
commit-creating subcommands. **No false-negative found.**

- **A clean `git commit --author=…` never fails open.** With no leading env and no
  global options, the loop reaches `commit` as the first bare token immediately;
  `$SUBCMD=commit` ⇒ the four checks run. Verified: `git commit --author=evil -m z`
  → 2, `git commit -m "msg" --author='A B <a@b>'` (case 18) → 2.
- **`commit` is never consumed as an option value on a *valid* invocation.** The
  only way `commit` gets eaten is `git -c commit …`, where `-c` takes `commit` as its
  config string — but `-c` requires `key=value`, so git itself rejects that
  (`fatal`), and no commit is created. That path fails open by design, and the doc
  layer remains authoritative; it is not a reachable identity-override hole.

## False-positive check (task §3 — all read cases ALLOW)

`git log --author=alice`, `git shortlog -sn --author=bob`, `git blame --author x`,
`git blame -L1,2 file`, `git -c user.email=x@y log`, `GIT_AUTHOR_NAME=foo git log`,
`git show --format=%an HEAD`, `git config user.name`, `git diff --author=x`, `git -c
user.email=x@y shortlog` — all exit 0. This is exactly the regression the Open MINOR
asks to close, and it is closed.

## Fail-open posture (task §4)

Justified and explicitly documented (§"The rule" 4 + Notes 2026-06-08). An
unrecognized global option clears `$SUBCMD` and breaks (case 28 → 0); no bare token
after `git` ⇒ empty `$SUBCMD` (case 29 → 0); the `case` falls through to the final
`exit 0`. This is consistent with the existing Stage-C fail-open and ADR 0003's
binding doc layer. The trade — an ambiguous *commit* override may slip the hook (still
forbidden by `commit-convention.md`) versus never blocking an ambiguous *read* — is
stated plainly and is the right call for a best-effort defense-in-depth hook.

## Verification matrix (task §5 — concrete, runnable, complete)

Sections A (read-ALLOW ×8), B (commit-BLOCK ×9 across all seven subcommands), C
(prior BLOCK regressions ×3), D (prior ALLOW regressions ×7 incl. message-text,
escaped-quote, non-git, odd-quote fail-open), E (fail-open ×2), F (jq-absent
fallback) are each driven by piped hook-shaped JSON with the exact-exit-code
assertion recorded. I ran all 30: **30/30 match** (read/ALLOW → 0, commit/BLOCK → 2,
fail-open → 0). The jq-absent branch was genuinely exercised by forcing the grep/sed
path: BLOCK #9 → 2, ALLOW #1 → 0, BLOCK #10 → 2. The matrix preserves every prior
Round-1..4 regression (message-text and escaped-quote ALLOW, the original
`commit --author=` / `-c user.*` / inline-env BLOCKs) and adds the new read-ALLOW
and per-subcommand BLOCK coverage. No matrix gap found.

## Scope (task §6)

Steps touch only `git-identity-guard.sh` (insert the parser between line 61 and the
detection block; wrap the four unchanged `if` blocks in one `case`; update the header
comment; preserve the mode). The plan explicitly forbids edits to `hooks.json`,
specs, ADRs, and `commit-convention.md`, with a sound rationale (the convention text
already describes the rule; the override paths it forbids only *take effect* on
commit-creating subcommands, so hook scope now matches reality). Single-purpose;
playbook-conformant (correct `Status:` line, location, naming).

## Findings

- [MINOR] **Sketch pre-git glob differs from prose, harmlessly.** The prose (§"The
  rule" 1) writes the leading-env pattern as `^[A-Za-z_][A-Za-z0-9_]*=`; the code
  sketch uses `case "$tok" in [A-Za-z_]*=*)`. The glob is looser (it also matches a
  hypothetical `foo.bar=baz`-shaped token), but it is consulted **only before the
  `git` word**, and the subcommand is always located *after* `git`, so it can never
  eat the subcommand. The implementer should keep the sketch's glob (POSIX `case`
  has no anchored-regex equivalent) — flagging only so the prose/sketch discrepancy
  is a known, intended simplification, not a bug to "fix" into something non-POSIX.
  Non-blocking.

- [MINOR] **`commit-tree` is in the gated set but not in the matrix.** Section B
  exercises six of the seven commit-creating subcommands (`commit`, `cherry-pick`,
  `rebase`, `merge`, `am`, and `revert`); `commit-tree` is asserted in the set
  (§2) but has no dedicated BLOCK row. It is a low-level plumbing command rarely
  given `--author`/`-c user.*` interactively, and detection is subcommand-agnostic
  once `$SUBCMD` matches the `case`, so coverage of the other six demonstrates the
  mechanism. Adding one `git -c user.email=x@y commit-tree …` → BLOCK row would make
  the matrix exhaustive over the declared set. Non-blocking.

## Verified correct (no findings)

- Parser is POSIX-clean (`sh -n` and `dash -n` both exit 0); no bash arrays, no
  `[[ ]]`. Order of the `case` arms (exact `-c`/`-C` before joined `-c*`/`-C*`) is
  correct and load-bearing, and the plan calls it out.
- The four detection regexes and `exit 2` messages are reused verbatim; only their
  enclosing `case "$SUBCMD"` condition is added — exactly the minimal change.
- The pre-existing stages this slice must not disturb (stdin/jq+grep extraction,
  three-stage de-quote, Stage-C odd-quote fail-open, git-word/env gate) are listed
  as out-of-scope and are untouched by the proposed insertion point (between line 61
  and the old line 63).
- Commit-creating set rationale (author/committer-honoring subcommands; `tag`/`notes`
  excluded with recorded reasoning) is accurate: `tag` records *tagger* identity and
  `notes` does not honor `--author`, so the blocked vectors do not alter recorded
  author/committer identity there — correct to exclude, and the exclusion is flagged
  for a future slice rather than silently dropped.

## Verdict rationale

The proposed parser, re-derived from the plan text and run independently, correctly
detects the subcommand in all ten task trace cases, passes the full 30-case
verification matrix 30/30 (read-ALLOW, commit-BLOCK across the set, prior-matrix
regressions, fail-open, and the genuinely-exercised jq-absent fallback), and survives
adversarial false-negative probing with **no real commit-time identity override
slipping to ALLOW** and **no legitimate read or message-text command blocked**. A
clean `git commit --author=` never fails open; the only fail-open paths are
invalid-git or genuinely-ambiguous invocations, consistent with the documented and
ADR-0003-backed defense-in-depth posture. Scope is confined to the script (+ header
comment) with specs/ADRs/`hooks.json`/convention untouched. No BLOCKER, no MAJOR; two
non-blocking MINORs (prose/sketch glob note; add a `commit-tree` BLOCK row). PASS.

## Required changes

None for PASS. The two MINORs are optional polish.

---

# Evaluation: scope-identity-guard-to-commit-subcommands (Round 2 — code)

Verdict: FAIL
Round: 2
Reviewed against: the slice-plan `scope-identity-guard-to-commit-subcommands.md`
(scope + acceptance authority), the prior guard evals
(`author-identity-enforcement-guard-eval.md` Rounds 1–4 and this file's Round 1),
and ADR 0003. This round reviews the **shipped artifact** at commit `5b07567` — the
committed `plugins/loom/hooks/git-identity-guard.sh` was executed against crafted
hook-shaped JSON stdin, not a prototype re-derived from the plan. Every exit code
below is observed from the committed script; the pre-slice script (`5b07567^`) was
also run to establish regression direction. Per the mechanical-check rule, I ran the
guard rather than trusting the diff or the developer's recorded matrix.

## Gate (re-run, not trusted)

- `sh -n` → exit 0; `dash -n` → exit 0. POSIX-clean.
- `#!/bin/sh`; mode `-rwxr-xr-x` (executable, not regressed).
- `git show --name-only 5b07567` → only `git-identity-guard.sh` + the slice-plan.
  No edit to `hooks.json`, specs, ADRs, or `commit-convention.md`. Scope clean.

## Plan-matrix replay (committed script, observed exit codes)

The developer's 30-case matrix replayed 33/33 against the shipped script: read
subcommands A1–A10 → 0; commit-creating B1–B14 (commit, commit-tree, am,
cherry-pick, revert, rebase, merge, with `--author`/`-c user.*`/`-c GIT_*`/inline-env
vectors) → 2; regression-ALLOW D1–D7 (message-text, escaped-quote, unbalanced-quote
fail-open, non-git) → 0; fail-open E1–E2 → 0. The jq-absent fallback was **genuinely
exercised** with a curated PATH (real `/usr/bin` symlinks for sh/cat/grep/sed/tr/wc/head,
`command -v jq` fails): BLOCK `git commit --author=evil -m z` → 2, BLOCK
`git -c user.email=x@y commit -m z` → 2, BLOCK `GIT_AUTHOR_NAME=foo git commit -m z`
→ 2, ALLOW `git log --author=alice` → 0, ALLOW `git commit -m z` → 0. The
read-subcommand false-positive this slice targets is genuinely fixed (A1–A10, plus
`git -c user.email=x@y log --author=alice`, `git diff --author=x`, `git stash`,
`git push`, `git log commit --author=alice`, all → 0). The declared-set
`commit-tree` BLOCK row (Round-1 MINOR) is now present and passes.

So far as the plan's own matrix goes, it holds. **But the plan's matrix has a gap,
and the new parser regresses a class of real overrides the prior guard caught.**

## [BLOCKER] Reachable commit-time identity overrides now reach exit 0 (false-negative + silent regression)

The new subcommand parser (lines 80–101) requires that the only tokens permitted
*before* the `git` word are leading `VAR=value` env assignments; **any other
pre-`git` token hits the `*) SUBCMD=""; break` arm (line 85) and fails open.** As a
result, every command that places a shell prefix before `git commit` now ALLOWS,
including reachable identity overrides that the **pre-slice script BLOCKED**. Each
override below was verified reachable in a throwaway repo (it changes the recorded
author/committer), and each pre-slice exit code was observed by running
`5b07567^`'s script:

| Command | Pre-slice | Shipped | Reachable override? |
|---|---|---|---|
| `export GIT_AUTHOR_NAME=Evil; git commit -m z` | 2 | **0** | yes — recorded `author=Evil` confirmed |
| `export GIT_COMMITTER_EMAIL=x@y; git commit -m z` | 2 | **0** | yes |
| `cd /tmp && git commit --author=evil -m z` | 2 | **0** | yes (`--author` is a valid commit flag) |
| `true; git commit --author=evil -m z` | 2 | **0** | yes |
| `env GIT_AUTHOR_NAME=Evil git commit -m z` | 2 | **0** | yes — recorded `author=Evil` confirmed |
| `sudo git commit --author=evil` | 2 | **0** | yes |

These are not contrived or git-rejected forms. `cd … && git commit --author=`,
`export VAR=…; git commit`, and `env VAR=x git commit` are ordinary, valid command
strings a Bash-tool invocation can emit, and each lands a genuine identity override
on the resulting commit. The task's decision rule is explicit: *a false-negative
(real override → ALLOW) = BLOCKER*. The rubric independently flags it: *"No silent
regressions — existing behavior preserved."* This slice silently dropped guard
coverage that shipped and passed Round 4 (case C5,
`export GIT_COMMITTER_EMAIL=x@y; git commit -m z` → 2, is now 0).

Root cause: the parser couples "locate the `git` invocation" to "the command must
*begin* with `git` (optionally after leading env assignments)". The old script ran
the four detection regexes on the whole de-quoted `$STRIPPED` unconditionally; it
did not care where `git` sat in a compound command. The new gating is correct in
*intent* (only fire on commit-creating subcommands) but the *locator* is too strict
about the pre-`git` region and fails open on any shell prefix instead of either
(a) skipping benign prefixes to find the `git commit`, or (b) at minimum, retaining
the pre-slice behavior for the inline/exported `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env
vector, which is unambiguous wherever it appears.

This is faithful to the plan's parser *sketch* (lines 84–86 specify exactly the
`*) SUBCMD=""; break` arm), but the plan's Verification matrix never exercised a
shell-prefixed `git commit`, so the regression was not caught at plan time either.
The fix may need a small plan amendment (how to treat pre-`git` tokens / compound
commands), but the shipped behavior as-is loses real, previously-guarded coverage,
so the slice cannot land. Rated BLOCKER (reachable false-negative + silent
regression of a shipped, Round-4-verified BLOCK case).

## Adversarial probes that are NOT defects (recorded for completeness)

- `git -cuser.email=x@y commit -m z` → 0. The joined `-c<key>=<val>` form is
  **rejected by git itself** (`unknown option: -cuser.email=…`, exit 129, no commit
  created) — git's `-c` requires a space-separated value. Not a reachable override;
  fail-open is acceptable. (The parser's `-c*` arm treats it as a consumed global,
  which is harmless since git won't run it.)
- `git commit -m z -- --author=evil` → 2 (over-block). After `--`, `--author=evil`
  is a pathspec, not an identity flag (git errors). Blocking a git-invalid command is
  harmless. Not a defect.
- `git -c commit --author=evil` / `git -C commit --author=evil` → 0. `-c`/`-C`
  consume `commit` as their value; git rejects (`-c` needs `key=value`). No commit
  created; fail-open acceptable.
- `git tag`/`git notes` with override vectors → 0, the documented intentional
  exclusion (tagger identity, not author/committer). Correct per plan §2 + Notes.
- All read subcommands with `--author`/identity-`-c`/leading-env → 0. The target
  false-positive is genuinely fixed.

## Scope / hygiene

In scope (script + slice-plan only). Commit is author-neutral, single-slice. The
header-comment update and the gated `case` wrapping of the four verbatim detection
`if` blocks are exactly the plan's Steps 2–3. The defect is in the new parser logic,
not in scope or hygiene.

## Verdict rationale

The slice fixes the read-subcommand false-positive it set out to fix (verified
across A1–A10 and more, plus a genuinely-exercised jq-absent fallback), and the
plan's own 30-case matrix replays clean. **But** the new pre-`git` locator fails open
on any shell prefix, and independent adversarial probing found **reachable
commit-time identity overrides that now reach exit 0** —
`export GIT_AUTHOR_NAME=…; git commit`, `env GIT_AUTHOR_NAME=… git commit`,
`cd … && git commit --author=`, `true; git commit --author=`,
`sudo git commit --author=` — each verified to change recorded identity and each
**BLOCKED by the pre-slice script** (one is the Round-4-verified case C5). That is a
reachable false-negative and a silent regression of shipped coverage. Per the task
("false-negative = BLOCKER") and the rubric ("no silent regressions"), this is a
BLOCKER. FAIL.

## Required changes (for FAIL)

1. **Eliminate the false-negative on shell-prefixed `git commit`.** The subcommand
   locator must not fail open merely because a benign token precedes `git`. At
   minimum, restore pre-slice coverage for the cases that regressed:
   - `export GIT_*=…; git commit …`, `env GIT_*=… git commit …`,
     `cd … && git commit --author=…`, `<stmt>; git commit --author=…`,
     `sudo git commit --author=…` must BLOCK (exit 2) again.
   Options to consider (a plan amendment may be warranted): scan for the `git` word
   anywhere in `$STRIPPED` and parse the subcommand from the token *after* it
   (rather than requiring the command to begin with `git`); and/or keep the inline
   `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env-var detection unconditional (it is
   unambiguous wherever it appears and changes nothing on a read). Whatever the
   approach, it must not re-introduce the read-subcommand false-positive.
2. **Add the regressed forms to the verification matrix** so the fix is proven:
   at minimum `export GIT_AUTHOR_NAME=x; git commit -m z` → 2,
   `env GIT_AUTHOR_NAME=x git commit -m z` → 2,
   `cd /tmp && git commit --author=evil` → 2, and a read counterpart
   (`cd /tmp && git log --author=alice` → 0) to confirm no new false-positive.
3. Re-run the full matrix (including the jq-absent fallback) and record observed
   exit codes.

The two Round-1 MINORs (prose/sketch glob; `commit-tree` row) are already addressed
or non-blocking; no further action needed on them.

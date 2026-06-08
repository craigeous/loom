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

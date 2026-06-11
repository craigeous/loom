# Review findings — precompact-write-ahead-backstop

Identity-neutral capture of the orchestrator-run automated review (ADR 0010/0011)
on the slice's commit range (`origin/HEAD..HEAD`, code files only). Advisory input
to the blind code-evaluator; the evaluator confirms/rejects each and owns the verdict
per `severity.md`. Both commands ran locally on the committed diff (no PR, no
`--comment`/`--fix`).

## /code-review
Status: ran-with-findings

### Finding 1
- source: /code-review
- location: plugins/loom/hooks/precompact-write-ahead-backstop.sh:101-111
- description: The manual no-progress block prints a remediation whose option 2 is
  "Re-run /compact if this block was spurious." But the hook is deterministic on
  identical state and **does not advance the marker on a block** (by design), so
  re-running a `manual` /compact with no new `.docs/` commit yields the identical
  `exit 2`. The only way past a manual no-progress block is to commit a `.docs/`
  change — there is no functioning spurious-case override. An operator (or the
  orchestrator itself) that follows remediation option 2 loops. Consider either
  correcting the text (drop the non-functional "re-run" escape) or adding a real
  override (e.g. an env-flag bypass, or allow-once on a repeated manual attempt).
- confidence: high

### Finding 2
- source: /code-review
- location: plugins/loom/hooks/precompact-write-ahead-backstop.sh:116
- description: `session_id` (from stdin) is written into the tab-separated log line
  via `printf '%s\t%s\t%s\n'`; a value containing a tab or newline would corrupt the
  log's line/field structure. Input is harness-supplied (low risk) and this is a
  data-shape nit, not a security issue — `/security-review` excludes it as log
  spoofing. Optional hardening: strip control chars from `session_id` before logging.
- confidence: low

### Finding 3
- source: /code-review
- location: plugins/loom/hooks/precompact-write-ahead-backstop.sh:114-116
- description: `precompact.log` is append-only with no bound or rotation; over a very
  long-lived checkout it grows unboundedly. Negligible (one short line per no-progress
  `auto` event) and DoS-class, so out of scope for the security pass — noted only for
  completeness.
- confidence: low

## /security-review
Status: ran-clean

No HIGH/MEDIUM vulnerabilities. The hook's only external input is the PreCompact
stdin JSON, supplied by the Claude Code harness (semi-trusted, not an external
attacker); `cwd`/`compaction_trigger`/`session_id` are used only as a `cd` target
(quoted), a branch selector, and a `printf '%s'` log field — no command
interpolation, `eval`, deserialization, secret, or crypto surface. Per the security
review's own policy, log-spoofing, DoS/unbounded-log, and shell-script command
injection from trusted input are not reportable here.

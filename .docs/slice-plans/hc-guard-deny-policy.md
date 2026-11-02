# Herdr `hc` Client (1 of 4): Role-Session `hc` Deny Policy

Status: Approved
Target specs: 08-playbook.md (hook wire, `hc` deny), 07-command-surface.md (Host surfaces)
Authority: ADR 0031 §4 (Accepted); program ceiling and split: ADR 0031 §8 items 1–4 become four slices
Target size: <= 140 LOC added (guard + Bats; deletions not counted); keep this plan <= 250 lines

## Context

ADR [0031](../ADR/0031-herdr-as-an-hc-driven-client.md) and amended spec 08 require
that no role session can call `hc`: a deny-by-default `PreToolUse` guard, with no
allowlist and no verb parsing. The research note
[hc runtime reference](../research/2026-11-01-hc-agent-runtime-reference.md) lists
the verbs that start programs or mutate state (`run exec send kill rm keys interrupt
attach file machine server update label keep put connect`); a verb list is therefore
not a policy. `plugins/loom/hooks/role-governance-guard.sh` today blocks only test
runners (orchestrator) and git mutation (evaluators), and it strips quoted words
before matching, so `sh -c "hc ls"` would never reach a command-word match.

This is slice 1 of 4. The program split (owner decision, replaces the single plan
`herdr-hc-client`, now `Abandoned`): **1** this guard, **2** `hc-host-adapter`
(`loom-host-hc`; owns the v0.3.0 matrix `hostFloors` registration), **3** `hc-live-probe`, **4**
`herdr-surface-retirement`. Order: 1 and 2 are independent; 3 needs no code from
1–2; 4 lands last (it edits files 1 and 2 touch). Program ceiling across all four
slices: 900 LOC added; budgets do not transfer between slices.

## Out of Scope & Threat-Model Boundary

- The guard is **defense in depth, not a boundary** (spec 08; `.docs/spec/00-overview.md`
  Non-goals). It reads the command text only. **Residual, accepted and stated:** a
  command name built at run time (`h=h; ${h}c ls`, `$(printf 'h%s' c)`), a script file
  or alias that calls `hc`, a renamed copy or symlink of the binary, `herdr-app`, and
  direct use of the `hc` core socket are not visible to a text guard.
- **Deliberate false positive:** any bare word `hc` in a non-orchestrator command
  (for example `git commit -m "hc run"` or `echo hc`) is blocked. Fail closed is the
  owner decision; reword the text. Words that merely contain `hc` (`which-hc`,
  `hc.sh`, `abc`) are allowed.
- Unset or empty `LOOM_ROLE` still fails open; `orchestrator` is unaffected. Wire
  envelopes, root validation and the existing orchestrator/evaluator rules do not change.
- The retired Herdr branches in this file (`HERDR_PLUGIN_ROOT`, `herdr` client select)
  stay untouched; slice 4 removes them.
- No `hc` use by roles is enabled; no role runs on `hc` (ADR 0031 §5, §6).
- **Open blocker (retained, not resolved here):** Blind review through `hc` is an **unresolved owner decision** (ADR 0031 §5 and Consequences): the deny guard is necessary, not sufficient, and does not enforce blind review. Until a follow-up ADR records isolation or explicit degraded blindness, hc evaluator use is blocked and no evaluator role runs on `hc`.

## Steps

1. **`plugins/loom/hooks/role-governance-guard.sh`**: add the block below after the
   `[ -n "${LOOM_ROLE:-}" ] || _loom_hook_allow` line and **before** the `DEESC`/`STRIPPED`
   de-quote transform and before the quote-parity fail-open (so an unbalanced quote
   cannot bypass it). It scans the raw `$CMD`, never `STRIPPED`:

   ```bash
   HC_REASON="Loom policy: hc is orchestrator-only; role sessions cannot call hc."
   if [ "$LOOM_ROLE" != "orchestrator" ]; then
       HCSCAN=$(printf '%s' "$CMD" | tr -d "\"'\\\\" | tr '`$();&|<>{}' ' ')
       if printf '%s\n' "$HCSCAN" | grep -qE '(^|[[:space:]])([^[:space:]]*/)?hc([[:space:]]|$)'; then
           _loom_hook_block "$CLIENT" "$HC_REASON"
       fi
   fi
   ```

   Behavior: quote characters and backslashes are deleted (so `h"c"`, `h\c`, `'hc'`
   become `hc`); `` ` $ ( ) ; & | < > { } `` become spaces (so `` `hc ls` ``, `$(hc ls)`,
   `-exec hc {} ;` expose the word); the match is the bare word `hc` or any path ending
   in `/hc`, anywhere in the command, including inside `sh -c`/`bash -c`/`eval`
   strings, after `timeout N`, `xargs`, `nohup`, `env`, `command`, `exec`, `time`, and
   after `NAME=value` assignments. There is no allowlist and no verb parsing.
   `HC_REASON` is one line, <= 512 bytes. Update only the header POLICY comment
   (add `any non-orchestrator role -> any bare word hc`). Do not touch
   other logic, the `herdr` branches or the existing reasons.
2. **`plugins/loom/hooks/role-governance-guard.bats`**: add `hc_guard_denied
   <role> <command>` and `hc_guard_allowed` helpers that run both wires (Claude exit 2
   with `HC_REASON` on stderr; Codex exit 0 with a `deny` JSON containing
   `HC_REASON`) and assert both. One `@test` per form below; each loops over the roles
   `researcher planner plan-evaluator developer code-evaluator foo` (an unknown role
   is denied too):
   - direct: `hc ls`, `hc run --bg x claude`, `hc get t1 --json`
   - assignment/env prefixed: `A=1 hc ls`, `env A=1 hc get t1`, `A=1 env B=2 hc ls`,
     `env -i hc ls`, `command hc read t1`, `exec hc ls`, `time hc ls`
   - `sh -c`: `sh -c "hc ls"`, `sh -c 'hc kill t1'`, `sh -c "echo a; hc ls"`
   - `bash -c`: `bash -c "hc ls"`, `bash -lc 'hc send t1 x'`, `env -i bash -c "hc ls"`
   - `eval`: `eval "hc ls"`, `eval 'hc rm t1'`
   - backtick: `` echo `hc ls` ``, `` x=`hc get t1` ``
   - command substitution: `echo $(hc ls)`, `x=$(hc get t1); echo $x`
   - `timeout`: `timeout 5 hc wait t1`, `timeout -k 1 5 hc ls`
   - `xargs`: `echo t1 | xargs hc get`, `printf 't1\n' | xargs -I{} hc kill {}`
   - absolute/relative path: `/usr/local/bin/hc ls`, `/opt/homebrew/bin/hc kill t1`, `./hc ls`
   - chained/other: `ls && hc send t1 x`, `nohup hc wait t1`, `find . -exec hc\;`,
     `ls;hc ls`, `echo $(hc)`, `h"c" ls`, `h\c ls`
   - unbalanced quote does not bypass: `hc ls # '`
   Also in the same file:
   - allowed (both wires, every role): `echo abc`, `which-hc`, `./hc.sh`, `git status`,
     `rg -n chc plugins`
   - documented false positive (denied): `git commit -m "hc run"`, `echo hc`
   - `orchestrator` running `hc ls`, `/usr/local/bin/hc run --bg x claude`,
     `sh -c "hc ls"`: allowed on both wires
   - unset `LOOM_ROLE` running `hc ls`: allowed on both wires
   - existing orchestrator and evaluator tests pass unchanged (regression proof).
3. **Docs (finalize pass)**: no `CLAUDE.md` change (no project-wide rule changes). Update
   `.docs/slice-plans/README.md` active-plans index (orchestrator-owned on `main`;
   skip if not on `main`).

## Verification

- Iteration: `shfmt -i 4 -d -ln bash plugins/loom/hooks/role-governance-guard.sh`,
  `shellcheck -s bash plugins/loom/hooks/role-governance-guard.sh`,
  `bash -n plugins/loom/hooks/role-governance-guard.sh`, then
  `TMPDIR=/private/tmp bats plugins/loom/hooks/role-governance-guard.bats`.
- Mutation check (developer records the result): with the guard block removed, every
  new deny test fails; with only the `tr -d` quote removal removed, the `sh -c`,
  `bash -c`, `eval`, `h"c"` tests fail; with only the second `tr` removed, the backtick,
  `$(hc ls)`, `echo $(hc)`, `ls;hc ls` and `find . -exec hc\;` tests fail (each puts `hc`
  next to a punctuation character, so the bare-word match exists only after that
  character becomes a space; `find . -exec hc ls ;` is not used for this mutation because
  it matches without the second `tr`).
- Regression proof (unchanged, passing): the other hook Bats files and the Claude/Codex
  hook wire fixtures.
- Full gate once on the candidate commit: `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check`.
  The only failure the developer may record-and-rerun-once is the known unrelated
  `INT during a mutation yields exit 130` race in `macos-dual-client-dogfood.bats`
  (owner-declared out of scope); any other failure blocks `Implemented`. `rg -n -i herdr`
  in the diff must find nothing new.
- Developer evidence (commit `8c6868a`, guard + Bats; LOC 127 added, 0 deleted; target <= 140):
  - Targeted: `shfmt`, `shellcheck`, `bash -n` clean; `bats role-governance-guard.bats` 35/35 ok (20 existing + 15 new `hc:` tests).
  - Mutation A (block removed): 13 deny tests fail; allow tests pass.
  - Mutation B (`tr -d` quote strip removed): `sh -c`, `bash -c`, `eval`, chained/quote-obfuscated tests fail. The documented false-positive test also fails, because `"hc run"` only matches after quotes are stripped.
  - Mutation C (second `tr` removed): backtick, `$(hc ls)`, chained (`echo $(hc)`, `ls;hc ls`, `find -exec hc\;`) tests fail.
  - Full gate on `8c6868a`: RED (superseded). Those two failures were `validate-repository --all` exiting 1 on `.docs/` evaluation and ADR naming/frontmatter errors inherited from `main` (`e6248b2`).
  - Full gate after rebasing on `main` `a1431ed`, at `5fdc971`: GREEN. Exit code 0; `TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` ends with "All checks passed"; Bats: 967 ok, 0 not ok.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 1 | Plan-eval round 1: `find -exec` mutation test rewritten to forms whose match depends on the second `tr`; unresolved blind-review blocker stated explicitly |
| 0 | Split from `herdr-hc-client` (owner decision): guard only; every wrapper form denied by scanning the raw command, a test per form |

# Research: hc (herdr-core) agent-control CLI — runtime reference for loom

Status: Research Review
Date: 2026-11-01
Topic: Reference for herdr-core's `hc` CLI (0.1.16) as the agent runtime under the Herdr desktop app (herdr-app 0.1.11), so loom can treat Herdr as a client the way it treats Orca. Input to the planner for any Herdr client adapter ADR/spec. Read-only: no agent was started, sent to, or killed. The sibling note `2026-11-01-herdr-extension-loading.md` covers the app's mod system; this note covers `hc`.

## Summary

- **`hc` is a terminal runtime; the app is a client of it.** The live terminal `t4` (started from the app, not from an hc terminal) carries `herdr.space` and `herdr.tab` labels and `parent: null`, and `hc get` reads it. [4]
- **Launch:** `hc run --bg --name <n> --cwd <dir> <program> "<brief>"` starts a program and returns at once. A brief passed as a program argument is *not* tracked by `first_message`; only a template run tracks delivery and waits for readiness. [1][3][5]
- **Status is pushed by the program** over OSC 7501 (`idle|working|done|blocked|error`). `hc` does not guess from screen text or recognize agent brands. [2][3][6] Claude Code reported status to `hc` on `t4` (observed). No Codex terminal has been observed. [4]
- **Interactive agents do not exit at turn end.** A loom role must be ended explicitly (`hc kill`, then `hc rm`). [2][4]
- **Children end with their parent** unless `--outlive-parent`. [1][3]
- **Blind review cannot be enforced by `hc`.** `notes = false` removes hc's own typed notes and `<hc from>` tags. It does not hide terminal names, parents, cwd, labels, or screens from any process running as the same account, and the project states there is no per-client permission check. [1][2][5]
- **Mapping:** loom's current `herdr` client emits a descriptor only and refuses `--model`/`--effort` (ambient inheritance). An hc adapter would have to put model and effort inside the program's command string, a decision ADR 0027 does not yet cover. Loom's Codex argv is a one-shot `codex exec` with a read-only sandbox, which does not fit interactive hc agents. [8][9]
- **Versions:** hc 0.1.16 matches the public `v0.1.16` docs. herdr-app is 0.1.11. Neither project publishes a compatibility statement; one app-started terminal is readable by hc 0.1.16. [4][5][11]
- **Current local state:** no config file, no templates, no machines. [4]

## 1. Command reference

Class key: **R** read-only · **L** launches a program · **M** mutates (ends, types, writes, or changes config) · **W** waits or streams. Source: `hc <cmd> --help` [1] and the schema [3]. `hc server status` and the server start/stop/restart commands were **not run**; help only.

| Command | Arguments | What it does | Class |
|---|---|---|---|
| `run` | `[--bg] [--name N] [--cwd D] [--on M] [--label k=v] [--parent T \| --no-parent] [--no-notify] [--outlive-parent] [--rm] [--keep] [--timeout S] [argv…]` | Starts argv in a new terminal; or a template name plus its task. Without `--bg` it waits and streams output like a shell. | L (W unless `--bg`) |
| `ls` | `[--all] [--label k=v]` | Live terminals on this core; `--all` adds finished ones. | R |
| `get` | `[t]` | One terminal's full record. | R |
| `attach` | `[t] [--observe] [--history N]` | Takes over a terminal; ctrl+\ detaches. `--observe` never types. | M (R with `--observe`) |
| `read` | `t [--lines N]` | Screen plus N lines of history, as text. | R |
| `kill` | `[t]` | Hangup, then terminate, then kill. | M |
| `rm` | `[t]` | Removes a finished terminal. | M |
| `label` | `t k=v…` | Sets labels; `k=` removes one. | M |
| `keep` | `t [--off]` | Replaces a lost program with a shell; never re-runs it. | M |
| `send` | `t <text> [--force] [--if idle\|working] [--wait] [--timeout S]` | Pastes text and presses Enter after ~3 s of typing quiet. Refuses a blocked program unless `--force`. | M (W with `--wait`) |
| `keys` | `t <keys…>` | Presses named keys. | M |
| `interrupt` | `[t] [--timeout S]` | Presses esc (status-reporting programs) or ctrl+c; reports the outcome; never escalates. | M |
| `wait` | `[t] [--children any\|all] [--output X] [--timeout S]` | Waits until a program is not `working`, exits, or prints X; `--children` waits on helpers. Default check-in 180 s. | W |
| `put` | `t <file>` | Copies a file beside a terminal on its machine; prints its path. Types nothing. | M |
| `exec` | `[--on m] [--cwd D] [--env K=V] [--timeout S] [-i] <argv…>` | Runs one program with no terminal; returns exact output and exit code. | L (short-lived) |
| `file read` | `[--on m] <path> [--offset N] [--limit N]` | Reads a text file. | R |
| `file write` | `[--on m] <path>` (stdin) | Replaces a whole file. | M |
| `file edit` | `[--on m] <path> --old X --new Y` | Replaces exact text found once; all edits or none. | M |
| `templates` | — | Lists `~/.config/herdr-core/templates/*.md`. | R |
| `events` | `[--terminal t] [--children-of t] [--label k=v]` | Follows fact changes as JSON lines. | W (stream) |
| `server status` | — | Core identity, holders, live and finished counts. | R (not run) |
| `server start\|stop\|restart` | — | `stop` stops every program, kept terminals become shells next start; `restart` keeps programs running. | M (not run) |
| `update` | `[--version X] [--from F] [--force]` | Replaces the hc binary and restarts the core; terminals keep running. | M |
| `machine ls` | — | Machines added here and their state. | R |
| `machine add` | `<target> [--name N] [--via CMD] [--session S] [--temp] [--install]` | Adds an ssh or custom-command machine. | M |
| `machine login\|update\|rename\|rm` | `<machine> […]` | Re-auth; copy hc to a remote and restart it; rename; forget (remote terminals keep running). | M |
| `connect` | `[--session S]` | Serves the JSON-RPC protocol over stdin/stdout (`ssh box hc connect`). | W (protocol) |
| `schema` | — | OpenRPC / JSON Schema of the API. | R |
| `hc` (no args) | — | Picker to attach to a terminal. | interactive |

Global: `--json` (default when piped), `-V`, `--licenses`, `hc --skill` (manual). Errors are `{error:{kind,message,hint}}` on stderr. Exit codes: 3 not_found, 7 needs_target, 9 blocked, 10 status_mismatch, 11 finished. [2] API error kinds: see [3].

## 2. Lifecycle

- **Address and naming.** `RunResult.address` (e.g. `t7`) is fixed for the life of the core. `--name` is 1–32 characters of `a-z 0-9 - _`, unique among live terminals (`name_taken` otherwise). [1][3]
- **Readiness.** Plain programs have no readiness signal; the caller must `hc wait` or `hc read`. [2] For templates, the default is to wait for the first OSC 7501 status report, with a 30 s default before core leaves the screen alone. `ready: quiet` opts into output-settle readiness, which "is not proof that an agent is ready." [5]
- **First message.** Template runs send the template body plus the task as the first message and report `first_message: {sent, started, turn, reason}`. If `sent` is false, read the screen before resending, because the send may have arrived. [3][5] A plain run passes the brief as argv; `first_message` is not set, and delivery is whatever the program does with its argument. The verified fallback is `run`, then `wait`, then `send`. [2]
- **Single-string caution.** A single quoted string containing spaces is sent as a shell line, not argv. Pass the brief as its own argv token. [1][3]
- **End.** Program exit sets `state: finished` with `exit_code` or `signal`, and `reason` one of `exited, killed, server_stop, host_shutdown, signaled, holder_lost, stopped_by_restart, spawn_pending`. [3] Interactive agents stay live after a turn: `t4` shows status `done` while its program is still live. [4] A loom role must therefore be ended with `hc kill` then `hc rm`. [2] `--rm` removes the record after exit. [1]
- **Outlive-parent.** Default: a child ends when its parent's program ends; `--outlive-parent` keeps it running. [1][3] The mechanism (hangup or kill) and timing are not documented. Unverified.
- **Core restarts.** Holder processes keep terminals alive across `hc update` or `server restart`. [5][3]

## 3. Addressing and hierarchy

- **Forms.** `t7` (the core's own address), a name (`review`), or `machine/t7` for a remote. Names are unique only among live terminals. [1][3]
- **`$HC_TERMINAL_ID`.** Inside an hc terminal, this is the caller's own address. It is the default for `caller` and for the parent. [1][2][3] Whether the desktop app sets it was not verified.
- **Parent.** Default is the terminal the command runs from; `--parent T` or `--no-parent` override. Set once at start. [1][3] The live record of `t4` shows `parent: null`. [4]
- **Children.** `hc wait --children all|any` and `hc events --children-of t` address them. [1][3]
- **Parent ends.** Children end with it unless `--outlive-parent`. [1] The API's `die_with_parent` is documented as ignored. [3]

## 4. Status and events

- **Source.** The program's own OSC 7501 records. States are `idle`, `working`, `done`, `blocked` (with `kind` `permission|question|auth` and optional `progress`), and `error`. `app`, `msg`, and `title` are free text. hc stores the words unchanged. [2][3][6]
- **Observed.** `t4`, started from the app, has foreground argv `claude --resume <id> --dangerously-skip-permissions`, `reported: true`, and `status: {app: "claude-code", state: "done", msg: "…"}`. So Claude Code emitted OSC 7501 to hc on this machine. This is one terminal, not a guarantee for every launch. [4]
- **Foreground name.** For Claude Code, `foreground.name` is the version string (`2.1.316`), not `claude`. Do not detect programs by that name. [3][4]
- **Codex.** Not observed. `hc --skill` says Codex must run with `--no-daemon`. Whether Codex emits OSC 7501 is unverified. [2]
- **Plain programs** report no status; `wait` then waits for exit. [2][3] A program that never reports is "working until it exits," so a Claude terminal that never reports would stall a wait until its timeout. Whether Claude emits a status at launch is unverified. [3]
- **`hc events`.** Snapshot, then fact changes of kinds `created, lost, restarted, keep, finished, removed, status, turn, title, labels, size, doc`; a `heartbeat` every 15 s; `missed` and a fresh snapshot for a subscriber that falls behind. Filters: `--terminal`, `--children-of`, `--label`. [1][3] Not run here (not on the read-only list); the sibling note's sample is from an earlier run. [8]
- **CLI versus API shape.** `hc ls --json` rows are a projection (`agent`, `where`, string `status`). `hc get --json` and the API return the full `Terminal` record with `status` as an object. Parse per command. [3][4]

## 5. Messaging and blind review

- **Send.** `hc send t "<text>"` pastes and submits. It refuses a blocked program unless `--force`. [1][3]
- **Child to parent.** With notes on (the default), reports arrive as `<hc from="t7 review">…</hc>`. A `reach="…"` attribute is added when a reply is expected. The tag gives the sender's address and name. [2] The `terminal.wait` result carries the sender's address as `from` for a message to the waiter. [3]
- **`notes = false`.** The help text says: "hc types nothing on its own (no notes to parent agents, no `<hc>` tags on messages)." [1][2] The per-launch equivalent is `--no-notify`. [1] No config file exists here, so the defaults apply. `t4` shows `notify: true`. [4][1]
- **What `notes = false` does NOT suppress** (schema or help, not runtime-tested): terminal `name`, `address`, `parent`, `labels`, `cwd`, `argv`, `foreground.argv` (which includes session ids and flags), status `msg`, screen and history via `read` or `attach`, and `ls`/`get`/`events` output. [1][3]
- **Access.** Anyone who can connect to the core's socket can run commands and read terminals with the owner's account access. There is no separate API password and no per-client permission check. Sessions "are not security boundaries." [5]
- **Git identity.** hc does not touch git identity; the commit-convention rules apply to the commands inside a terminal. [10]

**Constraint for loom's blind review (flag for the planner).** hc cannot keep an evaluator from learning the author's identity. An evaluator with a shell under the owner's account can run `hc ls`, `hc get`, or `hc read` and see the developer's terminal name, labels, parent, worktree cwd, and screen, which may include its reasoning. `notes = false` removes only typed notes and tags. Options, for the owner to decide: (a) withhold `hc` from evaluators by tool policy (evadable from Bash, like the git guard); (b) run evaluators under a separate OS account with no access to the core socket (strong, heavy); (c) accept "blind by convention" and record that in an ADR. A separate `HC_SESSION` is not a boundary. [5]

## 6. Templates

- **Location.** `~/.config/herdr-core/templates/<name>.md` (Windows: `%APPDATA%\herdr-core\templates`); `XDG_CONFIG_HOME` overrides. [2][5] None exist here; `hc templates` returns `{"templates":[]}`. [4]
- **Unknown names.** `argv[0]` is a template only if it names one; otherwise it is run as a program. This is inferred from the schema wording and not tested. [3]
- **Format.** One `.md` file. The header is line-based, between `---` lines, and is "not full YAML": values are literal after the first colon, unknown fields are ignored. The body is the opening instructions; core appends the task after a blank line. [5]
- **Fields.** `command` (required; the shell command that starts the agent), `description`, `ready` (default: status report; `quiet` for output-settle), `submit`, `stop`, `paste_gap_ms`. [5]
- **Correction.** The `name` field listed in `hc --skill` and in the owner's brief is ignored; the filename is the name. [2][5]
- **Model and effort.** There are no model or effort fields. The public docs say to "put model choices and other agent options in that command." [5] Example from `hc --skill`: `pi --provider openai-codex --model gpt-6.1-sol --thinking medium`. [2]
- Templates "do not install agents or configure their status reporting." [5]

## 7. Machines

- **Add.** `hc machine add <target> --name N` accepts an ssh target or a Host alias. `--via 'CMD'` uses a custom command that takes a shell line as its last argument, must pass bytes unchanged, and must ask nothing; it needs `--name`. [1][5]
- **Other commands.** `machine ls` shows state (`connecting`, `connected`, `needs_login`, `unreachable`). `login` re-auths, `update` copies hc to the remote and restarts it, `rename` changes the local name, `rm` forgets the connection. [1][3][5]
- **Remote run.** `hc run --on box --cwd /srv/app --bg --name build cargo build` returns `box/t3`. Remote paths default to the remote home. [5]
- **What a remote run needs.** hc installed on the remote at a compatible generation (copied automatically in a terminal after a prompt, or with `--install`). Non-interactive SSH auth (keys or agent); passwords need a person. Remote login must print nothing extra to stdout. The remote template and worktree must exist there. [5] Whether loom's helpers must exist in the remote checkout is unverified.
- **Here.** `hc machine ls` returns `{"machines":[]}`. No remote was tested. [4]
- **Trust.** Adding a machine gives local clients access to its account's commands, files, and terminals. [5]

## 8. Mapping to loom

**Current loom state.** `loom-launch-role` accepts `herdr` as a client, but `_launch_herdr` emits only a descriptor (`{"herdr":{"profile":…}}`) and "no window is spawned." It refuses `--model` and `--effort` because "Herdr inherits the ambient model." [9] An hc adapter is therefore new work, and it conflicts with ADR 0027's ambient inheritance for this client. That needs a planner decision.

| Loom input | hc mapping | Status |
|---|---|---|
| role | `--name <role>-<slice>`, 1–32 characters, unique among live terminals | verified syntax [1][3] |
| client `claude` | program `claude` | launch verified in `hc --help` [1]; flags unverified |
| client `codex` | program `codex --no-daemon …` (no template) | `--no-daemon` required [2]; Codex flag placement unverified |
| model | inside the command string: `--model <id>` (loom's Codex exec argv uses it [9]) | Codex interactive form unverified |
| effort | Codex: `-c model_reasoning_effort=<low\|medium\|high>` (loom's argv uses it [9]). Claude: loom's `_launch_claude` has no effort concept [9], so none today | unverified for interactive Codex |
| worktree path | `--cwd <worktree>` | verified [1] |
| brief | (a) template body plus task: verified delivery tracking [5]; (b) positional argv: `claude --model <id> "<brief>"`, delivery not tracked, depends on the program accepting a positional prompt; (c) `hc wait` then `hc send`: verified pattern [2] | (a) and (c) verified; (b) unverified |
| role prompt and tool limits (`agents/<role>.md` model and `tools`) | No hc equivalent. Only a template body carries role text; how Claude Code loads an agent file or restricts tools in an interactive hc session is unverified [9] | not mapped |
| completion | `hc wait` returns on `done`; the role is then ended with `hc kill` and `hc rm` | semantics verified [2][3] |
| parent | default parent is the orchestrator's terminal, so roles end with it; choose `--outlive-parent` or `--no-parent` deliberately | decision for the planner |

**Candidate invocations** (loom's requested shape, with caveats):

- Claude developer: `hc run --bg --name developer-s1 --cwd /path/to/worktree claude --model <id> "<brief>"`. The brief is positional, so `first_message` is not tracked; confirm the program accepts it.
- Codex developer: `hc run --bg --name developer-s1 --cwd /path/to/worktree codex --no-daemon --model <id> -c model_reasoning_effort=<e> "<brief>"`. Unverified: flag placement and interactive behaviour.

**Not possible or not verified:**

- Loom's Codex launch is `codex exec --ephemeral … --sandbox read-only` [9]. It is one-shot and read-only; hc expects interactive agents [2]; the developer role needs writes. The Codex argv cannot be reused, so the Codex path needs its own contract.
- "Only root delegates": hc does not restrict who may call `hc run`. Any role with Bash can start terminals. The role tool policy must deny it; hc will not enforce it. [5]
- Blind evaluation (§5), Claude effort, role-file loading, and per-role tool limits (above).
- Launching via the app (`herdr-app do tab.new --argv`) is in the sibling note [8] and was not re-verified here.

## 9. Version note

- **hc 0.1.16.** `hc --version` and `hc schema` `info.version` both report 0.1.16. [1][3] A public tag `v0.1.16` exists, and its `docs/commands.md` matches the local `hc --help` text on reading (not byte-diffed). [5]
- **herdr-app 0.1.11.** `Info.plist` `CFBundleShortVersionString` and `CFBundleVersion` are both 0.1.11; `herdr-app --version` prints `herdr-app 0.1.11`. [11]
- **Compatibility.** Neither project documents one. The public herdr-core page has no compatibility statement. [6] Loom's compatibility matrix floors the app at 0.1.10 and does not list hc. [8] Observed: an app-started terminal (`t4`) is listed, readable, and status-reporting through hc 0.1.16. [4] Whether the app uses this external `hc` or its own bundled core is unverified; the sibling note found herdr-core strings inside the app binary. [8][12]
- **Known compatible?** Not known. Observed working on one terminal only.

## 10. Open questions (owner-run live probe; listed, not run)

1. Does Claude Code emit an OSC 7501 status at launch, before any turn? This decides whether template readiness works for Claude.
2. Does an interactive Codex session emit OSC 7501? Does `codex --no-daemon --model … -c model_reasoning_effort=…` start cleanly under hc?
3. Does Claude Code accept a positional prompt in an hc terminal, and does `first_message` stay unset in that case?
4. Which Claude Code flags load an agent definition or system prompt and restrict tools in an interactive session? Is there an effort flag?
5. Does `HC_TERMINAL_ID` reach the Bash tool of a Claude session started by `hc run`, and does a nested `hc run` then set its parent automatically?
6. What does parent-end actually do (hangup or kill, and when)? Does `--outlive-parent` behave as documented?
7. Does `notes = false` change `terminal.wait`'s `from` field or message delivery? What else does it hide?
8. Can an evaluator session read another terminal's screen with `hc read`? (The blind-review check.)
9. Does the desktop app run this `~/.local/bin/herdr-core` or its own bundled core? Compare with `hc server status` (owner-run).
10. Do `hc events` on a launched Claude terminal emit the kinds listed in the schema? (Observation only.)
11. Does `hc run <unknown-name>` run it as a program, as §6 infers?
12. Does a remote run need loom's helpers in the remote checkout, and does that remote need its own hc copy?

## Sources

[1] `hc --help` and `hc <cmd> --help` for every command and the machine/file/server subcommands. Local hc 0.1.16 at `/Users/craig/.local/bin/herdr-core` (symlink `hc`), read 2026-11-01.
[2] `hc --skill` (full manual), local hc 0.1.16, read 2026-11-01.
[3] `hc schema` (OpenRPC, 63 KB), local; saved to `/tmp/hc-schema.json` outside the repo; read 2026-11-01.
[4] Local read-only observation, 2026-11-01T20:25Z: `hc templates` → `{"templates":[]}`; `hc machine ls` → `{"machines":[]}`; `hc ls --all`; `hc get t4 --json`. `~/.config/herdr-core/config.toml` and `~/.config/herdr-core/templates/` do not exist (read error).
[5] Public, GitHub `herdrdev/herdr-core` at tag `v0.1.16`, via `gh api` raw content, read 2026-11-01: `docs/commands.md`, `docs/templates.md`, `docs/machines.md`, `docs/security.md`. The default branch is `master`; the same paths on it are 404 or stale, so the tag is authoritative. Repo metadata: Apache-2.0, `pushed_at` 2026-11-01T19:11:55Z, `/releases/latest` 404.
[6] Public, https://herdr.dev/core/ and https://github.com/herdrdev/herdr-core, read 2026-11-01 via WebFetch summary (not verbatim).
[7] Public search, 2026-11-01: https://herdr.dev/docs/agents/ (WebFetch summary) describes the older `herdr` CLI (`herdr agent attach`), not hc. Search results for "herdr agent start / pane report-agent" are the same older CLI. Not used for hc claims.
[8] Local: `.docs/research/2026-11-01-herdr-extension-loading.md` (§4, §6); `.docs/research/2026-11-01-herdr-client-adapter-contract.md` (status Approved; floor `herdr: 0.1.10`).
[9] Local: `plugins/loom/bin/loom-launch-role` — usage line 52; `_launch_claude` 300–312; `_launch_codex` 315–330; `_launch_herdr` 366–373; herdr case 548–552.
[10] Local: `plugins/loom/skills/loom-playbook/references/commit-convention.md`.
[11] Local: `/Applications/Herdr.app/Contents/Info.plist` via PlistBuddy; `herdr-app --version` → `herdr-app 0.1.11`, read 2026-11-01.
[12] Local: `ls -la` of `~/.local/bin/hc` and `herdr-core` (5,970,944 bytes), 2026-11-01.

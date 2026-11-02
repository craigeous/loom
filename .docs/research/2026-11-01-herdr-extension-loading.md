# Research: Herdr extension loading and agent-hook surface

Status: Research Review
Date: 2026-11-01
Topic: How Herdr loads third-party extensions, and whether any of them can install Claude Code / Codex hooks, launch role sessions, or observe agent events. Input to the planner for any loom–Herdr integration ADR or spec.

Version note: the owner's brief said desktop app 0.1.10. The installed bundle reports `CFBundleShortVersionString` 0.1.11 (`/Applications/Herdr.app/Contents/Info.plist`:10) and `~/.config/herdr-app/update-notes.json` has `last_run: 0.1.11`. All findings below are from 0.1.11.

## Summary

- **Extension unit = "mod".** A mod is a folder `~/.config/herdr-app/mods/<name>/` whose required entry is `main.js` (a default-exported class extending `View`); `mod.json` is optional. [1][2] Mods are JavaScript that draws native GPUI elements, not a web view. [2]
- **Mods are trusted code.** They may run programs (`exec`, `hc`), use `fetch`, and read/write files; "commands and network access (including `fetch`) are unrestricted." [2][3]
- **No Claude Code / Codex hook API exists in the app, CLI, or bundle.** The app has no PreToolUse, SessionStart, SessionEnd, or PostToolUse names, and no install path for them. Both Herdr binaries were string-scanned for these names with no hits. [4]
- **Observation is possible; interception is not.** A mod can read live agent state (`agents()`: status, `app`, program) and follow a JSON event stream (`hc events`). [3][5][6] Agent status is *pushed by the agent program* over OSC 7501 terminal sequences. [4][7] Nothing documented lets a mod see or veto individual tool calls.
- **Launching is well covered.** `herdr-app do tab.new|space.new|pane.split --argv '["claude"]'` and `hc run --bg … claude "<task>"` both start agents, with labels and first-message delivery. [5][6]
- **A gpui-shell plugin runtime exists in the binary** (`gpui-shell.json` manifest with `id`, `version`, `shell-version`, `entry`, `dependencies`, `capabilities`). Its discovery path and install entry point were **not found**; its relationship to mods is unverified. [8]
- **No documented third-party package installer.** `installed.json` is a hash ledger of shipped mod files, not a package list. [9] Sharing is "copy a folder from a GitHub repo," done by an agent. [2]
- **Recommendation:** loom needs no Herdr extension to function, and should not build a mod that depends on hook semantics the app does not expose. Launch-via-`hc` and status-via-`hc events` are usable as adapter details but need an ADR before loom treats Herdr as a supported client. Owner tests in §6 settle the open points.

## Findings

### 1. Extension unit

- A mod folder holds `main.js` (required), `mod.json` (optional), and more modules or SVGs. [1]
- `mod.json` documented fields: `place` (`right|left|top|bottom|none`), `size` (px), and for overlays `overlay: { width, height }`. [1][10] Shipped samples also use `title` and a richer `overlay` (`kind`, `at`, `offset`, `width`, `height`), e.g. `picker/mod.json`. [10] `mod.json must be an object` is a load error string in the binary. [4]
- Full schema: the app does not publish one. The authoritative types are `herdr.d.ts` (module API) and `gpui-kit.d.ts` (elements), which the app rewrites on each start. [2][3] The `mod.json` schema above is therefore **partial**; the exact accepted keys are an open question.
- Mods appear through layouts (`layouts/*.json`, `content: {mod: "<folder>"}`) and `mod.open`/`pane.split {mod}`. [1]

### 2. Plugin, marketplace, or hook mechanisms

- **Local app, CLI, and config:** `herdr-app commands` lists 68 commands. None matches plugin, install, extension, package, marketplace, or hook; only `mod.clone` and `mod.open` match a broader search. [11] `herdr-app --help` lists `--skill`, `check`, `shot`, `feedback`, `do`, `status`, `commands` and no install verb. [12]
- **`installed.json`** maps each shipped mod file to a hash (e.g. `"agents": {"main.js": "84a7…"}`), and Herdr writes it. [9][1] It is bookkeeping for the first-run/redeploy logic, not a registry of third-party packages.
- **`herdr.d.ts`** exposes `exec`, `hc`, `knownAgents`, `watchFolder`, `props`, `shared`, `notify`, `openOverlay`, `run`, `agents`, `terminals`, `panes`, `focused`, `updates`, `telemetry`, but no plugin registration, hook, or event-subscription function. [3]
- **gpui-shell plugin runtime (binary only):** the app binary contains a manifest validator with strings: `A manifest has exactly the fields …`, `id`, `version`, `shell-version`, `entry`, `dependencies`, `capabilities`; `capabilities` accepts `fs` (read, write, execute), `network` (hosts, http), `storage`, `clipboard` (read, write), `process` (exit); `dependencies` may be a GitHub `owner/repository` shorthand or a Git URL with `branch`/`tag`; "Commands, panels, keybindings, settings and themes are registered in script, not declared here." [8] The discovery directory and whether any UI or command loads such a manifest were **not located** in the strings. Treat as an unexercised runtime until the owner test in §6 runs.
- **Public GitHub README (herdrdev/herdr, fetched via a summarizer; not verified verbatim):** says "**plugins** — extend panes and workflows," links a marketplace and plugin docs, and states Apache-2.0. [13] The public mods page uses "mods" and says nothing about hooks, a manifest beyond `RECIPE.md`/`preview.png`, or shell execution. [14] The two public vocabularies disagree; the local binary matches "mods."
- **Hook-like behaviour in Claude Code itself** (per public web sources): Claude Code 2.1.295 added Program Status Protocol (OSC 7501) support; this is a status-emission feature, not a Herdr plugin. [7]

### 3. Shell commands, hooks, and agent event observation

- **Run a shell command:** yes. `exec(command, args?, {cwd?, on?})` runs "with the user's real environment," 30 s limit, 8 MiB output. [3] `hc(args)` runs herdr-core. [3] Remote runs via `on: <machine>`.
- **Observe agents:** `agents()` returns `status` (`working|blocked|done|idle`), `app` (OSC 7501 `app`, e.g. `claude-code`, `codex`), `program`, `title`, `focused`, `seq`. [3] `terminals()` gives every core terminal with `status`, `report`, `program`. [3] Both are "live" and re-render mods on change. [2]
- **Event stream:** `hc events` "follow[s] fact changes as they happen (one JSON line each when piped)," filterable by `--terminal`, `--children-of`, `--label K=V`. [5] Local sample: a line with `seq`, `terminals[]` including `status: {app, msg, state}`, `status_ms`, `foreground.argv` (e.g. `claude --resume …`). [5]
- **Programmatic API:** `hc schema` emits an OpenRPC-style JSON schema (`openrpc`, `methods`, `Terminal`, `Status`, `SubscribeResult`, …); `hc connect` serves "the API over stdin/stdout." [6]
- **Hook names:** none. The status vocabulary is `idle|working|done|blocked|error` with `kinds` `permission|question|auth` (for `blocked`). [4][6]
- **Intercept or veto tool calls (PreToolUse-style):** no evidence of any such API in the app, CLI, bundle, or public docs. `blocked` is a *status*, not a gate; `hc send` refuses on blocked "unless `--force`", which is a CLI guard, not a hook. [6]
- **Install agent hooks:** no evidence that Herdr writes `~/.claude/settings.json` or Codex config. The app does not reference those paths in the strings checked.

### 4. How agents are launched and their events surfaced

- **App command:** `herdr-app do tab.new --name "fix login" --argv '["claude"]' --task "…"`; `space.new`, `pane.split {argv | mod}`, and `terminal.open {argv}` accept `argv`. [1][11]
- **CLI:** `hc run --bg --name <n> --cwd <dir> [--label k=v] claude "<task>"`; `hc send`, `hc wait <t> [--output X]`, `hc read`, `hc keys`, `hc interrupt`. [6] Codex "must run with `--no-daemon`… or its commands execute outside hc." [6]
- **Launcher registry:** `programs.json` `run` entries feed `knownAgents()` (installed or not). Built-in: `claude` → `run: ["claude"]`, `match: ["claude-code"]`; `codex` → `run: ["codex"]`. [4][1]
- **Labels:** terminals with `herdr.space=<id>` and `herdr.tab=<id>` appear in a space. [1]
- **Status surfacing:** agent programs emit OSC 7501 records; `hc` stores the program's own word unchanged. [4] Herdr shows status in the sidebar and sends notifications on `blocked`/`done`. [1]
- **OSC 7501 wire format (from binary strings and a public discussion):** query `ESC ] 7501 ; ?` answered with `…states=idle,working,done,blocked,error:kinds=permission,question,auth`; records like `state=working : id=… : msg=…`. [4][7] Limits reported for a subagent emitter: 64 records, 2 KB message, 192 B title. [7]

### 5. Third-party package installation

- **Documented path:** none for installing a package into the app. Sharing: publish a public GitHub folder with `RECIPE.md`, `preview.png`, and the repo topic `herdr-mod` or `herdr-layout`; an agent copies it into `mods/`. [2][14] Installing "reads every file" first and warns if a mod "reaches the network, runs programs (`exec`, `hc`) or reads files outside its own folder." [2]
- **Format of a shared mod:** `mods/<name>/` with `main.js`, `mod.json`, and assets; `keys.json` snippet optional. [2][14]
- **Undocumented runtime:** the gpui-shell manifest (§2) is the only package-like format found. Its `dependencies` field accepts Git sources, so a manifest-based plugin could pull code from GitHub; no installer command was found. [8]

### 6. Recommendation and owner tests

Which loom can use without spec change:
- **Keep loom's hooks in Claude Code's own plugin mechanism** (`plugins/loom/hooks/`). Herdr does not need to be involved; loom's guard and backstop run inside Claude Code. No spec change.
- **Read-only observation** via `hc events` or `agents()` from a *user-owned* mod, purely for display, is compatible with loom's blind-review rules. It would need no spec change if it writes nothing into loom's `.docs/`. Owner decides whether to build it.

Which need an ADR (and likely a spec 07/10 update) before loom depends on them:
- **Launching role sessions through `hc run` / `herdr-app do tab.new`** as a supported client path. This changes the launch contract that spec 07/10 and the launcher (`loom-launch-role`) define; it is a decision, not a research finding. Existing notes `.docs/research/2026-11-01-herdr-client-adapter-contract.md` and `…-herdr-native-app-hooks-contract.md` cover the planner's side and were not used as sources here.
- **Any reliance on agent status (OSC 7501) for role dispatch.** Its behaviour in this build is unconfirmed (§7).
- **Installing hooks through Herdr.** Not supported by any evidence found; do not plan around it.

Owner tests in the live app (read-only unless marked):
1. Confirm `mods/` is the only extension path: create a throwaway mod in a scratch `HERDR_APP_HOME` copy, not in `~/.config/herdr-app` (**write test**, owner-run).
2. Locate the gpui-shell plugin loader: check whether any path loads `gpui-shell.json`, and whether `herdr-app status` reports a plugin error (read-only).
3. Confirm `hc events` delivers Claude Code and Codex status transitions within a loom-style run (observe only).
4. Confirm whether Claude Code answers/emits OSC 7501 for an `hc run`-launched session; the public discussion says Herdr did not answer the query at commit 4dc23bb. [7]
5. Confirm no hook or interception surface: expect none; a negative result closes the question.

## Sources

[1] `~/.config/herdr-app/AGENTS.md` (local file, written by Herdr 0.1.11): §Mods L716–745 (folder layout, `mod.json` `place`/`size`, first-time docking); §Layouts/tab.new L514–520; §Agents L150–163; §herdr-core L932–946; §Programs L682–712; "Layouts and mods other people made" L410–460.
[2] `~/.config/herdr-app/AGENTS.md` L928 ("Mods are trusted code…"), L410–460 (sharing via GitHub topic, recipe, review rules), ≈L780–830 ("A mod" rules: `cx`, `cx.timer`, `close`, live re-render).
[3] `~/.config/herdr-app/herdr.d.ts` (local, rewritten each start): `exec` L13, `hc` L16, `knownAgents` L33, `props` L382, `watchFolder` L403; `agents()`, `terminals()`, `panes()`, `focused()`, `run()`, `openOverlay()`, `notify()` throughout.
[4] Binary string extraction, 2026-11-01: `/Applications/Herdr.app/Contents/MacOS/Herdr` and `~/.local/bin/herdr-core` (5,970,944 bytes, symlink `hc`). Hits: `gpui-shell.json`, manifest field text, capability text, `OSC 7501 …states=…kinds=…`, `mod.json must be an object`, `codex`/`claude` program entries. No hits for `PreToolUse`, `SessionStart`, `SessionEnd`, `PostToolUse`.
[5] Command output 2026-11-01: `timeout 4 hc events --json` (one JSON line, seq 106) and `hc events --help`.
[6] Command output 2026-11-01: `hc --help`, `hc run --help`, `hc --skill` (full manual, including OSC 7501 status section, `--no-daemon` note, `hc wait`/`send` semantics), `hc schema` (OpenRPC keys).
[7] Public: https://github.com/herdrdev/herdr/discussions/5073 (WebFetch, accessed 2026-11-01; post dated Oct 8 2026 per summarizer). Summarizer output, not verbatim; verify before quoting.
[8] Binary strings, `Herdr.strings` near `gpui-shell.json` (≈L106719) and manifest validator text (≈L114660–114700, L131700–131770); source path `vendor/gpui-kit/crates/shell/src/plugin.rs`.
[9] `~/.config/herdr-app/installed.json` (local, written by Herdr; keys are shipped mod names and file hashes).
[10] `~/.config/herdr-app/mods/pane/mod.json`, `toast/mod.json`, `agents/mod.json`, `worktree/mod.json`, `picker/mod.json` (local samples).
[11] `herdr-app commands` (JSON, 68 entries), read 2026-11-01.
[12] `herdr-app --help` output, 2026-11-01.
[13] Public: https://github.com/herdrdev/herdr (README, raw fetch returned 404; main page summarized via WebFetch, accessed 2026-11-01). Summarizer output; "plugins" and marketplace wording unverified.
[14] Public: https://herdr.dev/mods/ (WebFetch, accessed 2026-11-01): mod folder, `RECIPE.md`, `preview.png`, topic `herdr-mod`. No hook or manifest docs.
[15] Public: https://herdr.dev (WebFetch, accessed 2026-11-01): customization via files in `~/.config/herdr-app`; agents report state via OSC 7501; no plugin/hook docs.
[16] `/Applications/Herdr.app/Contents/Resources/LICENSE` — Apache License 2.0 (local). A search aggregator claimed AGPL-3.0; the bundled license overrides that claim.

## Open questions

- Is `gpui-shell.json` loaded from any location in 0.1.11? Not found in strings; needs owner test §6.2.
- Is the public "plugins/marketplace" vocabulary from a newer or different build than the local "mods" system? The README was only summarized.
- Does `hc events` report Claude Code/Codex status changes reliably in a loom role session? Not tested.
- The OSC 7501 query reply: the local binary contains the reply string, but the public discussion (commit 4dc23bb) says the observer handled only OSC 0, 2, 9. Current behaviour unconfirmed.
- Is there a live Claude session (terminal t4, title "Herdr plugin installation") that reported on the same question? Its status text ("Herdr can't load Loom's plugin; it would need a mod") is another agent's output, not evidence. Not relied on.
- The `mod.json` full key set is unpublished; this note lists only keys seen in samples and the docs.

## Scope and method

- Read-only on Herdr: no writes to `~/.config/herdr-app` or the app bundle; no `herdr-app do` calls. `hc events` was run with a 4-second timeout.
- Strings were extracted to `/tmp/herdr-research-strings/` (outside the repo) and not committed.
- No Agent or sub-agent tools were used.

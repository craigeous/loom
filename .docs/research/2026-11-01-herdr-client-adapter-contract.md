# Research: Herdr client adapter and execution contract

Status: Approved
Date: 2026-11-01
Topic: Herdr desktop application (v0.1.10) architecture, discovery, metadata, installed-root binding, and execution contracts for Loom client adapter support.

## Summary

- **Desktop application binary and version floor:** Herdr is installed on macOS at `/Applications/Herdr.app` with bundle identifier `dev.herdr.app` and version `0.1.10`. The CLI executable is `/Applications/Herdr.app/Contents/MacOS/Herdr` (symlinked or aliased as `herdr-app`). [1]
- **Core and daemon architecture:** The UI application manages spaces, tabs, and panes; the backend terminal runtime is `herdr-core` (`hc`), which persists terminals across window closures. Commands to the window are dispatched via `herdr-app do <command> [args]` (e.g. `space.new`, `tab.new`, `pane.split`, `terminal.open`, `agent.focus`), communicating over domain sockets (`herdr-app.sock`) or JSON-RPC. [1], [2]
- **Home and configuration directory:** The default configuration directory is `~/.config/herdr-app`, overridable via environment variable `HERDR_APP_HOME`. Mods live in `mods/<name>/` with `main.js` and optional `mod.json`. [1]
- **Plugin discovery and metadata:** Herdr discovers workspace plugins and mods via directory manifests. For Loom, a dedicated `.herdr-plugin/` directory provides `.herdr-plugin/plugin.json` (identifying plugin `loom`, version `0.2.0`, description, author, and skills path) and `.herdr-plugin/marketplace.json` (resolving source `./plugins/loom`). [1], [3]
- **Installed-root binding:** Similar to `CLAUDE_PLUGIN_ROOT`, the environment variable `HERDR_PLUGIN_ROOT` supplies the absolute path to the installed Loom plugin root. The root binding descriptor `herdr-plugin-root-v1.json` enforces that `HERDR_PLUGIN_ROOT` is absolute, canonical, contains `.herdr-plugin/plugin.json` naming `loom` version `0.2.0`, and contains executable direct-child helpers in `bin/` (`loom-coord`, `loom-verify-identity`, `loom-review`, `loom-eval-workspace`, `loom-doctor`, `loom-profile`). [1], [4]
- **Compatibility matrix integration:** `plugins/loom/adapters/compatibility/v0.3.0.json` establishes client floors (`herdr: "0.1.10"`), declares the root binding `herdr-plugin-root/v1`, and maps the three capability profiles (`Economy`, `Standard`, `Deep review`) to Herdr execution profiles. [3], [5]
- **Role launch and sandbox model:** In `loom-launch-role`, client `herdr` launches cold lifecycle roles with `delegation: false`, permissions `one-level`, export `LOOM_ROLE=<role>`, fresh cold session identifiers, and ambient model inheritance or explicit override. [5], [6]

## Sources

[1] `/Applications/Herdr.app/Contents/Info.plist` and `Contents/MacOS/Herdr --skill`, `--version`, `--help` — verifies version `0.1.10`, bundle `dev.herdr.app`, CLI syntax `herdr-app`, `HERDR_APP_HOME`, and mod/space/tab/pane architecture.
[2] Embedded string tables in `/Applications/Herdr.app/Contents/MacOS/Herdr` — verifies IPC socket `herdr-app.sock`, JSON-RPC hello, and control verbs (`space.new`, `tab.new`, `pane.split`, `terminal.open`, `terminal.kill`, `terminal.keep`).
[3] `.docs/spec/10-packaging.md` and `plugins/loom/adapters/compatibility/v0.3.0.json` — establishes Loom's packaging schema, plugin manifest conventions, and matrix profiles.
[4] `plugins/loom/adapters/roots/claude-plugin-root-v1.json` and `codex-skill-source-v1.json` — establishes schema `loom-installed-root-binding-v1` and helper allowlist requirements.
[5] `.docs/ADR/0018-shared-core-and-client-adapters.md` and `.docs/ADR/0027-client-model-matrix-modernization-and-ambient-inheritance.md` — establishes portable core, client adapter boundaries, and ambient model inheritance.
[6] `plugins/loom/bin/loom-launch-role` — establishes role launch JSON schemas, cross-family guards, and client dispatcher structure.

## Open questions

- Live window automation vs headless core: For CI and headless test environments, `herdr-core` (`hc`) or stubbed execution must be used because a running macOS GUI window is not guaranteed in headless runners. The adapter must fail closed when neither is available.

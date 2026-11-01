# Research: Herdr native app lifecycle and event hooks contract

Status: Approved
Date: 2026-11-01
Topic: Herdr desktop application (v0.1.10) hook discovery, execution environment, event mapping, and wire contracts for Loom lifecycle hooks.

## Summary

- **Hook manifest discovery:** Herdr loads plugin hooks when declared in `plugins/loom/.herdr-plugin/plugin.json` via `"hooks": "hooks/hooks.json"`. This mirrors the root-relative `./hooks/hooks.json` pattern used by Codex and the auto-discovered `hooks/hooks.json` path in Claude Code. [1], [2]
- **Hook process execution environment:** When invoking hook processes, Herdr supplies the environment variable `HERDR_PLUGIN_ROOT` pointing to the canonical absolute installed plugin root directory. The hook dispatcher in `hooks.json` uses `${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${HERDR_PLUGIN_ROOT:-}}}` so that whichever client environment is present resolves the absolute path to the hook script. [2], [3]
- **Hook events and payload shape:** Loom defines guards for two lifecycle events:
  - `PreToolUse`: fires before tool execution, passing JSON on stdin containing `tool_input.command` for shell execution.
  - `PreCompact`: fires before session compaction, passing JSON on stdin containing `trigger` (`manual` or `auto`) and `session_id`. [2], [4]
- **Process wire and block envelope:** In Herdr's POSIX sub-process execution model, hook processes communicate through process exit status and standard streams:
  - Policy allow: exit code `0`, empty stdout and stderr.
  - Policy block / malformed input: exit code `2`, empty stdout, single-line error message `<reason>\n` on stderr.
  This matches standard POSIX tool conventions and Claude Code's command-hook interface. [4], [5]
- **Provisional contract boundary:** This wire contract is established as a provisional default for M9 slice 2 (`herdr-native-app-hooks`) to enable offline fixture construction and static verification without requiring a live GUI desktop window. Behavioral end-to-end confirmation with live `/Applications/Herdr.app` is owned by M9 slice 3 (`herdr-verification`). [5]

## Sources

[1] `/Applications/Herdr.app/Contents/Info.plist` and `Contents/MacOS/Herdr --skill`, `--version`, `--help` — verifies Herdr v0.1.10 application architecture, mod discovery, and configuration home.
[2] `.docs/ADR/0029-herdr-client-adapter-and-native-app-support.md` and `.docs/research/2026-11-01-herdr-client-adapter-contract.md` — establishes Herdr client adapter authorization, installed-root binding (`herdr-plugin-root/v1`), and manifest metadata.
[3] `plugins/loom/hooks/hooks.json` — establishes shared hook manifest resolution across client root environment variables.
[4] `.docs/spec/08-playbook.md` § "Hook normalization and output adapters" — establishes normalized hook events, reason bounds (<= 512 bytes, control-free), and client output adapters.
[5] `.docs/repository-improvement-plan.md` § "M9 — Client compatibility: Herdr and native app integration" — establishes M9 milestone progression from adapter to hooks to live verification.

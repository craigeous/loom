# Research: Orca CLI and Antigravity CLI — Runtime Reference for Loom v0.3.0

Status: Approved
Date: 2026-11-08
Topic: Runtime reference for Orca CLI (`orca` 1.4.250) and Antigravity CLI (`agy` 1.4.12) on macOS 14+ Apple silicon, establishing verified CLI behavior and interface capabilities to support v0.3.0 host and client admission under ADR 0034.

## Summary

- **Orca is a host environment providing terminal and worktree primitives.** The CLI (`/Applications/Orca.app/Contents/Resources/bin/orca` 1.4.250) exposes synchronous and asynchronous terminal lifecycle management (`terminal create`, `terminal send`, `terminal wait`, `terminal read`, `terminal close`, `terminal list`) and git worktree isolation (`worktree create`, `worktree current`, `worktree ps`). [1]
- **Orca terminal lifecycle maps directly to Loom host adapter requirements.**
  - Creation: `orca terminal create --worktree <sel> --command <cmd> --json` launches a program in an isolated terminal and returns a stable runtime handle `term_<id>`. [1]
  - Interaction: `orca terminal send --terminal <handle> --text <text> --enter --json` sends input. [1]
  - Observation: `orca terminal read --terminal <handle> --lines <n> --json` and `orca terminal list --json` read terminal state and status. [1]
  - Synchronization: `orca terminal wait --terminal <handle> --for exit --timeout-ms <ms> --json` waits deterministically for termination. [1]
  - Teardown: `orca terminal close --terminal <handle> --json` closes the terminal. [1]
- **Orca satisfies host-adapter separation.** Orca acts as an outer container host; sub-agents launched within Orca terminals execute native CLI binaries (`claude`, `codex`) or interactive sessions. Evaluator isolation is preserved by launching evaluators in standalone POSIX execution workspaces (`0700` directories) rather than inside Orca terminal sessions. [1][3]
- **Antigravity is a multi-family client runtime with dynamic model discovery.** The CLI (`/Users/craig/.local/bin/agy` 1.4.12) dynamically discovers available backends and models via `agy models`. [2]
- **Antigravity model catalog spans multiple model families.** Observed catalog on macOS 14+ Apple silicon:
  - Google Gemini: `gemini-4-argon-medium`, `gemini-4-argon-high`, `gemini-4-argon-low`, `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `gemini-3.8-flash-low`.
  - Anthropic Claude: `claude-opus-5-5-low`, `claude-opus-5-5-medium`, `claude-opus-5-5-high`, `claude-sonnet-5-5-low`, `claude-sonnet-5-5-medium`, `claude-sonnet-5-5-high`.
  - Open weights: `gpt-oss-120b-medium`. [2]
- **Cross-family evaluation governance must track model family, not client name.** Because `agy` can run Claude, Gemini, or OSS models, cross-family rotation cannot rely on client token (`antigravity`) alone; it must resolve the underlying provider family (`google`, `anthropic`, `openai`, `oss`) to prevent intra-family self-review (e.g. `agy` running Claude reviewed by Claude Code). [2][3]

## 1. Verified Command Capabilities

| Harness | Command | Verified Behavior & Schema | Reference |
|---|---|---|---|
| `orca` | `orca --version` | Emits `1.4.250` (exit 0). | [1] |
| `orca` | `orca terminal create` | Accepts `--worktree`, `--command`, `--title`, `--json`; returns handle. | [1] |
| `orca` | `orca terminal send` | Accepts `--terminal`, `--text`, `--enter`, `--wait-submit`; returns status. | [1] |
| `orca` | `orca terminal wait` | Accepts `--terminal`, `--for exit`, `--timeout-ms`; returns exit code. | [1] |
| `orca` | `orca terminal read` | Accepts `--terminal`, `--lines`, `--screen`; returns screen/history buffer. | [1] |
| `orca` | `orca terminal close` | Accepts `--terminal`, `--json`; terminates process and frees handle. | [1] |
| `orca` | `orca repo list` | Lists registered repository paths and project setups. | [1] |
| `agy` | `agy --version` | Emits `1.4.12` (exit 0). | [2] |
| `agy` | `agy models` | Queries server and prints tabular model identifiers and friendly names. | [2] |

## References

[1] Local runtime inspection: `/Applications/Orca.app/Contents/Resources/bin/orca --help` and `orca --version`, executed 2026-11-08.
[2] Local runtime inspection: `/Users/craig/.local/bin/agy --version` and `agy models`, executed 2026-11-08.
[3] ADR 0022 (Controlled-Input Independent Evaluation), ADR 0027 (Ambient Model Inheritance), and ADR 0031 (Herdr as an hc-Driven Client).

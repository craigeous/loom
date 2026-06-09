# Gate: Shell

Status: Verified

Detected by: at least one `*.sh` file with a `#!/bin/sh`, `#!/usr/bin/env bash`,
or `#!/bin/bash` shebang, **and no `Cargo.toml`** at the repo/workspace root (a
`Cargo.toml` short-circuits to the Rust gate; the no-`Cargo.toml` clause keeps the
signal unambiguous against a Rust project that merely contains helper shell scripts).

Run in this order before a slice is marked `Implemented`; all must pass:

| Step   | Command                         |
|--------|---------------------------------|
| format | `shfmt -i 4 -d <paths>`         |
| lint   | `shellcheck <paths>`            |
| test   | `bats <test dir or file>`       |

Notes:
- The code evaluator **re-runs** this gate; it does not trust the recorded result.
- **shfmt indent:** `-i 4` matches a 4-space-indented project (such as loom's hook);
  a tab-indented project uses plain `shfmt -d`. The `-d` flag (diff mode) exits
  non-zero on any diff — that is the required behavior.
- **Test command is project-specific.** loom's own concrete gate on
  `plugins/loom/hooks/git-identity-guard.sh` is:
  - format: `shfmt -i 4 -d plugins/loom/hooks/git-identity-guard.sh`
  - lint: `shellcheck plugins/loom/hooks/git-identity-guard.sh`
  - test: `bats plugins/loom/hooks/git-identity-guard.bats`
- This is the first **learned** gate (recorded via the gate-learning mechanism,
  `references/gate-learning.md` Step 5); the next shell project loom encounters
  inherits it via the verified-gate path.

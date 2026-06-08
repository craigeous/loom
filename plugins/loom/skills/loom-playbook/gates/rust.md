# Gate: Rust

Status: Verified

Detected by: a `Cargo.toml` at the repo root (or workspace root).

Run in this order before a slice is marked `Implemented`; all must pass:

| Step   | Command                                       |
|--------|-----------------------------------------------|
| format | `cargo fmt --check`                           |
| lint   | `cargo clippy --all-targets -- -D warnings`   |
| test   | `cargo test`                                  |

Notes:
- `-D warnings` is what catches unused imports / dead code — keep it.
- For a workspace, run from the workspace root; add `--workspace` to clippy/test if
  members aren't picked up by default.
- The code evaluator **re-runs** this gate; it does not trust the recorded result.
- This is the only verified gate that ships with loom. New stacks get a gate created
  during init and recorded as `gates/<stack>.md`.

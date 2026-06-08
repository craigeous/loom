# Recommended Tooling

> All tools listed here are **RECOMMENDED, not required**; loom never hard-requires
> a tool (same rule as gates). Detect-and-prefer: if the tool is on `PATH` (or the
> language server is available), use it; otherwise fall back to the named
> alternative. A missing tool is never a blocker.

Most of these tools help on **managed CODE projects**; loom's **own markdown
repo** benefits mainly from `rg -U`, `yq`/`jq`, and the mechanical-check
discipline described below.

## The Mechanical-Check Principle

Invariants must be verified **mechanically**, not by reading. Reading alone is
unreliable: two concrete misses proved this —

- A **bare `/loom`** in prose survived an eyeball pass (spec 10, line 107); the
  convention is the namespaced `loom:<name>` / `/loom:<name>`, never bare `/loom`.
- A **line-wrapped `Code\nReview`** status token survived a line-based `grep`
  because the token spanned a line break; only `rg -U` (multiline mode) catches it.

The rubric rules in `plan-eval-rubric.md` and `code-eval-rubric.md` make this
discipline explicit for both evaluators: see the "Invariants verified
mechanically" bullet in each.

## Task → Preferred Tool → Fallback

| Task | Preferred | Fallback |
|------|-----------|----------|
| Multiline / wrapped-token text invariant | `rg -U` | `grep` + `tr -d '\n'`, or careful read |
| Config fact in YAML/JSON/TOML | `yq` / `jq` | careful manual read |
| Structural code search / refactor | `ast-grep` (`sg`) | `rg` |
| Structural search/replace ast-grep can't express | `comby` | manual edit |
| Syntax-aware diff of a commit | `difft` (difftastic) | `git diff` |
| "Did this change break callers?" / jump-to-def / type errors | LSP / code-intelligence find-references | read + `rg` for the symbol |
| Lint generated shell | `shellcheck` | manual review |
| Language / LOC detection at init | `scc` | `rg --files` + extension counting |

## By-Role Guidance

### Researcher

Mostly reads and cites. Prefer `rg -U` to confirm a claimed string truly exists
(and isn't line-wrapped past a line-based grep) before citing it. Fallback:
careful manual read of the raw file.

### Planner

When a plan asserts an invariant ("no bare `/loom`", "manifest key X = Y"),
verify it with `rg -U` / `yq` against the real tree before writing it as fact,
rather than trusting a read. Fallback: a careful manual cross-check against the
file. This is the same "verify references against the real tree" discipline
already in the planner's rules.

### Developer

On **managed CODE projects**: prefer `ast-grep` / LSP find-references to verify
signatures, types, and callers against the tree (makes the step-3 "don't code
from memory" rule deterministic); prefer `shellcheck` on generated shell.
Fallback: `rg` for the symbol + careful read; manual shell review.

On **loom's own markdown repo**: prefer `rg -U` to confirm cross-links and
tokens. Fallback: careful manual read.

### Plan-Evaluator

Verify any invariant the plan asserts with `rg -U` / `yq` rather than eyeballing
the artifact — a wrapped token or a bare `/loom` survives a read. Fallback:
careful manual cross-check of the raw file content.

### Code-Evaluator

Prefer `difft` for a syntax-aware view of the commit diff; prefer `ast-grep` /
LSP find-references to answer "did this diff break callers?"; prefer `rg -U` over
the diff/tree for text invariants. Fallback: `git diff` + `rg` for the symbol +
careful read. These tools augment, never replace, the gate — still re-run the
gate.

## Nice-to-Have (Not Correctness-Relevant)

`hyperfine` (benchmarking), `watchexec` (file-watch task runner), and `delta`
(paged diff UI) are useful for development ergonomics but are out of scope for
invariant-checking.

## Provenance

The LSP / code-intelligence guidance derives from Claude Code's code-intelligence
capability (jump-to-definition, find-references, post-edit type errors).

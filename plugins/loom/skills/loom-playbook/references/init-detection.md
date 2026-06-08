# Init-Mode Detection

The classifier every `/loom:*` command runs first. The authority is
[`../../../../../.docs/spec/06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md).
Spec `06-init-modes.md` wins on any conflict.

Detection is **read-only**: it never creates or mutates files. Acting on the
detected mode is the caller's job.

---

## Inputs to inspect (read-only)

- Presence of a `.docs/` directory at repo root.
- Whether that `.docs/` is **loom-shaped** (definition below).
- Whether the repo is **empty/near-empty** (definition below).

---

## Definition — "loom-shaped `.docs/`"

A `.docs/` that contains the canonical marker set from
[`docs-layout.md`](docs-layout.md). Concretely, ALL of:

- `.docs/spec/README.md` exists, **and**
- `.docs/status/` exists with `roadmap.md`, `progress.md`, and `handoff.md`.

If `.docs/` exists but is missing any of these markers, it is **present but not
loom-shaped** — treated as Unaligned, not Initialized.

---

## Definition — "empty/near-empty repo"

No tracked source/content beyond incidental scaffolding. Classify as
empty/near-empty when `git ls-files` returns only files matching this allowlist
(and nothing else):

- `.git*` (e.g. `.gitignore`, `.gitattributes`)
- `README*`
- `LICENSE*`
- `.editorconfig`
- An empty-or-near-empty `CLAUDE.md`

Any tracked build manifest, source file, or substantive doc means **not**
empty/near-empty. If the repo has no commits yet, apply the same allowlist to
the working tree.

> This is loom's operative definition of the spec-06 term "empty/near-empty."
> Spec 06 introduces the term but does not enumerate the allowlist; the list
> above is the playbook's concrete expansion.

---

## Classification procedure

First match wins:

```
1. loom-shaped .docs/ present?             → Initialized
2. .docs/ absent AND repo empty/near-empty → Greenfield
3. otherwise                               → Unaligned
      (covers: no .docs/ in a non-empty repo,
       AND .docs/ present but not loom-shaped)
```

This is a faithful, disambiguated expansion of the spec-06 sketch. A
present-but-not-loom-shaped `.docs/` resolves to Unaligned (the spec's
"`.docs/` not loom-shaped" branch), and Initialized requires the full marker
set. The rule order means a loom-shaped `.docs/` always wins — even when the
rest of the repo is otherwise empty.

---

## Edge cases

- `.docs/` present + loom-shaped + repo otherwise empty → **Initialized**
  (loom markers outrank emptiness; rule 1 precedes rule 2).
- Partial loom scaffold (e.g. `.docs/spec/` exists but `status/` markers
  missing) → **Unaligned**; re-running init/align will complete it.
- Detection is **read-only**: it never creates or mutates files.

---

## What each mode dispatches to

| Mode | Action | Spec reference |
|---|---|---|
| Greenfield | Scaffold `.docs/`, apply playbook, establish gate | [`06-init-modes.md §1`](../../../../../.docs/spec/06-init-modes.md) |
| Unaligned | Alignment pass: scaffold + playbook + gate + descriptive back-fill | [`06-init-modes.md §2`](../../../../../.docs/spec/06-init-modes.md) |
| Initialized | Summarize current state and continue | [`06-init-modes.md §3`](../../../../../.docs/spec/06-init-modes.md) |

Behavior bodies are detailed in `06-init-modes.md` and the relevant M2 slice.
This reference only classifies.

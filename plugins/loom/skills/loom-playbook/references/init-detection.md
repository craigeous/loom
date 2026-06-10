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
- Whether a **pre-existing docs spine** exists outside `.docs/` (definition
  below) — used only to sub-classify Unaligned; read-only.

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

## Definition — "pre-existing docs spine"

A **non-`.docs/` methodology tree** at repo root — a docs directory that
looks like a project methodology, not just stray notes. Detect it read-only:

A candidate root is a tracked directory named one of `docs/`, `doc/`, or
`documentation/` (case-insensitive). A candidate is a **pre-existing docs
spine** when it contains **at least one** of these methodology markers
(matched by directory or filename, case-insensitive):

- a **specs** grouping — a `spec`/`specs` subdirectory, OR numbered
  spec-spine files (e.g. `00-*.md`, `01-*.md`, … — two or more);
- a **decision-record** grouping — an `adr`/`adrs`/`decisions` subdirectory,
  OR `adr`/`decision`-named records;
- a **roadmap / progress / handoff**-style living doc — a file whose name
  contains `roadmap`, `progress`, or `handoff`;
- a **slice-plan / plan lifecycle** grouping — a `slice-plans`/`plans`
  subdirectory.

A directory with only a `README` or a few loose, unstructured notes is **not**
a spine. Record the matched path for the observation below. The distinguishing
fact is the presence of a methodology tree, **not** the repo's language or
size.

> This is loom's operative expansion of the spec-06 term "pre-existing docs
> spine." Spec 06 introduces the term and example paths but does not enumerate
> the markers; the set above is the playbook's concrete expansion. Spec 06
> wins on any conflict.

---

## Classification procedure

First match wins:

```
1. loom-shaped .docs/ present?             → Initialized
2. .docs/ absent AND repo empty/near-empty → Greenfield
3. otherwise                               → Unaligned
      (covers: no .docs/ in a non-empty repo,
       AND .docs/ present but not loom-shaped)
      then sub-classify Unaligned:
        a. pre-existing docs spine present?  → Unaligned-migrate
        b. else                             → Unaligned-bare
```

This is a faithful, disambiguated expansion of the spec-06 sketch. A
present-but-not-loom-shaped `.docs/` resolves to Unaligned (the spec's
"`.docs/` not loom-shaped" branch), and Initialized requires the full marker
set. The rule order means a loom-shaped `.docs/` always wins — even when the
rest of the repo is otherwise empty.

When the Unaligned branch is reached, detection sub-classifies by spine
presence. If a pre-existing docs spine is found, detection records "a
non-loom docs spine exists at `<path>`" and steers the acting body toward
Unaligned-migrate rather than back-fill. The sub-classification is
**read-only** — it observes the spine and steers; it mutates nothing. Authority
for the split: spec 06 §2a / §2b and ADR 0009 §2
([`0009-unaligned-migrate-sub-mode.md`](../../../../../.docs/ADR/0009-unaligned-migrate-sub-mode.md)).

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
| Unaligned-bare | Alignment pass: scaffold + playbook + gate + descriptive back-fill | [`06-init-modes.md §2a`](../../../../../.docs/spec/06-init-modes.md) |
| Unaligned-migrate | Reconcile/migrate the pre-existing docs spine into `.docs/` (owner gate; status-preserving); resume Initialized | [`06-init-modes.md §2b`](../../../../../.docs/spec/06-init-modes.md) |
| Initialized | Summarize current state and continue | [`06-init-modes.md §3`](../../../../../.docs/spec/06-init-modes.md) |

Behavior bodies are detailed in `06-init-modes.md` and the relevant M2 slice.
This reference only classifies.

# Migration Recipe (Unaligned-migrate)

The reusable, ordered, idempotent procedure for migrating an existing un-dotted
docs spine into `.docs/`, run inline by `/loom:init` on the Unaligned-migrate
path **after** the owner has chosen *migrate*.

**Authority:**
[`../../../../../.docs/spec/06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md)
§2b and
[`../../../../../.docs/ADR/0009-unaligned-migrate-sub-mode.md`](../../../../../.docs/ADR/0009-unaligned-migrate-sub-mode.md)
§5 (load-bearing properties) and §7 (operational preconditions).
Spec `06-init-modes.md` wins on any conflict.

**Precondition:** `init-detection.md` classified the repo
**Unaligned-migrate** (a pre-existing docs spine exists at `<path>`) **and** the
owner answered the migrate/thin-pointer/abort gate with **migrate** (spec 06 §2b /
ADR 0009 §3 — the gate itself is not part of this recipe; it gates entry to it).
This body **writes and moves** files.

---

## Step A — Preconditions before any move (ADR 0009 §7)

A required, ordered pre-flight that runs before a single file moves. All three
checks must pass.

### A.1 — Dirty-tree check first

Run `git status` before moving anything. If the working tree is dirty, **stash
or flag** the pre-existing uncommitted edits before moving anything, so they are
not bundled into the alignment commit (ADR 0009 §7; field report Operational
failure 3):

```sh
# refuse-or-stash a dirty tree before migrating
if [ -n "$(git status --porcelain)" ]; then
  # stash (or stop and tell the owner) — do not bundle pre-existing edits
  git stash push -u -m "pre-migration WIP"
fi
```

Do not proceed with any move until the working tree is clean.

### A.2 — Detect untracked files in the source spine

`git mv` **silently skips untracked files** (field report Operational failure 1:
ballboy's untracked `18-python-parity-analysis.md` was left behind when the spine
was moved). Enumerate untracked content under the source spine and move it with
plain `mv` + `git add` **separately** from the `git mv` of tracked files:

```sh
# enumerate untracked files under the source spine
git ls-files --others --exclude-standard -- <source-spine>/

# for each untracked file found:
mv <source-spine>/<file> .docs/spec/<file>
git add .docs/spec/<file>
```

The tracked set (handled by `git mv`) and the untracked set (handled by `mv` +
`git add`) must be treated as two distinct groups.

### A.3 — Build all bulk file lists NUL-delimited

Every bulk list — for moves and for the rewrite passes — is built using
`find … -print0 | xargs -0 …`. **Never** use word-splitting `$(find …)` (field
report Operational failure 2: space/newline splitting in `$(find …)` silently
glued and skipped files).

```sh
# correct — NUL-delimited, safe for filenames with spaces or newlines
find .docs/ -type f -name '*.md' -print0 | xargs -0 ...

# WRONG — word-splitting anti-pattern; silently breaks on spaces and newlines
$(find .docs/ -type f -name '*.md')
```

State this as a hard rule: `$(find …)` is the anti-pattern; `-print0 | xargs -0`
is always required for bulk operations.

---

## Step B — Numbered-spine → `spec/` + `status/` split (ADR 0009 §5 fourth bullet)

This step pulls the living docs out of a numbered spine and places each piece in
the correct location.

### B.1 — Extract the living docs into `.docs/status/`

The spine's roadmap/progress/handoff-equivalents move to `.docs/status/`. In the
ballboy field report (§4): `08-roadmap.md` → `status/roadmap.md`,
`09-session-handoff.md` → `status/handoff.md`, `10-progress.md` →
`status/progress.md`. Everything else in the spine goes to `.docs/spec/`.

Identify the living docs (roadmap, progress, handoff) by their content role; the
numeric prefix is not the deciding criterion. Move them to `status/`; move the
remaining spine files to `spec/`.

### B.2 — Numbering gaps are expected and accepted

Extracting 08/09/10 leaves `spec/` with gaps (e.g. 00–07, 11–18). The gaps are
left as-is — renumbering is not part of migration — so existing inbound references
to those files stay valid.

### B.3 — Two-directional link rewrite

Pulling files across directory boundaries breaks links **in both directions**. The
recipe must rewrite both directions:

- **Same-directory links *to* the extracted files** — other spine files that
  referenced `08-roadmap.md` as a sibling must be rewritten to `../status/roadmap.md`
  (i.e. the sibling reference becomes an outbound `../status/...` reference).
- **Outbound links *from* the extracted files** to the rest of the spine must be
  rewritten to `../spec/...` (the extracted file's new location is `.docs/status/`
  so the spine files are now one directory up and across).

Both directions must be handled; missing either direction leaves broken links.

---

## Step C — Ordered cross-reference rewrite rules (ADR 0009 §5 first bullet)

The **specific-before-generic** ordering is a hard requirement. State the rewrite
rules as an explicitly ordered list:

1. **Specific renames first** — the living-doc renames (spine's roadmap/handoff/
   progress → `.docs/status/...`, and any other specific rename identified in Step
   B) run **before** the generic `docs/...` → `.docs/...` rule.
2. **Generic catch-all last** — the generic `docs/specs/...` → `.docs/spec/...`
   (or `docs/...` → `.docs/...`) rule runs after all specific renames.

Applying the generic rule first would wrongly land 08/09/10-type living docs in
`spec/` instead of `status/`. The ordering is load-bearing.

---

## Step D — Idempotency / the self-match hazard (ADR 0009 §5 second bullet)

The recipe must be safe to re-run. **The self-match hazard:** a naive `docs/...` →
`.docs/...` rule **re-matches its own output**, producing `..docs/...` instead of
`.docs/...`.

Guard against re-matching already-rewritten paths using a **negative lookbehind
`(?<!\.)`** so an existing leading dot is not re-prefixed:

```
# guarded pattern — matches "docs/" only when NOT preceded by a dot
(?<!\.)docs/
```

The guarded pattern produces `.docs/` for an unmatched `docs/` and leaves `.docs/`
unchanged because the lookbehind fails on the preceding `.`. **Re-running the
recipe must be a no-op on already-migrated paths.** A `..docs/` artifact in the
output is always a sign the guard was missing.

---

## Step E — Three reference forms, handled separately (ADR 0009 §5 third bullet)

Each of the three forms that appear in docs must get its **own** rewrite rule.
Collapsing them into a single rule loses cases.

**(a) Path-form mentions** — e.g. `docs/specs/X` appearing in prose or as a path
argument — are matched by a path-aware rule that targets the path form specifically.

**(b) Bare markdown link targets** — e.g. `](X.md)` — these resolve **relative to
the file's new location** after it moves. The rewrite must account for the file
having moved; this is why Step B's two-directional rewrite is needed. A link target
correct in the source location may become broken at the destination if the relative
path is not updated.

**(c) Prose / backtick mentions** — e.g. `` `docs/...` `` inline — are matched by
a prose-aware rule distinct from the link-target rule.

Each form is matched and rewritten by its own rule; do not merge them.

---

## Step F — Living-rewritten vs archived-snapshot boundary (ADR 0009 §5 fifth bullet)

**Living docs** are migrated and their refs rewritten. **Archived slice-plans** are
left as **historical snapshots** — consistent with loom's convention that archived
plans are history — and their **internal refs are NOT rewritten**.

The rewrite passes (Steps C–E) must therefore **exclude** the archive from the
rewrite file list. Build the rewrite file list NUL-delimited (Step A.3) with the
archive excluded:

```sh
# build the rewrite file list, excluding the archive
find .docs/ -type f -name '*.md' \
  -not -path '**/slice-plans/archive/**' \
  -print0 | xargs -0 ...
```

Never apply the link rewrite passes to the `archive/` subtree.

---

## Step G — Status preservation (pointer to policy)

Migrated specs **retain their prior status**. Migration is **not** a re-review
trigger. The policy is single-sourced in spec
[`06-init-modes.md`](../../../../../.docs/spec/06-init-modes.md) §2b ("Status
preservation") and
[`ADR 0009`](../../../../../.docs/ADR/0009-unaligned-migrate-sub-mode.md) §4.
Do not re-derive the policy here; apply it as stated there.

---

## Step H — Link validation (final step)

As the **last step**, validate links across the migrated tree. Re-scan for any
remaining un-rewritten `docs/...` references and for self-match artifacts
(`..docs/...`), and confirm moved-file relative links resolve.

```sh
# no un-rewritten source-tree refs remain (outside the left-as-history archive)
rg -n --glob '!**/slice-plans/archive/**' '(?<!\.)\bdocs/' .docs/ \
  && echo "FAIL: unrewritten refs" || echo "OK"

# no self-match artifacts
rg -n '\.\.docs/' .docs/ && echo "FAIL: self-match artifact" || echo "OK"
```

Both checks must return `OK` before the alignment commit is made. If either fails,
trace back to the relevant step (D for self-match; C/E for unrewritten refs) and
correct.

This is the final step of link validation — all prior steps must complete before
this check is run.

---

## Idempotence / scope note

Re-running the recipe on an already-migrated repo is a no-op: the dirty-tree check
(Step A.1) sees a clean tree, the `git mv` / `mv` steps find no source spine to
move, and the negative lookbehind guard (Step D) ensures the `(?<!\.)` rewrite
passes leave already-rewritten `.docs/` paths unchanged. The recipe never touches
archived history (Step F) and never edits the spec or ADR — it relocates and
re-references existing artifacts only.

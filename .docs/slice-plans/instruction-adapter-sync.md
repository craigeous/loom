# Instruction Adapter Sync

Status: Plan Review
Target specs: 08-playbook.md, 06-init-modes.md, 03-artifact-lifecycle.md
Target size: <= 170 LOC net change (keep this plan document <= 250 lines)

## Context

Spec 08 (*Canonical project instruction digest*; *`CLAUDE.md` and `AGENTS.md`
adapters*) makes `.docs/status/project-instructions.md` the canonical digest. Root
`CLAUDE.md` and `AGENTS.md` (and, in this repo, `GEMINI.md`) each carry exactly one
Loom-owned block:

```text
<!-- loom:project-instructions begin schema=loom-project-instructions/v1 sha256=<64-hex> -->
...
<!-- loom:project-instructions end -->
```

The `sha256` is the lowercase SHA-256 of the canonical digest file's exact UTF-8 bytes,
with line endings normalized to LF and exactly one trailing LF (spec 08). It is **not**
a hash of the block. Today all three markers carry
`025e848ae610480a69d54967c9cafb87effe278464130d9cf421ca7100b2b2bf`, which still equals
`shasum -a 256 .docs/status/project-instructions.md`, because the digest was never
changed.

Findings, verified against the tree at `cc2b1ef`:

1. **No renderer or regeneration script exists.** Nothing under `plugins/`, `scripts/`,
   or the init references (`greenfield.md`, `unaligned.md`, `initialized.md`)
   mentions `project-instructions`, `AGENTS.md`, or the block markers. The blocks were
   hand-authored in the `macos-dogfood-program-amendment` slice (`aacf8da`) and
   `0dd3db9` (GEMINI.md). Spec 08's renderer and renderer fixtures are unimplemented.
   That is a larger gap, and this slice does not close it (Out of Scope).
2. **The gate does not check the blocks.** `scripts/validate-repository.mjs` has no
   rule for the digest hash, the markers, or adapter parity. The bullets in spec 08
   *Mechanical invariants* ("canonical-digest schema/hash and both instruction
   renderings") are also unimplemented. So the stale text passed the gate.
3. **The drift.** The landed `dogfood-retirement` slice hand-edited only the
   `CLAUDE.md` block. It replaced "Private macOS dogfood is not public support or
   release conformance." with the ADR 0032 §2 invariant. It did not change the
   canonical digest (`.docs/status/project-instructions.md:20-21` still states the
   retired invariant), `AGENTS.md:8-9`, or `GEMINI.md:10-11`. The hash still matches
   because the digest is unchanged. Spec 08 treats a manual block edit as an error, so
   the canonical source is now behind its own derived file.
4. **Other copies of the old wording:** ADR 0032 (it quotes the text it replaces, and
   the ADR is immutable), the archived plans `dogfood-retirement.md` and
   `packaging-conformance.md`, `.docs/evaluations/dogfood-retirement-eval.md`
   (historical records), and the shelved active plan `hc-live-probe.md:39` (a
   parenthetical citation, not an instruction block). There are no spec examples or
   test fixtures that embed the bullet.

This slice does four things. It moves the ADR 0032 §2 wording into the canonical
digest. It recomputes the digest hash with a fixed command and writes it into all
three markers. It makes the shared lines of the `AGENTS.md` and `GEMINI.md` blocks
byte-identical to `CLAUDE.md`. It also adds a small `--all` validator rule so the
next drift of this kind fails `scripts/check`. Only the hash/marker/parity subset of
spec 08 gets mechanized here. That subset needs no renderer, and it fits the existing
`validatePackaging()` pattern.

## Out of Scope & Threat-Model Boundary

- No spec, ADR, `README.md`, or `hc-live-probe.md` edit. Historical records stay
  untouched.
- No renderer, renderer fixtures, or semantic check that block text matches the
  digest's meaning. A future slice should implement the spec 08 renderer. Until
  then, a coordinated edit of all three blocks without a digest change still passes.
  The new rule catches single-adapter drift and digest changes made without
  re-stamping the markers.
- The client-specific final bullet of each block (Claude, Codex, and Antigravity
  invocation lines) stays as it is, and the rule does not compare it.
- `CLAUDE.md` changes only on its marker line, so it stays at 101 lines. A reflow
  back to 100 lines is **not** included. The ADR 0032 §2 sentence is about 300
  characters and needs 4 lines at the file's ~88-column width, so dropping a line
  would mean editing owner text outside the block. The 1-line excess over spec 08's
  80–100 target is a pre-existing finalize-pass item and stays out of this slice.
- No other digest content changes. For example, the "v0.2 release gate remains
  M0–M7" gate bullet stays as written, even if ADR 0032 makes it stale. That needs
  separate authorization.
- Threat model: per `.docs/spec/00-overview.md` *Non-goals*, the rule is a drift
  detector for trusted maintainers, not a defense against a hostile local writer.
  It reuses `readText`/`safeNode` (symlink and escape rejection) and nothing more.

## Steps

1. **`.docs/status/project-instructions.md`.** In `## Core invariants`, replace
   exactly these two lines:

   ```text
   - Loom has a portable shared core with thin client/host adapters. Private macOS
     dogfood is not public support or release conformance.
   ```

   with:

   ```text
   - Loom has a portable shared core with thin client/host adapters. A (platform,
     harness) pair is supported only in a release whose compatibility matrix lists it
     with complete conformance evidence; there is no private or partial support tier.
     Evidence from one platform or harness is not conformance for another.
   ```

   Keep LF endings and exactly one trailing LF. Change nothing else.

2. **Compute the digest hash mechanically** using the spec 08 algorithm. Never type
   it by hand:

   ```sh
   NEW=$(node -e 'const f=require("fs"),c=require("crypto");const t=f.readFileSync(process.argv[1],"utf8").replace(/\r\n?/g,"\n").replace(/\n*$/,"\n");process.stdout.write(c.createHash("sha256").update(t,"utf8").digest("hex"))' .docs/status/project-instructions.md)
   ```

   Cross-check that `shasum -a 256 .docs/status/project-instructions.md` prints the
   same value.

3. **Re-stamp all three markers from `$NEW`** (from the repo root):

   ```sh
   for f in CLAUDE.md AGENTS.md GEMINI.md; do
     sed -i.bak -E "s/^(<!-- loom:project-instructions begin schema=loom-project-instructions\/v1 sha256=)[0-9a-f]{64}( -->)$/\1${NEW}\2/" "$f" && rm "$f.bak"
   done
   ```

4. **`AGENTS.md` (lines 8–9) and `GEMINI.md` (lines 10–11).** Replace the two-line
   bullet beginning `- Keep shared policy portable and client adapters thin. Private
   macOS dogfood is not` with the 4-line bullet copied byte-for-byte from
   `CLAUDE.md` lines 13–16. Leave every other line in each block and in the file
   unchanged, including the client-specific final bullet and all of GEMINI.md's
   owner text after the end marker.

5. **`scripts/validate-repository.mjs`.** Add `import crypto from "node:crypto";`
   next to the other `node:` imports. Then add `function validateInstructionAdapters()`
   after `validatePackaging()` and call it with
   `if (mode === "all") validateInstructionAdapters();` right after the
   `validatePackaging()` call. The function behaves as follows:
   - **Activation (fail-closed).** Let `DIGEST = ".docs/status/project-instructions.md"`
     and `ADAPTERS = ["CLAUDE.md", "AGENTS.md", "GEMINI.md"]`. Probe each with
     `safeNode(p, { missing: false, regularFile: true })`. If the digest exists, or any
     existing adapter's text contains `loom:project-instructions`, the rule is active.
     Otherwise return, so existing fixture roots without these files are unaffected.
   - When active, read the digest with `readText(DIGEST)`. A missing digest is then
     reported as `required file is missing`. Return if it is null. Compute
     `expected` with the same normalization as Step 2.
   - **Required set.** `CLAUDE.md` and `AGENTS.md` are always checked when the rule
     is active (via `readText`, so a missing file is reported). `GEMINI.md` is checked
     only if it exists.
   - **Per adapter.** Split on `/\r?\n/`. Count lines matching
     `^<!-- loom:project-instructions begin schema=loom-project-instructions\/v1 sha256=([0-9a-f]{64}) -->$`
     and lines exactly equal to `<!-- loom:project-instructions end -->`. If there is
     not exactly one of each, or the end marker is not after the begin marker, report
     `<file>: expected exactly one loom:project-instructions begin marker followed by one end marker (found <B> begin, <E> end)`
     and skip this file. If the captured hash is not `expected`, report
     `<file>: loom:project-instructions sha256 <actual> does not match canonical digest sha256 <expected>`.
   - **Shared-line parity.** The block body is the lines strictly between the markers.
     Its shared part is the body up to, but not including, the last line matching
     `^- `, so the client-specific final bullet is excluded. Every checked adapter's
     shared part must equal `CLAUDE.md`'s shared part, compared as lines joined with
     `\n`. Otherwise report
     `<file>: loom:project-instructions shared lines differ from CLAUDE.md (only the final client-specific bullet may differ)`.
     Skip parity if `CLAUDE.md`'s block was invalid.
   - Use `report(...)` for diagnostics so they sort and set exit 1 like the other rules.
     Target: <= 45 lines.

6. **`scripts/tests/repository-validation.bats`.** After the packaging section, add
   `# ---- instruction adapter validation (--all) ----` with a helper and 6 tests,
   all built on `make_docs_root` plus `put`, run through `docs_all`. The helper
   `put_instruction_fixture` writes three files:
   - a minimal link-free digest (`# Project Instructions`, `Status: Living`,
     `Schema: loom-project-instructions/v1`, one bullet);
   - a `CLAUDE.md` and an `AGENTS.md`, each with a valid block whose sha256 is the
     digest hash computed in-test with the existing `sha256sum ... || shasum -a 256`
     idiom (see the `forced real-tree validator failure` test). Each block has two
     shared bullets and a distinct final bullet (`- Claude ...` / `- Codex ...`).

   Tests (expected `status` and output substring):
   1. `instruction adapters: matching digest hash and shared lines pass`: status 0.
   2. `instruction adapters: stale marker hash fails`: append a byte to the digest
      without re-stamping. Status 1, and output contains
      `CLAUDE.md: loom:project-instructions sha256` and `does not match canonical digest sha256`.
   3. `instruction adapters: single-adapter shared-line drift fails`: edit a shared
      bullet in `AGENTS.md` only. Status 1, and output contains
      `AGENTS.md: loom:project-instructions shared lines differ from CLAUDE.md`.
   4. `instruction adapters: client-specific final bullet may differ`: change only
      `AGENTS.md`'s final bullet. Status 0.
   5. `instruction adapters: duplicate or missing markers fail`: duplicate the begin
      line in `AGENTS.md`. Status 1, and output contains
      `AGENTS.md: expected exactly one loom:project-instructions begin marker`.
   6. `instruction adapters: an adapter block without the canonical digest fails`:
      remove the digest. Status 1, and output contains
      `.docs/status/project-instructions.md: required file is missing`.
   An optional GEMINI.md case is not required. The real-tree test
   `all mode passes for the valid repository` already exercises the three real files.
   Target: <= 85 lines.

7. **`.docs/slice-plans/README.md`.** The developer finalize pass moves this plan's
   index entry to `## Archived plans` in the normal landing step. The planner has
   already added the Active entry.

## Verification

Fast targeted checks (macOS, repo root):

1. `node scripts/validate-repository.mjs --all; echo "exit=$?"`. Expected: exit=0,
   with `Repository all validation passed`.
2. `grep -rn "Private macOS dogfood is not" CLAUDE.md AGENTS.md GEMINI.md .docs/status/project-instructions.md; echo "exit=$?"`.
   Expected: no matches and exit=1. Also run
   `grep -c "dogfood is not public support" .docs/status/project-instructions.md`,
   which should print `0`.
3. `grep -ho 'sha256=[0-9a-f]\{64\}' CLAUDE.md AGENTS.md GEMINI.md | sort -u`.
   Expected: exactly one line, equal to `sha256=` + the output of
   `shasum -a 256 .docs/status/project-instructions.md | cut -d' ' -f1`, and not
   `025e848a…`.
4. Run
   `for f in CLAUDE.md AGENTS.md GEMINI.md; do awk '/loom:project-instructions begin/{p=1;next}/loom:project-instructions end/{p=0}p' "$f" | sed -n '1,11p' | shasum -a 256; done`.
   Expected: three identical hashes. The first 11 body lines are the shared part.
5. `git diff --stat cc2b1ef -- CLAUDE.md` should show 1 line changed (the marker
   only), and `wc -l < CLAUDE.md` should print `101`.
6. A negative check proving the new rule protects the real tree: temporarily
   `sed -i.bak 's/no self-review/no self review/' AGENTS.md`, run
   `node scripts/validate-repository.mjs --all; echo "exit=$?"`, and expect exit=1
   with `AGENTS.md: loom:project-instructions shared lines differ from CLAUDE.md`.
   Then restore with `mv AGENTS.md.bak AGENTS.md`.
7. `TMPDIR=/private/tmp bats --filter 'instruction adapters' scripts/tests/repository-validation.bats`
   (with `LOOM_NODE` set as `scripts/check` sets it). Expected: 6 tests, 0 failures.
8. Format/lint the touched shell test file:
   `shfmt -i 4 -d scripts/tests/repository-validation.bats` and
   `shellcheck -s bash scripts/tests/repository-validation.bats`. Expected: no output
   and exit 0.

Full gate (once, on the candidate commit):
`TMPDIR=/private/tmp LOOM_BATS_JOBS=4 scripts/check` must exit 0. The regression
proof is the existing `repository-validation.bats` suite passing unchanged,
especially `all mode passes for the valid repository` and every `make_docs_root`
packaging/docs-state test, whose roots have none of the four files and so leave
the rule inactive.

## Notes

- 2026-11-06 (planner): Spec 08, spec 09 *Instruction files*, and the spec README
  make the digest canonical, not `CLAUDE.md`. `CLAUDE.md` holds the correct ADR 0032
  §2 text only because its block was hand-edited, so Step 1 restores the canonical
  source first.
- Docs-only fallback: if the plan evaluator judges a partial mechanization of spec 08
  *Mechanical invariants* out of bounds, drop Steps 5–6 and Verification 6–7. The
  slice then becomes Steps 1–4 (about 12 LOC), and the gate gap goes on the roadmap.

## Revision Log

| Round | Summary of in-place changes |
|---|---|
| 0 | Initial draft |

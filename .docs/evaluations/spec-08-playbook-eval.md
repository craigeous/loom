# Evaluation: spec/08-playbook.md

Verdict: PASS
Round: 1
Reviewed against: ADRs 0001–0006; the built playbook skill
(`plugins/loom/skills/loom-playbook/` — `SKILL.md`, `gates/rust.md`,
`references/{commit-convention,severity,plan-eval-rubric,init-detection,greenfield,docs-layout,status-machine}.md`,
`templates/*`); sibling Approved specs 01, 03, 05, 06, 07.

## Findings

- [MINOR] Packaging tree header (line 15) reads `loom/skills/loom-playbook/`,
  but the shippable plugin lives at `plugins/loom/` (ADR 0001 §Decision; ADR
  0006; spec 07 uses `plugins/loom/commands/` and `plugins/loom/agents/`). The
  `loom/...` prefix is the lone path in the spec that drops the `plugins/`
  segment, so it is inconsistent with the established convention and could read
  as a top-level `loom/skills/` dir that does not exist. Meaning is recoverable
  (the heading says "inside the plugin"), and the runtime form on line 22–23
  (`${CLAUDE_PLUGIN_ROOT}/skills/loom-playbook/...`) is correct because
  `${CLAUDE_PLUGIN_ROOT}` resolves to the plugin root. Not load-bearing for
  correctness; recommend prefixing the tree root with `plugins/` for parity.

- [MINOR] "These are largely the same content as the `agents/*.md` system
  prompts" (lines 35–36) is a soft, unverifiable claim about duplication rather
  than a stated invariant. The built tree keeps the *rubrics* in
  `references/{plan,code}-eval-rubric.md` and the blind contract in agents/
  prompts; the relationship is "agents reference the playbook rubrics," not
  "duplicated content." Reword to "agents reference these rubrics" to avoid
  implying a maintenance-burden duplication that the tree does not actually
  have. Non-blocking.

## Required changes (for FAIL)

None — PASS.

## Notes

Fidelity to the built playbook is strong. Verified claim-by-claim:

- **Packaging / "applies the result, not a copy"** (lines 22–26) matches
  `SKILL.md` lines 13–15 verbatim in intent. ✓
- **Contents list** (lines 30–42): `.docs/` structure, templates (research/ADR/
  spec/slice-plan/eval, each with a `Status:` line — confirmed in
  `templates/*`), status lifecycle, role rubrics + blind contract, gate
  definitions, `CLAUDE.md` template (`docs-layout.md` §Project `CLAUDE.md`),
  naming `<artifact>-eval.md` (matches `evaluation.md` location convention and
  ADR 0004 §Consequences). All present in the real tree. ✓
- **Verified gate (Rust)** (lines 59–69) matches `gates/rust.md` exactly:
  `cargo fmt --check` → `cargo clippy --all-targets -- -D warnings` →
  `cargo test`, in that order, "Rust is the only verified gate," others learned
  during init and recorded back. No command drift. ✓
- **Model tiers** (lines 44–48) match ADR 0002's table and `SKILL.md` lines
  61–64 (researcher haiku, developer sonnet, planner + both evaluators opus;
  tiers pinnable, versions track environment). ✓
- **Init-detection / greenfield references** exist as named
  (`references/init-detection.md`, `references/greenfield.md`) and the spec
  cites spec 06 correctly; gate-learning "learned during init then recorded
  back" matches `greenfield.md` Step E and `init-detection.md`. ✓
- **Skill-vs-plugin usage** is correct throughout: loom-playbook is genuinely a
  skill bundled in the plugin (ADR 0001 §Decision lists `skills/loom-playbook/`
  as a plugin component), and the spec consistently calls it a "bundled skill" —
  legitimate, not product-level drift. No stale bare `/loom`: the spec uses
  `/loom:run`-consistent references and never the deprecated bare `/loom`
  command name (it references commands generically). ✓
- **Commit identity** is not asserted in a way that contradicts
  `commit-convention.md`. The spec does not restate the commit rules in detail,
  but where it touches dogfooding ("changes are planned, evaluated, and landed
  like any other slice," lines 52–54) it is consistent with ADR 0003/0004 and
  the author-neutral/uniform-identity convention. No contradiction. ✓
- **Internal consistency / sibling specs**: cross-refs to specs 01, 03, 05, 06
  resolve to existing files with matching titles; no contradiction with spec 07
  (command surface) or the `.docs/` layout in spec 01 / `docs-layout.md`. ✓

The two MINORs are wording/path-parity hygiene and do not affect correctness or
plan-ability; per `severity.md` they do not block. Reviewed blind against the
authority and the real tree.

# GEMINI.md — loom (Antigravity Adapter)

<!-- loom:project-instructions begin schema=loom-project-instructions/v1 sha256=1c04cef53e48e9ca8830087536edc77948f71b176de0e02393defaddb495ee11 -->
## Loom project instructions

- Read `.docs/spec/README.md`, `.docs/status/handoff.md`, progress, then roadmap.
- Five cold roles use committed artifacts; no self-review; only root delegates.
- Specs change only through planner + cold plan evaluation. Remote verification and
  receipt establish `Landed`; never force-push a target.
- Keep shared policy portable and client adapters thin. A (platform, harness)
  pair is supported only in a release whose compatibility matrix lists it with
  complete conformance evidence; there is no private or partial support tier. Evidence
  from one platform or harness is not conformance for another.
- Run `scripts/check`; runtime floors are Bash 3.2+, Git 2.34+, and jq 1.6+.
- Antigravity workflows use `.agents/skills/loom-<name>/SKILL.md` routing to
  `plugins/loom/skills/loom-<name>/SKILL.md`; see specs 03, 04, 07, 08, and 10.
<!-- loom:project-instructions end -->

## Antigravity Deterministic Adapter Binding

Antigravity is bound to Loom's deterministic, fail-closed executable helpers and
repository validators:

### 1. Deterministic Helper Resolution (`loom-resolve-helper antigravity`)

Resolve `loom-coord` mechanically from the loaded skill path (never by guessing `$PATH`
or environment variables):

```sh
/Users/craig/git/loom/plugins/loom/bin/loom-resolve-helper antigravity \
  "/Users/craig/git/loom/.agents/skills/<skill>/SKILL.md" loom-coord
```

This fail-closed helper verifies physical containment, non-symlink skill/manifest
regularity, YAML frontmatter identity, and both `0.2.0` plugin manifests before
returning `/Users/craig/git/loom/plugins/loom/bin/loom-coord`.

### 2. Deterministic Cold Role Launch (`loom-launch-role antigravity <role>`)

Before spawning any role (`researcher`, `planner`, `plan-evaluator`, `developer`,
`code-evaluator`), run the fail-closed launcher by absolute path:

```sh
/Users/craig/git/loom/plugins/loom/bin/loom-launch-role antigravity <role>
```

`loom-launch-role antigravity <role>` deterministically:
- rejects descendant delegation (`LOOM_LAUNCH_ROLE_ACTIVE`), vendor model env overrides,
  and relative-path invocations;
- validates [`plugins/loom/adapters/compatibility/v0.2.0.json`](plugins/loom/adapters/compatibility/v0.2.0.json)
  schema and version;
- verifies [`plugins/loom/roles/<role>.md`](plugins/loom/roles/developer.md) is a
  physical regular file and computes its SHA-256 (`rolePromptSha256`); and
- prints a single `loom-role-launch/v1` JSON object containing the exact parameters to
  pass to Antigravity's `define_subagent` (`subagentName`, `enableSubagentTools: false`,
  `enableWriteTools: true`, `rolePromptPath`, `rolePromptSha256`) and `invoke_subagent`
  (`model`: `"flash"` for Economy, `"inherit"` for Standard, `"pro"` for Deep review,
  plus a fresh `coldId`).

### 3. Deterministic Repository & Git Hook Enforcement

- **Thin-adapter & frontmatter gate (`scripts/validate-repository.mjs`):** Every
  `.agents/skills/loom-*/SKILL.md` is mechanically checked during `scripts/check` for
  YAML frontmatter schema conformance (`skill-frontmatter-v1.schema.json`), `<= 20`
  line count, and an exact pointer to `skills/loom-<name>/SKILL.md`.
- **Git pre-commit & commit-msg hooks (`.git/hooks/pre-commit`, `.git/hooks/commit-msg`):**
  Every `git commit` run from any client (including Antigravity `run_command`) is
  deterministically checked for author-neutral commit messages (no `Co-Authored-By:` or
  AI attribution lines), non-bot git identity, and clean whitespace (`git diff --cached --check`).

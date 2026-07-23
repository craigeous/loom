# macOS-first dual-client dogfood program amendment

Status: Plan Review
Target specs: [00-overview.md](../spec/00-overview.md),
[02-roles.md](../spec/02-roles.md),
[03-artifact-lifecycle.md](../spec/03-artifact-lifecycle.md),
[04-orchestrator.md](../spec/04-orchestrator.md),
[06-init-modes.md](../spec/06-init-modes.md),
[07-command-surface.md](../spec/07-command-surface.md),
[08-playbook.md](../spec/08-playbook.md), and
[10-packaging.md](../spec/10-packaging.md)
Authority: [ADR 0024](../ADR/0024-macos-first-dual-client-dogfood-bootstrap-amendment.md)
Improvement slice: `macos-dogfood-program-amendment`

## Context

Remote `main` now contains the verified and settled M0 `ci-baseline` result. Accepted
ADR 0024 authorizes a private Apple-silicon macOS checkpoint before M1 while leaving
the Ubuntu/macOS-Intel v0.2 release matrix and M0–M7 release gate unchanged. This
documentation-only slice publishes ADR 0024 and its ratification evidence as merged
prerequisite authority, inserts the checkpoint without renaming M1–M8, amends the
frozen specs through cold plan evaluation, and brings every canonical/user-facing
document named by ADR 0024 section 7 into one consistent state.

This slice does not change plugin code, manifests, catalogs, fixtures, hooks, helper
behavior, client installation, or any public support/release claim. Those behaviors
belong only to the separately planned `macos-dual-client-dogfood` code slice.

## Exact path boundary

Implementation is confined to these paths, plus evaluator-owned evaluation output and
normal landing-only archive/index/living-status finalization:

- `.docs/repository-improvement-plan.md`
- `.docs/spec/README.md`
- `.docs/spec/{00-overview,02-roles,03-artifact-lifecycle,04-orchestrator,06-init-modes,07-command-surface,08-playbook,10-packaging}.md`
- `.docs/status/project-instructions.md`
- `README.md`
- `CLAUDE.md`
- `AGENTS.md`
- `.docs/slice-plans/macos-dogfood-program-amendment.md`

The accepted ADR/index/ratification files already integrated as prerequisite authority
remain byte-identical. Product paths under `plugins/loom/**`, catalogs, CI, schemas,
fixtures, scripts, and lockfiles are forbidden.

## Steps

1. Update `.docs/repository-improvement-plan.md` without renaming or combining M1–M8:
   insert a named `macos-dual-client-dogfood` checkpoint after M0; mark M0 landed;
   state that only Apple-silicon macOS dogfood execution gates the checkpoint; and
   retain the full ADR-0019 host/client matrix plus M0–M7 as the v0.2 release gate.
2. Amend `.docs/spec/README.md` and specs 00, 02, 03, 04, 06, 07, 08, and 10 as one
   authority change. Define the private checkpoint, shared-core/thin-adapter boundary,
   Claude `/loom:*` and Codex `$loom-*` mapping, five role mappings/no-delegation,
   hook `trigger`/blocking/trust evidence, installed-root rules, isolated client-home
   install/reinstall/uninstall evidence, inside/outside-project invocation, and the
   unchanged release matrix/gate. Keep intended design in specs and operational status
   out of them.
3. Create `.docs/status/project-instructions.md` using the exact
   `loom-project-instructions/v1` schema already fixed by spec 08. Render one matching
   Loom-owned block into `CLAUDE.md` and new `AGENTS.md`, preserving all owner text
   outside the markers. Compute the SHA-256 from the canonical body exactly as spec 08
   defines; both markers must carry that hash and the rendered semantics must be
   client-parity equivalents, not byte-identical client syntax.
4. Update `README.md`, `CLAUDE.md`, and `AGENTS.md` outside/inside their appropriate
   ownership boundaries so they agree on: current M0 static baseline, the not-yet-
   complete private macOS checkpoint, exact client floors, client-native invocation,
   installation limitations, full release support obligations, and `scripts/check`.
   Do not say Codex behavior is supported until the later code slice passes.
5. Run a cold plan evaluator over the complete amended planning set, not only this
   plan. Its controlled package includes ADR 0024, the accepted ADR/ratification
   bindings, prior target documents, amended documents, exact diff/path inventory,
   spec/plan rubric, and current protected transition/remote-main observations. Record
   degraded bootstrap labels; do not claim `loom-local-review/v1`, ADR-0022 isolation,
   or release conformance. A BLOCKER or MAJOR returns the planning set to Draft.
6. After PASS, prepare landing-only finalization: mark this plan `Archived`, move it to
   `.docs/slice-plans/archive/`, update the slice index, and update roadmap/progress/
   handoff to say the program amendment is prospectively landed and the code-bearing
   dogfood slice is next. Publish only through ADR-0023 intent, non-force remote-direct
   update, exact verification, receipt, settlement, and claim release.

## Verification

The planning/evaluation candidate must mechanically prove:

1. `git diff --name-only <base>...<head>` is a subset of the exact path boundary plus
   prerequisite ADR 0024 artifacts, evaluator output, and declared finalization paths;
   `git diff <accepted-adr-commit>..<head> -- .docs/ADR/0024* .docs/evaluations/0024*`
   shows no mutation of accepted history.
2. `rg` finds the ordered checkpoint between M0 and M1 while all literal M1–M8 headings
   remain once; every release statement still requires M0–M7 and Ubuntu 22.04/24.04,
   macOS arm64/Intel, Claude 2.1.216, and Codex 0.144.6 evidence.
3. Cross-document searches reject claims that Linux/Intel dogfood is required now,
   that macOS dogfood is a release, or that Codex behavior already passed. Searches
   also require all eight Claude/Codex workflow mappings and five role mappings in the
   frozen authority that owns them.
4. The canonical digest parser validates exact headings/order, hashes the normalized
   canonical body, finds exactly one marker block in each adapter, verifies both marker
   hashes, preserves text outside the blocks, and compares normalized semantic clauses.
5. `scripts/check` passes under system Bash 3.2 and current Bash 5.3 with
   `LOOM_DIFF_BASE` set to the fresh remote base. Because this is pure documentation,
   automated code/security finders are recorded as `skipped: docs-only`; the cold plan
   evaluator remains the verdict authority.
6. Immediately before publication, fresh reads must show transition phase `active`,
   `macos-dogfood-program-amendment` still allowed, and remote `main` equal to the
   candidate base. Any movement rebuilds and re-evaluates the affected planning set.

## Notes

- 2026-07-23: ADR 0024 and its acceptance/evaluation chain were merged without
  rewriting onto the fresh M0 result before this plan was authored.

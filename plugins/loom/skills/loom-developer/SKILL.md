---
name: loom-developer
description: Codex cold-subagent binding for loom's developer role — implements an approved slice-plan against the real code tree and proves it with the gate. Launched only by the root orchestrator through loom-run; never self-invoked.
---

# loom-developer — Codex role binding

**Profile:** Standard — see the versioned compatibility matrix at
`plugins/loom/adapters/compatibility/v0.2.0.json` for the exact `model` and
`model_reasoning_effort`.

**Installed-root bootstrap.** Resolve the physical installed plugin root by
ascending two directories from this skill's loaded
`skills/loom-developer/SKILL.md` source path (spec 10 → *Installed-root and
helper binding*). The role contract below is root-relative to that resolved
root.

Load and follow `roles/developer.md` exactly as your role contract.

**Launch constraints:** you may be launched only as a fresh, one-level cold child
by the client's root orchestrator (never self-invoked, never launched by another
role or finder). You MUST NOT launch a descendant agent or delegate any part of
your work — loom has exactly five lifecycle roles and only the root orchestrator
delegates (spec 02). Preserve the bounded-return contract from
`roles/developer.md`: your final message is only the new `Status:`, the path(s)
you touched, a ≤~150-token summary, and the one routing signal — never the diff,
file contents, or gate logs.

**Identity verification.** Before every commit command capture
`BASE=$(git rev-parse --verify HEAD 2>/dev/null || echo unborn)`; immediately
afterward run the verifier by its absolute resolved path
(`loom-resolve-helper codex <this SKILL.md absolute path> loom-verify-identity`
prints it): `"$VERIFY" "$BASE"`. Exit 0 continues; 1 or 2 stops the workflow. See
`skills/loom-playbook/references/commit-convention.md` ("Verify after committing").

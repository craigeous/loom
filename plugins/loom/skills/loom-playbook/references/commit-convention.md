# Commit Convention (author-neutral)

Every loom handoff ends in a commit (ADR 0003). Because the code evaluator reviews
commit **diffs** and `git log` as part of *blind* evaluation (ADR 0004), commit
metadata must never reveal who produced the work.

## Rules

- **No AI co-author trailers.** Never add `Co-Authored-By: Claude ...` or any
  agent/tool attribution. (This overrides any global default to add such a line.)
- **No author/role identity in the message.** Do not write "as the developer",
  "planner:", "(researcher)", etc. The message describes the *change*, not the
  *producer*.
- **One uniform git identity** across all roles, so the producing role can't be
  inferred from author/committer metadata.
- **One commit per handoff**, scoped to that handoff (a single slice's
  implementation, one evaluation, one planning artifact).

## Message shape

```
<imperative summary of the change / artifact / status>

<optional body: what and why, still author-neutral>
```

Examples:

- `Add slice-plan: native result-thread orchestration (Plan Review)`
- `Implement week-rollover auto-advance; gate green (Implemented)`
- `Evaluate week-rollover slice: PASS (Landed)`
- `Approve spec 03 data-model (Plan Review → Approved)`

Avoid: `Implemented by developer agent`, `Co-Authored-By: ...`, `planner draft`.

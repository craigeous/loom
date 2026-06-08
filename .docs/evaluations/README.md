# Evaluations

Blind verdicts authored by the **plan evaluator** and **code evaluator**. One file
per artifact reviewed, named to parallel the artifact:

```
slice-plans/native-result-thread.md  →  evaluations/native-result-thread-eval.md
spec/02-roles.md                     →  evaluations/02-roles-eval.md
```

Keeping verdicts here (rather than inline in the artifact) keeps work files clean
and verdicts scannable. The artifact's own `## Notes` section is for *clarification
requests* between roles; the eval file is the *verdict*.

Verdicts are **blind**: the evaluator never sees author identity or author
reasoning — only the artifact and the authority it's judged against. Format and the
PASS/FAIL + severity rules are in
[../spec/05-blind-evaluation.md](../spec/05-blind-evaluation.md).

> None yet.

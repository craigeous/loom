# Evaluation: Admit Antigravity, Orca, and Herdr (hc) to v0.3.0 Scope and Settle Evaluator Governance

Status: Evaluated
Round: 0
Verdict: FAIL

## Findings

- **MAJOR** Admission prerequisites not satisfied: The admission does not satisfy ADR 0033 §1's stated prerequisites: it cites no verified CLI research for Orca or Antigravity, does not cite or address each harness's ADR 0032 §6 work list, and gives no E1–E5 plan per harness. The brief live-proof slice and reference to E1–E5 do not establish those plans.
- **MAJOR** Evaluator isolation boundary across shared user account: Delegating to a CLI in a 0700 workspace does not itself prevent an evaluator under the same user account from accessing the hc core and author terminals. The runtime reference and ADR 0031 §5 expressly identify that exposure, so the claim that blindness is cryptographically and mechanically preserved is unsupported and the proposed separation lacks an enforceable boundary.
- **MAJOR** Matrix bindings and actual model family rotation: The matrix decision lists version floors but does not specify the actual client, host, root or profile bindings needed for the admitted harnesses. Its rotation rule treats client names as model families and permits either evaluator for Antigravity without determining its author's actual model family; this cannot guarantee the stated cross-family rule.
- **MAJOR** Misstatement of ADR 0031 §5 and surviving restrictions: The supersession description misstates ADR 0031 §5 as an absolute ban on Herdr workflows. That ADR already permits hc as an interactive host for non-evaluator roles subject to gates and prohibits hc evaluator roles. The new ADR does not clearly identify which existing evaluator restriction or live-probe gates change and which remain in force.

## Required changes

1. Provide traceable verified CLI research and ADR 0032 §6 work-list dispositions for each admitted harness, and an actionable E1–E5 evidence plan for each pair, or explicitly supersede the applicable admission prerequisites with a justified replacement.
2. Specify and justify an evaluator execution boundary that prevents access to author-identifying host state, or explicitly adopt and describe a permitted degraded-blindness decision; remove unsupported cryptographic guarantees.
3. Define the required matrix bindings and resolve actual author and evaluator model families before routing, including Antigravity and hosted author sessions; fail closed when the family cannot be established.
4. Correct the account of ADR 0031 §5 and explicitly state the precise supersessions and surviving role, isolation and live-probe restrictions.

## Notes

- The ADR cites all four requested authorities, pins five floors, explicitly supersedes ADR 0033 §1 deferrals, and gives a four-slice order and release consequences.

## Gate rerun evidence

Evidence mode: not applicable: no gate rerun for plan evaluations

---
name: Task Acceptance stricter than PRD allowance creates false gap
description: A task's literal Acceptance grep can fail when the PRD AC has an "or equivalent" clause that the task authoring narrowed; gap-check should resolve against the PRD, not the task.
type: footgun
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When a PRD AC contains an allowance clause (`"or equivalent"`,
`"satisfying"`, `"plain-English ordering"`), the task's `Acceptance:`
field often narrows that to a single example literal. If the
developer ships something inside the PRD allowance but outside the
task literal, a `grep`-based Acceptance command returns empty — a
**false** gap. Gap-check must resolve against the PRD's allowance,
not against the task's narrowed literal.

## Why

PRD is the contract; task Acceptance is an *operationalisation* of
the contract, often written before all implementation details are
known. An overly-strict Acceptance grep will flag a perfectly
compliant ship as missing. The fix is to (a) widen the grep in the
task authoring, or (b) cite the PRD AC id so QA interprets leniently.
But the audit-time fix — gap-check yielding to the PRD — must always
be available.

## How to apply

**At task authoring (TPM prevention)**:

- When the PRD AC has an allowance clause, either:
  - Widen the grep: `grep -E 'form-A|form-B|form-C'` so the literal
    allows alternate forms.
  - OR cite the PRD AC id in the Acceptance text: `"Shipped form
    satisfies PRD AC<n>.x; accepts any plain-English ordering per
    that clause."` This tells QA to interpret the grep leniently.

**At gap-check (QA-analyst resolution)**:

- When a task Acceptance grep returns empty, check the PRD AC for
  an allowance clause before flagging a gap.
- If the shipped form satisfies the PRD allowance but not the
  task literal, file an advisory finding naming both the PRD text
  and the shipped form — do not escalate to must.

## Example

Feature `20260419-user-lang-config-fallback`, 07-gaps.md §G1:

- PRD R6 AC6.c: *"README documents the full candidate-list
  precedence in plain words — or equivalent plain-English ordering
  (e.g. 'the project file wins when present; otherwise...')."*
- T9 Acceptance: `grep -F 'project > XDG > tilde' README.md` → ≥ 1.
- Shipped form: a numbered `### Precedence` list (1. project 2. XDG
  3. tilde).
- Result: task Acceptance grep returns 0; PRD AC6.c satisfied.
- Gap-check verdict: advisory G1; QA-analyst deferred to the PRD
  allowance clause. No code change, no escalation.

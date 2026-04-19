---
name: PRD allowance clauses must reach the task briefing — quote fully, not just the example
description: When a PRD AC has an "or equivalent" clause, the TPM task briefing must quote the full AC including the allowance, not just the example form — otherwise the developer narrows the ship to the example and QA files false gaps.
type: rule
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When quoting a PRD AC verbatim into a task briefing, include any
allowance clause (`"or equivalent"`, `"satisfying"`, `"plain-English
ordering — e.g. …"`) in the same block. Do not truncate to just the
example after `e.g.`. If the tech doc narrowed the allowance (as is
normal — tech picks one example), the briefing should quote BOTH
the PRD allowance AND the tech example, making the relationship
explicit ("PRD allows X; tech recommends Y as one form").

## Why

Extension of `tpm/briefing-contradicts-schema`: that rule says
"paste the schema verbatim, don't paraphrase." This rule adds: "and
don't truncate the allowance clause either." When the developer's
briefing shows only the tech example, they naturally ship that
example shape exactly. If they ship something in the PRD allowance
but not in the tech example form, the task's grep-based Acceptance
returns empty — a false gap-check that wastes everyone's time
explaining "yes this satisfies the PRD, the briefing narrowed the
text, no action needed."

## How to apply

**At task authoring**:

1. When locating the PRD AC text to quote, read the full paragraph
   including any `"or equivalent"` / `"e.g."` / `"satisfying"`
   clauses.
2. If the tech doc picked one form from that allowance, quote
   BOTH the PRD allowance AND the tech recommendation, with
   framing: "PRD AC<n>.x allows X, Y, or Z; tech D<m>
   recommends Z as the default shape."
3. Widen the Acceptance grep to match the allowance, OR cite the
   PRD AC id so QA interprets leniently.

**At audit time** (QA-analyst):

- See `qa-analyst/task-acceptance-stricter-than-prd-allowance.md`
  for the mirror-image resolution rule.

## Example

Feature `20260419-user-lang-config-fallback`, 07-gaps.md §G1+G2:

- PRD R6 AC6.c: "README documents the full candidate-list
  precedence in plain words — **or equivalent plain-English
  ordering (e.g. 'the project file wins when present;
  otherwise...')**".
- Tech 04-tech.md D8 picked one example form.
- T9 Briefing quoted the tech D8 example but NOT the PRD
  allowance.
- Developer shipped a `### Precedence` numbered list (1. project
  2. XDG 3. tilde) — inside the PRD allowance, outside the tech
  example.
- Gap-check G1/G2: both advisory, both resolved against PRD.
  Root cause: the allowance clause did not reach the briefing.

Had T9 Briefing quoted both: "*PRD AC6.c allows 'equivalent
plain-English ordering'; tech D8 recommends 'project > XDG >
tilde' as one concrete form*", the developer would have had both
options in view, and the grep Acceptance would have been written
to accept either.

## Cross-reference

- `tpm/briefing-contradicts-schema.md` — the parent rule (quote
  verbatim, don't paraphrase). This rule extends it to allowance
  clauses specifically.
- `qa-analyst/task-acceptance-stricter-than-prd-allowance.md` —
  the audit-time counterpart.

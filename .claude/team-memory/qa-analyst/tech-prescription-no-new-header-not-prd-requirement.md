---
name: Tech-doc shape prescriptions are guidance, not AC — only PRD creates must
description: When a tech doc tells the developer "do not add a new section header" but PRD does not prohibit it, QA should treat a shipped-with-header version as an advisory extra, not a failure.
type: craft-note
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Tech-doc (`04-tech.md`) prescriptions about documentation *shape*
(section headers, paragraph ordering, heading level) are **guidance
for the developer**, not acceptance criteria. QA-analyst and
QA-tester resolve against the PRD. If the developer ships something
the tech doc prescribed *against* but the PRD neither required nor
prohibited, it is at most an advisory extra — never a failure.

## Why

Tech docs are allowed to express opinions about shape without
elevating them to contract. The contract is the PRD. A developer
choosing to add a `### Subsection` header for discoverability — when
the tech doc said "no new headers" but the PRD merely said
"documents X" — is making a judgment call the tech doc cannot veto.
QA yielding to the PRD is the correct resolution; flipping to a
failure would invert the role of the tech doc.

## How to apply

1. When reviewing a ship against a gap-check, if the tech doc has
   a shape prescription the ship violated, check the PRD.
2. **PRD silent**: advisory finding at most. The tech doc can
   suggest a cleanup in a future feature.
3. **PRD explicit**: then it is a real finding (must or should per
   PRD language).
4. **PRD allowance clause** covers it: no finding at all.

## Example

Feature `20260419-user-lang-config-fallback`, 07-gaps.md §G2:

- Tech 04-tech.md D8: "Do NOT add a new section header."
- T9 Briefing: "Do NOT add a new section header" (quoted from
  tech).
- PRD R6 body: "documents the full candidate-list precedence in
  plain words" — neither requires nor prohibits a header.
- Shipped form: `### Precedence` subsection with numbered list.
- Verdict: G2 advisory. The header improves discoverability with
  no PRD violation. QA-analyst resolved against PRD, not tech.

---
name: Architect blocker on PRD semantic → PM update-req, not architect update-tech
description: When architect's tech doc flags a PRD AC conflict in blocker questions, the cheap recovery is PM rewording the PRD via /specflow:update-req, not flipping the architect's decision.
type: pattern
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When architect's `04-tech.md` §5 surfaces a blocker saying "the PRD
AC conflicts with the implementation semantic I chose", the PM's
default recovery is to reword the PRD AC via `/specflow:update-req`.
Do **not** flip the architect's chosen semantic via
`/specflow:update-tech` unless there is a concrete user-visible
regression at stake.

## Why

Architects evaluate implementation cost and contract precedence at
the tech stage with information the PM did not have at PRD time. When
architect flags a blocker and offers a resolution paragraph, that
paragraph is usually informed by a cost asymmetry (one side is one-
sentence AC change; the other side is a loop-structure rewrite).
Accepting the architect's semantic and rewording the PRD is almost
always the cheaper path, and the `[CHANGED YYYY-MM-DD]` tag on the
AC preserves the audit trail.

## How to apply

1. **Architect flags blocker** — they write a paragraph in `§5
   Blocker questions` naming the specific PRD AC and proposing a
   reworded form.
2. **PM runs `/specflow:update-req <slug>`** — rewords the AC
   verbatim from the architect's proposal, appending `[CHANGED
   YYYY-MM-DD]`. Updates the parent requirement body if needed so
   the AC fits coherently.
3. **TPM checks alignment** — confirms `03-prd.md` and `04-tech.md`
   now tell the same story before proceeding to plan.
4. **Only flip the architect** when: the PM discovers a user-visible
   regression the architect's semantic would introduce, or the
   architect explicitly invited flipping as an option.

## Example

Feature `20260419-user-lang-config-fallback`:

- PRD R4 AC4.a originally: *"iteration continues past invalid
  candidate — a malformed early candidate must not block a valid
  later one."*
- Architect D6 chose: stop-on-first-hit (even when value is
  invalid) — "file-level override means project's `chat: fr` is a
  deliberate signal, not a typo to cascade past."
- Architect §5 flagged the conflict with a proposed rewording.
- PM update-req same day: AC4.a reworded, `[CHANGED 2026-04-19]`
  tag added. R4 body clarified. Total diff: ~15 lines across 2
  paragraphs.
- TPM proceeded to plan; no further iteration. Zero downstream
  rework.

Full artifact trail in `.spec-workflow/archive/20260419-user-lang-
config-fallback/`: STATUS Notes lines for 2026-04-19, 03-prd.md R4
AC4.a, 04-tech.md §5 blocker.

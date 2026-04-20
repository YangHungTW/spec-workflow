---
name: b1-b2-split-validates-blast-radius-but-leaves-functional-gap
description: When splitting a user's one-sentence request into B1/B2 by blast radius (e.g. read-only vs control-plane), PM must acknowledge B1 alone ships only half the promise and pre-commit the B2 slug in the B1 archive notes.
type: feedback
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When brainstorm splits a single-sentence user request into B1 (read-only) + B2 (control-plane) or similar blast-radius partitions, PM MUST:

1. Explicitly state in PRD §1 Summary that B1 ships "the reading half of a two-part promise".
2. Pre-commit the B2 feature slug in the B1 archive notes (STATUS or RETROSPECTIVE).
3. Recommend in the B1 archive summary that the user queue B2 immediately, not in a later planning cycle.

## Why

Context from `20260419-flow-monitor`: the user's original ask was a single sentence that bundled "monitor + operate stalled sessions + invoke commands". Brainstorm correctly identified that bundling writes with reads in one feature would widen the blast radius (auth surface, confirmation UX, command injection surface) and split the work into B1 (read-only flow monitor) and B2 (control-plane actions). The split was architecturally sound and reduced B1's risk.

However, shipping B1 alone produced a dashboard that "sees but cannot act on" stalled sessions. To the user, this reads as "half done" — the UX delta between the one-sentence ask and the delivered B1 was large enough to feel incomplete at first run. The split served the implementation team but underserved the user's mental model until B2 landed.

This is a recurring tension: blast-radius splits are correct engineering hygiene, but they create a perceived functional gap that the user experiences as "it works but feels unfinished" unless PM explicitly manages expectations.

## How to apply

1. **PRD §1 Summary** — a sentence like: "This feature (B1) ships the read-only half of the user's original request. The control-plane half is tracked as <B2-slug> and will ship in a follow-up feature."

2. **Archive notes** — in `STATUS.md` and `RETROSPECTIVE.md` at archive time, include a line pointing to the B2 slug so a future reader can see the completion path.

3. **User-facing recommendation** — at the archive handoff message to the user, say something like: "B1 ships the monitoring view. For the stalled-session operations you mentioned, I recommend queuing B2 (<slug>) next — I've noted it in the archive."

4. **Split-justification audit** — when brainstorm proposes a blast-radius split, PM should write a one-line note in `01-brainstorm.md` summarising which user capabilities B1 covers vs which it defers. This makes the gap legible at brainstorm time rather than at first-run.

5. **First-run framing** — if possible, the B1 UI itself should signal "these actions are coming in a future release" on disabled controls (e.g. a `Run` button that is visibly disabled with a tooltip pointing to B2). This converts the perceived gap into an acknowledged roadmap item.

## Example

`20260419-flow-monitor` shipped a session list with per-session detail view, but every "act on this session" affordance (cancel, resume, send command) was absent. First-run reaction was "it sees my sessions but can't do anything with them — is this intentional?". Had the PRD §1 opened with "B1 ships the reading half; B2 <slug> ships the writing half", the reaction would have landed as "reading half works, B2 is queued" rather than "half done". The follow-up feature `20260420-flow-monitor-control-plane` was queued immediately after B1 archive per this rule; that pairing is the validating example for the pattern.

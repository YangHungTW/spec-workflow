---
name: Parallel-safe append-only sections — accept mechanical resolution
description: Append-only sections (STATUS notes, index.md rows, smoke.sh registrations) collide on every parallel wave. Accept mechanical keep-both resolution; don't over-serialize the wave schedule.
type: pattern
created: 2026-04-17
updated: 2026-04-17
---

## Rule

Not every shared-file collision warrants serialization. Distinguish:

- **Shared-file logic conflicts** — two tasks adding arms to the same
  `case` dispatcher, modifying the same function, ticking checkbox
  columns that interact. These MUST serialize across waves.
- **Shared-file append conflicts** — two tasks appending to an
  append-only section (STATUS notes, rules/index.md table rows,
  smoke.sh test registrations, tasks.md checkbox lines that don't
  depend on neighbors). These can stay parallel-safe; resolve
  mechanically by keeping both sides.

Sibling to `parallel-safe-requires-different-files.md`; that rule
covers the MUST-serialize case. This rule covers the MAY-stay-parallel
append-only case.

## Why

If every shared-file collision forced serialization, we'd lose most
of the parallelism benefit of the worktree model. Every task appends
a STATUS note. Every rule-add task appends an index row. Every new
test appends a smoke.sh registration. Serializing on these collisions
would collapse a 7-wide wave into 7 serial waves and defeat the
whole design.

The merge resolution cost is near-zero for append-only conflicts:
both sides' additions are kept verbatim, no content decision is
required, no semantic review needed. The orchestrator can resolve
these mechanically (or a reviewer can in seconds).

## How to apply

1. **During tasks breakdown**, for each shared file between two
   candidate-parallel tasks, ask: *"do the edits interact, or are
   they independent append-only additions?"*
2. **Interact (arms of a dispatcher, neighboring checkbox columns
   that reference each other, edits to the same function body)** —
   apply the strict rule from `parallel-safe-requires-different-files.md`
   and serialize across waves.
3. **Append-only (new row at end of table, new note at end of
   STATUS, new test at end of smoke.sh)** — keep them parallel-safe.
   Expect merge conflicts; resolve by keeping both sides.
4. **During merge**, don't retroactively "fix" the wave schedule
   because an append-only conflict fired. These are expected. Log
   the resolution in STATUS notes so the pattern is visible, but do
   not revise the plan.
5. **Communicate upfront** — in the tasks doc's `## Wave schedule`
   section, note which files will have expected append-only
   conflicts so the implementer isn't surprised.

## Example

Feature `20260416-prompt-rules-surgery`:

- **Wave 2 (T2–T7)**: 6 parallel tasks. 5 merge conflicts, all
  adjacent STATUS notes and rules/index.md rows. Resolved
  mechanically by keeping both sides. No rework.
- **Wave 5 (T10–T16)**: 7 parallel tasks (7 role-agent files).
  6 merge conflicts, mix of index.md row appends and STATUS notes.
  Auto-resolved.
- **Wave 7 (T18–T22)**: 5 parallel test batches. Collisions on
  test/t*.sh registrations; resolved by keeping both registration
  lines.

Total: ~11 append-only collisions across three waves. Zero rework.
Had these been treated as parallel-UNsafe, the waves would have
serialized to 18 waves instead of 3 — a 6× increase in cycle time
with no quality gain.

Cross-reference: `tpm/parallel-safe-requires-different-files.md`
(the strict case for interacting edits). Both rules coexist;
classify each shared-file collision to pick the right rule.

---
name: Tasks-doc format migration — minimal edits only
description: When a downstream command (e.g. `/YHTW:implement`) changes its required task-doc format mid-feature, do minimal edits — don't re-litigate scope.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Rule

When an in-flight `06-tasks.md` needs to adopt a new format required
by a downstream command (new field per task, new top-level section,
new sequencing convention), do a **format migration only**:

1. Add the new field to every existing task block in place.
2. Add the new top-level section (e.g. Wave schedule).
3. Log in STATUS that this was a format migration, not a scope change.
4. Do **NOT** renumber tasks.
5. Do **NOT** alter `Depends on` edges.
6. Do **NOT** flip existing checkboxes.
7. Do **NOT** rewrite acceptance criteria.

## Why

The tasks doc is a committed artifact — downstream work may already
be in flight against it. Scope/deps/checkboxes represent prior
agreements between PM, Architect, and the developer(s). Touching
them invites a second round of debate at a moment when the goal is
just to unblock the new command.

Format migration is reversible and cheap. Scope re-litigation is
neither.

## How to apply

When you notice `06-tasks.md` is missing a field that the orchestrator
or a downstream slash-command now expects:

1. Diff what the new format requires vs what the file has. List only
   the structural deltas.
2. Apply those deltas mechanically: add missing field to each block,
   add missing top-level section with derived values.
3. In STATUS Notes, write `TPM — added <field> and <section>
   (mid-stream tasks-doc update for new /YHTW:<command>)`. Explicit
   framing as a migration keeps the retro honest.
4. If the migration surfaces a genuine scope question (a new field
   can't be populated without a real decision), stop and escalate to
   PM or Architect — don't smuggle decisions into the migration.

## Example

Feature `symlink-operation`, 2026-04-16: `/YHTW:implement` went
wave-based and required `Parallel-safe-with:` on every task plus a
top-level `## Wave schedule`. TPM added both in place without
renumbering or touching deps. Later, when Wave 2 hit a merge
conflict, the de-pairing was a separate, logged decision — not
smuggled into the format migration.

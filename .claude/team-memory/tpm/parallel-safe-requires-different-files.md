---
name: Parallel-safe requires different files (or disjoint regions)
description: Two tasks may only be marked Parallel-safe-with each other if they edit different files (or genuinely disjoint, far-apart regions of the same file). Logical independence is necessary but not sufficient.
type: feedback
created: 2026-04-16
updated: 2026-04-16
---

## Rule

Before marking two tasks `Parallel-safe-with: T<peer>` in `06-tasks.md`,
confirm they edit **different files**. If they must edit the same file,
confirm the regions are genuinely disjoint and far apart — not adjacent
branches of the same `case`/`if`/dispatcher, not adjacent list items,
not neighboring checkbox lines. When in doubt, put them in separate
waves.

## Why

`git`'s textual three-way merge cannot reason about logical separation.
Two developers adding a new `elif` arm to the same dispatcher are doing
logically independent work, but the merge tool sees adjacent line
insertions in the same hunk and produces a conflict. The orchestrator
then halts mid-wave and the user has to choose between manual resolve,
re-run, or re-plan — all of which cost more than a single extra wave
would have cost.

Concrete example: feature `symlink-operation`, Wave 2 of 2026-04-16.
T4 (`owned_by_us`) and T5 (`plan_links`) were both marked
`Parallel-safe-with` each other because they're logically independent
helpers that depend only on T3. Both tasks' scope added a new arm to
the hidden `__probe` subcommand in `bin/claude-symlink`, and both
ticked their own checkbox in `06-tasks.md`. Merge failed on both
files. Recovery: discard T5's work, de-pair T4/T5, re-run T5 in its
own wave. Net cost: one extra wave plus a throwaway worktree.

## How to apply

When drafting `06-tasks.md` and considering a `Parallel-safe-with`
pair, run this mental check:

1. **File-set check** — list each task's `Deliverables` / `Files`.
   Intersection must be empty, OR every shared file must have its
   edits in demonstrably far-apart regions (different top-level
   functions with unchanged lines between them, or different
   top-level sections of a markdown doc).
2. **Dispatcher/registry check** — if either task adds a new arm to
   a shared dispatcher (`case` in bash, `match` in rust/python, a
   registry map, a route table, an enum variant list), treat that
   file as shared even if the functions themselves live elsewhere.
   Dispatcher edits collide textually.
3. **Markdown checkbox check** — if both tasks tick their own box in
   the same task file, that file is shared. Either serialize the
   tasks or have the orchestrator tick boxes in a single
   post-merge commit rather than inside each task's commit.
4. **Default** — same-file edits go in **different waves**. Only
   waive this if you can point to the specific line ranges and
   confirm there's unchanged buffer between them.

The `Parallel-safe-with` field is a claim the TPM is making on behalf
of git's merge tool. Be conservative; a single extra sequential wave
is cheaper than a mid-implement conflict.

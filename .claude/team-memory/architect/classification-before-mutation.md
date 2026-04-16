---
name: Classification before mutation
description: Filesystem tools that can destroy data — classify every target into a closed enum first, then dispatch via a table. Never mutate inside the classifier.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Context

Any CLI that can overwrite, remove, or replace files on the user's
filesystem (link managers, installers, sync tools, cleanup scripts)
risks destroying user work if classification and mutation are
interleaved. Mixed code is also near-impossible to review: you can't
see at a glance which states lead to which writes.

## Template

1. **Name every possible state as an explicit enum string.** Example
   for a link manager: `missing`, `ok`, `wrong-link-ours`,
   `broken-ours`, `real-file`, `real-dir`, `foreign-link`,
   `broken-foreign`. Closed set — no "other".

2. **Write a pure classifier.** One function, one input (path), one
   output (state string on stdout). **No side effects.** Not even a
   log line that fires conditionally on state.

3. **Dispatch via a table.** Callers read the classifier's output
   and route through a `case "$state" in …` that is the **only**
   place mutation happens. One arm per state. No fall-through.

4. **Separate ownership gate.** Whether a path is "ours" to touch
   is a distinct predicate (`owned_by_us`), not baked into the
   classifier. Classifier reports what the path **is**; ownership
   reports whether we **may** touch it.

5. **Reads first, writes second.** Do all classification calls up
   front (build a plan), then execute mutations. This lets `--dry-run`
   be a trivial early-return before the mutation loop.

## Why

- Reviewability: a diff that adds a new state is localized to the
  classifier enum and one new dispatch arm.
- Safety: dry-run and real-run share identical classification code.
  No "does this dry-run match what will actually happen?" worry.
- Testability: the classifier is a pure function, trivial to fuzz
  with sandbox fixtures.

## When to use

- Any filesystem-mutating CLI where target state varies per path.
- Installers, link managers, `rm`-style cleanup, any tool with a
  "skip vs replace vs error" decision.

## When NOT to use

- Tools that only create new paths and bail on any pre-existing file
  (trivial, single state).
- Pure read tools (reporters, linters).

## Example

`classify_target` function in `bin/claude-symlink` (feature
`symlink-operation`, T6). Eight-state enum, pure stdout emission,
dispatched by `cmd_install` / `cmd_uninstall` / `cmd_update` via
their own `case` tables.

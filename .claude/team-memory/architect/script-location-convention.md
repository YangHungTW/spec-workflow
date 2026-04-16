---
name: Script location convention — bin vs scripts
description: Repo executables go in `bin/<name>` (no extension, exec bit); `scripts/` is for dev-time helpers.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Context

This repo may ship two kinds of executable scripts:
- **User-facing / project CLIs** — things a user or agent runs directly.
- **Dev-time helpers** — release scripts, one-off migrations, internal
  tooling never invoked by end users.

Without a convention, these end up intermixed and it's unclear which
scripts are part of the product surface.

## Template

- `bin/<name>` — user-facing CLIs. No extension. `chmod +x`.
  Example: `bin/claude-symlink` (no `.sh` suffix).
- `scripts/<name>` — dev-time helpers. Extension allowed
  (`.sh`, `.py`) since they're internal.

**Why no extension on `bin/`**: matches UNIX convention (`ls`, `cat`
don't end in `.c`). Frees a future reimplementation in another
language from a rename that breaks every caller.

## When to use

- Any new executable intended to be invoked by a user or by an agent.
- Any new executable that is part of the repo's product surface.

## When NOT to use

- One-off migration scripts, release tooling, local dev aids — those
  go in `scripts/`.

## Example

`bin/claude-symlink` (feature `symlink-operation`, T1): no extension,
exec bit set, callable as `./bin/claude-symlink install`.

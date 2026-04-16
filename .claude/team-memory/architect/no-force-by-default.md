---
name: No --force by default on user-owned paths
description: Tools that touch user-owned paths default to report-and-skip on conflict; no `--force` in v1.
type: decision-log
created: 2026-04-16
updated: 2026-04-16
---

## Decision

For any mutating CLI where targets may already have real content at
the path (real file, real dir, foreign symlink, broken symlink),
default behavior is **report-and-skip**: enumerate conflict states,
emit `skipped:<reason>` per target, exit non-zero if any target was
skipped. No `--force` flag in v1.

## Alternatives considered

1. **`--force` from day one** — rejected. Cost of a wrong auto-overwrite
   (silent destruction of user work) strictly exceeds one manual `rm`.
   Users can always resolve conflicts manually once they see the list.
2. **Interactive prompt** — rejected. Breaks non-TTY use (CI, scripts,
   agent invocation). The skip-and-report output is already a checklist
   the user can act on.
3. **Symlink-only `--force`** (allow clobber only when target is a
   symlink we don't own) — deferred. Revisit only after reported
   friction.

## How to apply

When designing a filesystem-mutating CLI:

1. Enumerate every possible target state as a closed set (e.g.
   `missing`, `ok`, `real-file`, `real-dir`, `foreign-link`,
   `broken-ours`, `wrong-link-ours`).
2. For each non-clobber-safe state, emit a `skipped:<reason>` line
   and do not mutate.
3. Exit 1 if any skip occurred. Humans see the list; machines see
   the exit code.
4. Document in PRD that `--force` is explicitly out of v1 scope.

## Outcome

Applied in `symlink-operation` (PRD R11). To be revisited after
real-world use surfaces specific workflows blocked by the lack of
`--force`.

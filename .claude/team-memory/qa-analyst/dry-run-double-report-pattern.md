---
name: Dry-run line-shape assertions — catch double-emission
description: Hash-only dry-run ACs miss output-shape bugs. Add line-shape assertions to catch double-emission.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Rule

When auditing a PRD's acceptance criteria for a CLI that supports
`--dry-run`, do not accept "filesystem hash before/after is equal"
as a sufficient check. It catches mutation but not spurious output.

Insist on **line-shape assertions** in addition:

- Exact count of `would-*` lines (`grep -c '^\[would-' == N`).
- Zero count of mutation-verb lines under dry-run
  (`grep -c '^\[created\]' == 0`, `grep -c '^\[removed\]' == 0`).
- Line-count total equals planned-op count.

## Why

A helper that self-emits `would-*` under dry-run, plus a caller
that also emits via its own `report`, produces double lines per
op. The filesystem hash is untouched in either case — the hash
check passes and the bug ships.

## How to apply

During gap-check (`/YHTW:gap-check`) on any CLI that looks like
this:

```bash
remove_link "$x"
report removed "$x"
```

…grep the script for `report ` calls that sit adjacent to
`remove_link` / `create_link` / any helper that itself branches on
`DRY_RUN`. If you find the pattern, flag it as a should-fix gap
and insist the PRD's AC includes line-shape counts.

Template AC (copy into PRDs):

> **AC-dry-run-shape**: Running `<cmd> --dry-run` produces exactly
> N `[would-*]` lines and zero mutation-verb lines
> (`[created]`, `[removed]`, etc.). Verified by
> `grep -c '^\[would-' output == N` AND
> `grep -c '^\[created\]\|^\[removed\]' output == 0`.

## Example

Feature `symlink-operation`, gap-check verdict SF-2: T13 added
after QA-analyst flagged `cmd_uninstall` dry-run would double-emit
`[would-remove]` lines. The original PRD's dry-run AC was
hash-only, so the bug would have shipped if QA-analyst hadn't
inspected the script shape directly.

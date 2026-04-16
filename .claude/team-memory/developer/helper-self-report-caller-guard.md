---
name: Helper self-reports — guard caller's report under dry-run
description: If a helper self-emits a `would-*` verb under `--dry-run`, callers must guard their own `report` call — otherwise you double-emit.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Rule

If a mutation helper (`create_link`, `remove_link`, etc.) self-emits
its own user-visible verb when `DRY_RUN=1` (e.g. `[would-create] …`),
then the caller must **not** also call `report` after invoking the
helper under dry-run. Otherwise both fire and the user sees every
dry-run line twice.

## Why

Ownership of the user-visible emission has to sit in exactly one
place. Two sensible designs:

- **(a) Helpers mute; callers own all reporting.** Helpers perform
  the mutation (or skip it under dry-run) silently; the caller emits
  `[would-create]` / `[created]` / `[would-remove]` / `[removed]`.
- **(b) Helpers self-report.** Helpers emit their own line under
  dry-run and under real-run; callers skip their own `report` call
  when the helper already spoke.

What breaks: both the helper and the caller emit, so under dry-run
you see two lines per operation. The real-run path often dodges
this by a quirk (the helper only self-reports under dry-run), so
real-run looks fine and only dry-run is double-emitting — easy to
miss in review.

## How to apply

Prefer (a): keep helpers mute. Caller fully owns `report`. Cleanest
mental model, no flags to remember.

If you inherited (b) and can't refactor, apply a minimal-surgery
fix at each call site:

```bash
remove_link "$target"
if [ "$DRY_RUN" != "1" ]; then
  report removed "$target"
fi
```

## Example

Feature `symlink-operation`, SF-2 / T13: `cmd_uninstall` was calling
`remove_link` (which self-emits `[would-remove]` under dry-run) and
then also calling `report removed …`, producing a duplicate
`[would-remove]` line per target under `--dry-run`. Fix: guard the
caller's `report` with `if [ "$DRY_RUN" != "1" ]`.

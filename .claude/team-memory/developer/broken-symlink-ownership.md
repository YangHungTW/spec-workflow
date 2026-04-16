---
name: Ownership check on broken symlinks — skip resolve_path
description: `owned_by_us` can't classify broken symlinks — `resolve_path` errors on a non-existent parent. Bypass with bare `readlink` + literal prefix string compare.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Problem

A broken symlink's target does not exist. Any helper that tries to
canonicalize the target (our `resolve_path`, or GNU `readlink -f`)
will fail because it walks through `dirname` and expects the parent
to resolve. The ownership check (`owned_by_us`) therefore cannot be
reused as-is — it would report "not ours" for every broken link,
including ones we created and then had their target moved.

## Workaround

Inside the broken-link branch of the classifier, bypass the
canonical path helper entirely:

1. Read the link target with bare `readlink "$path"` (no `-f`).
2. If target is relative, resolve it against the **link's parent
   dir** using bash string ops (no `cd`, no `pwd`):
   `target="$(dirname "$path")/$target"`.
3. Prefix-compare against `"$REPO/.claude/"` — **trailing slash
   required** to avoid matching `".claude-something"`.

```bash
local linkdir tgt
tgt="$(readlink "$path")"
linkdir="$(dirname "$path")"
case "$tgt" in
  /*) ;;                    # absolute — use as-is
  *)  tgt="$linkdir/$tgt" ;; # relative — resolve literally
esac
case "$tgt" in
  "$REPO/.claude/"*) echo "broken-ours" ;;
  *)                 echo "broken-foreign" ;;
esac
```

## When to apply

- Any symlink-management tool that must distinguish "broken link we
  created" from "broken link we did not create".
- Any ownership/scope check where the target may be missing.

## When NOT to use

- Intact symlinks — use the normal `resolve_path`-based owner check
  (more robust against `..` segments, nested symlinks).

## Example

`classify_target`'s `broken-ours` vs `broken-foreign` handling in
`bin/claude-symlink` (feature `symlink-operation`, T6).

---
name: Shell portability — no GNU readlink on macOS
description: macOS bash 3.2 has no `readlink -f`; write a pure-bash `resolve_path` helper instead of depending on GNU coreutils.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Context

Any repo-shipped bash script that must run on both macOS (default
bash 3.2, BSD userland) and Linux (bash 4+, GNU coreutils) cannot
assume `readlink -f` or `realpath` exists. `readlink -f` is GNU-only;
`realpath` on macOS requires an explicit `brew install coreutils`.
Relying on either makes the tool silently broken on a fresh Mac.

## Template

Write a pure-bash `resolve_path` helper. Iteratively resolve the
parent dir with `cd ... && pwd -P`, then join the basename; if the
result is itself a symlink, follow it with bare `readlink` (no `-f`)
and repeat. Cap the loop at 40 hops to abort on cycles.

```bash
resolve_path() {
  local p="$1" i=0
  while [ $i -lt 40 ]; do
    local d b
    d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
    b="$(basename "$p")"
    p="$d/$b"
    if [ -L "$p" ]; then
      local t
      t="$(readlink "$p")"
      case "$t" in
        /*) p="$t" ;;
        *)  p="$d/$t" ;;
      esac
      i=$((i + 1))
      continue
    fi
    printf '%s\n' "$p"
    return 0
  done
  return 1
}
```

Concrete example: `bin/claude-symlink`'s `resolve_path` function,
added in T3 of feature `symlink-operation`.

## When to use

- Any bash script shipped from this repo that must resolve a symlink
  or canonicalize a path.
- Any script that currently uses `readlink -f` or `realpath` — rewrite.

## When NOT to use

- Scripts gated to Linux only (e.g. CI runners) — `readlink -f` is
  fine there.
- Python/Node tooling — use language-native canonicalization.

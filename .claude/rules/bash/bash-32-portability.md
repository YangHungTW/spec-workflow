---
name: bash-32-portability
scope: bash
severity: must
created: 2026-04-16
updated: 2026-04-18
---

## Rule

Write all repo-shipped bash scripts to run on bash 3.2 / BSD userland
(macOS default) without GNU coreutils extensions.

## Why

macOS ships bash 3.2 and BSD userland by default. `readlink -f` and
`realpath` are GNU-only; `jq` and `mapfile` are not available on a
fresh Mac; `[[ =~ ]]` regex matching has known differences between
bash 3 and bash 4+. A script that silently breaks on the developer's
laptop erodes trust and wastes debugging time.

## How to apply

- **No `readlink -f`** — use the `resolve_path` helper (see Example below).
- **No `realpath`** — same reason; requires `brew install coreutils`.
- **No `jq`** — parse JSON with Python 3 (`python3 -c "import json, sys; ..."`)
  or with `awk`/`sed` for simple single-key grabs; never assume `jq` exists.
- **No `mapfile` / `readarray`** — bash 3.2 does not have these builtins.
  Accumulate lines with a `while IFS= read -r line; do ... done` loop.
- **No `[[ =~ ]]` for portability-critical logic** — the regex dialect
  and quoting rules differ between bash 3 and 4. Use `case`/`glob` or
  POSIX `expr`/`grep` where the match must be reliable across versions.
- **No GNU-only flags** — `sed -i ''` (BSD) vs `sed -i` (GNU); always
  use a two-arg form (`sed -i '' ...`) when targeting macOS, or rewrite
  with `awk` + `mv`.
- **Sanity-check new scripts** with `/bin/bash script.sh` on macOS
  before merging (macOS's `/bin/bash` is 3.2 even if the user has
  brew-installed bash 5).
- **`case` inside subshells** — bash 3.2 can parse-error on `case`
  blocks nested inside `$(...)` or process substitution. Prefer
  `if/elif` for logic that runs inside subshells or piped loops.
  (See developer/bash32-case-in-subshell.md for details.)

## Example

Portable `resolve_path` — replaces `readlink -f` or `realpath`:

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
      if [ "${t#/}" != "$t" ]; then
        p="$t"
      else
        p="$d/$t"
      fi
      i=$((i + 1))
      continue
    fi
    printf '%s\n' "$p"
    return 0
  done
  return 1
}
```

Call: `canonical=$(resolve_path "$some_path")` — works on macOS bash 3.2
and Linux bash 4+. The loop caps at 40 hops to abort on symlink cycles.

Bare `readlink` (no `-f`) is used inside the loop; it is available on
both BSD and GNU. The `case "$t" in /*) ...` pattern from the architect
memory is replaced above with a POSIX `[ "${t#/}" != "$t" ]` test that
avoids nesting `case` inside a `while` subshell (see bash32 gotcha
above).

### BSD vs GNU `date` arithmetic — dispatch by `uname` once

`date -d "<string>"` is GNU-only; `date -j -f "<fmt>" "<string>"` is
BSD-only. Neither flag works on the other platform. Isolate the
dialect choice in one wrapper so the rest of the script stays
dialect-free:

```bash
# to_epoch "2026-04-18 11:30:00" → 1776500000
to_epoch() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null)"
  if [ "$uname_s" = "Darwin" ] || [ "$uname_s" = "FreeBSD" ] || \
     [ "$uname_s" = "OpenBSD" ] || [ "$uname_s" = "NetBSD" ]; then
    date -j -f "%Y-%m-%d %H:%M:%S" "$1" +%s 2>/dev/null
  else
    date -d "$1" +%s 2>/dev/null
  fi
}
```

Never rely on GNU-only `-d` or BSD-only `-j -f` alone at call sites;
`to_epoch` isolates the dialect choice. Source: `.claude/hooks/stop.sh`
in feature `shareable-hooks` (the wrapper was authored during D4 and
retained for future callers even after the implementation switched to
a sentinel-file approach — see qa-analyst memory
`dead-code-orphan-after-simplification` for the cleanup followup).

---
name: bash 3.2 — case inside subshells can parse-error
description: bash 3.2 (macOS default) rejects `case ... ;;` blocks inside `$(...)` command substitution in some contexts — use `if/elif` in `while` loops running in subshells.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Symptom

Script that works fine on bash 4+ (Linux) dies on macOS with a
parse error near a bare `;;`. The culprit is a `case` statement
nested inside a `$(...)` command substitution or a `while` loop
whose body is piped / fed via process substitution. bash 3.2's
parser occasionally rejects the `;;` terminator in these contexts
even when semantically valid.

## Workaround

Replace the `case` with `if/elif`. Same logic, no parser issue.

Before (fails on bash 3.2):

```bash
while IFS= read -r line; do
  case "$line" in
    skip:*) echo "S" ;;
    ok:*)   echo "O" ;;
    *)      echo "?" ;;
  esac
done < <(plan_links)
```

After (works):

```bash
while IFS= read -r line; do
  if [[ "$line" == skip:* ]]; then
    echo "S"
  elif [[ "$line" == ok:* ]]; then
    echo "O"
  else
    echo "?"
  fi
done < <(plan_links)
```

## When it hit

Surfaced during `plan_links` implementation in T5 of feature
`symlink-operation`. Logic verified on Linux, then failed under
macOS's default `/bin/bash` (3.2.57).

## How to apply

- When writing bash for this repo, prefer `if/elif` over `case`
  inside loops whose body runs under command substitution or
  process substitution.
- Top-level `case` (e.g. command dispatch in `main`) is fine — the
  issue only appears in nested-subshell contexts.
- Sanity check every new bash script with `/bin/bash script.sh` on
  macOS before merging.

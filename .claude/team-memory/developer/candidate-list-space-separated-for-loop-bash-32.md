---
name: Candidate-list walk — space-separated string + unquoted for-loop (bash 3.2 portable)
description: For short (≤5) known-at-hook-start candidate lists with paths under our control, prefer a space-separated string + unquoted for-loop over a bash 4+ array — bash 3.2 portable and idiomatic in this repo.
type: pattern
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When iterating a short candidate list (typically ≤ 5 entries) whose
paths are under our control — no user-supplied path components —
build the list as a space-separated string and iterate with an
**unquoted** `$VAR` in the `for` loop. Do NOT use bash 4+ array
syntax (`"${arr[@]}"`, `mapfile`).

## Why

Bash 3.2 (macOS default) lacks `mapfile` and has quirks with array
expansion inside `set -u`. The space-separated-string pattern works
cleanly on bash 3.2 + 4+ + 5+ and matches existing patterns in
`.claude/hooks/session-start.sh` (`WALK_DIRS`, `SKIP_SUBDIRS`).
Key constraint: the path segments must not contain spaces — for
controlled prefixes (`$HOME`, `$XDG_CONFIG_HOME`, literal subdirs)
this holds. For user-supplied paths or longer dynamic lists,
arrays remain the correct tool.

## How to apply

```bash
# Build the list — conditionally append segments
CANDIDATES=".spec-workflow/config.yml"
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  CANDIDATES="$CANDIDATES $XDG_CONFIG_HOME/specflow/config.yml"
fi
CANDIDATES="$CANDIDATES $HOME/.config/specflow/config.yml"

# Iterate — the $CANDIDATES expansion MUST be unquoted
for cfg_file in $CANDIDATES; do
  [ -r "$cfg_file" ] || continue
  # ... do stuff with "$cfg_file" (quoted inside the loop body) ...
done
```

Key rule: the `for … in $VAR` line is the ONE place you do NOT
quote the variable. Everywhere else in the loop body, quote the
individual item.

## When NOT to use

- Paths containing spaces (user-supplied, untrusted).
- Dynamic lists > ~5 entries.
- Lists where order is semantically critical AND the data has any
  chance of containing IFS characters.

In those cases, use `IFS='\n' read -r` loops or upgrade to bash 4+
arrays.

## Example

Feature `20260419-user-lang-config-fallback`, T1 (hook edit):
three candidates (project → XDG → tilde). All prefixes are
controlled. Architect D5 codified this form in tech doc; reviewer-
style passed as "matches neighbour" (`WALK_DIRS` pattern).

Source: `.claude/archive/20260419-user-lang-config-fallback/04-
tech.md` §3 D5; `.claude/hooks/session-start.sh` post-merge.

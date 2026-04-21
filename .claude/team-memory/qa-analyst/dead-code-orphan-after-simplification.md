---
name: dead-code-orphan-after-simplification
role: qa-analyst
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

<!-- 2026-04-18 update: added "How to detect at gap-check time"
subsection with a concrete grep recipe, per second occurrence in
feature 20260418-per-project-install. -->


## Rule

During gap-check, grep every new/modified script for function
definitions whose names are referenced only once (the definition
itself) — those are dead-code orphans left behind when the
implementation took a simpler path than the tech-doc pseudocode.

## Why

Architects sketch solutions with helper functions; developers often
find simpler paths during implementation that bypass those helpers.
The original helper gets retained "in case it's useful" and becomes
dead code that misleads future readers. A mechanical grep during
gap-check catches this class of drift before it compounds.

This is not a blocker — it is a note recommending cleanup in a
follow-up. But surfacing it during gap-check keeps the codebase
honest and gives the developer a concrete TODO.

## How to apply

During gap-check, for every new/modified shell/bash script touched
by the feature:

1. Extract all `function_name()` definitions — e.g.
   `grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' script.sh`.
2. For each function name, check reference count in the same file
   with `grep -c 'function_name' script.sh`.
3. If the count is 1 (the definition itself, with no callers), flag
   as a dead-code note in `07-gaps.md`.
4. Record as an N-note (e.g. N3) with file:line reference and the
   recommended follow-up: remove the orphan or wire it into the
   flow it was designed for.

Apply the same pattern for Python/Node helpers — language-specific
definition regex, but the same one-caller-minimum invariant.

## How to detect at gap-check time

Concrete one-liner per function name:

```bash
grep -c '\b<function_name>\b' path/to/file
```

- Count == 1 → the sole hit is the definition line; zero callers;
  this is a dead-code orphan.
- Count == 2+ → at least one caller; not an orphan.

Applied during feature `20260418-per-project-install`: the helper
`resolve_path` was defined at `bin/scaff-seed:69-93` carried over
from the tech-doc pseudocode, but the implementation took a
simpler relative-path approach and never called it. `grep -c
'\bresolve_path\b' bin/scaff-seed` returned `1` → orphan
confirmed, removed in gap-fix commit 60237a2.

Repeatable recipe for any gap-check:

```bash
for fn in $(grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$file" | tr -d '()'); do
  count=$(grep -c "\\b${fn}\\b" "$file")
  [ "$count" -eq 1 ] && echo "ORPHAN: $fn in $file"
done
```

## Example

Feature `20260417-shareable-hooks`. Tech doc D4 pseudocode used
`to_epoch()` inside `within_60s()` to parse STATUS.md timestamps for
the rate-limit check. Implementation replaced the awk-based
timestamp scan with a sentinel file (simpler, race-free), making
`to_epoch()` at `.claude/hooks/stop.sh:108-117` an orphan with zero
callers. QA-analyst caught it via `grep -c to_epoch` during
`07-gaps.md` authoring and added it as N3 with a follow-up
recommendation.

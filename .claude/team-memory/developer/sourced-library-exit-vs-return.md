---
name: Sourced library — use return, not exit
description: Functions in a sourced bash library must use `return N`, not `exit N`; `exit` inside a sourced function terminates the caller's shell.
type: feedback
created: 2026-04-20
updated: 2026-04-20
---

## Rule

In any bash file intended to be sourced (`. lib/foo.sh` or `source lib/foo.sh`), every function must use `return N` to propagate a non-zero status to its caller. Never `exit N` inside a sourced function. A sourced `exit` terminates the caller's shell, including tests and interactive sessions.

## Why

Observed in 20260420-tier-model W0a: `lib/tier-helpers.sh` (T2) used `exit 2` in five sites to signal validation failure. The library was sourced by `bin/scaff-tier` and by test scripts. The test run terminated immediately on the first bad fixture because `exit 2` propagated up through the `source` call and killed the test shell — 60+ downstream assertions silently skipped.

Fix: replace every `exit` with `return` across the five sites. Tests then ran to completion and surfaced the real bugs.

The symptom ("tests silently skip") is deceptive because the test runner reports the partial run as green up to the early exit. A green bar that ran 3 of 68 assertions is indistinguishable from a green bar that ran all 68, unless you count assertions.

## How to apply

1. **Scan every sourceable library for `exit`**:
   ```
   grep -nE '^\s*(exit|return)\s' lib/*.sh
   ```
   Any `exit` inside a function is a bug; `exit` at the top level is also wrong for a library (sourcing should not terminate).
2. **Use `return` uniformly**. `return` in top-level code of a sourced file is legal and means "stop sourcing", which is usually the intent.
3. **If a helper script's dual role is both executable-and-sourceable** (e.g. `bin/foo` that can be `. bin/foo` to get its functions), gate the top-level action with:
   ```
   if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
     main "$@"
   fi
   ```
   and use `return` inside every function regardless.
4. **Test harnesses should assert total assertion count**. A test run that reports "3 passed" when the file contains 68 assertions is a red flag — print `TOTAL:` at end-of-run and grep for it.

## Example

Bad (observed in T2 pre-retry):

```bash
# lib/tier-helpers.sh
validate_tier_transition() {
  case "$from" in
    tiny|standard|audited) ;;
    *) echo "bad from: $from" >&2; exit 2 ;;  # kills the sourcing test
  esac
}
```

Good (T2 retry):

```bash
validate_tier_transition() {
  case "$from" in
    tiny|standard|audited) ;;
    *) echo "bad from: $from" >&2; return 2 ;;
  esac
}
```

Cross-reference: the caller `bin/scaff-tier` then propagates the `return 2` to its own exit status via `|| exit $?`, which is the correct pattern for a standalone script wrapping a library.

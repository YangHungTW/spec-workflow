---
name: byte-identical-refactor-gate
role: architect
type: pattern
created: 2026-04-18
updated: 2026-04-18
---

## Rule

Pure-refactor tasks (zero behavior change) use byte-identical
before/after diff as the acceptance gate — NOT "tests still pass".

## Why

The smoke suite detects exit-code regressions but misses output drift.
A refactor that folds 6 greps into 1 awk can silently re-order output,
skip a check, or change an error message while all tests still pass.
Byte-diff on stdout+stderr+exit catches this class of drift. The
invariant — "this change is supposed to be invisible" — deserves an
invisibility gate, not a looser functional-pass gate.

## How to apply

1. In the task's Verify section, capture stdout+stderr+exit of the
   script before AND after the edit (run in the same sandbox, same
   inputs).
2. `diff /tmp/before.txt /tmp/after.txt` must be empty. Non-empty
   diff blocks the task.
3. If the diff is non-empty, inspect — it may be legitimate (e.g.,
   `set -o pipefail` surfaces a hidden pipeline bug) or a regression
   (e.g., awk parse mismatch changes an error string). Legitimate
   changes require explicit PRD/tech amendment; regressions block the
   task and must be fixed.
4. Pair with the `sandbox-home-in-tests` rule — capture both outputs
   in the same sandbox to avoid environment drift contaminating the
   diff.

## Example

Feature `20260418-review-nits-cleanup`:

- T2 (t35 awk fold) — replaced a 6-grep loop with one awk expression;
  verified byte-identical stdout+stderr+exit against pre-edit baseline.
- T3 (t34 read-once refactor) — replaced three reads of the same file
  with a single read into a variable; verified byte-identical.

Smoke suite remained 38/38 throughout, but that alone would not have
caught output re-ordering; the byte-diff gate did the actual work.

---
name: reviewer-performance
scope: reviewer
severity: should
created: 2026-04-18
updated: 2026-04-18
---

## Rule

Flag findings against the performance axis checklist; do not flag issues outside this axis.

## Why

Performance regressions in hook and loop paths are hard to detect from diff review alone and compound at runtime. A focused performance rubric applied at wave-merge time surfaces shell-out-in-loop patterns, O(n²) algorithms, and hook latency overruns before they reach gap-check or production, where they are costlier to fix.

## How to apply

1. **No shell-out in tight loops** (`must`) — any subprocess call (backtick, `$()`, `|`, or explicit `fork`) inside a loop body iterating over more than a small constant count is a finding; recommend batch invocation or in-process equivalent.
2. **Avoid O(n²) where O(n) works** (`must`) — obvious quadratic patterns (nested membership check against a list, repeated sort inside a loop) are findings; hash-lookup or pre-sort is the expected pattern.
3. **Cache expensive operations** (`should`) — repeated invocation of `uname`, `git status`, `git rev-parse`, network fetches, or other out-of-process calls within a single script run should be cached to a variable on first call; repeated invocation is a finding.
4. **Prefer `awk`/`sed` over `python3` for simple transforms** (`should`) — spawning a Python interpreter for a one-shot string replace or column extraction is wasteful on hook and loop paths; simple transforms belong in `awk`/`sed`.
5. **No re-reading the same file** (`should`) — reading the same file multiple times in a single tool invocation is a finding; read once, reuse the variable.
6. **Minimise fork/exec in hot paths** (`should`) — loops that spawn one or more processes per iteration should be refactored to batch invocation or in-process handling; flag when the loop body is expected to iterate more than a few times.
7. **Hook latency budget < 200ms** (`must`) — any code added to SessionStart / Stop / other hooks must keep total hook wall-clock under 200ms on a warm cache; a hook that exceeds this budget is a finding. Cross-references B1's R5 SLA (`.spec-workflow/features/prompt-rules-surgery/03-prd.md` R5).
8. **Avoid eager loads of unused data** (`should`) — loading a large file or dataset when only a few fields are read is a finding; stream or selective-parse where practical.

## Example

Finding: shell-out in a loop — a `must`-severity performance violation.

```diff
 # Checking each file's git status
 for f in $files; do
-  status=$(git status --porcelain "$f")
+  # FINDING: shell-out per iteration — O(n) git invocations
   if [ -n "$status" ]; then
     echo "modified: $f"
   fi
 done
```

Expected fix: batch the invocation outside the loop.

```diff
+status_map=$(git status --porcelain $files)
 for f in $files; do
+  status=$(printf '%s\n' "$status_map" | grep " $f$" || true)
   if [ -n "$status" ]; then
     echo "modified: $f"
   fi
 done
```

Verdict footer shape (D1 contract):

```
## Reviewer verdict
axis: performance
verdict: BLOCK
findings:
  - severity: must
    file: bin/example-script.sh
    line: 14
    rule: reviewer-performance
    message: shell-out inside loop — git invoked once per file; batch outside loop
```

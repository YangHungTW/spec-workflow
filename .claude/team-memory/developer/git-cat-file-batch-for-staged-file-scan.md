---
name: git-cat-file-batch-for-staged-file-scan
description: Use `git cat-file --batch` single persistent process when scanning N staged files in a hook-budget path; per-file `git show :FILE` forks N times and busts the 200ms hook latency budget.
type: feedback
created: 2026-04-19
updated: 2026-04-19
---

## Rule

When a lint or hook script needs to read N staged files (pre-commit / post-merge / similar), launch `git cat-file --batch` ONCE and feed it N object-ids on stdin, reading N blobs from its stdout in the same process. Do NOT invoke `git show :path` or `git cat-file -p <oid>` in a per-file shell-out loop.

## Why

Each `git show` or `git cat-file -p <oid>` invocation forks a new `git` process (~3–5ms cold on macOS). At N ≥ 40 staged files that's 120–200ms of pure fork/exec overhead — the entire hook latency budget is gone before any real work runs. Hook-path rules in `.claude/rules/reviewer/performance.md` entry 7 set the target at <200ms on a warm cache; per-file shell-out makes that unreachable on any non-trivial diff. The same pattern also violates entry 1 (no shell-out in tight loops) at diff-review time.

## How to apply

1. Collect the list of staged file OIDs via one call: `git diff --cached --raw` or `git ls-files --cached --stage`.
2. Spawn `git cat-file --batch` as a long-lived child:
   - bash: `coproc CAT { git cat-file --batch; }` or a named FIFO pair.
   - Rust: `std::process::Command::new("git").args(["cat-file", "--batch"]).stdin(piped).stdout(piped).spawn()`.
3. For each file, write `<oid>\n` to stdin; read the returned header line (`<oid> <type> <size>`) then exactly `size` bytes of blob content from stdout (followed by a trailing `\n`).
4. Close stdin when done; the subprocess exits cleanly.

## Context incident

`20260419-language-preferences` T3 retry 1 — a pre-commit shim that used per-file `git show :FILE` BLOCKED the performance axis with one `must` finding. Root cause: N fork/exec per commit, O(N) latency scaling. Retry rewrote to `git cat-file --batch` single process → dropped to O(1) fork/exec, scanned ≥100 files in <50ms warm cache.

Cross-references: `.claude/rules/reviewer/performance.md` entries 1 (no shell-out in tight loops) and 7 (<200ms hook budget).

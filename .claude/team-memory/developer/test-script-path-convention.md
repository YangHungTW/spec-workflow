---
name: Test scripts discover their own location
description: Test scripts must discover their own location, not hardcode worktree paths.
type: pattern
created: 2026-04-16
updated: 2026-04-16
---

## Rule

Test scripts (`test/*.sh` and similar) must discover their own
location at runtime. Never hardcode the worktree path, the repo
path, or the location of the script-under-test.

## Why

Hardcoded paths break as soon as the test runs in:
- Another worktree (`git worktree add`).
- Another checkout (clone in a different dir).
- The archive dir after `/scaff:archive` runs.
- A CI runner with a different checkout layout.

The test then silently passes on the author's machine and fails
everywhere else, or — worse — tests a stale copy of the script.

## Template

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${SCRIPT:-$REPO_ROOT/bin/claude-symlink}"

# ... tests use $SCRIPT ...
```

The `SCRIPT="${SCRIPT:-…}"` override lets the orchestrator or a CI
runner point the test at a different binary without editing the
script.

## How to apply

- Every new `test/*.sh` must use the template above.
- Retrofit target: tests t3–t10 in `symlink-operation`'s
  `test/smoke.sh` currently hardcode. Revisit in a follow-up sweep.
- Applies to any repo shipping shell tests.

## When NOT to use

- One-off debugging scripts you are about to delete.
- Tests that genuinely need a fixed path for reproducing a
  path-sensitive bug (rare; document explicitly).

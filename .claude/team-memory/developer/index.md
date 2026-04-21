# developer — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Ownership check on broken symlinks — skip resolve_path](broken-symlink-ownership.md) — `owned_by_us` can't classify broken symlinks — `resolve_path` errors on a non-existent parent. Bypass with bare `readlink` + literal prefix string compare.
- [Helper self-reports — guard caller's report under dry-run](helper-self-report-caller-guard.md) — If a helper self-emits a `would-*` verb under `--dry-run`, callers must guard their own `report` call — otherwise you double-emit.
- [Test scripts discover their own location](test-script-path-convention.md) — Test scripts must discover their own location, not hardcode worktree paths.
- [Bash heredoc-python3 inside a function consumes caller's stdin](bash-heredoc-stdin-conflict.md) — A bash function that runs `python3 - args <<'PYEOF'` cannot also receive piped stdin from its caller — the heredoc wins and the pipe payload is silently dropped. Drain stdin to a tmp file first.
- [Pipe-into-python3-heredoc: explicitly check pipeline exit before reporting success](python-heredoc-exit-code-propagation.md) — Under `set -u -o pipefail` without `set -e`, a failed `cat src | <python3-heredoc-fn> dst` silently returns non-zero while the caller still emits `created:` and increments counters. Always wrap in `if … then … else FAIL + SKIP fi`.
- [cd into $CONSUMER before invoking specflow-seed](consumer-cwd-discipline.md) — Tests of `bin/specflow-seed init|update|migrate` must `cd "$CONSUMER"` first; otherwise `repo_root()` resolves via `git rev-parse --show-toplevel` from the caller's cwd and silently corrupts the source repo.
- [Tauri 2 capability lockdown — re-grant on plugin add](tauri-2-capability-lockdown-must-re-grant-on-plugin-add.md) — Tauri 2 strict capability model blocks plugin commands silently unless the matching `<plugin>:default` permission is added to capabilities/default.json in the same commit that adds the plugin crate.
- [Tauri 2 async-command blocking API deadlocks](tauri-2-async-command-blocking-api-deadlocks.md) — In Tauri 2 async commands, never call `*_blocking` methods from plugin APIs; the blocking call deadlocks the tokio worker driving the plugin's main-thread dispatch.
- [IPC shape mismatch swallowed by silent catch](ipc-shape-mismatch-swallowed-by-catch.md) — TypeScript IPC types don't validate at runtime; a silent `.catch(() => undefined)` hides shape mismatches between frontend declared types and backend return types.
- [git cat-file --batch for staged-file scan](git-cat-file-batch-for-staged-file-scan.md) — Use `git cat-file --batch` single persistent process when scanning N staged files in a hook-budget path; per-file `git show :FILE` forks N times and busts the 200ms hook latency budget.
- [Test-authoring tasks must not add production code](test-task-scope-boundary-no-production-code.md) — A task scoped to writing tests must not also add the production function under test; let the test SKIP until the production task lands in a future wave.
- [Slug boundary check — path traversal prevention](slug-boundary-check-pattern.md) — Any command building a path from a user-supplied slug needs two layers: character deny-list (`..`, `/`, leading `-`) then canonical `cd && pwd -P` + prefix assert. Reviewers block missing boundary checks as security must.

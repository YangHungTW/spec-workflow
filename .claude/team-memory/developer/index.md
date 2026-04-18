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

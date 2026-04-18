# developer — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Ownership check on broken symlinks — skip resolve_path](broken-symlink-ownership.md) — `owned_by_us` can't classify broken symlinks — `resolve_path` errors on a non-existent parent. Bypass with bare `readlink` + literal prefix string compare.
- [Helper self-reports — guard caller's report under dry-run](helper-self-report-caller-guard.md) — If a helper self-emits a `would-*` verb under `--dry-run`, callers must guard their own `report` call — otherwise you double-emit.
- [Test scripts discover their own location](test-script-path-convention.md) — Test scripts must discover their own location, not hardcode worktree paths.

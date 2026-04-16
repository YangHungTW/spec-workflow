# developer — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [bash 3.2 — case inside subshells can parse-error](bash32-case-in-subshell.md) — bash 3.2 (macOS default) rejects `case ... ;;` blocks inside `$(...)` command substitution in some contexts — use `if/elif` in `while` loops running in subshells.
- [Ownership check on broken symlinks — skip resolve_path](broken-symlink-ownership.md) — `owned_by_us` can't classify broken symlinks — `resolve_path` errors on a non-existent parent. Bypass with bare `readlink` + literal prefix string compare.
- [Test scripts discover their own location](test-script-path-convention.md) — Test scripts must discover their own location, not hardcode worktree paths.
- [Helper self-reports — guard caller's report under dry-run](helper-self-report-caller-guard.md) — If a helper self-emits a `would-*` verb under `--dry-run`, callers must guard their own `report` call — otherwise you double-emit.

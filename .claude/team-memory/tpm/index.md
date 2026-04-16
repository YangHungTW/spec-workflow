# tpm — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Parallel-safe requires different files](parallel-safe-requires-different-files.md) — Parallel-safe-with pairs must edit different files (or disjoint regions); logical independence is necessary but not sufficient — git's textual merge can't reason about it.
- [Tasks-doc format migration — minimal edits only](tasks-doc-format-migration.md) — When a downstream command (e.g. `/YHTW:implement`) changes its required task-doc format mid-feature, do minimal edits — don't re-litigate scope.

# tpm — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Parallel-safe requires different files](parallel-safe-requires-different-files.md) — Parallel-safe-with pairs must edit different files (or disjoint regions); logical independence is necessary but not sufficient — git's textual merge can't reason about it.
- [Tasks-doc format migration — minimal edits only](tasks-doc-format-migration.md) — When a downstream command (e.g. `/specflow:implement`) changes its required task-doc format mid-feature, do minimal edits — don't re-litigate scope.
- [Parallel-safe append-only sections](parallel-safe-append-sections.md) — Append-only sections (STATUS notes, index rows, smoke registrations) collide on every parallel wave; accept mechanical keep-both resolution, don't over-serialize the wave schedule. Sibling to parallel-safe-requires-different-files.
- [Checkbox lost in parallel merge](checkbox-lost-in-parallel-merge.md) — Task-completion checkboxes get dropped during wave-parallel merges with mechanical append-conflict resolution; orchestrator must audit and auto-flip post-merge. Sibling to parallel-safe-append-sections.

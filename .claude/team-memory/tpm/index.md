# tpm — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Briefing contradicts schema — quote, don't paraphrase](briefing-contradicts-schema.md) — Before writing a concrete value (name, path, key) into a task briefing, grep the governing schema and paste the actual constraint; never paraphrase.
- [checkbox-lost-in-parallel-merge](checkbox-lost-in-parallel-merge.md) — After every wave-parallel merge, audit 06-tasks.md for task-completion checkboxes that were silently dropped during conflict resolution and flip them back. Fourth occurrence (20260419-flow-monitor W4+W5) confirms the pattern scales with wave width; recommends automation.
- [Pre-declare test filenames in 06-tasks.md](pre-declare-test-filenames-in-06-tasks.md) — When ≥2 same-wave tasks author test files, pre-declare the exact `test/tNN_*.sh` filename in each task's `Files:` field and grep the wave for collisions before publishing; developers left to pick a name converge on duplicates.
- [Task scope-fence literal placeholder hazard](task-scope-fence-literal-placeholder-hazard.md) — Placeholders like `tN_` or `<fill>` in Files:/Acceptance: are interpreted literally by developers. Pre-fill the value or prefix with `MUST-REPLACE:`; grep the plan doc for placeholders before dispatch.
- [Tasks-doc format migration — minimal edits only](tasks-doc-format-migration.md) — When a downstream command (e.g. `/specflow:implement`) changes its required task-doc format mid-feature, do minimal edits — don't re-litigate scope.

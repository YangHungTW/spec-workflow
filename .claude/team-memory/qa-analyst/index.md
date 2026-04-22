# qa-analyst — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [agent-name-dispatch-mismatch](agent-name-dispatch-mismatch.md) — 
- [dead-code-orphan-after-simplification](dead-code-orphan-after-simplification.md) — 
- [Dry-run line-shape assertions — catch double-emission](dry-run-double-report-pattern.md) — Hash-only dry-run ACs miss output-shape bugs. Add line-shape assertions to catch double-emission.
- [Post-/scaff:update-plan drift detection pattern](post-update-plan-drift-detection-pattern.md) — At validate, cross-grep PRD concrete values against shipped code + 04-tech.md D-ids, especially when an update-plan commit exists on the feature branch. Caught 4 `should` drifts on `20260420-flow-monitor-control-plane`.
- [Pre-allow-before-file-exists is a silent over-exemption](pre-allow-before-file-exists-is-a-silent-over-exemption.md) — Allow-list entries that name files not yet created blanket-exempt any future content at that path; prefer deferring the entry to the task that creates the file. Second consecutive occurrence (`20260421-rename-flow-monitor` again pre-allowed RETROSPECTIVE.md) → next occurrence must escalate to must-severity.
- [Grep assertion scans disk tree, not git tracking](grep-assertion-scans-disk-tree-not-git-tracking.md) — Forbidden-literal assertions that scan working tree with `grep -rn` pick up gitignored build output; the allow-list grows to absorb transient disk state. Prefer `git ls-files | xargs grep -l` or require clean working tree. Source: 20260421-rename-flow-monitor T16 added `flow-monitor/dist/**` as permanent carve-out for Vite bundle content.

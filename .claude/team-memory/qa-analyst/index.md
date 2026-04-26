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
- [Partial wiring trace — assert a test path for every emit site](partial-wiring-trace-every-entry-point.md) — When a fixup extends scope to a mirror emit site (e.g. cmd_init AND cmd_migrate of the same shim template), each site needs its own test path. Passing runtime + missing test for a mirror site is a should-class wiring-trace gap, not advisory. Source: 20260426-scaff-init-preflight W2 fixup line 1314 + t108 missing migrate-path coverage.
- [Named-risk + claimed-mitigation pairs need wiring verification](tech-doc-named-risk-with-plan-claimed-mitigation-must-verify-wiring.md) — When tech §6 names a risk and plan claims a task mitigates it, gap-check must trace the carry-state through the production path, not just check the symbol exists. Tests pass in isolation while production resets the state on every call.

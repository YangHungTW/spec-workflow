# qa-analyst — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Dry-run line-shape assertions — catch double-emission](dry-run-double-report-pattern.md) — Hash-only dry-run ACs miss output-shape bugs. Add line-shape assertions to catch double-emission.
- [Dead-code orphan after simplification](dead-code-orphan-after-simplification.md) — When tech-doc pseudocode is simplified during implementation, helper functions from the sketch may remain as dead code; gap-check should grep for unreferenced helpers.
- [Agent name / dispatch identifier mismatch — silent BLOCK](agent-name-dispatch-mismatch.md) — Grep every new agent file's `name:` frontmatter against every command-file dispatch identifier; a mismatch silently fails dispatch and looks like a legitimate BLOCK verdict.

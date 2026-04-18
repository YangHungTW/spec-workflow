# pm — memory index

<!-- One line per memory. Format:
- [Title](file.md) — one-line hook
-->

- [Split by blast radius, not item count](split-by-blast-radius-not-item-count.md) — When a request bundles multiple items, split by blast radius (what breaks if this ships wrong), not by item count; items with different failure surfaces belong in separate features.
- [Housekeeping sweep threshold](housekeeping-sweep-threshold.md) — Bundle review-generated nits into a dedicated housekeeping sweep when post-ship nit count crosses ~10 items, all advisory.
- [AC must verify existing baseline](ac-must-verify-existing-baseline.md) — Before writing an AC that asserts parity with a sibling (`match X and Y`), verify X and Y are themselves aligned.

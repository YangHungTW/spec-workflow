# Validate: 20260422-monitor-ui-polish
Date: 2026-04-22
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS (after 1 re-run following initial BLOCK)
Findings: 0 must, 4 should/advisory

## Run 1 (2026-04-22) — BLOCK

Initial run surfaced 2 must-severity runtime bugs that the reviewer waves' stub-based tests did not catch:
- **tester AC17 (must)**: `.repo-sidebar__archived-slug` had no matching CSS italic rule — italic never rendered at runtime.
- **analyst R18 (must)**: `RepoSidebar` declared `onArchivedRowClick`, `MainWindow` spread `onArchivedFeatureClick` — archived-row click handler silently dead.

Both fixed in branch `20260422-monitor-ui-polish-fix1` (commit `5920fb1`) and merged to feature branch.

## Run 2 (2026-04-22) — NITS (aggregate)

### Tester axis — PASS

All 24 ACs verified. AC17 italic now applies at runtime (CSS selector matches component class). Baseline test suite unchanged: 11 pre-existing failures carried over from `06432ce`, 0 new failures introduced by this feature. Rust: 126 lib + 56 integration tests all green. Shell: `bash test/t76_agent_color_frontmatter.sh` exits 0.

```
## Validate verdict
axis: tester
verdict: PASS
findings: []
```

### Analyst axis — NITS

R18 wiring fully resolved (both sides on `onArchivedFeatureClick`). AC17 italic selector now matches. No new drift from fix commit. `.repo-sidebar__item-label` rule remains used by non-archived rows — not dead CSS.

One residual advisory:

```
## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    ref: style
    file: flow-monitor/src/components/__tests__/RepoSidebar.test.tsx
    line: 335
    rule: reviewer-style
    message: Stale describe-block comment reads "navigates via onArchivedRowClick" (old name); actual prop renamed to onArchivedFeatureClick — comment should be updated to prevent misleading readers
```

## Accumulated advisories (informational — carry-over from reviewer waves)

- Multiple WHAT-restating code comments (T4, T6, T8, T9, T12, T14, T16 reviews) — style advisory.
- T13: `sidebar.archived` key left as English in `zh-TW.json` — i18n advisory.
- T13: `list_archived_features` IPC response cast without full runtime shape guard (T18's guard was for a different command) — security advisory.
- T15: unused `args` lambda param in `CardDetail.test.tsx` — style advisory.
- T8: `.repo-sidebar__arch-badge` BEM naming drift vs sibling `archived-*` classes — style advisory.
- T17: raw `rgba(0,0,0,0.25)` literal for tooltip shadow — theme-var advisory.

None block; all are documented and tracked for follow-up during next touches.

## Validate verdict
axis: aggregate
verdict: NITS

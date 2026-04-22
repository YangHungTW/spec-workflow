# Validate: 20260422-monitor-ui-polish
Date: 2026-04-22
Axes: tester, analyst

## Consolidated verdict
Aggregate: BLOCK
Findings: 2 must, 3 should/advisory

## Tester axis

AC walkthrough: 23 of 24 ACs pass; 1 must-severity AC17 fails at runtime.

- AC1–AC5: PASS (t76 shell test exits 0)
- AC6: PASS (no agent hex outside agent-palette.css)
- AC7: PASS (advisory: mockup 9px note is stale; shipped 10px matches StagePill)
- AC8: PASS (reviewer axis badge with sec/perf/style)
- AC9: PASS (SessionCard new row)
- AC10: PASS (CardDetailHeader next to StagePill)
- AC11: PASS (NotesTimeline inline var color)
- AC12: PASS (7px dot on active, none on archived)
- AC13: PASS (Archived section always shows count)
- AC14: PASS (collapsed default)
- AC15: PASS (sessionStore persists)
- AC16: PASS (archive_discovery Rust tests N slugs → N records)
- **AC17: BLOCK** — `.repo-sidebar__archived-slug` class on the component has NO matching italic CSS rule; the rule at `components.css:1520` targets `.repo-sidebar__archived-row .repo-sidebar__item-label` which never matches. Italic never rendered at runtime. Opacity 0.65 + arch badge are correct, but italic (R17 must) is missing.
- AC18: PASS structurally (ARCHIVED/Read-only badges, no AgentPill) — but see Analyst R18 finding below for the upstream wiring gap.
- AC19: PASS (no mutate IPC; controls omitted by construction)
- AC20: PASS (opacity 0.38, cursor: not-allowed, transparent border)
- AC21: PASS (::after "Not yet produced" tooltip)
- AC22: PASS (onClick guard + aria-disabled + tabIndex)
- AC23: PASS (list_feature_artefacts + shape guard)
- AC24: NITS — 11 pre-existing failures unchanged from `06432ce` baseline; 0 new failures from this feature (risk-log #4 interpretation)

```
## Validate verdict
axis: tester
verdict: BLOCK
findings:
  - severity: must
    ac: AC17
    file: flow-monitor/src/components/RepoSidebar.tsx
    line: 222
    rule: ac17-italic-slug
    message: archived-slug class has no CSS italic rule; component uses .repo-sidebar__archived-slug but styles/components.css targets .repo-sidebar__archived-row .repo-sidebar__item-label — italic never applied at runtime (R17 must)
  - severity: should
    ac: AC7
    file: flow-monitor/src/styles/components.css
    line: 1391
    rule: ac7-font-size-mockup-drift
    message: agent-pill font-size is 10px matching StagePill; AC7 parenthetical "(9px per mockup)" is stale — primary R7 met
  - severity: should
    ac: AC24
    file: flow-monitor/src/views/__tests__/MainWindow.perf.test.tsx
    line: 1
    rule: ac24-pre-existing-failures
    message: 11 pre-existing failures unchanged from 06432ce baseline; 0 new failures introduced
```

## Analyst axis

Static PRD-vs-diff gap analysis: 26 of 27 R-ids covered cleanly; 1 must-severity R18 broken at runtime due to prop-name dispatch mismatch.

- Group A (R1–R5): all covered; AC4 has no automated machine check (should).
- Group B (R6–R13, R26): all covered.
- Group C (R14–R20): all covered structurally BUT R18 broken at runtime — MainWindow→RepoSidebar prop-name dispatch mismatch (see finding).
- Group D (R21–R25): all covered.
- Cross-cutting: R27 regression sweep logged; zh-TW `sidebar.archived` untranslated (should).
- Tier upgrade audit trail: clean (STATUS.md line 54 records standard→audited at 2026-04-22 on T18 security-must).

```
## Validate verdict
axis: analyst
verdict: BLOCK
findings:
  - severity: must
    ref: R18
    file: flow-monitor/src/views/MainWindow.tsx
    line: 7270
    rule: partial-wiring
    message: MainWindow passes prop `onArchivedFeatureClick` via spread, but RepoSidebar declares `onArchivedRowClick` — prop name mismatch means archived-row click handler is silently dead; clicking any archived entry in the sidebar will not navigate to archived CardDetail (AC18 uncovered at runtime).
  - severity: should
    ref: AC4
    file: test/t76_agent_color_frontmatter.sh
    line: n/a
    rule: ac-coverage
    message: AC4 ("git diff shows only color: addition in frontmatter, no other lines changed") has no automated test; T3 script covers AC1/AC2/AC3/AC5 only.
  - severity: should
    ref: R11
    file: flow-monitor/src/i18n/zh-TW.json
    line: 6272
    rule: i18n-untranslated
    message: sidebar.archived = "Archived" in zh-TW.json (English string, not translated) — advisory only.
```

## Validate verdict
axis: aggregate
verdict: BLOCK

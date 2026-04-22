# 02-design — 20260422-monitor-ui-polish

Tool used: HTML mockup (standalone, no external deps).

## Files

| File | Purpose |
|---|---|
| `mockup.html` | Self-contained HTML mockup covering all three UI polish items |
| `palette.md` | Agent role color palette — tied to Claude Code `color:` frontmatter names (8 values); CSS hex for monitor rendering; reviewer axis handling |
| `notes.md` | Design decisions, rationale, open questions |

## Preview

```
open mockup.html
```

## Screens covered

1. **Agent role palette** — pill demo (all 10 roles), palette reference table,
   in-context view of colored role names in the Notes timeline.
2. **Archived sidebar** — collapsed state (default), expanded state, archived
   feature in CardDetail with read-only banner.
3. **Disabled tabs** — before/after comparison; hover tooltip simulation; full
   composite view of CardDetail with tabs disabled beyond current stage.
4. **Composite app shell** — full main window with sidebar agent dots,
   agent pills in session cards, collapsed archived section.

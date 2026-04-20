# 02-design — flow-monitor B1

## Tool used

HTML mockup (Tailwind CDN, self-contained, no build step).
Pencil MCP was not reachable at design time; HTML chosen as fallback per Designer agent definition.

## How to open

```
open .spec-workflow/features/20260419-flow-monitor/02-design/mockup.html
```

The file opens in any browser. Use the nav bar at the top to switch between screens.

## Screens

| Nav button | File section | What it shows |
|---|---|---|
| Main Window (EN) | `#screen-main-en` | Full main window in English: project switcher sidebar, 6-session card grid (all health states visible), toolbar with sort + compact-mode affordance, language toggle |
| Main Window (zh-TW) | `#screen-main-zh` | Same layout with all UI copy in zh-TW; demonstrates i18n parity across sidebar, cards, badges, and timestamps |
| Stalled State | `#screen-stalled` | Enlarged stalled card detail (red accent bar, stalled badge + duration, read-only actions) + macOS Notification Center banner simulation; two-level severity legend |
| Card Detail | `#screen-card-detail` | Drill-in read-only view for a single session: breadcrumb back-nav, header strip with stage pill and action buttons, left rail (11-stage checklist + Notes timeline), right pane (tab strip across all 8 doc slots + markdown preview + read-only footer) |
| Compact Panel | `#screen-compact` | Floating always-on-top panel side-by-side in EN and zh-TW; 1-line-per-session with coloured dot, stage pill, relative time; behaviour annotation |
| Settings | `#screen-settings` | General tab (language, idle thresholds, notification toggles, polling interval) + Repositories tab (add/remove repos, folder-picker CTA) |
| Empty State | `#screen-empty` | No repos registered: illustration, explanatory copy, primary CTA, what-the-app-watches explainer |

## Open decisions

See `notes.md` — section "Open visual decisions for PRD / Architect input" lists 10 items requiring policy decisions before PRD can lock acceptance criteria.

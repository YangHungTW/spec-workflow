# 02-design — flow-monitor B2 (Control Plane)

## Files

| File | Description |
|---|---|
| `mockup.html` | Self-contained HTML mockup (Tailwind CDN). 7 screens; dark/light toggle; B1 visual language. |
| `notes.md` | Design decisions, open questions, uncovered states. |
| `README.md` | This file. |

## Preview

```
open .spec-workflow/features/20260420-flow-monitor-control-plane/02-design/mockup.html
```

## Screens

| # | Title | B2 new surface |
|---|---|---|
| 1 | Card Grid + Stalled | Stalled card action-button strip; toolbar "Specflow ⌘K" launcher |
| 2 | Card Detail + Actions | Advance + Message/Choice buttons in header; inline send-panel with Q1 method tabs; audit trail in left rail |
| 3 | Command Palette | ⌘K palette; context-sensitive control actions; WRITE/DESTROY command taxonomy |
| 4 | Confirmation Modal | Fires for DESTROY commands (archive, update-*); cancel-safe default |
| 5 | Notification Banner | macOS Notification Center EN + zh-TW; compact panel badge in context |
| 6 | Compact Panel B2 | "▶ Next" quick-action on stalled rows; side-by-side B1 read-only comparison |
| 7 | Card Context Menu | "···" overflow menu; full command list with WRITE/DESTROY pills |

## Inheritance from B1

All design tokens, card grid, card styles, stage pills, sidebar, window chrome, compact panel glass style, and theme toggle are inherited verbatim from B1 (`archive/20260419-flow-monitor/02-design/mockup.html`). B2 adds new CSS classes and components but does not modify any existing B1 token values.

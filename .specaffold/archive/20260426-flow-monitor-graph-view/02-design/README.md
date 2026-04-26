# 02-design — flow-monitor graph view

## Files

| File | Contents |
|---|---|
| `mockup.html` | Self-contained HTML mockup, 3 screens, dark mode, no external dependencies |
| `notes.md` | Flows covered, design decisions, open questions, uncovered states |
| `README.md` | This file |

## Screens in mockup.html

1. **stage=plan** — full two-row DAG; request/design/prd/tech done; brainstorm skipped; plan active with spinning arc; artifact edge labels; per-node timestamp whisker.
2. **stage=implement** — tasks node in partial state (3/7 counter); implement node active; 7-pip task-bar above graph.
3. **Live-update affordance closeup** — old PollingFooter vs new sidebar pip; per-node whisker in three states; conceptual IPC event trace.

## Preview

```
open /Users/yanghungtw/Tools/specaffold/.specaffold/features/20260426-flow-monitor-graph-view/02-design/mockup.html
```

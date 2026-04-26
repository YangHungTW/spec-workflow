# Design Notes — flow-monitor graph view

## Flows covered

1. **Screen 1 — stage=plan**: request/design/prd/tech completed; brainstorm skipped;
   plan node active. Shows the full two-row DAG layout, artifact labels on edges,
   the skipped-node bypass arc, and the per-node "last-changed" whisker on the footer.

2. **Screen 2 — stage=implement, partial tasks**: plan done; tasks node in partial
   state (3/7 counter inside node); implement node active. Demonstrates the task-pip
   mini-bar above the graph (7 pips map 1:1 to task files) and the active-dot
   pulse on the implement node.

3. **Screen 3 — live-update affordance closeup**: side-by-side comparison of old
   PollingFooter vs new sidebar pip; per-node timestamp whisker in three states
   (just-updated, quiet, active); conceptual IPC event trace showing ~16 ms path
   from FS event to node state change.

## Key decisions

### Graph layout: two-row linear-DAG
Nodes are placed in two rows connected by a bridge from the plan node:
- Row 1: request → brainstorm → design → prd → tech → plan
- Row 2: tasks → implement → gap-check → verify → archive
This avoids a fully radial graph (hard to read at small card width) and maps
naturally to scaff's sequential stage model. The layout fits inside a card that
is already width-constrained to ~220px in the 2-column grid.

### Skipped stages: dashed outline + bypass arc
A brainstorm-skipped node uses a dashed purple outline (visually distinct from
both completed and future) plus an arc that jumps over it. This avoids a
"crossed out" treatment (too aggressive for a read-only monitor) and preserves
the topological integrity of the graph.

### Tasks node: partial state
When stage=implement, the tasks node switches to a green-outline "partial" state
with a "3/7" counter. The task-pip mini-bar above the graph gives a full breakdown
without expanding graph complexity. The pip-bar is the primary way to see per-task
progress; the graph node is the secondary confirmation.

### Live-update affordance: sidebar pip + per-node whisker
Removed PollingFooter entirely. Two affordances replace it:
- Sidebar footer: single pulsing pip + "Live FS watch" label.
  Answers: "is the watcher alive?" Grey pip = watcher error.
- Per-node timestamp whisker: shows artifact mtime only when recently changed
  (<60s), then hides. Answers: "what just changed in the graph?"
Rejected alternatives:
- Keeping PollingFooter with a 1s interval label: misleading — FS watch is
  event-driven, not interval-driven.
- Floating global "last refreshed" banner: loses the per-artifact granularity
  that makes the graph useful.

### Read-only constraint enforced
No click handlers, hover menus, or buttons on graph nodes. The spinning arc and
pulsing dot are purely visual status indicators. ActionStrip (stalled cards) is
unaffected — it remains separate from the graph area.

## Resolved decisions (user, 2026-04-26)

1. **Card height budget**: target **340px** per card. The two-row graph fits
   comfortably; compact-panel still uses StagePill-only (no toggle on the
   main card).

2. **Skipped-node bypass arc**: keep the arc treatment as mocked.

3. **Task overflow handling**: switch the per-task pip row to a **progress
   bar** (no pip cap, no overflow counter). The progress bar always shows
   `done / total` regardless of task count.

4. **Partial-tasks data source**: parse **tasks.md on the frontend**. The
   data contract is `{ tasks_done: number, tasks_total: number }` derived
   by counting `[x]` vs `[ ]` checkboxes. Rust IPC layer does not need a
   new field; the frontend reads tasks.md directly via the existing FS
   watcher event stream.

5. **Watcher error state**: grey pip **plus a toast** notification. The
   toast surfaces the failure mode (the user does not always look at the
   sidebar); the grey pip remains as the steady-state indicator.

## Uncovered states

- Stalled card (idleState=stalled) with graph view — the red color treatment
  from StageChecklist presumably carries over to node outlines; not mocked.
- Archive stage — final node in the chain; no special treatment mocked.
- Very long session slug overflowing the card header.
- Dark/light theme variants — mockup is dark-mode only; light mode needs
  its own color token pass.
- Compact panel graph view (if any).

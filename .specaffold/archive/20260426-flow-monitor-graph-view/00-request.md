# Request

**Raw ask**: Add a graph view of scaff stages and artifact dependencies to flow-monitor sessions, with active-stage highlight and filesystem-watch live updates replacing the current polling.

**Context**: The target app is `flow-monitor/` — a Tauri (Rust + React) read-only macOS dashboard that monitors parallel scaff sessions across git repos. Today it presents each session via a linear `StageChecklist` component and refreshes state via a `PollingFooter` on a 5 s timer (per B1 known-limitation: "Polling, not FS events"). The user, comparing flow-monitor to ComfyUI's node-based UI, identified two specific learnings worth porting:

1. Replace the linear stage checklist with a DAG/graph view that renders scaff stages as nodes and the artifact dependencies between them as edges (PRD → tech → plan → tasks → STATUS), with the currently-active stage visually highlighted.
2. Replace the 5 s poll with a Rust-side filesystem watcher (e.g. the `notify` crate) that emits IPC events to the React frontend whenever monitored `.specaffold/` artifacts change — analogous to ComfyUI's WebSocket-based live updates.

Motivation is timeliness and legibility: the current linear checklist hides the artifact-dependency structure that is central to scaff's mental model, and 5 s polling adds noticeable lag plus wasted CPU when nothing has changed. The user is the sole operator and dogfooder; there is no external stakeholder. This work was originally flagged as "B2 enhancement" in the B1 known-limitations list but is being pulled forward as a focused upgrade independent of the broader B2 control-plane work.

**Success looks like**:
- Each session card in flow-monitor renders a graph view (nodes = stages, edges = artifact dependencies) in place of (or alongside) the current linear `StageChecklist`.
- The currently-active stage is visibly highlighted in the graph.
- When a monitored `.specaffold/` artifact changes on disk, the corresponding node updates in the UI within ~1 second without the user reloading or waiting for the 5 s poll tick.
- The polling code path is removed (or reduced to a fallback) in favour of the filesystem-watch event stream.
- The app remains read-only: no new control-plane affordances.

**Out of scope**:
- B2 control plane (start / stop / interact with sessions from the app) — explicitly deferred.
- Shareable session snapshot export — separate future request.
- Cross-platform support (Linux / Windows) — macOS only, consistent with B1 scope.
- Code signing / notarisation — remains a separate Q-plan-3 follow-up.
- Re-skinning unrelated surfaces (settings panel, tray icon, compact panel) beyond what the graph-view integration strictly requires.

**UI involved?**: yes — this feature replaces a visible UI component (`StageChecklist`) with a new graph-view component and changes the live-update behaviour the user perceives. The Designer stage should run.

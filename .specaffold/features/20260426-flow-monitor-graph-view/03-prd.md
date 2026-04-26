# PRD — flow-monitor graph view

**Slug**: `20260426-flow-monitor-graph-view`
**Date**: 2026-04-26
**Author**: PM
**Has UI**: yes

## 1. Summary

Replace flow-monitor's linear `StageChecklist` and 5-second `PollingFooter` with two coordinated upgrades that match the artifact-dependency mental model of scaff and the live-update expectations the user formed comparing flow-monitor to ComfyUI: (a) a per-session two-row DAG **graph view** that renders the 11 scaff stages as nodes connected by their artifact dependencies, with the active stage visually highlighted and skipped stages shown via a dashed bypass arc; and (b) a Rust-side **filesystem watcher** (`notify` crate or equivalent) that emits Tauri IPC events on `.specaffold/**` changes, replacing the polling cycle so node state and the new sidebar "Live FS watch" pip update within ~1 second of disk change. The app remains read-only; no control-plane affordances are introduced. All six existing B1 manual smoke checks (empty state, add repo, theme toggle, language toggle, compact panel, tray icon) must continue to pass.

## 2. Goals & Non-goals

### Goals

- Replace `StageChecklist` with a graph view that renders the 11 scaff stages as a two-row DAG with artifact-edge labels and active-stage highlight.
- Replace the 5-second polling cycle with an FS-watch event stream so monitored `.specaffold/**` artifact changes are reflected in the UI within ~1 second of disk change.
- Replace `PollingFooter` with a single sidebar "Live FS watch" pip plus per-node "last-changed" whisker (auto-hides after 60s of quiet).
- Surface task progress as a `done / total` progress bar derived by parsing `tasks.md` checkboxes on the frontend (no new IPC field).
- Preserve the current read-only posture: no click handlers, hover menus, or buttons on graph nodes; `ActionStrip` on stalled cards is unchanged.
- Preserve all six existing B1 manual smoke checks.

### Non-goals

- B2 control plane (no start / stop / interact controls).
- Shareable session snapshot export.
- Cross-platform support (Linux / Windows).
- Code signing / notarisation.
- Re-skinning unrelated surfaces (settings, tray icon, compact panel) beyond the integration touches strictly required by graph view (e.g. compact panel continues to use `StagePill` only — no graph in compact view).
- Light-mode color token pass for the graph (mockup is dark-mode only; light mode is a follow-up; see §6).
- New stalled / red color treatment for graph nodes (carries over from existing CSS tokens; not redesigned here).

## 3. User scenarios

### S1 — Operator monitoring an active `plan` stage session

The user has a session at `stage=plan` open in the dashboard. Brainstorm was skipped. The session card renders the two-row DAG: row 1 (`request → brainstorm → design → prd → tech → plan`) with `request`, `design`, `prd`, `tech` shown as completed nodes, `brainstorm` shown as a dashed-outline node with a bypass arc skipping over it, and `plan` shown as the active node with a spinning arc. Edges between nodes are labelled with the artifact name they produce (e.g. `00-request.md`, `03-prd.md`). The sidebar shows a single pulsing pip with the label "Live FS watch". When a file under `.specaffold/features/<slug>/` changes on disk, the corresponding node's "last-changed" whisker appears within ~1 second showing the artifact mtime; the whisker auto-hides 60 seconds later if no further change.

### S2 — Operator watching tasks fill in during `implement`

The session has advanced to `stage=implement`. The graph shows row 1 fully complete, the bridge to row 2 active, `tasks` in a partial state with a "3 / 7" counter in-node, and `implement` as the active node. Above the graph, a horizontal progress bar renders 3/7 done with the label `3 / 7`. The user creates a fourth task file by editing `tasks.md`; within ~1 second the FS-watch event fires, the frontend re-parses `tasks.md`, the progress bar advances to `4 / 7`, the in-node counter updates to `4 / 7`, and the corresponding node's last-changed whisker appears.

### S3 — Watcher dies mid-session

The user is monitoring multiple sessions. A filesystem-watch error occurs (e.g. exhausted `kqueue` descriptors, removed mount). The Rust side emits a watcher-error IPC event. The sidebar pip turns grey (no pulse), the label remains "Live FS watch", and a toast notification appears explaining the failure mode. The user can still see existing card state but knows updates are no longer live until the watcher recovers.

### S4 — Existing B1 smoke regression check

After the upgrade lands, the user runs through the six B1 manual smoke checks (empty state, add repo, theme toggle, language toggle, compact panel, tray icon). Every check passes unchanged. The compact panel still shows `StagePill`-only summaries (no graph). The settings panel and tray icon are untouched.

## 4. Requirements

### Graph view (replaces `StageChecklist`)

**R1 — Two-row DAG layout per session card.** Each session card renders a graph component placing the 11 stages in two rows: row 1 = `request → brainstorm → design → prd → tech → plan`; row 2 = `tasks → implement → gap-check → verify → archive`; with a bridge edge from `plan` (row 1 terminus) to `tasks` (row 2 origin).
*AC1*: Open a session card at any stage; assert exactly 11 nodes are rendered, 6 in row 1 and 5 in row 2, in the order specified, with a visible bridge edge from `plan` to `tasks`.

**R2 — Artifact-labelled edges.** Each edge between adjacent stage nodes carries a label naming the artifact the upstream stage produces (e.g. `request → brainstorm` labelled with `00-request.md`; `prd → tech` labelled with `03-prd.md`). The 11-stage chain has 10 directed edges plus the bridge edge, each with an artifact label per the canonical scaff stage→artifact map.
*AC2*: Inspect a rendered session card; assert every directed edge in the DAG has a non-empty artifact-name label visible to the user.

**R3 — Active-stage highlight.** The node whose stage matches the session's `currentStage` is rendered in an "active" visual state distinct from completed and future nodes (per design: pulsing dot / spinning arc treatment).
*AC3*: Render a session at `stage=plan`; assert exactly one node — the `plan` node — carries the active-state class / data attribute. Repeat with `stage=implement`; assert only `implement` is active.

**R4 — Completed vs future state.** Every stage strictly before `currentStage` in the canonical 11-stage order renders in a "completed" visual state; every stage strictly after renders in a "future" state. The classifier matches the existing `StageChecklist` ordering rule (`STAGE_KEYS.indexOf`).
*AC4*: At `stage=tech`, assert nodes `request`, `design`, `prd` are completed; nodes `plan`, `tasks`, `implement`, `gap-check`, `verify`, `archive` are future. (Brainstorm handled by R5.)

**R5 — Skipped-stage treatment: dashed outline + bypass arc.** When a stage was skipped for a session (per the existing skip-detection signal flowing through to the frontend), its node renders with a dashed outline distinct from completed / active / future, and the graph draws a bypass arc that visually jumps over the skipped node from its predecessor to its successor. No "strikethrough" alternative.
*AC5*: Render a session where `brainstorm` is skipped; assert the `brainstorm` node carries the "skipped" class / data attribute, its outline is dashed, and a bypass arc edge is rendered from `request` to `design`.

**R6 — Tasks node partial state with `done / total` counter.** When `currentStage=implement` (and the session has tasks), the `tasks` node renders in a "partial" state with an in-node `done / total` counter (e.g. `3 / 7`). Counter values come from the data contract defined in R10.
*AC6*: At `stage=implement` with 3 of 7 tasks marked done, assert the `tasks` node renders the literal text `3 / 7` (or locale-formatted equivalent) inside the node and carries a "partial" class / data attribute.

**R7 — Read-only constraint.** Graph nodes have no click handlers, hover menus, popovers, buttons, or any interactive affordance. Visual status indicators (pulsing dot, spinning arc, whisker) are decorative only. `ActionStrip` on stalled cards remains separate from the graph area and is unaffected.
*AC7*: Inspect the rendered DOM for any session card's graph subtree; assert no node has `onClick`, `role="button"`, `tabIndex`, or any interactive ARIA role. `ActionStrip` continues to render unchanged on stalled cards (visible alongside, not inside, the graph).

**R8 — Card height budget: 340px target.** The graph view + existing card chrome (header, slug, stage pill, agent pill, note excerpt, meta row, hover actions) fits within a 340px target card height. Cards may exceed this when stalled (`ActionStrip` adds height) but the non-stalled steady state must hit 340px.
*AC8*: Render a non-stalled session card in a desktop viewport; measure the card outer height; assert it is ≤ 340px ± 16px tolerance.

**R9 — Per-node "last-changed" whisker.** Each node carries an optional whisker showing the artifact mtime in relative form (e.g. `2s ago`) when the artifact changed within the last 60 seconds. After 60 seconds of no change, the whisker hides for that node.
*AC9*: Trigger an FS-watch event for a node's artifact; within ~1s assert the whisker appears showing relative mtime; wait 60s with no further change; assert the whisker hides.

### Tasks data contract (frontend-only parse)

**R10 — Frontend parses `tasks.md` for `{ tasks_done, tasks_total }`.** The frontend reads `tasks.md` (via existing IPC file-read or extended FS-watch payload — implementation choice for the architect) and counts `[x]` (case-insensitive) vs `[ ]` checkboxes to derive `tasks_done` and `tasks_total`. No new Rust IPC schema field is added for task progress.
*AC10*: Author a `tasks.md` containing 3 lines with `- [x]` and 4 lines with `- [ ]`; render the session at `stage=implement`; assert the in-node counter shows `3 / 7` and the progress bar (R11) shows `3 / 7`.

**R11 — Progress bar replaces pip row, no cap.** Above the graph (and only when `currentStage=implement` and `tasks_total > 0`), the card renders a horizontal progress bar showing `tasks_done / tasks_total` filled proportionally, with the literal label `done / total` adjacent. There is no per-task pip; there is no cap on `tasks_total`.
*AC11*: Render a session with `tasks_done=3, tasks_total=7`; assert a progress bar is visible above the graph, ~43% filled, with text `3 / 7`. Render a session with `tasks_total=50`; assert the progress bar still renders without overflow or pip clipping.

### Live updates (replaces 5s polling)

**R12 — Rust-side FS watcher on `.specaffold/**`.** The Rust backend instantiates a filesystem watcher (`notify` crate or equivalent) covering `.specaffold/` subtrees of all monitored repositories. On any create / modify / delete event for a `.specaffold/` artifact, the backend emits a Tauri IPC event identifying the affected slug and artifact path. Watcher startup occurs at app launch (and on add-repo) and is registered before the first session card renders.
*AC12*: Edit any `.specaffold/features/<slug>/03-prd.md` file in a monitored repo while the app is running; assert a Tauri IPC event with the slug and artifact path is emitted within 1 second of the disk write (instrument via dev-mode log).

**R13 — Polling cycle removed.** The `polling_cycle_complete` event emitter and the 5-second poll loop are removed from the runtime path. (The settings polling-interval slider may remain present in the codebase as a no-op for backward settings compatibility; whether to also remove the slider is an architect call. R13's bar is that no live polling cycle runs during normal operation.)
*AC13*: Run the app for 60 seconds with no FS changes; assert no `polling_cycle_complete` event fires and no `.specaffold/` reads occur on a 5-second cadence (instrument via dev-mode log).

**R14 — UI latency: FS event → node update ≤ 1 second.** From the moment a `.specaffold/` artifact write completes on disk, the corresponding session card's relevant node (graph node state, last-changed whisker, or task progress bar) updates in the rendered DOM within 1 second p95 on a developer Mac.
*AC14*: Instrument an end-to-end timing harness in dev mode: write a file, capture the disk-write timestamp, capture the React render-commit timestamp; over 20 trials, assert p95 ≤ 1000ms.

**R15 — Sidebar "Live FS watch" pip replaces `PollingFooter`.** The sidebar footer component is replaced with a single pulsing pip plus the static label "Live FS watch" (i18n key required). No interval value is displayed (the FS watch is event-driven, not interval-driven).
*AC15*: Inspect the sidebar footer; assert exactly one pip element and the label "Live FS watch" (or its zh-TW translation when `LANG_CHAT=zh-TW`); assert no numeric interval is rendered. Assert the old `polling-footer` testid is gone.

**R16 — Watcher error UX: grey pip + toast.** If the Rust watcher errors out (initialisation failure, runtime drop, descriptor exhaustion, etc.), the backend emits a watcher-error IPC event. On receipt, the sidebar pip transitions to a grey non-pulsing state and a toast notification appears describing the failure (i18n key required).
*AC16*: Force a watcher failure in dev mode (test seam: emit a synthetic watcher-error IPC event); assert the sidebar pip turns grey and stops pulsing within 1 second, and a toast notification is visible to the user.

### Preservation of existing behaviour

**R17 — Six B1 smoke checks unchanged.** All six B1 manual smoke checks listed in `flow-monitor/README.md` (empty state, add repo, theme toggle, language toggle, compact panel, tray icon) continue to pass without regression. The compact panel continues to use `StagePill`-only summaries — no graph view in compact panel.
*AC17*: Execute the six smoke checks per `flow-monitor/README.md`; assert all six pass. In particular, assert the compact panel renders `StagePill` summaries only (no graph subtree).

**R18 — `SessionCard` chrome preserved.** The six elements of `SessionCard` per its existing AC7.a contract (slug, `StagePill`, relative time, `IdleBadge`/Active, note excerpt, hover-actions = exactly "Open in Finder" + "Copy path") remain present and unchanged. The graph view is added in place of `StageChecklist`'s former location; no other card chrome is removed or relocated.
*AC18*: Render a session card; assert all six chrome elements remain in their existing positions per `SessionCard.tsx`; assert no third hover action is added; assert `ActionStrip` continues to mount only on stalled cards.

**R19 — i18n coverage for new strings.** Every new user-visible string introduced by this feature ("Live FS watch", watcher-error toast text, `done / total` label format, any tooltip on whiskers) is added to both English and zh-TW translation files; per the existing i18n discipline, no hardcoded user-facing English appears in components.
*AC19*: Grep new strings against the translation files; assert each is registered in both `en` and `zh-TW`; toggle language at runtime; assert all new strings render in the selected language without reload.

## 5. Success metrics / acceptance bar

- **Graph render**: each session card's graph view renders within 100ms of card mount on a developer Mac (baseline: existing `StageChecklist` renders in ~5–10ms; the graph is allowed an order of magnitude headroom for its DAG layout).
- **FS-event-to-UI latency**: p95 ≤ 1000ms (R14 / AC14), measured end-to-end from disk write to React render-commit.
- **CPU steady-state**: with no FS changes, app CPU usage at idle is lower than the current polling baseline (the 5s poll is gone; no new periodic work replaces it). Verified via Activity Monitor over a 60-second idle window before vs after the change.
- **B1 smoke parity**: all six B1 manual smoke checks (`flow-monitor/README.md` §"Six manual smoke checks") pass unchanged.
- **Read-only invariant**: zero new control-plane affordances introduced. No graph node carries an `onClick` or interactive role (R7).
- **Card height**: non-stalled session card outer height ≤ 340px ± 16px tolerance (R8).
- **Watcher resilience**: a synthetic watcher-error event produces grey pip + toast within 1 second (R16).

## 6. Risks & open questions

### Risks

- **`notify` crate FSEvents quirks on macOS**: `notify` on macOS uses FSEvents, which coalesces events and has a small native delay. The 1-second p95 budget (R14) should be comfortably achievable but is the tightest end-to-end latency target the app has shipped to date. Mitigation: architect should benchmark `notify`'s default debounce / coalesce settings during tech stage and tune for the artifact-edit case.
- **Watcher descriptor exhaustion at scale**: monitoring many repos with deep `.specaffold/` trees could approach FSEvents resource limits. Mitigation: scope watch roots to `.specaffold/` (not the entire repo); R16's grey-pip + toast is the user-facing fallback when limits are hit.
- **Graph layout at narrow card widths**: the two-row DAG must fit within the existing ~220px card width. Mitigation: design's mockup demonstrates the layout fits at 220px; verify in Designer/Architect handoff.
- **`tasks.md` parse drift**: frontend regex / parser for `[x]` vs `[ ]` may drift from how scaff itself formats tasks. Mitigation: PRD R10 fixes the contract to literal `[x]` (case-insensitive) vs `[ ]`; QA writes a fixture-based test (AC10) that pins the expected counts.
- **Light-mode color tokens not designed**: design notes flag light mode as an uncovered state. Mitigation: light mode is explicitly out of scope for this PRD per §2; a follow-up token pass is queued separately.
- **Stalled / red node treatment not designed**: design notes flag stalled-card graph treatment as uncovered. Mitigation: existing CSS tokens for stalled state apply unchanged to the card chrome; node-level red treatment is not in scope here. If the architect identifies this as a hard blocker during tech, surface it then.

### Open questions

(None blocking PRD finalisation. The five resolved decisions in `02-design/notes.md` cover card height, skipped-state, task overflow, tasks data source, and watcher error UX. Implementation choices — graph rendering library vs hand-rolled SVG, exact FS watcher debounce window, IPC event payload shape for FS events — are architect-stage concerns and intentionally not pinned here.)

## 7. Blocker questions

None. The five user-resolved decisions in `02-design/notes.md` (card height 340px, dashed-outline + bypass arc for skipped, progress bar replacing pip row, frontend `tasks.md` parse, grey pip + toast for watcher error) cover the previously-open design questions, and no contradiction was uncovered in the existing flow-monitor codebase: `StageChecklist`, `SessionCard`, `PollingFooter`, and `StagePill` all expose the contracts this PRD references (11-stage canonical order, six-element card chrome, `polling_cycle_complete` event seam to remove). PRD is ready for architect handoff.

## Team memory

- `pm/ac-must-verify-existing-baseline` — applied: every parity claim is anchored to one concrete file (R4 cites `STAGE_KEYS.indexOf`, R17 cites `flow-monitor/README.md` smoke list, R18 cites `SessionCard.tsx` AC7.a contract).
- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap` — does not apply: this is a single self-contained upgrade, not a B1/B2 split; the user's one-sentence ask is delivered in full by this feature.
- `pm/housekeeping-sweep-threshold` — does not apply: this is a feature ask, not a nit sweep.
- `shared/dogfood-paradox-third-occurrence` — does not apply: flow-monitor is a Tauri app that does not deliver self-shipping specaffold infrastructure; the FS watcher and graph view exercise immediately on app rebuild.
- `shared/css-classname-rename-requires-consumer-grep` — flagged for architect/developer attention: this feature removes `StageChecklist` and `PollingFooter` and may rename CSS classnames; consumers must be grepped before merge per that memory.
- `shared/status-notes-rule-requires-enforcement-not-just-documentation` — does not apply at PRD stage.
- `shared/auto-classify-argv-by-pattern-cascade` — does not apply: no argv polymorphism in this feature.

Proposed new memory: none — the patterns invoked are already captured.

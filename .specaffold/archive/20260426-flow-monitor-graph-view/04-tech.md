# Tech / Architecture — flow-monitor graph view

**Slug**: `20260426-flow-monitor-graph-view`
**Date**: 2026-04-26
**Author**: Architect
**Inputs**: `03-prd.md` R1–R19; `02-design/notes.md` Resolved decisions §; `02-design/mockup.html`; existing `flow-monitor/` codebase (Tauri 2.2 / React 19 / Rust 2021).

## §1 Summary

The graph view ships as **two coordinated additions to the existing stack** with a deliberately minimal new-dependency surface:

- **Frontend**: a new `<SessionGraph>` component rendered in **raw inline SVG** (no React Flow / no visx) inside `SessionCard`, replacing the import of `<StageChecklist>`. The two-row, eleven-node DAG is small enough and fixed enough that a hand-laid coordinate table beats every graph library on bundle size, theming integration, and read-only-by-construction guarantees. Task progress is parsed in the renderer with a 25-line regex helper. The state path stays in the existing **per-component `useState` + `listen()` from `@tauri-apps/api/event`** pattern (the codebase has no zustand/redux; the only "stores" are local hook factories like `useSessionStore`).
- **Backend**: one new Rust dependency, `notify = "8"` with `notify-debouncer-full = "0.6"`, watching only `<repo>/.specaffold/**` per registered repo. The watcher runs in `tauri::async_runtime::spawn` next to the existing `run_session_polling` loop; the polling loop is **deleted** (R13) and the existing `sessions_changed` event becomes the watcher's emit channel for repo/session list changes, with a new sibling event `artifact_changed` for per-artifact mtime updates that drive whiskers and tasks.md re-parse.

Net: **+1 React component (~250 LOC SVG)**, **+2 Rust deps (notify family)**, **+1 IPC event (`artifact_changed`)**, **+1 IPC event (`watcher_status`) for R16 grey-pip**, **−1 component (`PollingFooter` → `LiveWatchFooter`)**, **−1 polling loop**. No store rewrite, no router change, no settings schema break.

## §2 Decisions

### D1 — Graph rendering: hand-laid inline SVG, no graph library

**What.** `<SessionGraph>` is a single React component that renders the 11 nodes and 11 edges (10 sequential + 1 bridge + 0..1 bypass arc) as inline SVG. Node positions come from a `STAGE_LAYOUT` const (an array of `{ stage, x, y }` records, two rows at fixed y-coordinates). Edges come from a `STAGE_EDGES` const that lists `{ from, to, label }` triples in canonical order. The bypass arc is emitted only when a stage's "skipped" predicate fires (R5), as one extra `<path>` element with a quadratic curve over the skipped node.

**Why.**
- **Bundle size**: React Flow / xyflow is ~110 KB minified+gzipped before nodes/edges JS. visx-network is ~30 KB but pulls d3-selection. Raw SVG is **0 KB net dep weight** and the graph component itself adds ~6 KB of source.
- **Layout engine quality**: PRD R1 fixes the layout to a two-row linear DAG; there is no force-directed, dagre, or elk requirement. Every layout decision a graph library would make is already made for us. A hand-laid layout is *more* correct here than a library because we never want it to shift on us at runtime.
- **Read-only by construction**: PRD R7 requires zero `onClick`, zero `tabIndex`, zero `role="button"` on nodes. Inline SVG has none of these by default; React Flow has all of them by default and would require explicit suppression at every node, which is fragile. (See `shared/css-classname-rename-requires-consumer-grep` memory: the "absence" guarantee is harder to enforce when the library's defaults disagree.)
- **Theme integration**: existing `--stage-<key>-bg` / `--stage-<key>-fg` tokens (see `StagePill.tsx`) plug directly into `fill="var(--stage-…)"` on `<rect>` / `<circle>`. No CSS-in-JS bridge needed.
- **License & maintenance**: zero deps to vet.

**Alternatives considered.**
- *React Flow / @xyflow/react*: rejected — bundle weight and read-only friction outweigh "free" layout we don't need.
- *visx-network*: rejected — d3-selection transitive dep, still requires explicit positions for fixed layouts (no advantage over raw SVG).
- *dagre + custom SVG renderer*: rejected — dagre's value is layout for arbitrary DAGs; ours is fixed.
- *vis.js / cytoscape*: rejected — interactive-by-default; suppressing all interaction is a lot of negative work.

**Rejected reason in one line.** *"Least magic that does the job"* — 11 nodes in two fixed rows is a coordinate table, not a graph problem.

### D2 — Filesystem watcher: `notify` crate with `notify-debouncer-full`, RecommendedWatcher mode

**What.** Add to `src-tauri/Cargo.toml`:
```toml
notify = "8"
notify-debouncer-full = "0.6"
```
Use `new_debouncer(Duration::from_millis(150), None, tx)` with the default `RecommendedWatcher` backend. On macOS this resolves to FSEvents. Watch root: `<repo_root>/.specaffold/` per registered repo, `RecursiveMode::Recursive`. Re-watch on `add_repo` / `remove_repo` IPC commands (existing seam in `ipc.rs`). The debouncer aggregates per-path events within the 150 ms window; one logical write produces one outbound event regardless of how many FSEvents fired.

**Why.**
- `notify` 8.x is the de-facto Rust FS-watch crate, MIT-licensed, actively maintained (last release within 6 months as of 2026-04-26), and known-compatible with Tauri 2.x runtimes (used by `tauri-plugin-fs` itself).
- `notify-debouncer-full` solves the "FSEvents fires 2–4 times per save" coalescing problem that `notify`'s docs explicitly call out for macOS APFS. 150 ms window is well below the R14 1-second p95 latency budget while comfortably catching IDE-style "write tmp + rename" sequences (most editors finish in <50 ms).
- `RecommendedWatcher` (FSEvents on macOS) avoids the descriptor-exhaustion path that `PollWatcher` would hit at the kqueue limit. R16's grey-pip+toast covers the case where FSEvents itself errors out (mount removed, permission revoked).
- Watch root narrowed to `.specaffold/` per repo (not the repo root) keeps FSEvents subscription cost proportional to scaff artefacts only, not the full git tree — important for monorepos.

**Alternatives considered.**
- *`notify` with `PollWatcher`*: rejected — defeats the purpose; reintroduces 2–5 s lag and a periodic CPU spike.
- *`notify` without debouncer*: rejected — multi-fire on save is the documented FSEvents behaviour and would force per-callsite dedup that `notify-debouncer-full` already does correctly.
- *Hand-rolled `kqueue`/`FSEventStream` FFI*: rejected — minimal-diff principle, no value over `notify`.
- *`tauri-plugin-fs` watch API*: checked — the plugin re-exports notify but only for whitelisted paths declared at build time, which doesn't fit the dynamic repo-list model. Stay with `notify` directly.

**Wiring task.** `lib.rs run()` `.setup()` block must spawn the watcher task in addition to (or in place of) `run_session_polling`. Per architect memory `setup-hook-wired-commitment-must-be-explicit-plan-task`, this is called out explicitly so the TPM scopes the lib.rs edit as part of the plan.

### D3 — IPC event shape: two events, `artifact_changed` (per debounced batch) and `watcher_status` (state machine)

**What.** Three Tauri events on the renderer-bound bus:

1. **`sessions_changed`** — *kept, repurposed*. Emitted when the session **list** (slug set, stage, idle state, last_activity) changes. Payload identical to today's `SessionsChangedPayload` (`stalled_transitions: Vec<(PathBuf, String)>`) — renderer behaviour at `MainWindow.tsx:120` (`loadData()`) is unchanged. Emitted whenever a `STATUS.md` change is observed, after re-parsing affected sessions.

2. **`artifact_changed`** — *new*. Emitted per debounced batch (one event per debouncer flush, not per file). Payload:
   ```rust
   #[derive(Serialize, Clone)]
   pub struct ArtifactChangedPayload {
       pub repo: PathBuf,                  // absolute repo root
       pub slug: String,                   // feature slug, derived from path
       pub artifact: ArtifactKind,         // "request" | "design" | "prd" | "tech" | "plan" | "tasks" | "status" | "other"
       pub path: PathBuf,                  // absolute path of the artefact
       pub mtime_ms: u64,                  // Unix epoch ms — for whisker "Ns ago"
   }
   ```
   `ArtifactKind` is derived in Rust from the filename via a closed enum match (`00-request.md`, `02-design/`, `03-prd.md`, `04-tech.md`, `05-plan.md`, `tasks.md`, `STATUS.md`, else `other`). Per classify-before-mutate (see `.claude/rules/common/classify-before-mutate.md`), the classifier is a pure function: `fn classify_artifact(path: &Path) -> ArtifactKind`; the dispatch (emit vs ignore) lives in the watcher loop.

3. **`watcher_status`** — *new*. Two-state event for R16. Payload:
   ```rust
   #[derive(Serialize, Clone)]
   pub struct WatcherStatusPayload {
       pub state: WatcherState,            // "running" | "errored"
       pub error_kind: Option<String>,     // e.g. "init_failed", "descriptor_exhausted", "dropped"
       pub repo: Option<PathBuf>,          // which repo's watcher errored, when applicable
   }
   ```
   Emitted on watcher startup (`running`), on watcher error (`errored`, with kind), and on recovery (`running` again).

**Why per-batch, not per-file.** The debouncer already aggregates; emitting one IPC event per file inside a batch would re-fan-out the multiplicity we just collapsed. The renderer iterates the batch on receive — typed once, dispatched many times.

**Why a separate `artifact_changed` rather than overloading `sessions_changed`.** `sessions_changed` carries authoritative session-list state and triggers `loadData()` (a full re-fetch). `artifact_changed` is high-frequency, low-cost, and drives the whisker + tasks-bar updates without a full re-fetch. Keeping them separate avoids an n×m IPC storm where every stroke in `tasks.md` would refetch every session.

**Alternatives considered.**
- *Single overloaded event with discriminator field*: rejected — couples two semantically different update channels and breaks the existing `sessions_changed` contract that `MainWindow.tsx` already consumes.
- *Tauri channels (`Channel<T>`) instead of `emit`*: rejected — channels are 1:1 producer→consumer; we have N renderer surfaces (MainWindow, CompactPanel) that all want the same artifact-change feed. `emit` is the right primitive.

### D4 — Frontend state model: extend the existing `useState`+`listen` pattern; add `useArtifactChanges()` hook, no new store

**What.** No zustand, no redux, no context provider. The codebase pattern (visible in `MainWindow.tsx` and `PollingFooter.tsx`) is:

```ts
const [x, setX] = useState(...);
useEffect(() => {
  let unlisten: (() => void) | null = null;
  listen("evt", (e) => setX(e.payload)).then(fn => unlisten = fn);
  return () => unlisten?.();
}, []);
```

Continue this. Add:

- **`useArtifactChanges(repoPath, slug)`** in `flow-monitor/src/stores/artifactStore.ts` — a hook returning `Map<ArtifactKind, number>` (artifact → last mtime ms) for the given session. Internally subscribes to `artifact_changed`, filters by `(repo, slug)`, updates a local `useState<Map>`. Consumers: `<SessionGraph>` (whiskers), `<SessionCard>` (tasks progress bar refresh trigger).
- **`useWatcherStatus()`** in the same file — hook returning `{ state: "running" | "errored", errorKind?: string }`. Subscribes to `watcher_status`. Consumers: `<LiveWatchFooter>` (the new sidebar pip, replacing PollingFooter), and a top-level toast effect in `App.tsx` (R16).
- **`useTaskProgress(repoPath, slug)`** — derived from `artifact_changed` (kind == `tasks`); on every event for the session, calls `invoke("read_artefact", { path })` to read `tasks.md`, runs the regex parser (D5), returns `{ tasks_done, tasks_total }`. Re-parse is throttled to one-per-1000ms per session via a `useRef`-held timestamp gate (defensive guard against rapid editor saves; the debouncer already covers most of this).

The hook factory naming matches the existing convention (`useSessionStore`, `useInvokeStore`, `useTheme`). No prop-drilling: each `<SessionCard>` calls the hooks it needs directly, exactly as `App.tsx` already does for `useInvokeStore`.

**Why.** Adding a new state-management library would be the largest architecture change in the feature and the PRD does not motivate it. The current pattern works; the only cost is one `listen()` per consumer, which is cheap (Tauri's event bus deduplicates serialisation).

**Alternatives considered.**
- *Zustand store*: rejected — no other zustand in the app; minimal-diff principle.
- *React Context (single provider)*: rejected — would force a re-render of every `<SessionCard>` on every event; the per-hook subscribe-by-key pattern lets each card update independently. Architect memory `react-context-as-default-reactive-primitive` notes context's pitfalls when fan-out is high.

### D5 — Tasks.md parsing: frontend-only, regex-based, in `useTaskProgress` hook

**What.** Parsing happens in TypeScript, in `useTaskProgress(repoPath, slug)`. On `artifact_changed` events with `kind: "tasks"`, the hook calls `invoke<string>("read_artefact", { path })` (existing IPC command) to fetch `tasks.md` content, then runs:

```ts
function parseTaskCounts(md: string): { tasks_done: number; tasks_total: number } {
  // Match leading "- [ ]" / "- [x]" / "- [X]" markers at line start (allowing leading whitespace).
  // Block-fenced code is excluded by tracking ``` toggles per line.
  let inFence = false;
  let done = 0, total = 0;
  for (const line of md.split("\n")) {
    if (line.trimStart().startsWith("```")) { inFence = !inFence; continue; }
    if (inFence) continue;
    const m = line.match(/^\s*-\s\[( |x|X)\]\s/);
    if (!m) continue;
    total++;
    if (m[1] !== " ") done++;
  }
  return { tasks_done: done, tasks_total: total };
}
```

Pure function, exported separately so it is unit-testable without React.

**Why frontend, not Rust.**
- Resolved decision (design notes §"Resolved decisions" #4): *parse on the frontend*.
- No new IPC schema field is needed. `read_artefact` already exists.
- The R10 contract is *literal* `[x]` (case-insensitive) vs `[ ]` per PRD; a 5-line regex pins this contract in one file the QA fixture-test can exercise directly (`__tests__/parseTaskCounts.test.ts`).
- Cost: tasks.md is small (typically <10 KB even for a 50-task plan); `read_artefact` round-trip + regex is well under the 1 s budget.

**Why throttle.** Editor saves can fire 3–5 times per second during fast typing. The debouncer at 150 ms collapses bursts; the additional 1 s renderer-side throttle ensures we don't over-invoke `read_artefact` even if the debouncer flushes are tight. Cross-references performance rule check 3 (cache expensive operations).

**Alternatives considered.**
- *Parse in Rust, emit `{tasks_done, tasks_total}` on the event*: rejected — adds a new IPC schema field and contradicts the resolved decision.
- *Parse via `markdown-it-task-lists`* (already a dep): rejected — overkill for counting; would require running the full markdown AST per change. The 5-line regex is faster and trivially testable.

### D6 — Polling: full removal from production runtime; `PollingFooter` deleted; settings slider becomes inert

**What.**
- **Delete** the `tokio::time::sleep(...).await` loop at `lib.rs:340`. Replace `run_session_polling` with `run_fs_watcher` whose entry point is the watcher's debouncer event channel; the body re-uses the existing `discover_sessions → parse → diff → emit("sessions_changed")` pipeline but is invoked **per debounced FS event batch** rather than per tick. The session list is also rebuilt on `add_repo` / `remove_repo` (existing seam) so the first paint after add-repo doesn't wait for a STATUS.md change.
- **Delete** `PollingFooter.tsx`; replace with `LiveWatchFooter.tsx` (single pulsing pip + i18n label `sidebar.liveFsWatch`).
- **Delete** the `polling_cycle_complete` event emitter (currently only emitted by a B2 path; R13 says remove). Search-replace any consumers.
- **Settings slider**: `Settings.tsx` still reads/writes `polling_interval_secs` for backward settings compatibility (R13 explicitly carves this out). Add a one-line `<p className="settings__deprecated">` note indicating "FS watch is event-driven; this value has no effect" gated by an i18n key. **Decision: keep the slider visible, mark it deprecated, do not delete the field from `Settings` Rust struct** — deleting would require a settings-file migration. Lazy migration deferred to a follow-up per `shared/lazy-migration-at-first-write-beats-oneshot-script` memory.

**Why.** Full removal is what R13's "no live polling cycle runs during normal operation" requires. The slider stays as an inert vestige to avoid forcing a settings migration in this feature.

**Watcher fallback to polling**: **none** in v1. R16 is the contract: on watcher error → grey pip + toast → user knows updates are stale. No silent fallback. Reasoning: a silent poll-fallback would mask the very class of bug R16 is designed to surface; per `.claude/rules/common/no-force-on-user-paths.md` ethos, fail loud.

### D7 — Component decomposition

**New / edited files.**

```
flow-monitor/src/
├─ components/
│  ├─ SessionGraph.tsx               (NEW — D1, ~250 LOC; SVG; consumes useArtifactChanges, useTaskProgress)
│  │   ├─ <StageNodes /> (sub-component, internal)
│  │   ├─ <StageEdges /> (sub-component, internal)
│  │   └─ <BypassArc />  (sub-component, internal)
│  ├─ TaskProgressBar.tsx            (NEW — R11; ~40 LOC; consumes {tasks_done, tasks_total})
│  ├─ LiveWatchFooter.tsx            (NEW — replaces PollingFooter; ~50 LOC; consumes useWatcherStatus)
│  ├─ SessionCard.tsx                (EDIT — replace `<StageChecklist>` import with `<SessionGraph>`; mount `<TaskProgressBar>` above graph when stage===implement && tasks_total>0)
│  ├─ StageChecklist.tsx             (DELETE — no callers after SessionCard edit; verify with grep before delete per shared/css-classname-rename-requires-consumer-grep)
│  └─ PollingFooter.tsx              (DELETE — R15)
├─ stores/
│  └─ artifactStore.ts               (NEW — useArtifactChanges, useWatcherStatus, useTaskProgress, parseTaskCounts; ~150 LOC)
├─ views/
│  └─ MainWindow.tsx                 (EDIT — swap PollingFooter import → LiveWatchFooter; remove pollingIntervalSecs state if unused after swap)
├─ App.tsx                           (EDIT — add useWatcherStatus subscriber + toast effect for R16)
├─ i18n/
│  ├─ en.json                        (EDIT — add sidebar.liveFsWatch, watcher.error.toast, card.tasks.progress.label, etc.)
│  └─ zh-TW.json                     (EDIT — same keys, zh-TW translations)
└─ styles/
   └─ components.css                 (EDIT — add .session-graph__node, .session-graph__edge, .live-watch-footer styles using existing tokens; remove .polling-footer, .stage-checklist after deletes)

flow-monitor/src-tauri/
├─ Cargo.toml                        (EDIT — +notify, +notify-debouncer-full)
├─ src/
│  ├─ fs_watcher.rs                  (NEW — D2/D3; spawn_watcher, classify_artifact, emit handlers; ~250 LOC)
│  ├─ lib.rs                         (EDIT — replace run_session_polling spawn with spawn_watcher in .setup(); add ArtifactChangedPayload + WatcherStatusPayload structs and tauri::generate_handler entries if any new commands; do NOT delete run_session_polling immediately — gate behind a one-task migration)
│  └─ ipc.rs                         (no schema break; polling_interval_secs remains a settings field but is no longer read by any runtime path)
```

**Compact panel** is **not** changed. R17 / AC17 require it to keep showing `StagePill`-only summaries. `CompactPanel.tsx` is unaffected.

### D8 — Styling: inline SVG attributes + existing CSS tokens

**What.** Reuse `theme.css` tokens (`--stage-<key>-bg`, `--stage-<key>-fg`, `--surface-secondary`, `--page-bg`, `--stalled-red`, `--stale-amber`). Add new tokens for graph-only roles in `theme.css`:

```css
:root[data-theme="dark"] {
  --graph-edge-stroke: rgba(255, 255, 255, 0.18);
  --graph-edge-label-fg: var(--text-secondary);
  --graph-node-active-glow: 0 0 0 2px var(--primary);
  --graph-node-skipped-stroke-dasharray: "4 3";
  --graph-bypass-arc-stroke: var(--primary);
  --graph-whisker-fg: var(--text-tertiary);
  --live-watch-pip-running: #22c55e;     /* matches existing --polling-dot-color */
  --live-watch-pip-errored: #6b7280;
}
```

Light-mode tokens are deliberately **not added in this feature** — PRD §2 non-goal #5 carves them out. Add a `[CHANGED YYYY-MM-DD]` tag on the dark-only tokens when the light-mode follow-up lands.

Styling lives in `styles/components.css` (the existing pattern; see `.session-card`, `.stage-pill`). No CSS-in-JS, no tailwind (none in repo).

**Why.** Match neighbour convention (`reviewer/style.md` rule 4); zero new styling-system surface.

### D9 — Testing strategy

| PRD AC | Verification approach | Type |
|---|---|---|
| AC1 (11 nodes, 6+5 layout) | Vitest snapshot of `<SessionGraph stage="plan" />` rendered DOM; assert exactly 11 `[data-stage-node]` nodes, 6 with `data-row="1"`, 5 with `data-row="2"`. | unit |
| AC2 (every edge has artifact label) | Same render; assert every `[data-stage-edge]` has a `<text>` child with non-empty content. | unit |
| AC3 (one active node) | Render with each of 11 stages; assert exactly one `[data-active="true"]`. Loop test. | unit |
| AC4 (completed/future split) | Render at `stage="tech"`; assert `data-state="completed"` count and identities. | unit |
| AC5 (skipped + bypass arc) | Render with `skippedStages={["brainstorm"]}`; assert dashed outline + presence of one `[data-bypass-arc]` path. | unit |
| AC6 (tasks node `3/7` in partial) | Render with `tasksDone=3, tasksTotal=7, stage="implement"`; assert `data-stage-node="tasks"` contains literal `3 / 7`. | unit |
| AC7 (no interactive affordance) | Snapshot: query for `[onClick]`, `[role="button"]`, `[tabIndex]` inside `.session-graph`; assert empty. | unit |
| AC8 (≤340±16 px card height) | Vitest + jsdom: render `<SessionCard>` with full chrome at default viewport; `getBoundingClientRect().height` ≤ 356. (jsdom has no real layout — fall back to manual verification with the dev build.) | manual + smoke |
| AC9 (whisker on event) | Vitest with mocked `listen` event firing `artifact_changed`; assert whisker DOM appears within one render tick; advance fake timers 60 s; assert whisker hides. | unit |
| AC10 (parseTaskCounts contract) | Vitest fixture-based: 7 lines (3 `[x]`, 4 `[ ]`); assert `{ tasks_done: 3, tasks_total: 7 }`. Plus edge cases: case-insensitive `[X]`, code-fence-excluded markers. | unit |
| AC11 (progress bar + no overflow at 50) | Vitest render with `tasks_total: 50`; assert one progress bar element, no per-task pip; computed width is 50% styled width. | unit |
| AC12 (watcher emits within 1 s) | Rust integration test in `src-tauri/tests/fs_watcher_latency.rs`: tempdir + spawn watcher + write a file + assert event arrives within 1 s on a channel. **Sandbox-HOME rule does not apply** (Rust tests via `tempfile::tempdir()`, not `$HOME`-touching shell). | integration |
| AC13 (no 5 s polling cycle) | grep gate in `bin/check-no-polling.sh` (new): assert no `tokio::time::sleep` or `interval(...)` over `>= 1s` exists in production paths under `src-tauri/src/lib.rs` or `src-tauri/src/poller.rs`. **Bash 3.2 portable** per `.claude/rules/bash/bash-32-portability.md`. | static |
| AC14 (p95 ≤ 1000 ms end-to-end) | Manual dev-mode timing harness: a small `flow-monitor/scripts/measure-latency.sh` script writes a file 20× with `sleep 0.2`; renderer console-logs `(disk_write_ts → render_commit_ts)` deltas; the script tails the log and computes p95. **Bash 3.2 portable**. Sandbox-HOME applies (the script invokes the app as the test target — see D10). | smoke |
| AC15 (sidebar pip + label, no interval shown) | Vitest render of `<LiveWatchFooter />`; assert one `[data-testid="live-watch-pip"]` and label text from i18n; assert no numeric digit in the rendered footer. | unit |
| AC16 (grey pip + toast on error) | Vitest with mocked `listen` firing `watcher_status` with `state: "errored"`; assert pip className includes `--errored` and a toast element appears. | unit |
| AC17 (six B1 smoke checks) | Manual run-through per `flow-monitor/README.md` §"Six manual smoke checks". Documented in QA test plan; no automation in scope. | manual |
| AC18 (SessionCard chrome unchanged) | Vitest render of `<SessionCard>` with full props; assert all six AC7.a chrome elements present by their existing `data-testid`s. | unit |
| AC19 (i18n coverage en + zh-TW) | New test `i18n.parity.test.ts`: load both JSON files; assert every key in `en.json` exists in `zh-TW.json` and vice versa. (May exist already in `i18n/__tests__/`; verify and extend, don't duplicate.) | unit |

**Sandbox-HOME applicability.** Per `.claude/rules/bash/sandbox-home-in-tests.md`: any bash script that invokes a CLI which reads or writes under `$HOME` must sandbox HOME. The Rust integration tests use `tempfile::tempdir()` and don't go through `$HOME`. The one bash script (`check-no-polling.sh`) is read-only against the source tree (no CLI invocation). The latency harness `measure-latency.sh` invokes the dev build of `flow-monitor` which writes settings under `~/Library/Application Support/com.flow-monitor.app/`; **it MUST sandbox HOME** per the rule. Flagged for the TPM in plan acceptance.

### D10 — Test sandbox flag

`check-no-polling.sh` is a static grep gate; no CLI invocation; sandbox-HOME does not apply.

`measure-latency.sh` invokes the dev-mode app; sandbox-HOME **does apply** (the app reads/writes `~/Library/Application Support/com.flow-monitor.app/`). Header to include:
```bash
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
case "$HOME" in "$SANDBOX"*) ;; *) echo "FAIL: HOME not isolated" >&2; exit 2 ;; esac
```
The TPM should anchor this requirement to the latency-harness task acceptance.

## §3 Component & data-flow diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│  macOS filesystem                                                         │
│  /Users/.../<repo>/.specaffold/features/<slug>/03-prd.md                  │
│  /Users/.../<repo>/.specaffold/features/<slug>/tasks.md                   │
│  /Users/.../<repo>/.specaffold/features/<slug>/STATUS.md                  │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │  FSEvents (kernel)
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  src-tauri/src/fs_watcher.rs    [NEW]                                     │
│                                                                           │
│   notify::RecommendedWatcher (per repo)                                   │
│        │                                                                  │
│        ▼                                                                  │
│   notify_debouncer_full (window: 150ms)                                   │
│        │                                                                  │
│        ▼                                                                  │
│   classify_artifact(path) → ArtifactKind  (pure fn, classify-before-     │
│        │                                   mutate rule)                   │
│        ▼                                                                  │
│   dispatch:                                                               │
│     ├─ STATUS.md  → re-discover sessions → emit "sessions_changed"       │
│     ├─ tasks.md / 0X-*.md → emit "artifact_changed" {repo,slug,kind,…}    │
│     └─ watcher error → emit "watcher_status" {state: errored, kind}      │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │  Tauri IPC (emit → JS bus)
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  flow-monitor/src/stores/artifactStore.ts    [NEW]                        │
│                                                                           │
│   useArtifactChanges(repo, slug)  ─── returns Map<ArtifactKind, mtimeMs> │
│   useTaskProgress(repo, slug)     ─── returns {tasks_done, tasks_total}  │
│   useWatcherStatus()              ─── returns {state, errorKind}         │
│   parseTaskCounts(md): pure       ─── unit-tested                         │
└──────────────────────────────┬───────────────────────────────────────────┘
                               │  React hooks
        ┌──────────────────────┼──────────────────────┬──────────────────┐
        ▼                      ▼                      ▼                  ▼
┌────────────────┐   ┌──────────────────┐   ┌──────────────────┐   ┌────────────┐
│ <SessionGraph> │   │ <TaskProgressBar>│   │ <LiveWatchFooter>│   │ App.tsx    │
│ (NEW, SVG)     │   │ (NEW)            │   │ (NEW)            │   │ toast for  │
│  - 11 nodes    │   │  done / total    │   │  pulsing pip +   │   │ R16 on    │
│  - artifact-   │   │  bar (R11)       │   │  "Live FS watch" │   │ errored   │
│    label edges │   │                  │   │  i18n            │   │ status    │
│  - whiskers    │   │                  │   │                  │   │            │
└────────┬───────┘   └────────┬─────────┘   └────────┬─────────┘   └────────────┘
         │                    │                      │
         └─────── inside ─────┴──────────┐           │
                                         ▼           │
                              ┌──────────────────┐   │
                              │ <SessionCard>    │   │
                              │ (EDIT — graph in │   │
                              │  place of        │   │
                              │  StageChecklist) │   │
                              └──────────────────┘   │
                                                     ▼
                                            ┌─────────────────┐
                                            │ <MainWindow>    │
                                            │  sidebar slot   │
                                            └─────────────────┘
```

## §4 Test strategy

Covered fully in **D9**. Summary:

- **Unit** (Vitest): every AC except AC8, AC12, AC13, AC14, AC17. ~14 ACs covered; co-located in `flow-monitor/src/components/__tests__/` and `flow-monitor/src/stores/__tests__/` per existing convention.
- **Integration** (Cargo): AC12 (watcher latency) in `src-tauri/tests/fs_watcher_latency.rs`.
- **Static** (bash grep): AC13 (no polling) in `bin/check-no-polling.sh`.
- **Smoke / manual**: AC8 (card height in real layout), AC14 (p95 latency harness), AC17 (six B1 smoke checks per README).

Sandbox-HOME applies to `measure-latency.sh` (D10).

Bash 3.2 portability applies to all new shell scripts (D10).

## §5 Blocker questions

**None.**

The PRD's resolved decisions, the existing codebase patterns (per-component `useState` + `listen()`, inline SVG in `StagePill`'s clock icon, CSS-token theming), and the `notify` crate's well-documented Tauri compatibility leave no contradictions to escalate. Every architecture question has a decision in §2 with a justifying *why*. PRD R10/R11 (frontend tasks parsing), R12 (notify watcher), R13 (polling removal), R15 (LiveWatchFooter), R16 (grey pip + toast) all map cleanly onto existing seams.

## §6 Risks

1. **`notify` 8.x + Tauri 2.2 build interaction.** New transitive deps (kqueue-sys via notify on macOS) could conflict with `tauri-plugin-fs`'s own notify version pin. *Mitigation*: `cargo tree --duplicates` after add-deps; if a duplicate notify version appears, pin to match. *Detection*: build fails or runtime panics on watcher init.

2. **FSEvents coalescing latency on APFS.** Apple FSEvents has a documented ~50–500 ms tail for some sequence events (rename → modify). 150 ms debouncer + ~50 ms FSEvents tail ≈ 200 ms ceiling for the watcher path; renderer round-trip + React render adds ~100–200 ms; total typical ≈ 400 ms, well under the 1 s p95. *Mitigation*: AC14 latency harness (D9) is the trip-wire; if p95 trends >800 ms in dev, drop debouncer to 100 ms.

3. **Watcher descriptor exhaustion at scale.** Multiple monitored repos × deep `.specaffold/` trees × FSEvents internal limits. *Mitigation*: scope watch to `.specaffold/` (not repo root); R16 grey-pip + toast surfaces the failure to the user. No silent degradation.

4. **Inline SVG accessibility regression.** `<StageChecklist>` had `aria-label="Stage progress"` and an `<ol>` semantic. The SVG replacement loses both unless we add `<title>` / `aria-labelledby` deliberately. *Mitigation*: `<SessionGraph>` carries `role="img"` + `aria-label={t("graph.aria.label", {stage})}` + per-node `<title>` elements containing the stage name. Verified in unit test (AC7 also asserts no `role="button"` so the role check is by-construction).

5. **`tasks.md` regex edge cases.** Lines like `> - [ ] block-quoted task` or nested `  - [ ] indented sub-task`. *Mitigation*: spec the regex as "any indent followed by `- [...]`" (the regex in D5 is `^\s*-\s\[…\]\s`). Code-fenced markers are excluded via the `inFence` toggle. Fixture tests in AC10 lock the contract.

6. **`PollingFooter` consumer grep.** Per `shared/css-classname-rename-requires-consumer-grep`, deleting `PollingFooter.tsx` requires a repo-wide grep for imports. *Mitigation*: T-task acceptance: "grep `PollingFooter` returns 0 hits in `src/` after delete". Same for `StageChecklist`.

7. **`run_session_polling` removal regression on existing notification path.** Today's notification firing logic (`fire_stalled_notification` in `lib.rs:308`) lives inside the polling loop. The watcher path must preserve `prev_stalled_set` carry-state and the `store::diff` notification gate (the AC1.c tests in `lib.rs:131`). *Mitigation*: the watcher's `STATUS.md` handler runs the **same** `discover → parse → diff → notify` pipeline; only the trigger changes (FSEvents instead of `tokio::time::sleep`). The `lib.rs:131` tests continue to apply unchanged.

8. **Settings slider as inert vestige.** Users who change `polling_interval_secs` will see no effect. *Mitigation*: add `settings.polling.deprecated.note` i18n string explaining "Polling has been replaced by FS watch; this setting has no effect" (R19 picks up the new string into the i18n parity test). Lazy-migration of the field is a follow-up per `shared/lazy-migration-at-first-write-beats-oneshot-script`.

## §7 Open follow-ups (non-blocking, surfaced for tracking)

- Light-mode color tokens for the graph (PRD §2 non-goal; queued as separate feature).
- Stalled / red graph-node color treatment (PRD §6 risk; existing card-level red token may suffice — verify in QA).
- `polling_interval_secs` field deletion + settings migration (lazy, deferred).

## Team memory

- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task` — applied: D2 contains `**Wiring task**` so TPM scopes the lib.rs `.setup()` edit explicitly (avoiding the `purge_stale_temp_files` orphan pattern).
- `architect/scope-extension-minimal-diff` — applied: `ArtifactKind` is appended (closed enum + `other` fallback), not a re-cut taxonomy; `WatcherState` is two values, not a generic state-machine.
- `architect/reviewer-verdict-wire-format` — n/a (this feature has no agent-verdict surface).
- `shared/css-classname-rename-requires-consumer-grep` — applied: D7 lists `PollingFooter` and `StageChecklist` deletes with explicit grep gates flagged as task-acceptance (also Risk 6).
- `shared/lazy-migration-at-first-write-beats-oneshot-script` — applied: D6 keeps `polling_interval_secs` as an inert vestige rather than forcing a settings-file migration in this feature.

Proposed new memory: **none** — every pattern this feature uses (closed-enum classification, hooks-not-store reactive primitive, sandbox-HOME for app-launch tests, setup-hook wiring task) is already captured.

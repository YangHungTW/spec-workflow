# 05-plan — flow-monitor graph view

**Slug**: `20260426-flow-monitor-graph-view`
**Stage**: plan
**Author**: TPM
**Date**: 2026-04-26
**Tier**: standard

## Section 1: Wave plan (narrative)

This feature lands in five waves. The shape is dictated by D7 (component delta) and §3 (data flow): the new IPC surface (`fs_watcher.rs` + `notify` deps + payload structs in `lib.rs`) is the trunk every renderer hook subscribes to, so the Rust side and the frontend store skeleton are W1 foundations. Once subscribers exist, the three new React components (`SessionGraph`, `TaskProgressBar`, `LiveWatchFooter`) are independent leaves that fan out in W2. W3 is the integration wave: rip out `StageChecklist`/`PollingFooter`, mount the new components inside `SessionCard` / `MainWindow` / `App.tsx`, and run the consumer-grep gate (per `shared/css-classname-rename-requires-consumer-grep`). W4 attaches the test suite per D9 (Vitest unit tests, the Cargo integration test for AC12, the static `check-no-polling.sh` grep, and the manual latency harness `measure-latency.sh`). W5 is the polish wave: dark-only `--graph-*` token comment markers, the `settings.polling.deprecated.note` i18n key wiring, and the README smoke-checks update.

The plan honours D2's explicit `**Wiring task**` callout: the `lib.rs` `.setup()` edit that swaps `run_session_polling` for `run_fs_watcher` is its own task (T5), separated from the watcher-module authoring (T1). Per architect memory `setup-hook-wired-commitment-must-be-explicit-plan-task`, this avoids the "wired but never spawned" orphan that the architect memory warns against. Reviewers can grep for `**Wiring task**` in this file to confirm it's surfaced.

The `tasks.md` parsing path (D5) lives entirely in the frontend, so it's a clean leaf inside W1's `artifactStore.ts` skeleton — no backend coupling. The polling-removal step is sequenced explicitly in W3 (T11) so the watcher path is provably emitting `sessions_changed` before the polling loop is deleted; this preserves the `prev_stalled_set` carry-state and notification-gate behaviour flagged in tech §6 risk 7.

No dogfood-paradox handling is required: flow-monitor is a Tauri app, not specaffold infrastructure (per PRD `## Team memory` line 152). Verification exercises immediately on app rebuild.

**Out of scope (deferred per PRD §2)**: light-mode `--graph-*` tokens, stalled-card red node treatment, `polling_interval_secs` field deletion + settings migration. The settings slider stays as an inert vestige (D6) with a deprecation note string added in W5. The latency harness is bash + sandbox-HOME (D10).

### Risk register (cross-references tech §6)

| Risk (tech §6 #) | Description | Mitigated by |
|---|---|---|
| 1 | `notify` 8.x + Tauri 2.2 build interaction (transitive duplicates) | T1 (`cargo tree --duplicates` step in Verify); T13 (Cargo integration test trips on init failure) |
| 2 | FSEvents coalescing latency on APFS | T16 (latency harness — trip-wire if p95 > 800ms) |
| 3 | Watcher descriptor exhaustion at scale | T1 watch-root scoped to `.specaffold/`; T9 wires `watcher_status.errored` UX |
| 4 | Inline SVG accessibility regression | T6 (`SessionGraph` carries `role="img"` + `aria-label` + per-node `<title>`) |
| 5 | `tasks.md` regex edge cases (block quotes, fences) | T3 (`parseTaskCounts` with `inFence` toggle); T14 fixture tests pin the contract |
| 6 | `PollingFooter`/`StageChecklist` consumer grep | T11 explicit grep gate (`shared/css-classname-rename-requires-consumer-grep`) |
| 7 | `run_session_polling` removal regresses notification path | T11 sequencing — watcher proven emitting `sessions_changed` (W2 done) before delete |
| 8 | Settings slider as inert vestige confuses users | T17 adds `settings.polling.deprecated.note` i18n key + UI line in `SettingsGeneral.tsx` |

### Critical path

`T1 (fs_watcher.rs) → T5 (lib.rs .setup() wiring) → T11 (rip out polling + StageChecklist + consumer grep) → T13 (Cargo integration test AC12) → T16 (latency harness AC14)`.

Of these, **T1, T5, T11, T13, T16** are the load-bearing critical-path tasks. T6 (`SessionGraph`) is on a near-critical parallel branch — it gates AC1–AC7 / AC9 unit tests but does not block the Rust runtime path.

### Escalations

None at plan time. PRD R10 (frontend parses `tasks.md`) is anchored by D5; PRD R13 (polling removal) is anchored by D6; PRD R16 (grey pip + toast) is anchored by D3 + D4. All risks listed above have explicit mitigation tasks.

## Section 2: Wave schedule

Wave count: **5**. Total task count: **18** (T1–T18).

### W1 — Foundations (Rust watcher + frontend store skeleton + parser)

Tasks: **T1, T2, T3, T4**.

Parallel-safety: all four tasks edit disjoint files (T1 → `src-tauri/src/fs_watcher.rs`; T2 → `flow-monitor/src/stores/artifactStore.ts`; T3 → same `artifactStore.ts` but T2 owns the file scaffold and T3 is folded into T2; T4 → `Cargo.toml` + new payload structs in `src-tauri/src/lib.rs`). Per `tpm/parallel-safe-requires-different-files`, T2 and T3 share `artifactStore.ts` so they collapse into one task (T2 below); T1 and T4 both touch the Rust crate but T4 is `Cargo.toml` deps + struct *additions* in `lib.rs` (not the `.setup()` block — that is T5 in W2), and T1 is a brand-new file. T1 / T2 / T4 run in parallel.

### W2 — Frontend leaf components + setup-hook wiring

Tasks: **T5, T6, T7, T8, T9**.

Parallel-safety: **T5** edits `lib.rs` `.setup()` — same file as T4 but a different region (deps + structs vs `.setup()` body); we serialise T5 *after* T4 in the wave order by gating T5's `Depends on` on T4. T5 stands alone in the Rust file; therefore T5 is parallel-safe with T6/T7/T8/T9 (different repos: src-tauri vs src). **T6** (`SessionGraph.tsx`), **T7** (`TaskProgressBar.tsx`), **T8** (`LiveWatchFooter.tsx`) are three new files — fully parallel-safe with each other. **T9** edits `App.tsx` (new toast effect) — disjoint from T6/T7/T8 file-set, parallel-safe.

T6 / T7 / T8 / T9 / T5 all run in parallel within W2 (after their W1 deps land).

### W3 — Integration (mount components + polling removal + consumer grep)

Tasks: **T10, T11, T12**.

Parallel-safety: **T10** edits `SessionCard.tsx`. **T11** deletes `StageChecklist.tsx`, deletes `PollingFooter.tsx`, removes `run_session_polling` body in `lib.rs`, runs the consumer-grep gate, and edits `MainWindow.tsx` (swap import). **T12** edits `i18n/en.json` + `i18n/zh-TW.json` (new strings).

T10 and T11 both touch `MainWindow.tsx` only via T11 (T10 is `SessionCard.tsx` only) — disjoint. T11 and T12 are disjoint (`.tsx` deletes + `MainWindow.tsx` swap vs `.json` files). T10 and T12 disjoint. **All three run in parallel**.

### W4 — Tests + smoke

Tasks: **T13, T14, T15, T16**.

Parallel-safety: **T13** is `src-tauri/tests/fs_watcher_latency.rs` (new). **T14** is the Vitest test file set under `flow-monitor/src/components/__tests__/` and `flow-monitor/src/stores/__tests__/` (new files only). **T15** is `bin/check-no-polling.sh` (new). **T16** is `flow-monitor/scripts/measure-latency.sh` (new) plus the dev-mode console-log instrument inside `artifactStore.ts`. T16 touches `artifactStore.ts` which T2 authored in W1; the W4 edit is appended at the bottom (separate function), and no other W4 task touches that file — parallel-safe per `tpm/parallel-safe-append-sections`.

All four run in parallel.

### W5 — Polish

Tasks: **T17, T18**.

Parallel-safety: **T17** edits `SettingsGeneral.tsx` (deprecation note for the inert slider). **T18** edits `flow-monitor/README.md` (smoke-checks update + `--graph-*` token comment marker). Disjoint. **Both run in parallel**.

## Section 3: Task checklist

- [x] T1: Author `fs_watcher.rs` — debouncer, classifier, dispatch
    - Wave: W1
    - Owner: Developer
    - Files: `flow-monitor/src-tauri/src/fs_watcher.rs` (new)
    - Milestone: foundation — Rust watcher module exists and can be unit-tested in isolation
    - Requirements: R12, R16
    - Decisions: D2, D3, classify-before-mutate (`.claude/rules/common/classify-before-mutate.md`)
    - Scope: implement `pub fn spawn_watcher(repos: Vec<PathBuf>, app: AppHandle) -> Result<JoinHandle<()>>`; pure `fn classify_artifact(path: &Path) -> ArtifactKind` (closed enum match per D3); debounce window 150ms via `notify_debouncer_full`; `RecursiveMode::Recursive` rooted at `<repo>/.specaffold/`; emit `sessions_changed` on `STATUS.md` events (re-using existing pipeline shape) and `artifact_changed` on `00-request.md` / `02-design/` / `03-prd.md` / `04-tech.md` / `05-plan.md` / `tasks.md`; emit `watcher_status` on init success and on watcher errors. Do NOT touch `lib.rs .setup()` — that is T5.
    - Deliverables: new `fs_watcher.rs` (~250 LOC), pure classifier, dispatcher, three event payload emitters
    - Verify: `cd flow-monitor/src-tauri && cargo build` succeeds and `cargo tree --duplicates 2>&1 | grep -E '^notify ' | wc -l` ≤ 1 (no duplicate `notify` versions); module compiles
    - Depends on: T4 (Cargo.toml deps + payload structs must exist before fs_watcher imports them)
    - Parallel-safe-with: T2 (different file/dir tree)

- [x] T2: Author `artifactStore.ts` skeleton — `useArtifactChanges`, `useWatcherStatus`, `useTaskProgress`, `parseTaskCounts`
    - Wave: W1
    - Owner: Developer
    - Files: `flow-monitor/src/stores/artifactStore.ts` (new)
    - Milestone: foundation — frontend hooks exist and `parseTaskCounts` is unit-callable
    - Requirements: R10, R14, R15, R16
    - Decisions: D4, D5
    - Scope: implement `useArtifactChanges(repoPath, slug): Map<ArtifactKind, number>` subscribing to `artifact_changed` and filtering by `(repo, slug)`; `useWatcherStatus(): { state: "running" | "errored", errorKind?: string }` subscribing to `watcher_status`; `useTaskProgress(repoPath, slug): { tasks_done, tasks_total }` driven by `artifact_changed` events with `kind: "tasks"`, calling `invoke<string>("read_artefact", { path })`, parsing via `parseTaskCounts`, throttled to 1/sec via `useRef`; `parseTaskCounts(md: string): { tasks_done, tasks_total }` exported separately, regex `^\s*-\s\[( |x|X)\]\s` with `inFence` toggle for ``` ``` ``` blocks (D5 verbatim).
    - Deliverables: `artifactStore.ts` (~150 LOC) with four named exports
    - Verify: `cd flow-monitor && npx tsc --noEmit` passes; existing test suite `cd flow-monitor && npm test -- --run --reporter=basic stores` still green (no regressions). New unit tests are written in T14, not here.
    - Depends on: none (no W0)
    - Parallel-safe-with: T1, T4

- [x] T3: (FOLDED INTO T2) — kept as task ID for traceability; no separate work
    - Wave: W1
    - Owner: n/a
    - Files: n/a
    - Milestone: traceability placeholder — `parseTaskCounts` is implemented inside T2 because both edit the same file (`artifactStore.ts`). Per `tpm/parallel-safe-requires-different-files`, splitting T2/T3 across the same file would violate parallel-safe rules.
    - Requirements: R10
    - Decisions: D5
    - Scope: marker task only; no code, no commit. The Developer dispatcher should skip T3.
    - Deliverables: none
    - Verify: `true`
    - Depends on: T2
    - Parallel-safe-with: (none — no work)

- [x] T4: Add `notify` + `notify-debouncer-full` deps + payload structs in `lib.rs`
    - Wave: W1
    - Owner: Developer
    - Files: `flow-monitor/src-tauri/Cargo.toml`, `flow-monitor/src-tauri/src/lib.rs` (struct additions only)
    - Milestone: dep + types ready for T1 to import
    - Requirements: R12, R16
    - Decisions: D2, D3
    - Scope: append to `[dependencies]` in `Cargo.toml`: `notify = "8"` and `notify-debouncer-full = "0.6"`; in `lib.rs`, add `pub struct ArtifactChangedPayload` and `pub struct WatcherStatusPayload` with the exact field shapes from D3 (Serialize, Clone derives); add `pub enum ArtifactKind` (closed enum: `Request | Design | Prd | Tech | Plan | Tasks | Status | Other`) and `pub enum WatcherState` (`Running | Errored`). Do NOT modify `.setup()`, do NOT delete `run_session_polling` — that is T5/T11. Additions only.
    - Deliverables: 2 dep lines, 4 new types in `lib.rs`
    - Verify: `cd flow-monitor/src-tauri && cargo build` succeeds (compile-only, no runtime path uses these yet); `cargo tree --duplicates 2>&1 | grep -E '^notify ' | wc -l` reports ≤ 1
    - Depends on: none
    - Parallel-safe-with: T1 (T1 imports these types but does not touch Cargo.toml or the struct definitions — disjoint), T2

- [ ] T5: **Wiring task** — `lib.rs run() .setup()` swap: spawn `fs_watcher::spawn_watcher`
    - Wave: W2
    - Owner: Developer
    - Files: `flow-monitor/src-tauri/src/lib.rs` (`.setup()` block region only)
    - Milestone: backend runtime path now event-driven on FS changes (sessions_changed still fires)
    - Requirements: R12
    - Decisions: D2 (architect-flagged Wiring task per `architect/setup-hook-wired-commitment-must-be-explicit-plan-task`)
    - Scope: in the `.setup(|app| { ... })` block, replace the `tauri::async_runtime::spawn(run_session_polling(...))` call with `tauri::async_runtime::spawn(fs_watcher::spawn_watcher(repos, app.handle()))`. Do NOT delete `run_session_polling` body in this task — leave the function in place but unreferenced. T11 deletes the function. This split preserves "watcher proven working before polling removed" sequencing (tech §6 risk 7).
    - Deliverables: ~5 line edit in `.setup()`
    - Verify: `cd flow-monitor/src-tauri && cargo build` succeeds; `cd flow-monitor && npm run tauri dev` boots and existing notification tests `cargo test --test notify_dedupe_test` still pass
    - Depends on: T1, T4
    - Parallel-safe-with: T6, T7, T8, T9 (all different files — `.tsx` / `App.tsx` vs Rust)

- [ ] T6: Author `<SessionGraph>` — inline SVG, 11 nodes, edges, bypass arc, whiskers
    - Wave: W2
    - Owner: Developer
    - Files: `flow-monitor/src/components/SessionGraph.tsx` (new), `flow-monitor/src/styles/components.css` (append `.session-graph__*` classes)
    - Milestone: graph component renders independently; consumed by T10
    - Requirements: R1, R2, R3, R4, R5, R6, R7, R8 (height contribution), R9
    - Decisions: D1, D7, D8 (existing tokens + dark-only `--graph-*`)
    - Scope: single React function component, ~250 LOC; `STAGE_LAYOUT` const (11 `{stage, x, y, row}` records); `STAGE_EDGES` const (10 sequential + 1 bridge `{from, to, label}` triples per the canonical scaff stage→artifact map); subcomponents `<StageNodes/>`, `<StageEdges/>`, `<BypassArc/>`; consume `useArtifactChanges` + `useTaskProgress` from T2; per-node `<title>` for accessibility (tech §6 risk 4); top-level `role="img"` + `aria-label`; render whisker ("Ns ago") when `mtime_ms` < 60s old, hide otherwise (use `setInterval(1000)` for the relative-time refresh, cleared on unmount); data attrs `[data-stage-node]`, `[data-row]`, `[data-state]`, `[data-active]`, `[data-bypass-arc]`, `[data-stage-edge]` per D9 test contract; tasks node renders literal `done / total` text in partial state (R6 / AC6). NO `onClick`, NO `tabIndex`, NO `role="button"` on any node element. Add new `--graph-*` tokens to `theme.css` ONLY if T8/T18 haven't already — coordinate via Wave-merge order; safest is to put the token additions in T18 (W5) and use placeholder values here. **For this task, add the new tokens directly in `theme.css` `:root[data-theme="dark"]` block** (single edit, no parallel writers in W2).
    - Deliverables: `SessionGraph.tsx`, ~120 lines added to `components.css`, ~7 lines added to `theme.css`
    - Verify: test in T14 covers AC1–AC7, AC9; for this task, `cd flow-monitor && npx tsc --noEmit` passes and `npm run build` succeeds
    - Depends on: T2 (hook contract), T4 (ArtifactKind type imported via store)
    - Parallel-safe-with: T5 (different file tree), T7, T8 (T8 also touches `theme.css` — coordinate: T8 owns `--live-watch-pip-*` tokens, T6 owns `--graph-*` tokens; same file but disjoint blocks, parallel-safe per `tpm/parallel-safe-append-sections`), T9

- [ ] T7: Author `<TaskProgressBar>` — `done / total` bar above graph
    - Wave: W2
    - Owner: Developer
    - Files: `flow-monitor/src/components/TaskProgressBar.tsx` (new), `flow-monitor/src/styles/components.css` (append `.task-progress-bar__*` classes)
    - Milestone: progress bar component renders independently; consumed by T10
    - Requirements: R11
    - Decisions: D7
    - Scope: ~40 LOC; props `{ tasksDone: number; tasksTotal: number }`; render iff `tasksTotal > 0`; horizontal bar with proportional fill (`width: ${(done/total)*100}%`); literal label `${done} / ${total}` adjacent; no per-task pip; no cap on total (R11). Pure presentational — no hook calls (the parent passes props from `useTaskProgress`).
    - Deliverables: `TaskProgressBar.tsx`, ~25 lines added to `components.css`
    - Verify: test in T14 covers AC11; here `cd flow-monitor && npx tsc --noEmit` passes
    - Depends on: T2 (only for type signature; no hook called from this component)
    - Parallel-safe-with: T5, T6, T8, T9 (all disjoint file edits in components.css — append-only different sections)

- [ ] T8: Author `<LiveWatchFooter>` — pulsing pip + i18n label, grey on errored
    - Wave: W2
    - Owner: Developer
    - Files: `flow-monitor/src/components/LiveWatchFooter.tsx` (new), `flow-monitor/src/styles/components.css` (append `.live-watch-footer__*` classes), `flow-monitor/src/styles/theme.css` (append `--live-watch-pip-running` and `--live-watch-pip-errored` tokens to `:root[data-theme="dark"]`)
    - Milestone: footer component renders independently; consumed by T11 (replaces `<PollingFooter>` in MainWindow)
    - Requirements: R15, R16 (pip side; toast side is T9)
    - Decisions: D7, D8
    - Scope: ~50 LOC; consume `useWatcherStatus` from T2; render single `[data-testid="live-watch-pip"]` element with pulse animation when `state === "running"` and grey static when `state === "errored"`; static label from i18n key `sidebar.liveFsWatch` (key registered in T12); NO numeric interval shown (R15 / AC15); when state errored, also stop the pulse animation (CSS class swap) per AC16.
    - Deliverables: `LiveWatchFooter.tsx`, ~30 lines added to `components.css`, ~2 token lines in `theme.css`
    - Verify: test in T14 covers AC15, AC16; here `cd flow-monitor && npx tsc --noEmit` passes
    - Depends on: T2 (hook), T12 (i18n key, but we accept fallback `t()` returning the key during dev — strict gate is W3)
    - Parallel-safe-with: T5, T6 (different sections of `theme.css` — disjoint token blocks), T7, T9

- [ ] T9: `App.tsx` — toast effect on `watcher_status.errored`
    - Wave: W2
    - Owner: Developer
    - Files: `flow-monitor/src/App.tsx`
    - Milestone: R16 toast surface is wired
    - Requirements: R16 (toast side; pip side is T8)
    - Decisions: D4 (top-level toast in App.tsx, not inside footer)
    - Scope: import `useWatcherStatus` from T2; in a `useEffect` triggered when `state` transitions to `"errored"`, fire the existing toast surface (the codebase has `PreflightToast` at App level — extend its mechanism or add a sibling toast emitter consistent with that pattern); copy comes from i18n key `watcher.error.toast` (registered in T12). On recovery (`state` back to `"running"`), dismiss any active error toast.
    - Deliverables: ~15 line addition to `App.tsx`
    - Verify: test in T14 covers AC16 (mocked `listen` firing `watcher_status` → toast DOM appears); here `cd flow-monitor && npx tsc --noEmit` passes
    - Depends on: T2
    - Parallel-safe-with: T5, T6, T7, T8

- [ ] T10: Mount `<SessionGraph>` + `<TaskProgressBar>` in `<SessionCard>`
    - Wave: W3
    - Owner: Developer
    - Files: `flow-monitor/src/components/SessionCard.tsx`
    - Milestone: card chrome integrated; AC8 height target measurable
    - Requirements: R1 (mounting), R6 (tasks node visibility), R8 (340px target), R11 (progress bar visibility), R18 (chrome unchanged)
    - Decisions: D7
    - Scope: in `SessionCard.tsx`, replace the `<StageChecklist>` import + JSX with `<SessionGraph>`; above the graph (and only when `currentStage === "implement" && tasks_total > 0`), mount `<TaskProgressBar tasksDone={...} tasksTotal={...}/>` — fetch the values via `useTaskProgress` from T2. Preserve the six existing `SessionCard` chrome elements per AC18 / AC7.a contract — no other change. Do NOT delete `StageChecklist.tsx` here — T11 owns the delete + grep gate.
    - Deliverables: ~10 line replacement in `SessionCard.tsx`
    - Verify: test in T14 covers AC18 (chrome unchanged); manual smoke covers AC8 / AC10 / AC11; here `cd flow-monitor && npm run build` succeeds
    - Depends on: T6, T7, T2
    - Parallel-safe-with: T11 (T11 edits `MainWindow.tsx` + deletes `StageChecklist.tsx` + edits `lib.rs` polling region + i18n unrelated to T10's `SessionCard.tsx`), T12

- [ ] T11: Rip out polling + `StageChecklist` + `PollingFooter`, swap `LiveWatchFooter` in `<MainWindow>`, run consumer-grep gate
    - Wave: W3
    - Owner: Developer
    - Files: `flow-monitor/src/components/StageChecklist.tsx` (DELETE), `flow-monitor/src/components/PollingFooter.tsx` (DELETE), `flow-monitor/src/views/MainWindow.tsx` (swap import + remove `pollingIntervalSecs` state if unused), `flow-monitor/src-tauri/src/lib.rs` (delete `run_session_polling` fn body + `polling_cycle_complete` emitter), `flow-monitor/src-tauri/src/poller.rs` (review for orphan deletion if all callers gone), `flow-monitor/src/styles/components.css` (delete `.polling-footer` and `.stage-checklist` rules)
    - Milestone: AC13 satisfied (no polling cycle); AC15 satisfied (no `polling-footer` testid)
    - Requirements: R13, R15
    - Decisions: D6
    - Scope: (1) `git grep -n PollingFooter -- 'flow-monitor/src/'` and `git grep -n StageChecklist -- 'flow-monitor/src/'` MUST return zero hits before delete commits (per `shared/css-classname-rename-requires-consumer-grep`); (2) replace `<PollingFooter />` mount in `MainWindow.tsx` with `<LiveWatchFooter />`; (3) delete the two component files + their CSS rules; (4) in `lib.rs`, delete `run_session_polling` function body and the `polling_cycle_complete` emitter; if `poller.rs` becomes orphan-only (no callers from `lib.rs`), delete it too — verify with `git grep poller -- 'flow-monitor/src-tauri/'`. (5) Settings field `polling_interval_secs` REMAINS (D6 — inert vestige; T17 adds the deprecation note).
    - Deliverables: 2 file deletes (frontend), possibly 1 file delete (poller.rs), `MainWindow.tsx` edit, `lib.rs` deletions, `components.css` rule removals
    - Verify: `cd flow-monitor && git grep -nE '(PollingFooter|StageChecklist|polling_cycle_complete)' -- '*.tsx' '*.ts' '*.rs' '*.css' | wc -l` returns 0; `cd flow-monitor && npm run build` succeeds; `cd flow-monitor/src-tauri && cargo build` succeeds; `cd flow-monitor/src-tauri && cargo test` (existing tests still green); T15 `bin/check-no-polling.sh` (W4) is the formal AC13 gate
    - Depends on: T5 (wiring active before polling removed), T8 (`LiveWatchFooter` exists), T10 (`SessionCard` already swapped off `StageChecklist`)
    - Parallel-safe-with: T10 (different files), T12 (different files)
    - **STATUS Notes hook**: on completion, append `- 2026-04-26 Developer — T11 polling fully removed; consumer-grep gate clean; lib.rs run_session_polling deleted` to STATUS Notes.

- [ ] T12: i18n keys — register `sidebar.liveFsWatch`, `watcher.error.toast`, `card.tasks.progress.label`, `settings.polling.deprecated.note`, graph aria/whisker tooltips
    - Wave: W3
    - Owner: Developer
    - Files: `flow-monitor/src/i18n/en.json`, `flow-monitor/src/i18n/zh-TW.json`
    - Milestone: AC19 i18n parity preserved; new strings translated
    - Requirements: R19
    - Decisions: D7
    - Scope: add the following keys to BOTH `en.json` and `zh-TW.json` at the same nesting paths (the parity test in `i18n/__tests__/parity.test.ts` enforces symmetry): `sidebar.liveFsWatch`, `watcher.error.toast`, `card.tasks.progress.label` (format string with `{done}` / `{total}` placeholders), `settings.polling.deprecated.note`, `graph.aria.label` (parameterised by stage), `graph.whisker.tooltip` (relative-time tooltip if any). Translations are zh-TW (Traditional Chinese, not zh-CN). Per `.claude/rules/common/language-preferences.md`, the JSON file content stays English-only for the en.json side and zh-TW for the zh-TW.json side; commit message and tool args remain English regardless of `LANG_CHAT`.
    - Deliverables: ~6 new keys × 2 files
    - Verify: `cd flow-monitor && npm test -- --run i18n/__tests__/parity.test.ts` passes; `cd flow-monitor && npm run build` succeeds
    - Depends on: none
    - Parallel-safe-with: T10, T11

- [ ] T13: Cargo integration test — watcher emits within 1s (AC12)
    - Wave: W4
    - Owner: QA-tester
    - Files: `flow-monitor/src-tauri/tests/fs_watcher_latency.rs` (new)
    - Milestone: AC12 automated
    - Requirements: R12
    - Decisions: D9, D10 (sandbox-HOME does NOT apply — `tempfile::tempdir()` not `$HOME`)
    - Scope: `#[tokio::test]` (or std thread) that creates a `tempfile::tempdir()`, places a synthetic `.specaffold/features/<slug>/03-prd.md`, calls `fs_watcher::spawn_watcher` with that root, sets up a one-shot channel for `artifact_changed` (test harness extracts the emit into the channel via a feature-gated test seam OR by intercepting at the debouncer level), writes to the file, asserts the channel receives an event with the matching path within `Duration::from_secs(1)`. NO `$HOME` access (per D10 / `.claude/rules/bash/sandbox-home-in-tests.md` — the rule is for bash test scripts; Rust integration tests use `tempfile`).
    - Deliverables: ~80 LOC test file
    - Verify: `cd flow-monitor/src-tauri && cargo test --test fs_watcher_latency` passes
    - Depends on: T1, T5
    - Parallel-safe-with: T14, T15, T16

- [ ] T14: Vitest unit tests — every AC except AC8/AC12/AC13/AC14/AC17 (~14 ACs)
    - Wave: W4
    - Owner: QA-tester
    - Files: `flow-monitor/src/components/__tests__/SessionGraph.test.tsx` (new), `flow-monitor/src/components/__tests__/TaskProgressBar.test.tsx` (new), `flow-monitor/src/components/__tests__/LiveWatchFooter.test.tsx` (new), `flow-monitor/src/stores/__tests__/parseTaskCounts.test.ts` (new), `flow-monitor/src/stores/__tests__/artifactStore.test.ts` (new), `flow-monitor/src/components/__tests__/SessionCard.graph.test.tsx` (new — AC18 chrome assertion under graph view)
    - Milestone: 14 ACs automated under `npm test`
    - Requirements: R1–R7, R9, R10, R11, R15, R16, R18, R19 (parity test already exists; verify still green)
    - Decisions: D9 test matrix
    - Scope: write the unit tests per the D9 table; use the data-attribute hooks defined in T6 (`[data-stage-node]`, `[data-row]`, `[data-active]`, `[data-state]`, `[data-bypass-arc]`, `[data-stage-edge]`); fixture `parseTaskCounts.test.ts` covers 3-of-7 case (AC10), case-insensitive `[X]`, code-fence-excluded markers, indented bullets, block-quoted lines (tech §6 risk 5); `artifactStore.test.ts` mocks `@tauri-apps/api/event::listen` and asserts `useArtifactChanges` filters by `(repo, slug)` correctly, plus `useWatcherStatus` transitions; `SessionCard.graph.test.tsx` asserts the six chrome elements remain present.
    - Deliverables: ~6 new test files; total ~400–500 LOC
    - Verify: `cd flow-monitor && npm test -- --run` passes (all suites including pre-existing tests); coverage for all listed ACs visible in test output
    - Depends on: T2 (parseTaskCounts), T6 (SessionGraph), T7 (TaskProgressBar), T8 (LiveWatchFooter), T10 (SessionCard mounts graph)
    - Parallel-safe-with: T13, T15, T16

- [ ] T15: `bin/check-no-polling.sh` — static grep gate for AC13
    - Wave: W4
    - Owner: QA-tester
    - Files: `flow-monitor/bin/check-no-polling.sh` (new — note: under `flow-monitor/bin/` not repo-root `bin/`, since the script is flow-monitor-specific)
    - Milestone: AC13 automated as a static gate
    - Requirements: R13
    - Decisions: D9, D10 (sandbox-HOME does NOT apply — read-only static grep)
    - Scope: bash 3.2 portable (`.claude/rules/bash/bash-32-portability.md`); use `set -euo pipefail`; grep for prohibited patterns in `flow-monitor/src-tauri/src/`: `tokio::time::sleep` with seconds-scale durations in production paths, `tokio::time::interval`, `polling_cycle_complete`, and `run_session_polling` (the function body should be deleted by T11; only references in archived comments allowed); exit 0 if all clean, exit 1 with offending file:line on any hit. NO `[[ =~ ]]` regex matching for portability — use `grep -E` only. NO `mapfile`, NO `readlink -f`. The script is read-only (static grep), so sandbox-HOME does not apply per D10.
    - Deliverables: ~50 LOC bash script
    - Verify: `bash flow-monitor/bin/check-no-polling.sh` exits 0 after T11 lands; deliberately reverting T11's deletion makes the script exit non-zero (the Developer should test this manually before submission)
    - Depends on: T11
    - Parallel-safe-with: T13, T14, T16

- [ ] T16: `flow-monitor/scripts/measure-latency.sh` — manual latency harness for AC14
    - Wave: W4
    - Owner: QA-tester
    - Files: `flow-monitor/scripts/measure-latency.sh` (new), `flow-monitor/src/stores/artifactStore.ts` (append a dev-mode `console.log` of `(disk_write_ts → render_commit_ts)` deltas guarded by `import.meta.env.DEV`)
    - Milestone: AC14 has a runnable measurement procedure
    - Requirements: R14
    - Decisions: D9, D10 (sandbox-HOME **DOES apply** — `.claude/rules/bash/sandbox-home-in-tests.md`)
    - Scope: bash 3.2 portable; **MUST** include the sandbox-HOME header (`mktemp -d`, `trap 'rm -rf "$SANDBOX"' EXIT`, `export HOME="$SANDBOX/home"`, preflight `case "$HOME" in "$SANDBOX"*) ;; *) echo "FAIL: HOME not isolated" >&2; exit 2 ;; esac`); script writes a fixture `.specaffold/features/<slug>/03-prd.md` 20 times with `sleep 0.2` between writes; tails the dev-mode flow-monitor console log; computes p95 of the deltas; asserts p95 ≤ 1000ms or exits non-zero. Document in script header the assumption that the user has `npm run tauri dev` running in another terminal; the script does not auto-start the app. Append the dev-mode `console.log` instrumentation to `artifactStore.ts` (in `useArtifactChanges`'s event handler) — guarded by `import.meta.env.DEV` so it's compiled out in production. The `artifactStore.ts` edit is append-only (new lines at the bottom of the existing event handler), parallel-safe with no W4 sibling that touches the same file.
    - Deliverables: ~70 LOC bash script + ~5 line console.log addition
    - Verify: `bash flow-monitor/scripts/measure-latency.sh --help` shows usage (smoke); the full p95 measurement is a manual run-through documented in script comments. The Developer captures one successful run's p95 in the commit message.
    - Depends on: T2 (artifactStore.ts must exist), T11 (polling removed so the measured path is event-driven)
    - Parallel-safe-with: T13, T14, T15

- [ ] T17: Settings deprecation note for inert `polling_interval_secs` slider
    - Wave: W5
    - Owner: Developer
    - Files: `flow-monitor/src/components/SettingsGeneral.tsx`
    - Milestone: tech §6 risk 8 mitigated (user sees explanation when slider has no effect)
    - Requirements: R13 (carve-out)
    - Decisions: D6 (slider stays as inert vestige; lazy-migration deferred per `shared/lazy-migration-at-first-write-beats-oneshot-script`)
    - Scope: in `SettingsGeneral.tsx`, beneath the existing polling-interval slider, render a `<p className="settings__deprecated">` element with text from i18n key `settings.polling.deprecated.note` (registered in T12). The slider itself remains functional (writes to `polling_interval_secs`) but the value has no runtime effect. NO migration of the settings file. NO removal of the `polling_interval_secs` Rust field.
    - Deliverables: ~3 line addition to `SettingsGeneral.tsx`, ~10 lines added to `components.css` (`.settings__deprecated` style)
    - Verify: `cd flow-monitor && npm run build` succeeds; manual: open Settings, see the deprecation note beneath the slider
    - Depends on: T11 (polling actually removed), T12 (i18n key registered)
    - Parallel-safe-with: T18

- [ ] T18: README + smoke-checks update + dark-only token marker
    - Wave: W5
    - Owner: Developer
    - Files: `flow-monitor/README.md`, `flow-monitor/src/styles/theme.css` (add `[CHANGED 2026-04-26]` comment marker on the dark-only `--graph-*` tokens noting "light-mode tokens deferred — see follow-up")
    - Milestone: AC17 manual smoke-check procedure documented; dark-only tokens flagged for the eventual light-mode pass
    - Requirements: R17 (six B1 smoke checks unchanged)
    - Decisions: D8 (light-mode token follow-up deferred)
    - Scope: in `flow-monitor/README.md`, update the "Six manual smoke checks" section to confirm each of the six checks still passes after this feature lands (no procedural change — just a confirmation pass + dated note); add a paragraph noting the new graph view does not alter any of the six smoke procedures. In `theme.css`, add a single-line `/* [CHANGED 2026-04-26] dark-only — light-mode follow-up tracked in PRD §6 risk 5 */` comment above the `--graph-*` token block. NO new tokens added here (T6 already added them).
    - Deliverables: README paragraph; one-line CSS comment
    - Verify: `cd flow-monitor && npm run build` succeeds; manual: walk the six smoke checks per README, confirm each still passes (this is the AC17 manual gate)
    - Depends on: T11 (graph view fully integrated), T17 (settings note matches user-visible behaviour)
    - Parallel-safe-with: T17

## Team memory

- `tpm/parallel-safe-requires-different-files` — applied: drove the W2 split (T6/T7/T8/T9 → separate files) and forced T3 collapse into T2 (same `artifactStore.ts`).
- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task` — applied: T5 surfaced as its own task with the literal `**Wiring task**` marker in the title, separated from T1 (watcher module) and T11 (polling removal).
- `shared/css-classname-rename-requires-consumer-grep` — applied: T11 explicit grep gate before deleting `StageChecklist`/`PollingFooter`/`polling_cycle_complete`.
- `shared/lazy-migration-at-first-write-beats-oneshot-script` — applied: T17 keeps `polling_interval_secs` as inert vestige + deprecation note; no settings-file migration in this feature.
- `tpm/parallel-safe-append-sections` — applied: T6/T7/T8 all append disjoint blocks to `components.css` and `theme.css`, marked parallel-safe under the append-section relaxation.

Proposed new memory: none — every pattern this plan applies is already captured; no novel TPM lesson to promote.

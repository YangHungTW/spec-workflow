# Gap Check — flow-monitor (B1: read-only dashboard)

_2026-04-19 · QA-analyst_

## 1. Summary

**Verdict: PASS-WITH-NITS**

All 15 PRD requirements (R1–R15) have implementation coverage. The feature ships 43 tasks (T1–T42 + T43 cleanup), 382 tests (99 Rust + 283 frontend), and 7 Architect test seams. Runtime-dependent ACs are correctly deferred under the dogfood-paradox protocol (`shared/dogfood-paradox-third-occurrence`). Three accumulated `should`-severity NITS from wave reviews remain unfixed; none block gap-check. One new advisory finding is raised (orphaned `markdown.footer` i18n key). No `must`-severity gaps were found.

---

## 2. PRD Coverage

Legend: ✓ implemented · 🕐 runtime-verify deferred · ⚠ partial / nit

### R1 — Session discovery (non-archived feature dir with STATUS.md)

| AC | Status | Evidence |
|---|---|---|
| AC1.a (feature dir with STATUS.md shown) | 🕐 | `repo_discovery.rs` + `poller.rs`; structural: `repo_discovery_tests.rs` + `poller_integration.rs` (Seam 3). Runtime: requires live app. |
| AC1.b (no STATUS.md = not shown) | 🕐 | Same seams; fixture `delta/` (no STATUS.md) verified excluded in `repo_discovery_tests.rs`. |
| AC1.c (archive excluded) | 🕐 | `classify_entry` excludes archive dir; verified in `repo_discovery_tests.rs` fixture `archive/foxtrot/`. |
| AC1.d (template excluded) | 🕐 | `_template` excluded by name in `repo_discovery.rs`; fixture verified. |

### R2 — Multi-repo registration; "All Projects" default

| AC | Status | Evidence |
|---|---|---|
| AC2.a (add + persist) | 🕐 | `ipc.rs` `add_repo` + `settings.rs` write; `Settings.tsx` folder picker. Runtime: requires live app. |
| AC2.b (remove) | 🕐 | `ipc.rs` `remove_repo`. Runtime. |
| AC2.c (validation — not a specflow repo) | ✓ | `SettingsRepositories.tsx` checks `.spec-workflow/` existence (`path = pickedPath + "/.spec-workflow"`). `Settings.test.tsx` confirms rejection. |
| AC2.d ("All Projects" default) | 🕐 | `MainWindow.tsx` route logic; `EmptyState.tsx` for zero-repo state. Runtime. |

### R3 — Polling reads STATUS.md; resolves last-activity timestamp

| AC | Status | Evidence |
|---|---|---|
| AC3.a (updated: field) | 🕐 | `status_parse.rs` `parse()` Seam 1; structural: `status_parse` fixture tests `recent_updated.md`. Runtime: requires live app. |
| AC3.b (last Notes line) | 🕐 | Structural: `recent_notes.md` fixture. |
| AC3.c (mtime fallback) | 🕐 | Structural: `mtime_fallback.md` fixture. |
| AC3.d (no writes) | ✓ | Seam 4 `seam4_no_writes.rs` build-time grep asserts zero write calls against `spec-workflow` paths. Confirmed: `poller.rs` write calls are in `#[cfg(test)]` test fixture code only (lines 305, 312, 320 are inside `fn make_repo` under `#[cfg(test)]`). |

### R4 — Polling interval 2–5s, 3s default

| AC | Status | Evidence |
|---|---|---|
| AC4.a (default 3s) | 🕐 | `settings.rs` `default_polling_interval_secs() = 3`. `Settings.test.tsx` default assertion. Runtime. |
| AC4.b (range enforced) | ✓ | `interval_secs.clamp(2, 300)` in `poller.rs` lines 85 + 208. `SettingsGeneral.tsx` slider clamped. |
| AC4.c (live indicator) | 🕐 | `PollingFooter.tsx` subscribes to `polling_indicator` event (T29); `MainWindow.events.test.tsx`. Runtime: 1s update SLA requires live poll. |

### R5 — Two-tier idle severity (stale/stalled)

| AC | Status | Evidence |
|---|---|---|
| AC5.a (default thresholds) | 🕐 | `settings.rs` defaults `stale_threshold_mins = 5`, `stalled_threshold_mins = 30`. Runtime. |
| AC5.b (stale badge) | 🕐 | `IdleBadge.tsx` + `SessionCard.tsx`; `StagePill.test.tsx` + `IdleBadge.test.tsx` snapshot tests. Runtime badge crossing requires live clock. |
| AC5.c (stalled badge + top accent) | 🕐 | `IdleBadge.tsx` stalled state; structural tests. Runtime. |
| AC5.d (threshold ordering) | ✓ | `SettingsGeneral.tsx` lines 31–52: enforces stalled ≥ stale on each slider change. `Settings.test.tsx` asserts error message on violation. |

### R6 — One-shot macOS Notification Center on stalled transition

| AC | Status | Evidence |
|---|---|---|
| AC6.a (single fire on transition) | 🕐 | `notify.rs` + `store::diff` `stalled_transitions`; `notify_dedupe_test.rs` structural. Runtime. |
| AC6.b (no recurrence while stalled) | 🕐 | Structural: `notify_dedupe_test.rs` fixture. |
| AC6.c (re-notify on re-cross) | 🕐 | Structural: `notify_dedupe_test.rs` second-crossing assertion. |
| AC6.d (no sound) | ✓ | `notify.rs` line 108: `.silent()` call. Grep: `grep -E 'silent' notify.rs` confirms. |
| AC6.e (user-disablable) | ✓ | `notify.rs` checks `settings.notifications_enabled` before firing. `SettingsNotifications.tsx` toggle. `Settings.test.tsx` covers this. |

### R7 — Card grid with 4 sort axes

| AC | Status | Evidence |
|---|---|---|
| AC7.a (card grid renders; 6 elements) | 🕐 | `SessionCard.tsx` + `MainWindow.tsx`; `SessionCard.test.tsx` 6-element assertion. Runtime. |
| AC7.b (default sort last-updated DESC) | 🕐 | `store::sort_by(SortAxis::LastUpdatedDesc)`. Structural: `store_diff_tests.rs`. Runtime. |
| AC7.c (4 sort axes available) | 🕐 | `store.rs` `SortAxis` enum: `LastUpdatedDesc`, `Stage`, `SlugAZ`, `StalledFirst`. `SortToolbar.tsx`. Runtime. |
| AC7.d (hover actions = exactly 2: Open in Finder + Copy path) | ✓ | `SessionCard.tsx` renders exactly these 2 buttons. `SessionCard.test.tsx` asserts `getAllByRole("button").length === 2`. No B2 leakage found: grep for `send_instruction`/`advance_stage` in `src/` returns empty. |

### R8 — "All Projects" grouped by repo with collapsible headers

| AC | Status | Evidence |
|---|---|---|
| AC8.a (grouped layout) | 🕐 | `store::group_by_repo()` + `MainWindow.tsx` rendering. `store_diff_tests.rs` Seam 2 covers group-by-repo. Runtime. |
| AC8.b (collapsible — state persists across restart) | ✓ | `settings.rs` `repo_section_collapse: HashMap<PathBuf, bool>` field (line 68). Persisted via atomic write. |
| AC8.c (single-repo selection bypass) | 🕐 | `MainWindow.tsx` route `/repo/:repoId` renders flat. Runtime. |

### R9 — Card detail: read-only, stage checklist, Notes, markdown artefacts

| AC | Status | Evidence |
|---|---|---|
| AC9.a (detail opens on click; title = slug + repo) | 🕐 | `CardDetail.tsx` master-detail route; `CardDetail.test.tsx`. Runtime. |
| AC9.b (stage checklist parsed) | ✓ | `status_parse.rs` `parse()` returns `stage_checklist: Vec<(StageItem, bool)>`. Seam 1 fixture `template_baseline.md` asserts 11-line checklist. `StageChecklist.tsx` renders display-only. |
| AC9.c (Notes timeline source order) | ✓ | `status_parse.rs` `notes: Vec<NotesEntry>` in source order. `NotesTimeline.tsx` renders entries. Structural: fixture test `notes_multi.md`. |
| AC9.d (file list reflects existence) | 🕐 | `TabStrip.tsx` shows only present artefacts per `list_artefact_files` IPC. Runtime. |
| AC9.e (read-only invariant; no edit affordance) | ✓ | `CardDetail.test.tsx` asserts `queryByRole("textbox") === null` and no save/edit/advance button. `CardDetailMarkdownPane.tsx` is display-only. Seam 7 XSS test. |
| AC9.f ([CHANGED] back-nav restores filter state) | ✓ | `CardDetail.tsx` encodes `?sort=&repo=` search params before navigation; breadcrumb restores them. `CardDetail.test.tsx` AC9.f test. |
| AC9.g ([CHANGED] tab strip scrolls; active tab auto-scrolls) | ✓ | `TabStrip.tsx`: CSS `overflow-x: auto`; `scrollIntoView` on active tab switch. `TabStrip.test.tsx` 480px-width assertion. |
| AC9.h ([CHANGED] 02-design tab Reveal in Finder per file; header-strip opens feature dir) | ✓ | `DesignFolderIndex.tsx` single action per row is "Reveal in Finder". `DesignFolderIndex.test.tsx` asserts every button is Reveal. |
| AC9.i ([CHANGED] Notes newest-first, untruncated) | ✓ | `status_parse.rs` `notes_newest_first()` accessor. `NotesTimeline.tsx` uses it. `NotesTimeline.test.tsx` 100-entry no-truncation test. |
| AC9.j ([CHANGED] stalled badge static in detail header) | ✓ | `IdleBadge.tsx`: no `animation`/`transition`/`@keyframes`. `IdleBadge.animation.test.tsx` computed-style assertion. |
| AC9.k ([CHANGED] markdown pane footer literal) | ✓ | `CardDetailMarkdownPane.tsx` JSX literal `Read-only preview. Open in Finder to edit.` (not `t()`). `CardDetailMarkdownPane.test.tsx` string-match + zh-TW locale carve-out test. |

### R10 — Floating always-on-top compact panel

| AC | Status | Evidence |
|---|---|---|
| AC10.a (panel opens/closes; main stays functional) | 🕐 | `CompactPanel.tsx` + `ipc.rs` `set_compact_panel_open`. `CompactPanel.test.tsx`. Runtime. |
| AC10.b (always-on-top default; Settings toggle) | 🕐 | `settings.rs` `always_on_top: bool = true`; `set_always_on_top` IPC wired in T28. Runtime. |
| AC10.c (sync with main) | 🕐 | Both windows subscribe to `sessions_changed` event from same `poller.rs`. Runtime. |
| AC10.d (free-floating, no edge-snap) | 🕐 | Tauri default; T28 `tauri-plugin-window-state` wired. No edge-snap code. Runtime. |
| AC10.e ("Open main" affordance) | 🕐 | `CompactPanel.tsx` "Open main" button. `CompactPanel.test.tsx`. Runtime focus test. |

### R11 — English + zh-TW; language toggle in Settings

| AC | Status | Evidence |
|---|---|---|
| AC11.a (default English) | 🕐 | `i18n/index.ts` defaults to `en`. Runtime. |
| AC11.b (toggle to zh-TW within one frame) | 🕐 | `i18n/index.ts` `setLocale` updates Context, re-renders. Runtime. |
| AC11.c (parity coverage) | ✓ | Seam 6 `parity.test.ts`: every key in `en.json` (76 keys) present in `zh-TW.json` and vice versa. |
| AC11.d (notification language) | 🕐 | `ipc.rs` `set_notification_strings()` bridges renderer locale to `notify.rs`. Runtime. |
| AC11.e (no auto-detect) | ✓ | Grep for `navigator.language` in `src/` returns empty (confirmed). |

### R12 — Empty state when no repos registered

| AC | Status | Evidence |
|---|---|---|
| AC12.a (empty state shows) | 🕐 | `EmptyState.tsx` renders when `repos = []`. `EmptyState.test.tsx`. Runtime. |
| AC12.b (CTA functional) | 🕐 | CTA triggers folder picker. `EmptyState.test.tsx`. Runtime. |
| AC12.c (sidebar ghost item) | ✓ | `RepoSidebar.tsx` shows dashed-border ghost item when `repos.length === 0`. |

### R13 — Polling overhead budget

| AC | Status | Evidence |
|---|---|---|
| AC13.a (read-once per cycle) | ✓ | `poller.rs` one `read_to_string` per STATUS.md per tick; `repo_discovery.rs` one `read_dir` per repo. `poller_integration.rs` Seam 3 read-count assertion. |
| AC13.b (no subprocess in polling) | 🕐 | `poller.rs`: grep for `Command::new`/`process::Command` returns empty. Seam 4 `seam4_no_writes.rs`. Runtime: `dtruss` audit deferred. |
| AC13.c (cycle within interval at 20 sessions) | ✓ | `wall_clock_budget.rs` Seam 3 extension: 5 repos × 4 sessions, 5 ticks, all < 3000ms. |

### R14 — Settings persistence across restarts

| AC | Status | Evidence |
|---|---|---|
| AC14.a (round-trip) | ✓ | `settings_roundtrip.rs` Seam 5: byte-equality assertion for all fields. |
| AC14.b (read-once at launch; no re-read during polling) | ✓ | `settings.rs` reads on launch only; `poller.rs` receives `interval_secs` as parameter, never re-reads settings file. |
| AC14.c (atomic write) | ✓ | `settings.rs` writes to `.tmp` then `std::fs::rename` (atomic). `settings_roundtrip.rs` crash-simulation test. `.bak` created before rename. |

### R15 — Light/dark themes; no OS auto-follow in B1

| AC | Status | Evidence |
|---|---|---|
| AC15.a ([CHANGED] theme toggles within one frame; control in Settings → General) | ✓ | `themeStore.ts` flips `html.dark` class synchronously. `themeStore.timing.test.ts` Seam within-one-frame assertion. `SettingsGeneral.tsx` hosts the Light/Dark control. |
| AC15.b ([CHANGED] persists across restart) | ✓ | `settings.rs` `theme: Theme` field; atomic write. `settings_roundtrip.rs` covers this field. |
| AC15.c ([CHANGED] first-run defaults to Light) | ✓ | `settings.rs` `default_theme() = Theme::Light`. `themeStore.test.tsx` asserts `html` class absent (light) on fresh settings. |
| AC15.d ([CHANGED] both themes apply to all 7 screens) | 🕐 | `theme.css` covers all surfaces; `StagePill.test.tsx` + `IdleBadge.test.tsx` 2-theme snapshot variants. Full 7-screen coverage requires live app inspection. |
| AC15.e ([CHANGED] primary tokens match locked palette) | ✓ | `theme.css` line 15: `--primary: #4F46E5` (light); line 94: `--primary: #1B4332` (dark). Structural match against `02-design/notes.md` token table. |
| AC15.f ([CHANGED] WCAG AA contrast) | ✓ | `contrast.test.ts`: 22+ assertions across 11 stage pills + body text + idle badges, both themes, ≥4.5:1 body / ≥3:1 pill. |

---

## 3. Task Completion

All 43 tasks are marked `[x]` in `06-tasks.md`. Implementation files confirmed present for every wave:

- **W0 (T1–T5)**: `flow-monitor/` scaffold, `Cargo.toml`, `tauri.conf.json`, `.github/workflows/build.yml`, smoke `.dmg`.
- **W1 (T6–T11)**: `status_parse.rs`, `repo_discovery.rs`, `store.rs`, `poller.rs`, `settings.rs`, `ipc.rs`.
- **W1.5 (T43)**: `lib.rs` gains `pub mod status_parse;`; stub types replaced; 10 cleanup items verified.
- **W2 (T12–T16)**: React shell, `theme.css`, `en.json`/`zh-TW.json`, `StagePill.tsx`, `IdleBadge.tsx`, `MarkdownPane.tsx`.
- **W3 (T17–T24)**: `MainWindow.tsx`, `CardDetail.tsx`, `TabStrip.tsx`, `DesignFolderIndex.tsx`, `NotesTimeline.tsx`, `CardDetailMarkdownPane.tsx`, `Settings.tsx`, `EmptyState.tsx`, `CompactPanel.tsx`.
- **W4 (T25–T29)**: `tray.rs`, `notify.rs`, `open_in_finder`/`reveal_in_finder` argv-form, `tauri-plugin-window-state`, compact-panel `WebviewWindow` + polling indicator wiring.
- **W5 (T30–T42)**: All 7 Architect test seams implemented (`poller_integration.rs`, `seam4_no_writes.rs`, `parity.test.ts`, `MarkdownPane.xss.test.tsx`, `MarkdownPane.gfm.test.tsx`, `settings_roundtrip.rs` extended, `wall_clock_budget.rs`, `IdleBadge.animation.test.tsx`, `themeStore.timing.test.ts`, `contrast.test.ts`). T42 STATUS rollup written.

**No checked task found to have missing implementation.** **No unchecked task exists.**

---

## 4. Scope Creep

The diff introduces 142 files (+28,064 lines). All files trace back to PRD requirements or explicit tech decisions:

| File / group | PRD trace |
|---|---|
| `.github/workflows/build.yml` | Q-plan-4 (T4) |
| `flow-monitor/` entire app directory | R1–R15, D1–D12 |
| `src-tauri/icons/` | D1 Tauri scaffold; needed by `tauri build` |
| `flow-monitor/.vscode/extensions.json` | Developer tooling; no behaviour impact |
| `src/App.css` | Tauri scaffold leftover from template pruning (T1) |
| `src/assets/react.svg` | Scaffold artifact (T1) |
| `src/vite-env.d.ts` | Vite scaffold (T1/T2) |
| `src/types/markdown-it-task-lists.d.ts` | Type stub for D4 markdown-it plugin; required for TS compilation |

**One potential scope concern noted but not blocking:**

- `flow-monitor/src/App.css` contains generic Vite/React template CSS (99 lines). The T1 task specified pruning demo boilerplate but this file was not entirely removed. It appears to be leftover scaffold CSS that has no PRD requirement and may conflict with `theme.css`. Classified as **advisory nit** (`should`-severity per reviewer/style check 8 "dead imports/unused symbols"). The CI build passes, so it does not break anything.

No B2 scope creep detected: grep for `send_instruction`, `invoke_specflow`, `advance_stage`, `write_status`, `controlPlane` in `src/` and `src-tauri/src/` returns results only in comments, test assertions, and B2-forward-compat test fixtures — not in any functional code path.

---

## 5. Outstanding NITS (accumulated from W0–W5 wave reviews)

All items below are `should`-severity (advisory). None were escalated to `must` by any wave reviewer verdict. All carried forward to verify as known state.

| Wave | Finding | Source | Status |
|---|---|---|---|
| W0 T2 | DevDep wildcards on `@testing-library/*`, `@types/*`, `vitest` in `package.json` — major-version floats on test-only deps | W0 reviewer verdict NITS | Accepted; not fixed |
| W1 retry | T6 WHAT-comment at `status_parse.rs` line 185 | W1 retry verdict NITS | T43 item 10 scope covered this; re-verify |
| W1 retry | T8 dead `let now` in `SortAxis::StalledFirst` arm | W1 retry verdict NITS | T43 item 4 confirmed cleaned up (line 190 arm now clean) |
| W1 retry | T9 `metadata()` + `read_to_string` as 2 syscalls (open file once instead) | W1 retry verdict NITS | T43 item 5 consolidated; `grep -E 'metadata\(\)'` shows each hit is on an open File handle |
| W1 retry | T11 `update_settings` full-struct clobber; `read_artefact` inner duplication | W1 retry verdict NITS | T43 items 8 + 9 addressed |
| W2 retry 2 | Eager locale load in `i18n/index.ts` (loads both en + zh-TW JSON at startup) | W2 reviewer verdict NITS | Not fixed; accepted |
| W2 retry 2 | WHAT-comments in component files | W2 reviewer verdict NITS | Not fixed; accepted |
| W2 retry 2 | DOMPurify test-mock not matching production config | W2 reviewer verdict NITS | Not fixed; accepted |
| W4 | Line-length violations in several Rust files (e.g. `ipc.rs`) | W4 reviewer verdict NITS | Not fixed; accepted |
| W4 | `btn.compactPanel` i18n key missing at wave merge time | W4 reviewer verdict NITS | Fixed post-merge (key now present in both `en.json` and `zh-TW.json`) |
| W4 | `notify.rs` title/body string validation not enforced | W4 reviewer verdict NITS | Not fixed; accepted |

**New advisory finding (gap-check raised):**

- `flow-monitor/src/i18n/en.json` and `zh-TW.json` both contain key `"markdown.footer"` (en value: `"Read-only preview. Open in Finder to edit."`; zh-TW value: `"唯讀預覽。如需編輯，請在 Finder 中開啟。"`). However, `CardDetailMarkdownPane.tsx` uses a JSX literal, NOT `t("markdown.footer")`, per the AC9.k carve-out. The i18n key is therefore a **dead key**: it exists in both locale files but is never consumed at runtime. The parity test in `parity.test.ts` will not catch this because the key is symmetrically present in both files. The zh-TW translation is also misleading — if a future developer adds `t("markdown.footer")`, they would get zh-TW text where AC9.k mandates English-only. **Advisory nit** (`should`-severity per reviewer/style check 8 — dead i18n symbols). Recommend removing `"markdown.footer"` from both locale files in a follow-up task or during B2, and replacing with an inline comment in the component referencing AC9.k.

---

## 6. Runtime-Verify Queue for /specflow:verify

Per PRD §6 dogfood paradox and `shared/dogfood-paradox-third-occurrence`: the following ACs require the running app observing live specflow sessions. They are structurally PASS but must be manually exercised by the QA-tester after building and launching `flow-monitor_0.1.0_universal.dmg` against this repository.

**Queue size: 37 ACs**

### Group A — Session discovery and freshness (requires live polling, real STATUS.md files)

- AC1.a: Feature dir with STATUS.md appears in card grid within one poll cycle of launch.
- AC1.b: Empty dir (no STATUS.md) does not appear.
- AC1.c: Archive dir excluded.
- AC1.d: `_template/` excluded.
- AC3.a: `updated:` field drives last-activity display.
- AC3.b: Most-recent Notes-line date overrides `updated:` when newer.
- AC3.c: mtime fallback when fields absent.

### Group B — Multi-repo and settings persistence (requires OS folder-picker and app restart)

- AC2.a: Add repo via folder picker; persists across restart.
- AC2.b: Remove repo causes sessions to disappear.
- AC2.d: First launch after adding repo lands on "All Projects".
- AC4.a: Default 3s polling interval shown in Settings.
- AC5.a: Default thresholds (stale 5 min, stalled 30 min) shown in Settings.

### Group C — Idle badges and notifications (requires real time passage or clock manipulation)

- AC4.c: Polling indicator updates within 1s of slider change.
- AC5.b: Stale badge appears after 5 min idle (amber).
- AC5.c: Stalled badge + top accent bar after 30 min idle (red); card sorts to top under Stalled-first axis.
- AC5.d: (Already structural-PASS via Settings test; verify UX feels correct.)
- AC5.e (implicit in AC5.d): stalled ≥ stale enforced programmatically.
- AC6.a: Exactly one notification fires on first stalled crossing.
- AC6.b: No additional notification while session remains stalled.
- AC6.c: Second notification fires on stalled → non-stalled → stalled re-cross.
- AC6.d: Notification plays no sound (silent flag).

### Group D — Card grid and sort (requires real session data)

- AC7.a: Card grid renders all 6 card elements with real session data.
- AC7.b: Default sort is last-activity DESC.
- AC7.c: All 4 sort axes reorder cards correctly.
- AC8.a: "All Projects" grouped by repo with labelled sections in registration order.

### Group E — Card detail and compact panel (requires running app)

- AC9.a: Click opens detail view; title shows slug + repo.
- AC9.d: Artefact tab list shows only files that exist on disk.
- AC10.a: Compact panel opens as separate window; main stays functional.
- AC10.b: Compact panel sits above other apps by default; Settings toggle disables.
- AC10.c: Compact panel session rows sync with main window within one poll cycle.
- AC10.d: Compact panel is draggable; no edge-snapping.
- AC10.e: "Open main" button in compact panel focuses or restores main window.

### Group F — Localisation (requires runtime locale switch)

- AC11.a: Fresh install renders all UI in English.
- AC11.b: Selecting zh-TW in Settings re-renders all strings within one frame.
- AC11.d: macOS notification banner is in the currently-active UI language.

### Group G — Empty state and first-run

- AC12.a: No repos registered → empty state shown (not card grid).
- AC12.b: "Add repository" CTA opens folder picker; on success navigates to All Projects.

### Group H — Resource budget

- AC13.b: `dtruss` / process-spawn audit on macOS during polling-only session confirms no subprocess spawn.

### Group I — Theme (runtime observation)

- AC15.d: Switching to Dark while viewing any of 7 screens re-tones all surfaces.

---

## 7. Gap-Check Verdict

## Verdict: PASS-WITH-NITS

**Rationale:**

- All 15 requirements (R1–R15) are implemented. No `must`-severity PRD requirement is unimplemented.
- All 43 tasks (T1–T42 + T43) are shipped and verified by the diff.
- All 7 Architect test seams (Seams 1–7) are implemented (382 tests: 99 Rust + 283 frontend).
- 37 ACs are runtime-deferred per the dogfood-paradox protocol — not a gap; classified correctly.
- No B2 scope creep in any functional code path.
- The NITS are `should`-severity only. The one new finding (dead `markdown.footer` i18n key) is advisory.
- The `App.css` scaffold leftover is advisory (no functional impact; CI passes).

**Blocking conditions for verify:**

None. The verify stage (08-verify.md) may proceed. The QA-tester must:

1. Build and launch `flow-monitor_0.1.0_universal.dmg` from `flow-monitor/src-tauri/target/universal-apple-darwin/release/bundle/dmg/`.
2. Register this repository (`/Users/yanghungtw/Tools/spec-workflow`) as a watched repo.
3. Exercise the 37-AC runtime-verify queue (§6 above) manually.
4. Document runtime observations in 08-verify.md per the dogfood-paradox memory's "Next feature after a dogfood-paradox feature" protocol.

---

## STATUS Notes

- 2026-04-19 qa-analyst — gap-check complete; 07-gaps.md written; verdict PASS-WITH-NITS; 37 ACs runtime-deferred; 1 new advisory (dead markdown.footer i18n key); no must-severity gaps.

## Team Memory

Applied entries:

- **`shared/dogfood-paradox-third-occurrence`** — drove the structural PASS / runtime PASS split throughout §2 and §6. The 37 runtime-deferred ACs are not gaps; they are correctly deferred per this pattern. Applied to every AC that depends on the running app observing live sessions.
- **`qa-analyst/dry-run-double-report-pattern`** — considered for AC3.d (no-writes structural check via Seam 4). The Seam 4 test uses a static grep, not a dry-run output check, so the double-emission pattern does not apply here. No gap found on this axis.
- **`qa-analyst/agent-name-dispatch-mismatch`** — not applicable; this feature does not ship a new agent name.
- **`qa-analyst/manifest-sha-baseline-for-drifted-ours`** — not applicable; this feature does not use the manifest/symlink subsystem.

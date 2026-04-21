# Verify — flow-monitor (B1: read-only dashboard)

_2026-04-19 · QA-tester_

## 1. Summary

**Overall verdict: PASS-DEFERRED**

All structural ACs pass. 37 runtime-deferred ACs are appropriately deferred per the dogfood-paradox protocol (`shared/dogfood-paradox-third-occurrence`). Zero structural failures; zero regressions observed during test execution.

Note: the `.dmg` referenced in the feature dir prompt (`flow-monitor_0.1.0_universal.dmg`) does not exist on disk — the `src-tauri/target/` tree contains only `debug/` and `tmp/`; no `universal-apple-darwin/release/bundle/` path was built in this environment. Runtime exercise of the live app is therefore not possible in this session. This aligns with the dogfood-paradox expectation.

---

## 2. Structural AC Verification

Test commands executed:

```
cd /Users/yanghungtw/Tools/spec-workflow/flow-monitor
cargo test --manifest-path src-tauri/Cargo.toml   # exit 0 — 99 tests pass
npm test -- --run                                  # exit 0 — 283 tests pass
```

Total: 382 tests, 0 failures, 0 ignored.

### R1 — Session discovery

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC1.a (feature dir with STATUS.md shown) | `tests/repo_discovery_tests.rs`, `tests/poller_integration.rs` | `discover_includes_valid_sessions`, `test_discovered_set_is_alpha_bravo_charlie` | 0 | PASS (structural) |
| AC1.b (no STATUS.md = not shown) | `tests/repo_discovery_tests.rs` | `discover_excludes_dir_without_status_md`, `classify_dir_without_status_md_returns_not_a_session` | 0 | PASS (structural) |
| AC1.c (archive excluded) | `tests/repo_discovery_tests.rs` | `discover_excludes_archive_dir` | 0 | PASS (structural) |
| AC1.d (template excluded) | `tests/repo_discovery_tests.rs`, `src-tauri/src/poller.rs` unit | `discover_excludes_template`, `classify_template_dir_returns_template`, `test_discover_sessions_excludes_template_and_missing_status` | 0 | PASS (structural) |

### R2 — Multi-repo registration

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC2.a (add + persist) | N/A — runtime-deferred | — | — | DEFERRED (Group B) |
| AC2.b (remove) | N/A — runtime-deferred | — | — | DEFERRED (Group B) |
| AC2.c (validation — not a specflow repo) | `src/views/__tests__/Settings.test.tsx` | SettingsRepositories validation tests | 0 | PASS (structural) |
| AC2.d ("All Projects" default) | N/A — runtime-deferred | — | — | DEFERRED (Group B) |

### R3 — Polling reads STATUS.md; resolves last-activity

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC3.a (updated: field) | `src-tauri/src/status_parse.rs` unit | `test_recent_updated_wins` | 0 | PASS (structural) |
| AC3.b (last Notes line wins if newer) | `src-tauri/src/status_parse.rs` unit | `test_recent_notes_wins` | 0 | PASS (structural) |
| AC3.c (mtime fallback) | `src-tauri/src/status_parse.rs` unit | `test_mtime_fallback` | 0 | PASS (structural) |
| AC3.d (no writes to STATUS.md) | `tests/seam4_no_writes.rs` | `seam4_no_write_call_references_spec_workflow_path` | 0 | PASS (structural) |

### R4 — Polling interval 2–5 s, 3 s default

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC4.a (default 3 s) | N/A — runtime-deferred | — | — | DEFERRED (Group B) |
| AC4.b (range enforced) | `src-tauri/src/poller.rs` unit + `src/views/__tests__/Settings.test.tsx` | `clamp(2, 300)` lines 85 + 208 verified by code inspection; frontend slider test | 0 | PASS (structural) |
| AC4.c (live indicator updates within 1 s) | `src/views/__tests__/MainWindow.events.test.tsx` | polling indicator event subscription | 0 | PASS (structural — SLA requires live clock for full confirmation; DEFERRED for 1 s wall-clock SLA) |

### R5 — Two-tier idle severity

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC5.a (default thresholds 5 min / 30 min) | N/A — runtime-deferred | — | — | DEFERRED (Group B) |
| AC5.b (stale badge) | `src/components/__tests__/IdleBadge.test.tsx` | stale snapshot | 0 | PASS (structural snapshot) |
| AC5.c (stalled badge + top accent) | `src/components/__tests__/IdleBadge.test.tsx` | stalled snapshot | 0 | PASS (structural snapshot) |
| AC5.d (threshold ordering enforced) | `src/views/__tests__/Settings.test.tsx` | stalled ≥ stale enforcement test; `SettingsGeneral.tsx` lines 31–52 inspected | 0 | PASS (structural) |

### R6 — One-shot macOS notification on stalled transition

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC6.a (single fire on transition) | `tests/notify_dedupe_test.rs`, `tests/store_diff_tests.rs` | `notify_ac6a_fires_on_first_stalled_crossing`, `ac6a_stalled_transition_fires_on_first_crossing` | 0 | PASS (structural) |
| AC6.b (no recurrence while stalled) | `tests/notify_dedupe_test.rs`, `tests/store_diff_tests.rs` | `notify_ac6b_no_notification_while_already_stalled`, `ac6b_no_recurrence_while_still_stalled` | 0 | PASS (structural) |
| AC6.c (re-notify on re-cross) | `tests/notify_dedupe_test.rs`, `tests/store_diff_tests.rs` | `notify_ac6c_fires_again_after_recovery_and_re_cross`, `ac6c_recross_fires_again_after_recovery` | 0 | PASS (structural) |
| AC6.d (no sound) | `src-tauri/src/notify.rs` unit | `silent_flag_is_honoured_by_mock_sink`; `.silent()` at line 115 verified | 0 | PASS (structural) |
| AC6.e (user-disablable) | `src-tauri/src/notify.rs` unit, `src/views/__tests__/Settings.test.tsx` | `disabled_notifications_fire_zero_times`, SettingsNotifications toggle test | 0 | PASS (structural) |

### R7 — Card grid with 4 sort axes

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC7.a (card grid renders; 6 elements) | `src/components/__tests__/SessionCard.test.tsx` | `all 6 required elements are present` | 0 | PASS (structural) |
| AC7.b (default sort last-updated DESC) | `tests/store_diff_tests.rs` | `ac7c_sort_last_updated_desc` | 0 | PASS (structural) |
| AC7.c (4 sort axes available) | `tests/store_diff_tests.rs` | `ac7c_sort_stage`, `ac7c_sort_slug_az`, `ac7c_sort_stalled_first`, `ac7c_sort_last_updated_desc` | 0 | PASS (structural) |
| AC7.d (hover actions = exactly "Open in Finder" + "Copy path") | `src/components/__tests__/SessionCard.test.tsx` | `shows hover actions: exactly 2 buttons`, `does NOT render Send instruction...` | 0 | PASS (structural) |

### R8 — "All Projects" grouped by repo

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC8.a (grouped layout) | `tests/store_diff_tests.rs` | `ac8a_group_by_repo_groups_correctly`, `ac8a_group_by_repo_empty_map` | 0 | PASS (structural) |
| AC8.b (collapsible, state persists) | `tests/settings_roundtrip.rs`, `settings.rs` field inspection | `seam5_all_fields_non_default_round_trip`, `seam5_round_trip_byte_equality` — `repo_section_collapse: HashMap<PathBuf, bool>` confirmed | 0 | PASS (structural) |
| AC8.c (single-repo selection bypass) | N/A — runtime-deferred | — | — | DEFERRED (Group D) |

### R9 — Card detail: read-only, stage checklist, Notes, artefacts

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC9.a (detail opens; title = slug + repo) | N/A — runtime-deferred | — | — | DEFERRED (Group E) |
| AC9.b (stage checklist parsed — 11 lines) | `src-tauri/src/status_parse.rs` unit | `test_template_baseline_checklist`, `test_checklist_checked_flags` | 0 | PASS (structural) |
| AC9.c (Notes timeline source order) | `src-tauri/src/status_parse.rs` unit, `src/components/__tests__/NotesTimeline.test.tsx` | `test_notes_source_order`, `test_notes_entry_fields` | 0 | PASS (structural) |
| AC9.d (file list reflects existence) | N/A — runtime-deferred | — | — | DEFERRED (Group E) |
| AC9.e (read-only invariant — no edit, no save) | `src/components/__tests__/CardDetail.test.tsx` | `queryByRole("textbox") === null`; no save/advance button assertion | 0 | PASS (structural) |
| AC9.f (back-nav restores filter state) | `src/components/__tests__/CardDetail.test.tsx` | AC9.f test (search params encode/restore) | 0 | PASS (structural) |
| AC9.g (tab strip scrolls; active stays visible) | `src/components/__tests__/TabStrip.test.tsx` | 480 px-width assertion, scrollIntoView | 0 | PASS (structural) |
| AC9.h (02-design tab Reveal in Finder per file) | `src/components/__tests__/DesignFolderIndex.test.tsx` | every row button is Reveal assertion | 0 | PASS (structural) |
| AC9.i (Notes newest-first, untruncated) | `src-tauri/src/status_parse.rs` unit, `src/components/__tests__/NotesTimeline.test.tsx` | `test_notes_newest_first`, 100-entry no-truncation test | 0 | PASS (structural) |
| AC9.j (stalled badge static — no animation) | `src/components/__tests__/IdleBadge.animation.test.tsx` | computed-style no-animation assertion | 0 | PASS (structural) |
| AC9.k (markdown pane footer literal) | `src/components/__tests__/CardDetailMarkdownPane.test.tsx` | string-match `Read-only preview. Open in Finder to edit.` | 0 | PASS (structural) |

### R10 — Floating always-on-top compact panel

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC10.a (panel opens/closes) | N/A — runtime-deferred | — | — | DEFERRED (Group E) |
| AC10.b (always-on-top default; Settings toggle) | N/A — runtime-deferred | — | — | DEFERRED (Group E) |
| AC10.c (sync with main) | N/A — runtime-deferred | — | — | DEFERRED (Group E) |
| AC10.d (free-floating, no edge-snap) | N/A — runtime-deferred | — | — | DEFERRED (Group E) |
| AC10.e ("Open main" affordance) | N/A — runtime-deferred | — | — | DEFERRED (Group E) |

### R11 — English + zh-TW; language toggle

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC11.a (default English) | N/A — runtime-deferred | — | — | DEFERRED (Group F) |
| AC11.b (toggle to zh-TW within one frame) | N/A — runtime-deferred | — | — | DEFERRED (Group F) |
| AC11.c (parity: every en key present in zh-TW) | `src/i18n/__tests__/parity.test.ts` | 76-key parity assertion | 0 | PASS (structural) |
| AC11.d (notification language follows active locale) | N/A — runtime-deferred | — | — | DEFERRED (Group F) |
| AC11.e (no auto-detect) | Grep: `navigator.language` absent in `src/` (non-test files) | N/A — clean grep | 0 | PASS (structural) |

### R12 — Empty state

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC12.a (empty state shows with no repos) | N/A — runtime-deferred | — | — | DEFERRED (Group G) |
| AC12.b (CTA opens folder picker) | N/A — runtime-deferred | — | — | DEFERRED (Group G) |
| AC12.c (sidebar ghost item) | `src/components/__tests__/` (RepoSidebar / EmptyState tests) | ghost-item render assertion | 0 | PASS (structural) |

### R13 — Polling overhead budget

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC13.a (read-once per cycle) | `tests/poller_integration.rs` | `test_per_cycle_read_count_is_3` | 0 | PASS (structural) |
| AC13.b (no subprocess in polling) | `src-tauri/src/poller.rs` unit | `test_no_process_spawn_in_module` | 0 | PASS (structural); `dtruss` live audit DEFERRED (Group H) |
| AC13.c (cycle within interval — 20 sessions) | `tests/wall_clock_budget.rs`, `tests/poller_integration.rs` | `wall_clock_budget_20_sessions_5_ticks`, `test_wall_clock_20_sessions_under_1500ms_at_3s_interval` | 0 | PASS (structural) |

### R14 — Settings persistence

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC14.a (round-trip) | `tests/settings_roundtrip.rs` | `seam5_round_trip_byte_equality`, `seam5_all_fields_non_default_round_trip` | 0 | PASS (structural) |
| AC14.b (read-once at launch; no re-read during polling) | `src-tauri/src/settings.rs` + `poller.rs` code inspection | `settings_read_returns_defaults_when_absent`; poller receives `interval_secs` as parameter | 0 | PASS (structural) |
| AC14.c (atomic write — write-temp-then-rename + .bak) | `tests/settings_roundtrip.rs` | `seam5_atomic_rename_no_tmp_after_write`, `seam5_bak_exists_after_second_write`, `seam5_atomic_write_crash_leaves_original_intact` | 0 | PASS (structural) |

### R15 — Light/dark themes

| AC | Test file(s) | Test name(s) | Exit | Result |
|---|---|---|---|---|
| AC15.a (theme toggles within one frame; control in Settings → General) | `src/stores/__tests__/themeStore.timing.test.ts` | within-one-frame assertion | 0 | PASS (structural) |
| AC15.b (persists across restart) | `tests/settings_roundtrip.rs` | `seam5_round_trip_byte_equality` (theme field included) | 0 | PASS (structural) |
| AC15.c (first-run defaults to Light) | `src/stores/__tests__/themeStore.test.tsx` | `html` class absent on fresh settings | 0 | PASS (structural) |
| AC15.d (both themes apply to all 7 screens) | `src/components/__tests__/StagePill.test.tsx`, `IdleBadge.test.tsx` snapshot variants | 2-theme snapshot assertion | 0 | PASS (structural snapshots); full 7-screen live inspection DEFERRED (Group I) |
| AC15.e (primary tokens match locked palette) | `src/styles/theme.css` — line 15: `--primary: #4F46E5`; line 94: `--primary: #1B4332` | Direct file inspection + `contrast.test.ts` | 0 | PASS (structural) |
| AC15.f (WCAG AA contrast) | `src/styles/__tests__/contrast.test.ts` | 22+ assertions: ≥4.5:1 body text, ≥3:1 pill labels, both themes | 0 | PASS (structural) |

---

## 3. Runtime AC Verification

All 37 ACs in the §6 runtime queue are marked DEFERRED per the dogfood-paradox protocol. The DMG is also not present in the build tree at time of verify (only `debug/` target exists; no `universal-apple-darwin/release/` build was produced in this environment), which independently confirms runtime exercise is not possible here.

| Group | ACs | Count | Status |
|---|---|---|---|
| A — Session discovery and freshness | AC1.a, AC1.b, AC1.c, AC1.d, AC3.a, AC3.b, AC3.c | 7 | DEFERRED |
| B — Multi-repo and settings persistence | AC2.a, AC2.b, AC2.d, AC4.a, AC5.a | 5 | DEFERRED |
| C — Idle badges and notifications | AC4.c, AC5.b, AC5.c, AC6.a, AC6.b, AC6.c, AC6.d | 7 | DEFERRED |
| D — Card grid and sort | AC7.a, AC7.b, AC7.c, AC8.a | 4 | DEFERRED |
| E — Card detail and compact panel | AC9.a, AC9.d, AC10.a, AC10.b, AC10.c, AC10.d, AC10.e | 7 | DEFERRED |
| F — Localisation | AC11.a, AC11.b, AC11.d | 3 | DEFERRED |
| G — Empty state and first-run | AC12.a, AC12.b | 2 | DEFERRED |
| H — Resource budget | AC13.b (dtruss audit) | 1 | DEFERRED |
| I — Theme (runtime observation) | AC15.d (7-screen full inspection) | 1 | DEFERRED |

**Total deferred: 37 ACs**

The handoff contract: the next feature after archive must include an early STATUS Notes line confirming the first real session observation (per `shared/dogfood-paradox-third-occurrence` "Next feature after a dogfood-paradox feature" protocol).

---

## 4. Regressions Found During Verify

None. All 382 tests (99 Rust + 283 frontend) pass with exit code 0. No unexpected test output, no panics, no compilation errors.

One pre-existing advisory nit (carried from gap-check, not a regression):

- Dead `"markdown.footer"` i18n key in both `en.json` and `zh-TW.json` — the key exists but `CardDetailMarkdownPane.tsx` uses a JSX literal per AC9.k. Not a regression; not a structural failure; classified as `should`-severity advisory by QA-analyst in `07-gaps.md §5`. Recommend removing the key in B2 cleanup.

---

## 5. Final Verdict

## Verdict: PASS-DEFERRED

**Rationale:**

- All structural ACs that can be verified without a running app pass (382 tests, 0 failures).
- 37 runtime ACs are appropriately deferred per the dogfood-paradox protocol. The app cannot observe its own development session; runtime verification requires installing the built app and pointing it at this repository on the next specflow feature after archive.
- Zero `must`-severity findings from gap-check; none surfaced during verify.
- No regressions found.
- The `.dmg` binary is not present in the `src-tauri/target/` tree (only `debug/` and `tmp/` exist); the DMG referenced in the feature description does not exist on disk and cannot be exercised. This does not block PASS-DEFERRED — the dogfood paradox already governs the runtime-deferred classification independently of the DMG availability.
- PASS-DEFERRED is the correct terminal state for this feature per the dogfood-paradox pattern: the feature archives, the user builds and installs the `.dmg` locally (`cargo tauri build --target universal-apple-darwin`), launches the app, registers this repo as a watched repo, and exercises the 37-AC runtime queue. The next feature's STATUS Notes must confirm first-real-session observation.

---

## Runtime-Verify Handoff for Archive Retrospective

The following 37 ACs remain to be exercised after the user builds and launches the app:

**Group A (7):** AC1.a, AC1.b, AC1.c, AC1.d, AC3.a, AC3.b, AC3.c — requires app running, this repo registered, real STATUS.md files observed.

**Group B (5):** AC2.a, AC2.b, AC2.d, AC4.a, AC5.a — requires OS folder-picker interaction and app restart.

**Group C (7):** AC4.c, AC5.b, AC5.c, AC6.a, AC6.b, AC6.c, AC6.d — requires real time passage or clock manipulation to cross idle thresholds; notification permission granted.

**Group D (4):** AC7.a, AC7.b, AC7.c, AC8.a — requires real session data in card grid.

**Group E (7):** AC9.a, AC9.d, AC10.a, AC10.b, AC10.c, AC10.d, AC10.e — requires running app; detail view click; compact panel window.

**Group F (3):** AC11.a, AC11.b, AC11.d — requires live locale toggle; notification fires with correct language.

**Group G (2):** AC12.a, AC12.b — requires first-launch with zero repos, then add-repo flow.

**Group H (1):** AC13.b — requires `dtruss` or equivalent process-spawn audit while app is running.

**Group I (1):** AC15.d — requires visual inspection of all 7 mockup screens under Dark theme.

**Build step required first:** `cd flow-monitor && cargo tauri build --target universal-apple-darwin` (the DMG is absent from this environment's build tree).

---

## STATUS Notes

- 2026-04-19 QA-tester — verify complete; 08-verify.md written; verdict PASS-DEFERRED; 382/382 structural tests pass; 37 ACs deferred per dogfood-paradox; 0 regressions; DMG absent from build tree (runtime exercise requires local build).

## Team Memory

Applied entries:

- **`shared/dogfood-paradox-third-occurrence`** — governed the structural PASS / runtime DEFERRED split throughout. The 37 deferred ACs are not failures; they are the expected handoff artifact for a self-shipping UI feature. Applied per the "QA-tester" section of the memory: each deferred AC is tagged DEFERRED with the group label; the archive retrospective handoff list enumerates them explicitly.
- **`qa-tester/sandbox-home-preflight-pattern`** — not applicable. The Rust and frontend tests do not invoke a `$HOME`-touching CLI from a shell script; sandbox HOME discipline is internal to the test fixtures.

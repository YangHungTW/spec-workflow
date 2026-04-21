# Plan — flow-monitor (B1: read-only dashboard)

_2026-04-19 · TPM_

## 1. Summary

Greenfield Tauri 2.x desktop app with a Rust core (filesystem polling + state
diff + macOS Notification Center bridge + tray) and a React 19 + TypeScript
renderer (card grid, master-detail drill-in, compact panel, Settings, Empty
state). Stack pins: **Tauri 2.2**, **Rust 1.88.0 (MSRV)** [CHANGED 2026-04-19], **React 19.0**,
**Vite 6 + TypeScript 5.7**, **markdown-it 14 + DOMPurify 3**, plus the
official Tauri plugins for tray, notification, and window-state. The work
breaks into **6 sequential waves (W0–W5)** with internal parallelism in W1,
W2, W3, and W5. Ship target: macOS-first (`.dmg` only); Windows / Linux are
explicitly out of B1 CI scope. Per the dogfood-paradox memory, verify is
structural-only — runtime exercise lands on the next feature after archive.

## 2. Resolved §6 plan-stage questions

### Q-plan-1 — Tauri version pin and Rust MSRV

**Locked** [CHANGED 2026-04-19]: `tauri = "2.2"` (latest stable in the 2.x line as of 2026-04),
`rustc 1.88.0` as MSRV. Pinned in
`src-tauri/Cargo.toml` with caret-pinned minor (`tauri = "2.2"`,
`tauri-build = "2.0"`) and exact `rust-toolchain.toml` (`channel =
"1.88.0"`) so CI and dev machines use the same toolchain. Pinning matters
because the build matrix in W0 derives every cache key from these two
values and a floating pin would silently re-compile the world on every
upstream patch release. [CHANGED 2026-04-19] MSRV bumped from 1.83.0 to 1.88.0 during T2 implementation: Tauri 2.10's transitive dependency `time-core 0.1.8` requires `edition = "2024"` (Rust 1.85+), so 1.83.0 cannot resolve the dep tree; 1.88.0 is the lowest version that builds end-to-end. CI workflow `.github/workflows/build.yml` (T4) already uses `dtolnay/rust-toolchain` with `toolchain: 1.88.0` to match.

### Q-plan-2 — Renderer UI framework

**Locked**: **React 19.0** + **TypeScript 5.7** + **Vite 6**. Chosen over
SolidJS and Svelte 5 because (1) the largest pool of Tauri starter
templates target React, (2) the team has the most existing React patterns
to crib from per Architect's D-prelude in §6, (3) `react-markdown`-style
component testing harnesses (Vitest + React Testing Library) are mature
and well-documented, (4) markdown-it + DOMPurify integrate as a thin
wrapper component without framework-specific glue. Trade-off accepted:
React 19's bundle is ~10 KB heavier than SolidJS minified; immaterial
inside a Tauri app whose bundle floor is the system webview, not
JS payload size.

### Q-plan-3 — Packaging targets

**Locked**: **macOS only for B1** — produce a single `.dmg` artifact via
`tauri build --target universal-apple-darwin` (Apple Silicon + Intel
fat binary). `.msi` (Windows) and `.AppImage` / `.deb` (Linux) are
**out of B1**; deferred to a follow-up feature. Rationale: the PRD locks
"macOS first-class" (D1 trade-offs), the dogfood loop runs on macOS
exclusively (this repo is Darwin 25.3.0), and limiting the packaging
target bounds W0's CI scope to one runner image. Code-signing with an
Apple Developer ID is a release-time concern outside this plan; W5 ships
an unsigned `.dmg` for local dogfood and notes "signing is a follow-up".

### Q-plan-4 — CI matrix

**Locked**: **macOS-latest runner only** for the entire B1 CI matrix.
Justified by Q-plan-3 (only macOS artifacts ship in B1) and the
dogfood paradox (the app cannot exercise itself; there are no production
users yet to require multi-platform CI). Cross-platform CI is added in
the same follow-up feature that adds Windows / Linux packaging. The CI
workflow file (`.github/workflows/build.yml`) is added in W0 with a
single-job matrix `os: [macos-latest]` and is structurally trivial to
extend.

### Q-plan-5 — Window-state plugin

**Locked**: **`tauri-plugin-window-state` IS in B1 scope** (low-cost,
high-UX-value). The plugin remembers the main window's size and position
across launches and applies them before first paint, which is a
significant polish win for a dashboard the user keeps open all day.
Estimated cost: ~10 lines of plugin-init code in `src-tauri/main.rs`
plus one Cargo dep. Risk: the plugin is widely used but is
community-maintained — flagged in the risk register below. Settings
persistence for the **compact panel** position is also handled by the
same plugin (per-window state).

## 3. Wave map

```
                 W0 (foundations)
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
    W1 (Rust core, internal parallel)
        │
        └──┬──────── W2 (Frontend foundations, internal parallel)
           │              │
           └──────┬───────┘
                  ▼
            W3 (UI integration — depends on W1 outputs + W2 primitives)
                  │
                  ▼
            W4 (OS surface integration — tray, notification, window-state)
                  │
                  ▼
            W5 (Polish + structural verification harness + .dmg build)
```

| Wave | Goal | Pre-conditions | Internal parallelism | Exit (ACs unlockable) |
|---|---|---|---|---|
| W0 | Scaffold Tauri 2 + React 19, pin versions, smoke build, CI skeleton | none | sequential | structural — `cargo build` and `npm run build` green; `tauri build --target universal-apple-darwin` produces an unsigned `.dmg` |
| W1 | Rust core modules — pure parsers, store, polling engine, settings I/O | W0 merged | 5 parallel tasks (different files) | AC1.a–d, AC3.a–c, AC13.a–b, AC14.a–c (structural) |
| W2 | React shell, theming, i18n, component primitives | W0 merged (can start parallel with W1) | 4 parallel tasks (different files) | AC11.a, AC11.c (structural), AC15.c (default-light first-paint) |
| W3 | UI integration — Main Window, Card Detail, Settings, Empty, Compact | W1 + W2 merged | 5 parallel tasks (different files) | AC1.a (UI side), AC2.a–d, AC4.a–c, AC5.a–d, AC7.a–d, AC8.a–c, AC9.a–k, AC10.a, AC10.c–e, AC11.b, AC11.d, AC11.e, AC12.a–c, AC15.a–b, AC15.d–f |
| W4 | OS surfaces — tray icon + badge, macOS Notification Center, window-state, Open in Finder / Copy path | W3 merged | 4 parallel tasks (different files) | AC6.a–e, AC10.b, AC10.e (OS-level focus), AC9.h (`open -R`) wiring |
| W5 | Polish + structural verification harness + `.dmg` build | W4 merged | 5 parallel tasks (different files) | AC3.d (structural via Seam 4), AC6.a–c (structural via Seam 2), AC9.j (computed-style assertion), AC13.c (per-cycle wall-clock); final `.dmg` smoke launch |

**B1/B2 boundary discipline**: every wave below carries a §X "B1/B2 boundary
check" subsection. The headline rule: no IPC command in `ipc.rs` writes
to `.spec-workflow/**`; no UI surface paints a "Send instruction" / "Advance
stage" / "Invoke specflow CLI" affordance. Reviewer-security at every wave
merge re-scans `src-tauri/src/` for `OpenOptions::write` against any path
matching `**/spec-workflow/**` (Seam 4).

## 4. Per-wave detail

### W0 — Foundations (sequential, single wave-merge boundary)

**Goal**: scaffold the Tauri 2 + React 19 project with pinned versions,
produce a smoke build (Rust + JS both compile, `.dmg` packages), and lay
down the macOS-only CI workflow. **No feature logic.**

**Pre-conditions**: none (this wave starts from an empty `flow-monitor/`
subdirectory under the repo root).

**Tasks (high-level)**:
- T0.1: `flow-monitor/` directory scaffold via `npm create tauri-app@latest`, prune the template down to the module layout from §2 of 04-tech.md.
- T0.2: pin Tauri 2.2, Rust 1.88.0 (MSRV) via `rust-toolchain.toml`, React 19, TypeScript 5.7, Vite 6 in `Cargo.toml` and `package.json`. [CHANGED 2026-04-19]
- T0.3: `.github/workflows/build.yml` with a single-job matrix `os: [macos-latest]`, runs `cargo check` + `npm run build` + `tauri build --target universal-apple-darwin`.
- T0.4: `.gitignore` (`target/`, `node_modules/`, `dist/`), `README.md` stub for the app, `LICENSE` placeholder.
- T0.5: smoke verify — `cargo build` green, `npm run build` green, `tauri build` produces an unsigned `.dmg` locally.

**Parallel-safe within wave**: NO — every task touches the same scaffold and dependencies block. Sequential T0.1 → T0.2 → T0.3 → T0.4 → T0.5.

**Exit criteria**:
- `cargo check` succeeds in `src-tauri/`.
- `npm run build` succeeds in the renderer.
- `tauri build --target universal-apple-darwin` produces a `.dmg`.
- CI workflow is committed and the macOS runner passes the same three checks.

**Wave merge gate (reviewer-{security,performance,style})**:
- security: confirm `tauri.conf.json` does not allow `shell-execute`, `http-request`, or `notification` permissions beyond what W4 will need; remove unused capability allowlists.
- performance: confirm the Vite config produces a minified production bundle; no source maps in `dist/`.
- style: confirm `Cargo.toml` and `package.json` use exact pins for the major dependencies (Tauri, React, markdown-it, DOMPurify); no `^*` floats on these.

**B1/B2 boundary check**: trivially satisfied — no feature logic exists. Confirm `tauri.conf.json` does not pre-allow any `tauri-plugin-shell` `execute` permission that a future B2 might need; B1 does not invoke subprocesses (AC13.b).

---

### W1 — Rust core modules (5 tasks, parallel within wave)

**Goal**: build the read-only Rust subsystem — parsers, state diff, polling
engine, settings I/O — as pure modules with no UI dependency. Every module
in this wave is fixture-testable in isolation (Architect's Test Seams 1, 2,
5 land here).

**Pre-conditions**: W0 merged (`src-tauri/` scaffold exists with Cargo deps).

**Tasks (high-level)**:
- T1.1: `src-tauri/src/status_parse.rs` — pure `parse(content: &str, mtime: SystemTime) → SessionState` per Architect's D12 + Seam 1 (covers AC1.d via `_template/` exclusion logic moved to caller; AC3.a–c, AC9.b, AC9.c, AC9.i fixture parses).
- T1.2: `src-tauri/src/store.rs` — `HashMap<SessionKey, SessionState>` plus pure `diff(prev, new) → DiffEvent` per Architect's Seam 2 (covers AC6.a–c logic, AC8.a sort logic).
- T1.3: `src-tauri/src/poller.rs` — `tokio::time::interval` with the closed-enum `classify_entry(entry) → SessionKind` per Architect's D12 (covers AC1.a–c, AC13.a–b at the Rust layer; AC13.c instrumentation lands in W5).
- T1.4: `src-tauri/src/settings.rs` — read-merge-write-tmp + atomic-rename + `.bak` discipline per Architect's D8 (covers AC14.a–c structurally via Seam 5).
- T1.5: `src-tauri/src/ipc.rs` — `tauri::command` wrappers exposing the read-only command table from Architect's §2 (no write commands; one `read_artefact` reader; no stub B2 commands).

**Parallel-safe within wave**: YES — each task owns its own file under `src-tauri/src/`. The shared file is `src-tauri/src/main.rs` (the `mod` declarations) which is appended-to by each task; this is an **append-only collision** per `tpm/parallel-safe-append-sections` and resolves keep-both mechanically. Same for `src-tauri/Cargo.toml` if any task adds a new dep — append-only `[dependencies]` block.

**Exit criteria**:
- Every Rust module has unit tests with at least 80% line coverage of the module's public functions.
- `cargo test` green.
- Seam 1, Seam 2, Seam 5 fixture tests run and pass.
- A repo-level grep for `OpenOptions::write` / `fs::write` against any path matching `**/spec-workflow/**` returns zero hits in `src-tauri/src/` (Seam 4 lite, full Seam 4 lands in W5).

**Wave merge gate**:
- security: re-run the Seam 4 grep for write-call patterns; confirm `read_artefact` validates `repo` is in the registered-repo set (path-traversal boundary check per `.claude/rules/reviewer/security.md` check 2).
- performance: confirm `poller.rs` uses one `read_dir` per repo + one `read_to_string` per session (no recursive walk); confirm no shell-out in the polling code path (cross-references `.claude/rules/reviewer/performance.md` check 1).
- style: confirm bash-32-portability is N/A (Rust); confirm no commented-out code (`.claude/rules/reviewer/style.md` check 2); confirm `set -euo pipefail` convention is N/A (no bash in this wave).

**B1/B2 boundary check**: `ipc.rs` (T1.5) is the highest-risk surface for B2 leakage. Reviewer-security must confirm: (a) no `tauri::command` named `send_instruction`, `invoke_specflow`, `advance_stage`, or any write-side verb; (b) no `OpenOptions::write` in any IPC handler against a `.spec-workflow/**` path; (c) no enum slot or struct field reserved for a future write command; (d) `read_artefact` opens read-only via `std::fs::read_to_string`, not `File::open` with write flags.

---

### W2 — Frontend foundations (4 tasks, parallel within wave)

**Goal**: stand up the React 19 + Vite app shell with routing, theming,
i18n, and the component primitives that W3's view tasks will compose. No
feature logic in this wave — only the building blocks.

**Pre-conditions**: W0 merged. Can start in parallel with W1 once W0 ships
(no cross-wave dependency between W1 and W2).

**Tasks (high-level)**:
- T2.1: `src/main.tsx` + `src/App.tsx` + router (5 routes: `/`, `/repo/:slug`, `/detail/:repo/:slug`, `/settings`, `/compact`) + `src/styles/theme.css` with CSS custom properties for light + dark per Architect's D9 and the design `02-design/notes.md` token table.
- T2.2: `src/i18n/index.ts` + `src/i18n/en.json` + `src/i18n/zh-TW.json` — flat-JSON `t(key)` lookup with React-context language switcher per Architect's D10 (covers AC11.a, AC11.c, AC11.e).
- T2.3: Component primitives — `src/components/StagePill.tsx`, `IdleBadge.tsx`, `SessionCard.tsx` (skeleton), `MarkdownPreview.tsx` (markdown-it + DOMPurify wrapper per D4) (covers AC9.e XSS-safety via Seam 7 setup).
- T2.4: `src/stores/themeStore.ts` + `src/stores/settingsStore.ts` (renderer mirror of settings.json read via IPC) + `src/stores/sessionStore.ts` (subscribes to `sessions_changed` event); first-paint theme application per Architect's D9 (covers AC15.c first-run default-light).

**Parallel-safe within wave**: YES — T2.1, T2.2, T2.3, T2.4 own disjoint files. The append-only collision is `src/main.tsx` (router + provider wiring); resolves keep-both per `tpm/parallel-safe-append-sections`.

**Exit criteria**:
- `npm run dev` launches the empty shell with theme + i18n applied.
- `npm test` (Vitest) green for component primitives.
- Switching language via the i18n test harness re-renders within one frame.
- Theme `--primary` resolves to `#4F46E5` (light) and `#1B4332` (dark) per AC15.e.

**Wave merge gate**:
- security: confirm `MarkdownPreview` calls `DOMPurify.sanitize()` with the default profile (no relaxation) before insertion; confirm no `dangerouslySetInnerHTML` outside the sanitized path. Reviewer-security headline: this is the XSS surface.
- performance: confirm `markdown-it` is dynamically imported (not eagerly loaded) so the markdown render cost is paid lazily on first detail-view open (per `.claude/rules/reviewer/performance.md` check 8 — avoid eager loads of unused data).
- style: confirm React component naming convention (PascalCase) is consistent; confirm no commented-out code; confirm CSS custom property names match the design `02-design/notes.md` token table 1:1.

**B1/B2 boundary check**: confirm `themeStore` and `settingsStore` have no reserved keys for B2 features (no `controlPlaneEnabled`, no `instructionHistory`); confirm `sessionStore` does not declare optional fields that B2 plans to populate. Per Architect's §7 B2 reservations: B1 ships zero placeholder buttons.

---

### W3 — UI integration (5 tasks, parallel within wave)

**Goal**: compose the W2 primitives + W1 IPC commands into the five
user-facing routes — Main Window, Card Detail, Settings, Empty State,
Compact Panel. This is the wave where most of the PRD ACs become
demonstrable.

**Pre-conditions**: W1 + W2 both merged.

**Tasks (high-level)**:
- T3.1: `src/views/MainWindow.tsx` — sidebar (repo list + "All Projects"), 2-column card grid, toolbar (sort dropdown with the 4 axes per AC7.c, compact-mode toggle, language switcher hint), polling indicator footer (AC4.c), All Projects grouped layout (AC8.a–c). Covers AC1.a (UI render side), AC2.a–d (sidebar render of registered repos), AC4.a–c (polling indicator), AC5.a–d (idle-badge tinting), AC7.a–d, AC8.a–c, AC11.b, AC11.d.
- T3.2: `src/views/CardDetail.tsx` — master-detail navigation per D2, breadcrumb back-arrow (AC9.f restoring filter state via the sessionStore), 9-tab horizontal-scroll strip (AC9.g), MarkdownPane footer literal copy (AC9.k), 02-design tab file index with per-file Reveal in Finder (AC9.h), Notes timeline newest-first untruncated (AC9.i), static stalled badge in detail header (AC9.j). Covers AC9.a–k.
- T3.3: `src/views/Settings.tsx` — tabs (General / Notifications / Repositories), polling-interval slider (AC4.b), stale + stalled threshold inputs (AC5.d ordering enforcement), notifications toggle (AC6.e), language selector (AC11.b), theme Light/Dark control per the locked R15 §3-only placement (AC15.a, AC15.d), folder-picker for repo registration (AC2.a–c). Covers AC2.a–c, AC4.b, AC5.d, AC6.e, AC11.b, AC15.a–b, AC15.d–f.
- T3.4: `src/views/EmptyState.tsx` — illustration + "no repositories registered" copy + primary "Add repository" CTA + explainer box per design notes Empty State row + dashed-border ghost "Add repo…" sidebar item (AC12.c). Covers AC12.a–c.
- T3.5: `src/views/CompactPanel.tsx` — separate top-level window (Tauri `WebviewWindow`), one row per active session with `dot · slug · stage · relative-time`, "Open main" affordance (AC10.e). Covers AC10.a, AC10.c, AC10.d (free-floating, draggable), AC10.e. AC10.b (always-on-top toggle) lands fully in W4 wiring.

**Parallel-safe within wave**: YES with one caveat — T3.1, T3.2, T3.3, T3.4, T3.5 own disjoint view files. The shared dispatcher is `src/App.tsx`'s router (each task adds one Route element); per `tpm/parallel-safe-requires-different-files` this is a **dispatcher edit** and would normally serialize, but since each task adds a single sibling `<Route>` line at a stable position (end of the routes block), this falls under `tpm/parallel-safe-append-sections` mechanical keep-both resolution. **Note in tasks doc** that the App.tsx routes block will collide on every parallel task and that's expected.

**Exit criteria**:
- All 5 views render without runtime errors.
- Vitest component tests green for each view.
- Manual smoke: launch dev app, register a repo (the in-progress dogfood repo), confirm the sidebar populates and a card grid renders.
- AC9.g — at narrow window width (480px min from §8 design defaults), the 9-tab strip scrolls horizontally and the active tab auto-scrolls into view.
- AC9.k — markdown footer reads literally `Read-only preview. Open in Finder to edit.` (string match).

**Wave merge gate**:
- security: re-confirm AC9.e read-only invariant — no edit affordance, no save button, no command-trigger affordance in any view; confirm MarkdownPreview is the only path that renders user markdown content and that DOMPurify is in-line for every render call.
- performance: confirm card list rendering uses React 19 concurrent features (no re-render of the entire list on a single-card update); confirm sessionStore's selector functions return stable references for unchanged sessions.
- style: confirm CSS class naming matches the design notes token table (no ad-hoc `--my-color` variables); confirm i18n keys are referenced via the `t(key)` helper, not hardcoded strings.

**B1/B2 boundary check** — **THIS IS THE HIGHEST-RISK WAVE FOR B2 LEAKAGE**:
- T3.1 (MainWindow): card hover actions are exactly "Open in Finder" + "Copy path" (AC7.d). No "Send instruction" button greyed out. No third hover action of any kind.
- T3.2 (CardDetail): no "Edit" button, no "Save" button, no "Advance stage" button, no input field. The detail view's only interactive controls are tab switching + breadcrumb back + per-file "Reveal in Finder" buttons + theme is read-only display only.
- T3.3 (Settings): tabs are exactly General / Notifications / Repositories. No "Control Plane" tab. No reserved settings keys.
- T3.5 (CompactPanel): the "Open main" affordance focuses the main window; it does not invoke any specflow CLI.

Reviewer-security must explicitly cite each of these B2 reservations in its verdict footer for W3.

---

### W4 — OS surface integration (4 tasks, parallel within wave)

**Goal**: wire the Tauri OS-surface plugins — tray icon with stalled-count
badge, macOS Notification Center fire-once, window-state persistence,
Open-in-Finder / Copy-path system actions.

**Pre-conditions**: W3 merged (every UI affordance that triggers an OS-side
call exists in some form).

**Tasks (high-level)**:
- T4.1: `src-tauri/src/tray.rs` — `tauri-plugin-tray-icon` wiring; subscribe to store's stalled-count; render badge with the count per Architect's D6 (covers tray side of AC5.c stalled badge). macOS produces a visual badge overlay; Windows / Linux fall back to tooltip (per D6 trade-off, but Windows / Linux are out of B1 scope per Q-plan-3 — so this task is macOS-only).
- T4.2: `src-tauri/src/notify.rs` — `tauri-plugin-notification` wiring; consumes `stalled_set` transitions from `store.rs` (T1.2); fires one banner per crossing with no sound (AC6.d) per Architect's D11; receives renderer-supplied notification strings via `set_notification_strings()` IPC for AC11.d. Covers AC6.a–e fully.
- T4.3: Window-state plugin wiring (`tauri-plugin-window-state`) per Q-plan-5 — main window position + size persisted across launches, applied before first paint; compact panel position persisted separately. Settings-side toggle for always-on-top compact panel (AC10.b).
- T4.4: Finder + clipboard system actions — `open_in_finder(path)` IPC handler invoking `open` (macOS) for the feature directory (AC7.d, AC9.e header-strip "Open in Finder") and `open -R <abs_path>` for per-file reveal (AC9.h sub-file rows); `copy_to_clipboard(text)` IPC handler using `tauri-plugin-clipboard-manager`. Note: this task uses `std::process::Command::new("open")` which is shell-out, but it's NOT inside the polling loop — AC13.b's no-subprocess-in-polling invariant is preserved.

**Parallel-safe within wave**: YES — each task owns its own file (`tray.rs`, `notify.rs`, the window-state plugin init in `main.rs` is the one append-only collision, `Cargo.toml` deps append-only). T4.4's IPC handler additions to `ipc.rs` collide with W1's T1.5 baseline — but since W1 is already merged, T4.4 simply extends the existing IPC table by appending new commands; if T4.4 itself is paired with another T4.x task that also extends `ipc.rs`, those collide and require keep-both. **Note in tasks doc**: T4.1, T4.2, T4.3, T4.4 each may add to `Cargo.toml` and `main.rs` — expect keep-both resolution.

**Exit criteria**:
- Tray icon visible in the macOS menu bar with a numeric badge that updates within one polling cycle when stalled count changes.
- Notification Center banner fires exactly once per stalled transition; verifiable by a counter in the diagnostic log.
- Window position + size restore correctly across app quit/relaunch.
- "Open in Finder" opens the feature directory; "Reveal in Finder" selects the specific sub-file in a new Finder window.
- "Copy path" places the absolute path on the system clipboard.

**Wave merge gate**:
- security: confirm `open_in_finder()` validates the path is under one of the registered repository roots before invoking `open` (path-traversal boundary per check 2); confirm no `Command::new` invocations in the polling code path (AC13.b).
- performance: confirm tray-icon updates are throttled (one update per polling cycle, not one per session change); confirm notification firing does not block the polling tick.
- style: confirm `tray.rs` and `notify.rs` follow the same module structure as W1 modules; no commented-out code; consistent error handling per Architect's §4.

**B1/B2 boundary check**: T4.4's `open_in_finder` shells out to `open`, which is the **only** subprocess invocation in B1 — and it's a read-only operation (Finder window opening). Reviewer-security must confirm: (a) no shell-out to `bin/specflow-*`; (b) no shell-out to `git`; (c) no shell-out to any program that could mutate `.spec-workflow/**`. The `open` invocation must use argv-form (`Command::new("open").args(&["-R", path])`), not string-built shell commands (`.claude/rules/reviewer/security.md` check 4).

---

### W5 — Polish + structural verification harness + .dmg build (5 tasks, parallel within wave)

**Goal**: implement the structural verification seams that the dogfood
paradox forces (Architect's §8 Test Seams 3, 4, 6, 7), instrument the
per-cycle wall-clock for AC13.c, build the final `.dmg`, and smoke-launch
it on macOS. **This wave exists because of
`shared/dogfood-paradox-third-occurrence` — runtime exercise is deferred
to the next feature, so structural seams are the verify gate.**

**Pre-conditions**: W4 merged.

**Tasks (high-level)**:
- T5.1: `src-tauri/tests/poller_integration.rs` — Architect's Seam 3: `tempdir` fixture repo with `_template/`, `archive/`, `alpha/`, `bravo/`, `charlie/`, `delta/` (no STATUS.md), `echo/` (stage: archive — excluded), `foxtrot/` (in archive). Asserts discovered set = `{alpha, bravo, charlie}`, per-cycle read count = 3 (AC13.a), per-cycle wall-clock < interval at 2s/3s/5s (AC13.c). Replicate the fixture to 20 sessions to test the AC13.c upper bound synthetically.
- T5.2: `src-tauri/tests/seam4_no_writes.rs` — Architect's Seam 4: a build-time test (or `cargo test`) that greps `src-tauri/src/` for `OpenOptions::write` / `File::create` / `fs::write` against any path containing `spec-workflow` and fails the build if any hit is found. Covers AC3.d structurally.
- T5.3: `src/components/__tests__/MarkdownPreview.test.tsx` — Architect's Seam 7: fixture markdown source containing `<script>`, `onclick`, `javascript:` URL; assert all three are absent from rendered DOM. Plus `src/i18n/__tests__/parity.test.ts` — Architect's Seam 6: load `en.json` + `zh-TW.json`, assert key sets are equal. Plus `src/components/__tests__/IdleBadge.test.tsx` — Architect's verification for AC9.j: render the stalled badge in the detail header, assert via `getComputedStyle()` that no `animation` / `transition` property drives a repeating visual change.
- T5.4: Per-cycle wall-clock instrumentation in `poller.rs` (extending T1.3) — `let start = Instant::now(); ... ; let elapsed = start.elapsed(); emit polling_indicator { interval, last_tick_ms: elapsed.as_millis() };`. Logged at info level. Covers AC13.c instrumentation. Plus theme-switch frame-time observation harness (lightweight `console.time` wrapper for AC15.a).
- T5.5: Build the final unsigned `.dmg` via `tauri build --target universal-apple-darwin`; smoke-launch it on macOS and verify: app opens, Empty State shows on first launch (no settings file), adding a repo populates the sidebar, theme toggle works, language toggle works. Document the smoke procedure in `flow-monitor/README.md` for the next feature's first-real-session check (per dogfood-paradox memory's "Next feature after a dogfood-paradox feature" section).

**Parallel-safe within wave**: YES — T5.1, T5.2, T5.3, T5.4, T5.5 own disjoint files. Append-only collisions: `Cargo.toml` (T5.1, T5.2 may add dev-deps), `package.json` (T5.3 may add Vitest config tweaks), `flow-monitor/README.md` (T5.5). All resolve keep-both.

**Exit criteria**:
- All 7 Test Seams from Architect's §8 either implemented (Seams 1, 2, 3, 4, 5, 6, 7) or confirmed already-covered from prior waves (Seams 1, 2, 5 land in W1; Seam 7 setup lands in W2).
- Per-cycle wall-clock log emits a `last_tick_ms` value below the polling interval at the 20-session synthetic load.
- Unsigned `.dmg` launches on macOS without crashing.
- Empty State renders on first launch (no settings file).
- Theme toggle, language toggle, repo registration all work end-to-end on the smoke build.

**Wave merge gate**:
- security: re-run the full Seam 4 grep across the merged tree; confirm zero hits for write-call patterns against `**/spec-workflow/**`. Re-run the Seam 7 markdown XSS test and confirm no regression.
- performance: confirm AC13.c — at 20-session synthetic load with 3s polling interval, the per-cycle wall-clock stays below 1.5s (50% headroom). Confirm no shell-out in the polling code path (AC13.b re-verified).
- style: confirm the `flow-monitor/README.md` documents the dogfood paradox explicitly so the next feature's first-real-session check has a checklist to follow.

**B1/B2 boundary check**: this wave adds tests, instrumentation, and a `.dmg` build — no new product surfaces. Confirm no B2 stub appears in the smoke-launched app; confirm the smoke procedure documented in `flow-monitor/README.md` does not invoke any specflow CLI from the app itself.

## 5. Risk register

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R-1 | Tauri 2.x WKWebView quirks on macOS 25 (Darwin) — render glitches, IPC race conditions, plugin incompatibilities not yet flushed by the upstream community | **medium-high** | Pin Tauri to `2.2` (a known-stable patch line), exercise the framework end-to-end in W0's smoke build before any feature code lands. If a blocker surfaces, fall back to Tauri 2.1.x with documented downgrade. |
| R-2 | `tauri-plugin-window-state` is community-maintained; may have bugs on macOS 25 (Darwin) that surface as window-position drift or first-paint flashes | **medium** | Q-plan-5 locks it as in-scope but flagged as cuttable. If W4's T4.3 surfaces a blocker, drop the plugin and fall back to "no position memory" — a small UX regression, not a functional one. Document the cut in STATUS Notes. |
| R-3 | Dogfood paradox — verify is structural-only; the app cannot exercise itself end-to-end. Real bugs may only surface on the next feature's first real session | **high (process-level)** | Architect's Seams 1–7 cover every AC structurally; W5 implements them all. Per `shared/dogfood-paradox-third-occurrence`, this is **expected** for self-shipping mechanisms — runtime confirmation lands on the next feature after archive, with an early STATUS Notes line cited per the memory's "Next feature" section. |
| R-4 | Markdown XSS regression — DOMPurify default profile may strip benign content (e.g. `<details>` collapsibles, GFM checkbox inputs) and ship a degraded markdown preview | **medium** | W5 Seam 7 fixture covers `<script>` + `onclick` + `javascript:` only. Add a positive-control fixture (a markdown source using `<details>`, GFM tables, GFM task lists) to confirm legitimate content is preserved. If DOMPurify strips GFM checkboxes, allow the `type="checkbox" disabled` attribute via DOMPurify config — narrowest possible relaxation, security review required. |
| R-5 | macOS notification permission UX — first-launch users must grant notification permission; the app's onboarding flow doesn't currently address this | **low-medium** | W4 T4.2 adds an in-app banner / Settings indicator surfacing the denied permission state per PRD §6 "macOS Notification Center permission denied". The empty-state CTA in W3 T3.4 should mention "you'll see notifications when sessions stall" as a soft prompt before the OS-level dialog fires on first stalled-transition. |

## 6. Open questions deferred to /specflow:tasks

None at the wave-plan level. The five §6 architect-deferred questions are
all resolved above (Q-plan-1..5). One sub-decision lands at task-stage:
**which icon library** (W2 T2.3's StagePill, IdleBadge, etc., need an icon
set). Default at task time: Lucide (small, MIT-licensed, React 19
compatible). This is a one-line `npm install` decision that doesn't
affect the wave structure.

## 7. Memory citations

**Applied**:

- **`tpm/parallel-safe-requires-different-files`** — drove every wave's
  internal-parallelism analysis. W0 is sequential because every task
  edits the scaffold dependencies block (shared file). W1, W2, W3, W4,
  W5 are parallel within wave because each task owns its own primary
  file. W3 has the highest collision risk (the App.tsx router dispatcher);
  classified as append-only collision per the sibling rule and kept
  parallel.
- **`tpm/parallel-safe-append-sections`** — drove the keep-both
  resolution stance for: W1's `main.rs` `mod` declarations, W2's
  `App.tsx` provider wiring, W3's `App.tsx` routes block, W4's
  `Cargo.toml` deps, W5's `package.json` test config. All five waves
  carry a "expect append-only collisions, keep both" note in their
  task-stage briefing.
- **`tpm/same-file-sequential-wave-depth-accepted`** — considered;
  does not apply. The flow-monitor app is not a single-file CLI with N
  subcommands; it's a multi-file Tauri app. The pattern's N+2 wave
  count rule is not load-bearing here. The shape of W0–W5 (6 waves)
  is driven by the architecture's natural layers, not by dispatcher-arm
  serialization.
- **`tpm/reviewer-blind-spot-semantic-drift`** — informed the
  per-wave reviewer-style brief: every wave's reviewer-style pass
  must check that strings hardcoded in components match the
  `i18n/en.json` keys, not the other way around. Cross-artefact drift
  between component code and i18n JSON is the predicted gap-check
  finding for this feature.
- **`shared/dogfood-paradox-third-occurrence`** — drove the existence
  of W5 entirely. The wave exists because the app cannot exercise
  itself; structural verification via Architect's Seams is the verify
  gate; runtime exercise is deferred to the next feature. W5's task
  T5.5 explicitly documents the smoke procedure for the next
  feature's first-real-session check per the memory's "Next feature
  after a dogfood-paradox feature" section.

**Considered, not load-bearing**:

- **`tpm/briefing-contradicts-schema`** — would apply at /specflow:tasks
  when each task briefing cites a concrete API surface (e.g. the
  Tauri command signatures from Architect's §2 IPC table). At plan
  stage, the wave structure is paraphrase-tolerant; the rule binds
  later when individual task briefings concretize the contract.
- **`tpm/checkbox-lost-in-parallel-merge`** — applies at /specflow:tasks
  when the tasks doc itself becomes the parallel-merged artifact;
  not load-bearing at plan stage.
- **`tpm/tasks-doc-format-migration`** — does not apply; no format
  migration in flight.
- **`shared/local-only-env-var-boundary-carveout`** — Architect
  applied lightly in §4 Security; the same posture carries into the
  plan: B1 is local-only single-user no-auth; reviewer-security
  rule check 3 (input validation at boundaries) is satisfied by
  the registered-repo path-set check, not by general-purpose
  untrusted-input hardening.
- **`shared/skip-inline-review-scope-confirmation`** — not applicable
  at plan stage; relevant if the user invokes `--skip-inline-review`
  during /specflow:implement.

**Rules applied** (cited where they bind):

- `.claude/rules/bash/bash-32-portability.md` — applies to any
  helper bash that ships with the app (W0's CI workflow uses bash;
  W5's smoke-launch script is bash). No `readlink -f`, no `realpath`,
  no `jq`, no `mapfile`.
- `.claude/rules/bash/sandbox-home-in-tests.md` — applies to W5
  T5.1's poller integration test if it spawns any CLI that touches
  `$HOME`; current design uses pure Rust `tempdir` so this does not
  bind. If T5.1's design changes, the rule binds.
- `.claude/rules/common/no-force-on-user-paths.md` — Architect
  locked this in D8 for settings persistence; reinforced in W1 T1.4
  (read-merge-write-tmp + atomic-rename + `.bak` discipline) and W4
  T4.3 (window-state plugin must follow the same write discipline,
  or be cut per R-2).
- `.claude/rules/common/classify-before-mutate.md` — Architect
  applied in D12 for the read-only repository walker; reinforced in
  W1 T1.3 (closed-enum `classify_entry` is the only acceptable shape).
- `.claude/rules/reviewer/security.md` — applies at every wave
  merge gate; headline rule is W3's MarkdownPreview XSS-safety and
  W4's argv-form `Command::new("open")` invocation. Cross-references
  to checks 2, 4, 5 enumerated per-wave above.
- `.claude/rules/reviewer/performance.md` — applies at every wave
  merge gate; headline checks: no shell-out in tight loops (W1, W4),
  hook latency budget (N/A — this app ships no hooks), avoid eager
  loads (W2 lazy markdown import).
- `.claude/rules/reviewer/style.md` — applies at every wave merge
  gate; headline checks: match existing naming conventions (cross-cuts
  every wave), no commented-out code (cross-cuts), bash-32-portability
  for any helper bash (W0, W5).

## Team memory

Tier listing performed at task start:

- `~/.claude/team-memory/tpm/` — 4 entries
  (parallel-safe-requires-different-files, parallel-safe-append-sections,
  same-file-sequential-wave-depth-accepted, reviewer-blind-spot-semantic-drift).
- `.claude/team-memory/tpm/` — 3 entries
  (briefing-contradicts-schema, checkbox-lost-in-parallel-merge,
  tasks-doc-format-migration).
- `~/.claude/team-memory/shared/` — 2 entries
  (local-only-env-var-boundary-carveout, skip-inline-review-scope-confirmation).
- `.claude/team-memory/shared/` — 1 entry
  (dogfood-paradox-third-occurrence).

Applied (5 entries):

- **`tpm/parallel-safe-requires-different-files` (global)** —
  drove the per-wave parallelism analysis. Every "parallel-safe-within-
  wave: YES" claim cites the rule's file-set check.
- **`tpm/parallel-safe-append-sections` (global)** — drove the
  keep-both stance for the predictable append-only collisions in W1
  (mod decls), W2 (provider wiring), W3 (router routes), W4 (deps), W5
  (test config). Sibling-rule pairing with the strict rule above.
- **`tpm/reviewer-blind-spot-semantic-drift` (global)** — drove the
  reviewer-style cross-check on i18n key parity vs. hardcoded
  component strings; predicts the gap-check finding for this feature.
- **`shared/dogfood-paradox-third-occurrence`** — drove the existence
  of W5 and the structural-only verify posture. The wave map's W5
  exists entirely because of this rule; cited per-wave in the B1/B2
  boundary discipline.
- **`tpm/same-file-sequential-wave-depth-accepted` (global)** —
  considered and explicitly rejected; the flow-monitor app is not a
  single-file CLI with N subcommands. Documented to surface the
  rejection rationale (no future TPM should re-litigate by trying to
  collapse W0–W5 into a different shape).

# Tech — flow-monitor (B1: read-only dashboard)

_2026-04-19 · Architect_

## 1. Context & Constraints

### Existing stack in this repo

- This repo (`spec-workflow`) is a bash-3.2 / BSD-userland toolchain
  shipping `bin/specflow-*` shell scripts plus `.claude/agents/`
  prompt assets. There is **no existing desktop-app stack**: no
  Node.js, no Electron, no Rust, no Tauri, no Python beyond the
  `python3` one-liners used by `bin/specflow-install-hook` for
  settings.json mutation.
- The flow-monitor app is therefore a **greenfield subsystem** that
  lives alongside the existing bash toolchain, not a refactor of
  it. The bias-toward-existing-stack rule still applies to any
  helper scripts that ship with the app (install / uninstall /
  packaging) — those remain bash-3.2 / BSD-safe per
  `.claude/rules/bash/bash-32-portability.md`. App-internal code
  (Rust, JS, whatever the framework picks) is governed by the
  framework's own conventions.

### Hard constraints (from PRD)

- **Form factor**: native desktop app (locked at brainstorm).
- **First-class platform**: macOS (Darwin 25.3.0). Windows / Linux
  are nice-to-have; B1 may ship macOS-only if cross-platform
  carries disproportionate cost (Decision D1 makes the call).
- **Read-only**: no writes to user-owned `.spec-workflow/**` state
  (R1, R3, AC3.d). Polling is `open + read + close` only.
- **Polling budget (R13)**: 3-second default cycle; 20 sessions
  across 5 repos must complete within the cycle without backlog.
  No subprocess spawn during polling.
- **No `--force` defaults on user-owned paths** — applies to the
  settings store (R14, AC14.c) and the polling code path.
  Cross-references `.claude/rules/common/no-force-on-user-paths.md`
  and `architect/no-force-by-default` (memory).
- **Atomic writes** for settings.json equivalents — read-merge-
  write-tmp + `os.replace` (or platform equivalent), per
  `architect/settings-json-safe-mutation` (memory) and
  `.claude/rules/common/no-force-on-user-paths.md` AC14.c.
- **Classify before mutate** for filesystem state — applies to the
  session-discovery walker (R1) and any settings migration code,
  per `.claude/rules/common/classify-before-mutate.md` and
  `architect/classification-before-mutation` (memory).
- **XSS-safe markdown** in the detail view (R9, AC9.e), per
  `.claude/rules/reviewer/security.md` checks 4 and 5.
- **Single instance** assumed (R14); no multi-instance lock in B1.

### Soft preferences

- **Small binary, fast cold start** — the user keeps the compact
  panel always-on-top, so the app must not feel like an Electron
  IDE. Smaller bundle and lower idle memory are preferred.
- **Web-stack UI** — the design mockup is HTML/CSS, the surface is
  card-based, theming is CSS custom properties. A web-renderer
  framework matches the mockup naturally; switching to a native
  toolkit (SwiftUI / WinUI / GTK) would force a parallel re-build
  per platform.
- **One language for the surface, one for any system glue** —
  reduce cognitive load for a one-person codebase.

### Forward constraints from B2 (control plane)

- **B2 will add**: send instruction into a live Claude Code
  session, invoke `bin/specflow-*` from the UI, possibly
  SessionStart/Stop hook integration (PRD §3 Non-goals;
  brainstorm A2).
- **What B1 must not preclude**:
  - The polling state store must be addressable by a future
    write-side coordinator (so B2 can attach without re-architecting
    state).
  - The IPC surface (renderer ↔ core) must support adding new
    one-way commands without breaking existing ones (additive
    schema only).
  - The settings file format must be forward-extensible —
    additional top-level keys must not break a B1 reader.
- **What B1 must NOT pre-wire**: no scaffolded "Send instruction"
  button greyed out in the UI, no stub IPC channel for control
  commands, no settings keys reserved for B2 features (R7
  contract). Every B2 affordance is **explicitly absent** from B1
  per AC7.d / AC9.e.

## 2. System Architecture

### Module layout (Tauri-shaped)

```
flow-monitor (Tauri app)
│
├── src-tauri/                   # Rust core (privileged)
│   ├── main.rs                  # app entry, window/tray setup
│   ├── poller.rs                # filesystem polling cycle
│   ├── status_parse.rs          # STATUS.md → SessionState (pure)
│   ├── store.rs                 # in-memory session map + diff
│   ├── settings.rs              # settings.json read/write (atomic)
│   ├── notify.rs                # macOS Notification Center bridge
│   ├── tray.rs                  # menu-bar icon + stalled badge
│   └── ipc.rs                   # tauri::command surface (read-only)
│
└── src/                         # web UI (renderer)
    ├── main.ts                  # app bootstrap, router
    ├── views/
    │   ├── MainWindow.tsx       # card grid, sidebar, toolbar
    │   ├── CardDetail.tsx       # master-detail drill-in
    │   ├── CompactPanel.tsx     # floating always-on-top
    │   ├── Settings.tsx         # tabs: General/Notifications/Repos
    │   └── EmptyState.tsx       # no-repos first-run
    ├── components/
    │   ├── SessionCard.tsx
    │   ├── StagePill.tsx
    │   ├── IdleBadge.tsx
    │   └── MarkdownPreview.tsx  # markdown-it + DOMPurify
    ├── i18n/
    │   ├── en.json              # English strings
    │   └── zh-TW.json           # Traditional Chinese strings
    ├── stores/
    │   ├── sessionStore.ts      # subscribes to poller events
    │   ├── settingsStore.ts     # mirrors settings.json
    │   └── themeStore.ts        # light/dark, persisted
    └── styles/
        └── theme.css            # CSS custom properties (D9)
```

### Data flow — happy path (steady-state polling)

```
                  [3s tick]
                      │
                      ▼
  ┌──────────────────────────────────────┐
  │  poller.rs (Rust, async tokio task)  │
  │  for each registered_repo:           │
  │    walk .spec-workflow/features/*/   │
  │    for each STATUS.md:               │
  │      open → read → close             │
  │      → status_parse::parse()         │
  └──────────────────────────────────────┘
                      │
                      ▼
  ┌──────────────────────────────────────┐
  │  store.rs                            │
  │  diff(prev_map, new_map) →           │
  │    {added, removed, changed,         │
  │     stalled_transitions}             │
  └──────────────────────────────────────┘
                      │
        ┌─────────────┼──────────────┐
        ▼             ▼              ▼
  ┌──────────┐  ┌──────────┐   ┌──────────┐
  │ notify.rs│  │  ipc.rs  │   │ tray.rs  │
  │ fire on  │  │ emit     │   │ update   │
  │ stalled  │  │ event to │   │ badge    │
  │ trans    │  │ renderer │   │ count    │
  └──────────┘  └──────────┘   └──────────┘
                      │
                      ▼
  ┌──────────────────────────────────────┐
  │  Renderer (web UI)                   │
  │  sessionStore.subscribe(event):      │
  │    update reactive state →           │
  │    re-render affected cards          │
  └──────────────────────────────────────┘
```

### IPC surface (Rust ↔ Renderer, read-only in B1)

| Direction | Name | Payload | Purpose |
|---|---|---|---|
| R→C | `list_sessions()` | — | initial fetch on UI mount |
| R→C | `get_settings()` | — | initial settings load |
| R→C | `update_settings(patch)` | partial settings | user changed a setting in UI |
| R→C | `add_repo(path)` | abs path | add a registered repo |
| R→C | `remove_repo(path)` | abs path | remove a registered repo |
| R→C | `read_artefact(repo, slug, file)` | triple | detail-view markdown read (on demand) |
| R→C | `open_in_finder(path)` | abs path | shells out to `open` (R/Reveal) |
| R→C | `copy_to_clipboard(text)` | string | copy path action |
| R→C | `set_compact_panel_open(bool)` | bool | toggle floating panel |
| R→C | `set_always_on_top(bool)` | bool | persisted in settings |
| C→R | `sessions_changed` (event) | diff | poller emitted new state |
| C→R | `settings_changed` (event) | full settings | settings file changed |
| C→R | `polling_indicator` (event) | `{interval, last_tick_ms}` | sidebar footer feed |

**B2 reservation note**: any command that writes into a live Claude
Code session, invokes `bin/specflow-*`, or mutates a feature
artefact is **absent**. B2 will add commands following the same
`tauri::command` shape; B1 contains no placeholder, no greyed-out
button, no reserved enum slot.

### Component responsibilities

- **`poller.rs`** — owns the 3s interval (configurable 2–5s);
  iterates registered repos sequentially; for each repo, lists
  `.spec-workflow/features/*/STATUS.md` (one `read_dir` + filtered
  list); for each STATUS.md, performs one `read_to_string`. Records
  per-cycle wall-clock for AC13.c. Excludes `_template/` and
  `archive/**` by name / path filter.
- **`status_parse.rs`** — pure function: `parse(content: &str,
  mtime: SystemTime) → SessionState`. No I/O, no side effects.
  This is the dogfood-paradox test seam (see §8).
- **`store.rs`** — holds the session map (`HashMap<SessionKey,
  SessionState>`); produces a diff against the previous tick;
  identifies stalled transitions (idle crossing the stalled
  threshold) for `notify.rs`.
- **`settings.rs`** — read-once at app launch, write-on-mutate
  with atomic swap (D7 + D8). Holds in-memory mirror; never
  re-reads from disk during polling (AC14.b).
- **`notify.rs`** — wraps Tauri's `tauri-plugin-notification`
  (macOS → `UserNotifications.framework`; Windows / Linux → toast
  / D-Bus where supported). Dedupe key in-memory only (D11).
- **`tray.rs`** — wraps `tauri-plugin-tray-icon`; maintains a
  badge count = number of currently-stalled sessions.
- **`ipc.rs`** — exposes the table above as `tauri::command`
  handlers; each command is a thin wrapper over store / settings /
  filesystem reads.

## 3. Technology Decisions

### D1. Desktop framework

- **Options considered**: (A) Tauri 2.x (Rust core + system
  webview); (B) Electron (Node + Chromium); (C) native per-
  platform (SwiftUI on mac, WinUI on Windows, GTK on Linux); (D)
  Wails (Go + system webview).
- **Chosen**: **Tauri 2.x** (cross-platform mac + Windows + Linux;
  ship macOS first, others as best-effort).
- **Why**: (1) Smallest bundle of the cross-platform options
  (~10 MB for the Tauri app vs ~100 MB for Electron) — directly
  matches the soft preference for an always-on-top panel that
  doesn't feel like an IDE. (2) Tauri 2.x has first-class plugins
  for the four exact OS surfaces this PRD requires: tray icon
  (R10 + design item 5), Notification Center (R6),
  always-on-top window (R10), file-system access (R3). (3) Rust
  core gives precise control over the polling cycle wall-clock
  budget (R13 / AC13.c) and zero GC pauses, which Electron's V8
  cannot match for a 3s timer. (4) System webview (WKWebView on
  mac, WebView2 on Windows, WebKitGTK on Linux) renders the
  mockup's CSS-custom-property theming natively without bundling
  Chromium. (5) Tauri 2.x is the maintained line as of 2026; v1
  is end-of-life.
- **Tradeoffs accepted**: Rust core means a steeper learning
  curve than Electron's pure-JS model; this is a single-developer
  codebase and Rust ergonomics for I/O are now mature. Tauri's
  Linux story depends on WebKitGTK quality, which is the
  weakest leg — flagged as best-effort, not blocking. SwiftUI
  (option C) was rejected because the user works cross-platform
  per the brainstorm framing; Electron (option B) was rejected
  on bundle size and idle memory; Wails (option D) was rejected
  because the team has no Go expertise in this repo and Tauri's
  plugin ecosystem is more mature for the specific surfaces
  needed.
- **Reversibility**: medium. The renderer (TypeScript / web
  components) is portable; the Rust core would need to be
  re-implemented. A switch to Electron later would mean
  porting `poller.rs`, `status_parse.rs`, `settings.rs`, and
  `ipc.rs` to Node. Worst-case ~1 week of work.
- **Requirement link**: framework choice driven by R6, R10, R13.

### D2. Card detail surface shape

- **Options considered**: (A) modal overlay; (B) side-drawer
  (slide-in from right); (C) master-detail navigation in the
  main window.
- **Chosen**: **master-detail navigation** in the main window
  (Designer's locked recommendation; PRD §R9 [CHANGED 2026-04-19]
  confirms).
- **Why**: The detail view is heavyweight (full markdown
  preview, stage checklist, Notes timeline, file tabs) and would
  feel cramped in either a modal or a drawer. The breadcrumb
  back-arrow + filter-state restoration (AC9.f) is the standard
  master-detail navigation pattern users already know from email
  clients and file explorers. Modal would also clash with the
  always-on-top compact panel (R10) being a separate window.
- **Tradeoffs accepted**: Loses the "preserve grid context
  visually behind the detail" benefit a side-drawer would give;
  mitigated by the breadcrumb back-arrow restoring filter / sort
  / repo state on return (AC9.f).
- **Reversibility**: high. The detail view is one route in the
  renderer's router; switching to a drawer or modal is a
  template-level change with no backend impact.
- **Requirement link**: R9, AC9.a–k.

### D3. Settings file location and format

- **Options considered for path**: (A) `~/Library/Application
  Support/<AppName>/config.json` (macOS standard);
  (B) `~/.config/flow-monitor/config.json` (XDG-style); (C) a
  Tauri-managed app-data dir (`tauri::api::path::app_data_dir`).
- **Chosen**: **Tauri-managed `app_data_dir`** which resolves to:
  - macOS: `~/Library/Application Support/com.flow-monitor.app/`
  - Windows: `%APPDATA%\com.flow-monitor.app\`
  - Linux: `~/.local/share/com.flow-monitor.app/`

  File name: `settings.json`. Format: JSON, top-level object,
  versioned with a `schema_version: 1` key.
- **Why**: Using Tauri's path resolver gives correct platform
  conventions for free; on macOS this is the standard Application
  Support path the PRD §7.3 expected. JSON is the natural
  cross-platform format; the team already uses Python's `json`
  for `bin/specflow-install-hook`'s settings.json mutation, so
  the read-merge-write discipline (D7) is already familiar.
- **Tradeoffs accepted**: A bare-cat reader (e.g. a shell script
  inspecting the file) needs to parse JSON instead of a `.ini`;
  acceptable since no shell scripts read this file in B1.
- **Reversibility**: medium. A schema migration path is
  required (D8).
- **Requirement link**: R14.

### D4. Markdown rendering library (R9)

- **Options considered**: (A) `markdown-it` + `DOMPurify` (JS,
  battle-tested, plugin-rich); (B) `marked` + `DOMPurify` (JS,
  smaller); (C) `react-markdown` (React-native, sanitises by
  default via rehype); (D) Rust-side rendering (`pulldown-cmark`)
  with HTML sent over IPC.
- **Chosen**: **`markdown-it` (^14) + `DOMPurify` (^3)** in the
  renderer, called via a thin `MarkdownPreview` component. No
  inline scripts, no link-target relaxation, no HTML passthrough
  beyond what DOMPurify's default profile permits.
- **Why**: (1) `markdown-it` has stable, well-audited XSS
  posture when paired with DOMPurify; the renderer never sees a
  raw HTML string from the markdown content. (2) The
  specflow markdown documents use plain CommonMark + GFM tables
  + GFM task-list checkboxes — `markdown-it` handles all three
  with documented plugins (`markdown-it-task-lists`). (3)
  Rendering renderer-side keeps the IPC payload small (raw text,
  not pre-rendered HTML) and keeps the Rust core focused on
  filesystem I/O. (4) `react-markdown` (option C) was rejected
  because it depends on the React tree shape; if we later switch
  the UI framework (Vue / Svelte / SolidJS) the markdown layer
  would need re-porting.
- **Tradeoffs accepted**: Two npm dependencies (markdown-it +
  DOMPurify) instead of one. DOMPurify must be kept up-to-date
  via dependabot or manual review — acceptable; both libs have
  decade-long maintenance records.
- **Reversibility**: high. Swap is a one-component change.
- **Requirement link**: R9, AC9.e; security: `.claude/rules/
  reviewer/security.md` check 5.

### D5. HTML mockup (`02-design/mockup.html`) display strategy

- **Options considered**: (A) in-app webview (Tauri's
  `WebviewWindow` opens the file in a sandboxed pop-up); (B)
  `Reveal in Finder` only (per AC9.h locked); (C) in-tab iframe
  rendering.
- **Chosen**: **`Reveal in Finder` only** (option B), per AC9.h
  [CHANGED 2026-04-19] which locks this for the `02-design` tab's
  sub-file rows.
- **Why**: PRD AC9.h is unambiguous: every sub-file row in the
  `02-design` tab has exactly one action, "Reveal in Finder".
  An in-app webview (option A) would add a scroll-and-focus
  mode on a single file with no clear UX win, and would couple
  B1 to the security posture of arbitrary user-authored HTML
  (the mockup files are user-owned but design intent is to
  treat them as opaque external artefacts in B1). An iframe
  (option C) has the same security cost with worse UX.
- **Tradeoffs accepted**: User must leave the app to view the
  mockup; acceptable since the mockup is a designer's work
  product the user may want to open in their preferred browser
  with dev-tools anyway.
- **Reversibility**: high. Adding an in-app preview later is
  additive (a second action button on the row).
- **Requirement link**: R9, AC9.d, AC9.h.

### D6. Menu-bar icon implementation (R10 + design item 5)

- **Options considered**: (A) Tauri's official
  `tauri-plugin-tray-icon` (cross-platform tray surface); (B)
  hand-roll macOS `NSStatusItem` via `objc2` crate (mac-only);
  (C) third-party Rust tray crate (`tray-icon`).
- **Chosen**: **`tauri-plugin-tray-icon` (option A)**.
- **Why**: First-party Tauri plugin, maintained alongside the
  framework; supports macOS menu bar, Windows system tray, and
  Linux system tray (where supported). Badge count for stalled
  sessions is achieved by re-rendering the icon image with a
  number overlay (mac NSStatusItem supports this natively;
  Windows and Linux fall back to a tooltip-only count, which is
  acceptable for B1's macOS-first posture).
- **Tradeoffs accepted**: The Linux tray story is the weakest
  (some desktop environments hide system trays by default);
  acceptable since Linux is best-effort. On Windows, the badge
  is tooltip-only rather than visually overlaid; flag this as a
  known cross-platform difference for QA.
- **Reversibility**: medium. Switching to option B would re-
  build the macOS path; the cross-platform fallback would need
  to be re-built too.
- **Requirement link**: R10, design item 5.

### D7. Polling implementation primitive (R13)

- **Options considered**: (A) `tokio::time::interval` (async
  fixed-period timer in Rust); (B) OS filesystem watcher
  (`notify` crate using FSEvents on mac, inotify on Linux,
  ReadDirectoryChangesW on Windows); (C) hybrid — watcher with
  debounced rescan plus a 30s safety poll.
- **Chosen**: **`tokio::time::interval` (option A)** with a 3s
  default tick, configurable 2–5s per R4.
- **Why**: (1) Filesystem watchers (option B) sound efficient
  but have known correctness gaps in this exact use case:
  STATUS.md mtime updates from atomic-rename writers (the
  pattern this repo uses for STATUS.md) on macOS sometimes fail
  to deliver an FSEvent because the inode changes; a missed
  event means a session looks stale that is not. (2) A simple
  fixed-period poller has predictable wall-clock behaviour
  (AC13.c is straightforwardly verifiable: log
  `start_instant.elapsed()` per cycle); a watcher's debounce-
  plus-rescan model has many more failure modes to document and
  test. (3) The polling work per cycle is small —
  one `read_dir` per repo + one `read_to_string` per session,
  with 20 sessions across 5 repos that's ~25 syscalls every
  3 seconds, which is comfortably below any meaningful budget.
  (4) Hybrid (option C) inherits both surfaces' failure modes;
  the simplicity of option A wins for B1.
- **Tradeoffs accepted**: Up to 3s of latency between a
  STATUS.md change and the UI reflecting it. Acceptable per the
  PRD's chosen polling model. Wakes the system every 3s even
  when idle; mitigated by the small per-cycle work.
- **Reversibility**: high. Swap to a watcher later by
  re-implementing `poller.rs` against the same store interface;
  no UI change needed.
- **Requirement link**: R3, R4, R13, AC13.a–c.

### D8. Settings persistence — read-merge-write with atomic swap

- **Options considered**: (A) Tauri's built-in plugin-store
  (`tauri-plugin-store`); (B) hand-rolled
  read-merge-write-tmp + `std::fs::rename` (atomic on POSIX
  and on NTFS for same-volume); (C) sqlite via
  `tauri-plugin-sql`.
- **Chosen**: **Hand-rolled read-merge-write + atomic rename
  (option B)**.
- **Why**: Per `architect/settings-json-safe-mutation` memory
  and `.claude/rules/common/no-force-on-user-paths.md`, the
  required discipline is: read existing → merge in-place →
  write to `<file>.tmp` → backup the old file as `<file>.bak`
  → `rename(tmp, file)`. Tauri's plugin-store (option A) does
  not give first-class control over the backup step or the
  exact write order. SQLite (option C) is overkill for a
  single-instance app with <50 settings keys and complicates
  the schema-migration path.
- **Tradeoffs accepted**: ~30 lines of Rust I/O code instead
  of a one-line library call. Acceptable: the discipline is
  the value.
- **Schema migration**: a top-level `schema_version: 1` key
  is read first; if a future B2 ships `schema_version: 2`,
  B1's reader treats unknown top-level keys as
  forward-compatible (preserves them on rewrite) and only
  writes `schema_version: 1` itself. This guarantees a B2 →
  B1 downgrade does not lose user data.
- **Reversibility**: high. The settings I/O is one module.
- **Requirement link**: R14, AC14.a–c; cross-references
  `.claude/rules/common/no-force-on-user-paths.md`,
  `architect/settings-json-safe-mutation`.

### D9. Theming — CSS custom properties

- **Options considered**: (A) CSS custom properties (`--token`)
  toggled via `html.dark` class, persisted in localStorage
  mirror of `theme: 'light' | 'dark'` in settings.json; (B)
  styled-components / emotion theme provider; (C) Tailwind dark-
  mode `dark:` variants.
- **Chosen**: **CSS custom properties (option A)**.
- **Why**: The design mockup already uses this exact pattern
  (per `02-design/notes.md` "Decision: ship both light and dark
  modes in B1" — "implemented in the mockup via CSS custom
  properties on `html.dark` and a localStorage-persisted
  toggle"). Re-implementing in styled-components or Tailwind
  would re-do the work for no gain. The token table in design
  notes maps 1:1 to CSS variable names.
- **Tradeoffs accepted**: CSS custom properties have no
  build-time validation; a typo in a token name silently
  falls through to the inherited value. Mitigated by a single
  `theme.css` file owning the token contract.
- **Persistence**: theme stored in `settings.json` under the
  `theme` key (`'light' | 'dark'`); on app launch, the value is
  read once and applied as the `html.dark` class before the
  first paint. localStorage is **not** the source of truth in
  the shipped app (only in the mockup); the settings.json store
  is. AC15.b's "persists across restart" is satisfied by the
  same atomic-write discipline (D8).
- **Reversibility**: medium. Switching to a runtime theme
  provider would touch every component; switching token names
  is a sed across `theme.css`.
- **Requirement link**: R15, AC15.a–f.

### D10. i18n library (R11)

- **Options considered**: (A) `i18next` + framework binding
  (e.g. `react-i18next`); (B) a hand-rolled lookup over a flat
  JSON dictionary (`en.json`, `zh-TW.json`); (C) framework-
  native solution (e.g. SolidJS's `solid-i18n`).
- **Chosen**: **Hand-rolled flat-JSON lookup (option B)**.
- **Why**: B1 has exactly two locales (en, zh-TW) and no
  pluralisation needs (the PRD ACs do not mention any "1 item /
  N items" string); `i18next` brings ~20 KB of runtime for
  features the spec does not use. A flat-JSON `t(key)` lookup
  with React-context (or framework equivalent) live update on
  language switch (AC11.b: "within one frame, no app restart")
  is ~30 lines of code. Default locale is English; no auto-
  detect (AC11.e) — the lookup never reads `navigator.language`.
- **Tradeoffs accepted**: If B2 (or B1 polish) needs
  pluralisation or interpolation features, swapping to
  `i18next` is a same-shape replacement (`t(key, vars)` API
  is identical).
- **Notification language (AC11.d)**: the Rust-side
  `notify.rs` does not have direct access to the renderer's
  i18n state. The renderer therefore generates the
  notification title and body strings on the language-toggle
  side and passes them to a `set_notification_strings()` IPC
  command; the Rust core stores the most-recent strings and
  uses them on the next stalled-transition. This avoids
  duplicating the en / zh-TW strings on the Rust side.
- **Reversibility**: high. Swap to i18next is a one-file
  change to `i18n/index.ts`.
- **Requirement link**: R11, AC11.a–e.

### D11. Notification dedupe key (R6)

- **Options considered**: (A) per-session boolean flag
  (`stalled_now: bool`) held in-memory only; (B) per-session
  flag persisted to disk (so a stalled session that became
  stalled while the app was off does not re-notify on next
  launch); (C) `(slug, transition_timestamp_to_minute)` tuple
  persisted to disk.
- **Chosen**: **In-memory per-session boolean flag (option A)**.
- **Why**: PRD §7.8 explicitly says "persistence not required
  across app restarts since a relaunch is a legitimate
  re-evaluation". App relaunch should re-notify on any
  currently-stalled session — the user just relaunched the app
  and may have missed the original notification (especially if
  they restarted because of a crash or OS update). The dedupe
  invariant is **within a single app run**, not across runs.
- **Tradeoffs accepted**: A user who relaunches the app while
  N sessions are stalled will see N notification banners on
  startup. Acceptable: the user just opened the app, they are
  looking at it. To soften this, the renderer can suppress the
  dedupe-fire for the first 2 polling cycles after launch (a
  "warm-up" window where state transitions don't notify) —
  flagged as a polish item, not a tech blocker.
- **State shape**: `stalled_set: HashSet<SessionKey>` in the
  store. Transition: `stalled_set.insert(key)` returns `true`
  if newly stalled → fire notification; `false` if already in
  set → no fire. Going non-stalled: `stalled_set.remove(key)`.
- **Reversibility**: high. Adding persistence is one
  serialiser at app shutdown + one deserialiser at startup.
- **Requirement link**: R6, AC6.a–e.

### D12. Repository discovery — classify-before-mutate applied to read-only walking

- **Options considered**: (A) `walkdir::WalkDir` with depth
  limit; (B) explicit `read_dir` of
  `<repo>/.spec-workflow/features/`; (C) glob-pattern walk.
- **Chosen**: **Explicit `read_dir` of
  `<repo>/.spec-workflow/features/` (option B)** with a closed
  enum classifier `classify_entry(entry) → SessionKind`.
- **Why**: Per `architect/classification-before-mutation`
  memory and `.claude/rules/common/classify-before-mutate.md`,
  filesystem reads benefit from the same closed-enum
  classification as filesystem writes — the test harness
  becomes trivial (one fixture per enum value). Closed enum:
  `Session(slug)`, `Template`, `NotASession(reason)`. The
  walker collects `Session` entries, drops the rest, logs
  `NotASession` with reason at debug level.
- **Why not WalkDir**: depth-limited recursion would re-visit
  every file inside every feature directory on every poll
  cycle — a budget violation per AC13.a (which limits
  per-cycle reads to one stat + one read of each STATUS.md).
- **Reversibility**: high.
- **Requirement link**: R1, AC1.a–d, R13, AC13.a.

## 4. Cross-cutting Concerns

### Error handling

- **Polling errors**: a single repo failing (path no longer
  exists, permission denied) does not abort the cycle; the
  repo's session set becomes empty and a `path_not_found`
  state is emitted to the sidebar (per PRD §6 "Repository
  moves or is deleted while running"). The error is logged at
  warn level; one log line per occurrence per cycle to avoid
  flooding.
- **Parse errors**: `status_parse::parse()` is total — every
  malformed STATUS.md returns a `SessionState` with
  `stage: Stage::Unknown` and `last_activity: file_mtime`
  (per PRD §6 "STATUS.md is malformed or partial mid-write").
  Diagnostic log entry, no user-surfacing error.
- **Notification permission denied**: `notify.rs` returns a
  silent `Ok(())` on permission denied; the in-app banner /
  Settings indicator (PRD §6 "macOS Notification Center
  permission denied") shows the denied state.
- **Settings file corrupt**: on launch, if `settings.json`
  exists but parses as invalid JSON, the corrupt file is
  renamed to `settings.json.corrupt-<epoch>` (no overwrite),
  a fresh defaults file is written, and the user is shown a
  one-line in-app banner. Cross-references
  `architect/settings-json-safe-mutation` (the backup-before-
  overwrite discipline applies even to corruption recovery).

### Logging

- **Diagnostic log**: rotating file under app data dir
  (`<app_data>/logs/flow-monitor.log`), max 1 MB per file,
  3 files retained. Levels: `error` / `warn` / `info` /
  `debug`. Default at `info`. Tauri-side via `tracing` crate;
  renderer-side via console only (no file write from renderer).
- **No telemetry**: no network egress at all in B1.

### Security

- **Read-only invariant** (R3): the Rust core has zero
  filesystem-write code paths against `.spec-workflow/**`;
  `cargo deny` or a manual grep for `OpenOptions::write` in
  any file matching `**/spec-workflow/**` is a static check.
- **XSS** (R9): all rendered markdown passes through
  `DOMPurify.sanitize()` with the default profile (no
  custom relaxation). Inline scripts, event handlers, and
  `javascript:` URLs are stripped.
- **IPC surface**: every `tauri::command` validates its
  argument types via Tauri's serde-based deserialisation;
  path arguments are canonicalised and checked against the
  set of registered repository roots before any file read
  (a path-traversal boundary check per
  `.claude/rules/reviewer/security.md` check 2).
- **Operator boundary carveout**: per
  `shared/local-only-env-var-boundary-carveout`, this is a
  local-only single-user no-auth tool; `read_artefact()`
  reads from paths derived from registered repos that the
  user themselves added through the folder picker. The
  validation discipline above is still applied as a defense-
  in-depth measure, but the boundary is the user's own
  filesystem permissions.

### Testing strategy (feeds Developer's TDD)

- **Unit tests (Rust)**: `status_parse.rs` has fixture-
  driven tests (one fixture per branch of the parse logic);
  `store.rs` has diff-table tests; `settings.rs` has
  round-trip tests (write then read, assert byte-identical).
- **Integration tests (Rust)**: `poller.rs` is exercised
  against a `tempdir` fixture repo with a `_template/`,
  an `archive/` dir, and 3 active sessions; the test asserts
  the discovered session set, the STATUS.md read count, and
  the per-cycle wall-clock budget (AC13.c).
- **Renderer tests**: component-level tests with the chosen
  framework's test harness (e.g. Vitest + Testing Library);
  i18n parity check (every key in `en.json` has a matching
  key in `zh-TW.json`); markdown sanitiser check (a fixture
  `<script>` block in a markdown source is dropped from the
  rendered output).
- **End-to-end**: out of scope for B1; the dogfood paradox
  applies (see §6 of PRD and §8 below).

### Performance

- **Polling cycle budget (AC13.c)**: instrumented; the
  `poller.rs` cycle records `start.elapsed()` and emits it
  via the `polling_indicator` event. CI has no soak test
  (synthetic fixture only).
- **Markdown render**: lazy — only the active tab's
  markdown is parsed. Switching tabs reparses; caching is
  out of scope for B1 (revisit if the user reports lag on a
  large `06-tasks.md`).

## 5. Blocker questions

**None.** All eight PRD §7 architect questions are resolved
in §3 above (D1–D8 plus D9–D12 for theming, i18n, dedupe,
discovery). Proceed to `/specflow:plan`.

## 6. Open questions deferred to plan

These are not blocking the tech doc but TPM should resolve
during `/specflow:plan`:

- **Q-plan-1**: Specific Tauri version pin and minimum Rust
  toolchain version. Recommendation: Tauri 2.x (latest stable
  at plan time) and Rust MSRV matching Tauri's published
  MSRV. TPM picks the exact pin in `Cargo.toml`.
- **Q-plan-2**: Renderer UI framework — React 19, SolidJS,
  Svelte 5, or Vue 3. The architecture in §2 is framework-
  agnostic at the component-name level. Recommendation:
  React 19 (largest ecosystem, the team has the most
  templates to crib from); but any of the four are
  compatible with the IPC contract and the markdown choice.
- **Q-plan-3**: Build / packaging targets — `.dmg` for macOS
  (yes), `.msi` for Windows (yes if cross-platform ships in
  B1), `.AppImage` / `.deb` for Linux (best-effort). Code
  signing for macOS (Apple Developer ID) is a release-time
  concern; not blocking the build.
- **Q-plan-4**: CI matrix. Recommendation: macOS-latest
  runner only for B1 (matches "macOS first-class" lock);
  Windows / Linux CI added when those targets become
  blocking.
- **Q-plan-5**: Window-state persistence — should the
  main window's last position and size be remembered? Tauri
  has `tauri-plugin-window-state` for this. Not in PRD;
  small UX polish; TPM decides whether to include in B1
  scope.

## 7. B2 reserved interfaces

Explicit list of surfaces left **architecturally extensible**
in B1 but **not wired** in B1 (no stub UI, no greyed buttons,
no reserved keys per PRD R7 contract):

1. **`tauri::command` namespace**: the `ipc.rs` command
   table (§2) is read-only in B1. B2 will add commands of
   the form `send_instruction(repo, slug, text)`,
   `invoke_specflow(repo, slug, command, args)`, etc.
   Adding new `tauri::command`-decorated functions does not
   break existing ones. **No stub commands in B1.**
2. **Settings schema**: `schema_version: 1` is the B1
   shape. B2 may bump to `schema_version: 2` and add keys
   like `control_plane_enabled`, `instruction_history_max`.
   B1's read-merge-write discipline (D8) preserves unknown
   top-level keys on rewrite, so a B2 → B1 downgrade is
   safe. **No B2 keys reserved in B1's defaults.**
3. **Store event channel**: the `sessions_changed` event
   carries a diff struct. B2 may extend the diff struct
   with additional optional fields (e.g. `control_state`).
   Renderer code in B1 must use serde with `default = ...`
   on any field it depends on, so a missing optional field
   from a B2-emitted event is tolerated. **No optional B2
   fields declared in B1.**
4. **Hook integration**: B2 may install Claude Code
   SessionStart / Stop hooks for live-state detection. B1
   neither installs nor reads any such hook. The polling
   cycle is the sole state source in B1.
5. **Card hover actions / detail-view actions**: per
   AC7.d and AC9.e, only "Open in Finder" and "Copy path"
   appear. B2 will add "Send instruction…", "Advance
   stage", etc. **B1 ships zero placeholder buttons.**

## 8. Test seams (dogfood paradox)

Per `shared/dogfood-paradox-third-occurrence`: the flow-
monitor cannot observe its own development sessions because
no card exists for `20260419-flow-monitor` until the app
ships. The test seams below let QA-tester structurally
verify the polling code path against fixture STATUS.md
files without needing a live Claude Code session.

### Seam 1 — `status_parse::parse()` is a pure function

`fn parse(content: &str, mtime: SystemTime) → SessionState`.
No I/O. QA-tester can construct any STATUS.md byte string
(including the malformed cases from PRD §6) and assert the
parsed `SessionState`. This covers AC3.a, AC3.b, AC3.c,
AC9.b (stage checklist parse), AC9.c (Notes order), AC9.i
(Notes newest-first).

### Seam 2 — `store::diff(prev, new)` is a pure function

`fn diff(prev: &SessionMap, new: &SessionMap) → DiffEvent`.
Given two in-memory session maps, the function returns the
diff events (added / removed / changed / stalled-transition).
QA-tester can construct synthetic state pairs and assert
the diff. This covers AC6.a (single fire on transition),
AC6.b (no recurrence while stalled), AC6.c (re-notify on
re-cross), AC8.a (grouped layout — sort logic).

### Seam 3 — fixture-repo integration test for `poller.rs`

A `tempdir` fixture with the shape:

```
<tempdir>/
├── .spec-workflow/
│   ├── features/
│   │   ├── _template/STATUS.md      # AC1.d
│   │   ├── alpha/STATUS.md          # AC1.a (recent updated:)
│   │   ├── bravo/STATUS.md          # AC3.b (recent Notes line)
│   │   ├── charlie/STATUS.md        # AC3.c (mtime fallback)
│   │   ├── delta/                   # AC1.b (no STATUS.md)
│   │   └── echo/STATUS.md           # AC1.a (stage: archive — excluded)
│   └── archive/
│       └── foxtrot/STATUS.md        # AC1.c
```

The integration test asserts: discovered session set is
`{alpha, bravo, charlie}` (4 cases verified in one fixture),
per-cycle read count = 3 (AC13.a), per-cycle wall-clock
< polling interval at 2s, 3s, 5s settings (AC13.c at
synthetic 20-session scale by replicating the fixture).

### Seam 4 — read-only invariant static check

A repo-level grep / cargo check rule asserting no Rust file
in `src-tauri/src/` contains a write call (`OpenOptions::
write`, `fs::write`, `fs::create`) targeting a path
matching the STATUS.md or feature-directory pattern. This
is a CI-level structural check; covers AC3.d (no writes
across an entire app session) without needing a runtime
mtime snapshot.

### Seam 5 — settings round-trip

`settings::write(s); let s2 = settings::read(); assert!(s
== s2)`. Covers AC14.a structurally (round-trip) and
AC14.c (atomic write — verified by killing the process
mid-write and asserting the original file is intact via
the `.bak`).

### Seam 6 — i18n parity check

A unit test that loads `en.json` and `zh-TW.json` and
asserts every top-level key present in one is present in
the other. Covers AC11.c structurally (parity).

### Seam 7 — markdown XSS check

A fixture markdown source containing a `<script>` block,
an `onclick` attribute, and a `javascript:` URL is parsed
through the `MarkdownPreview` component; the rendered DOM
is inspected and all three are asserted absent. Covers R9
read-only invariant + `.claude/rules/reviewer/security.md`
check 5.

Runtime verification (the app actually surfaces real
ongoing features in this very repo) is deferred to the
**next feature after archive + a fresh app launch**, per
the dogfood-paradox memory's "How to apply / Next feature
after a dogfood-paradox feature" section. That next
feature should add an early STATUS Notes line confirming
first-real-session observation, e.g. `- 2026-04-DD User —
flow-monitor app surfaced this feature's session in the
All Projects view on first launch`.

## Team memory

Tier listing performed at task start:

- `~/.claude/team-memory/architect/` — present, 8 entries
  (shell-portability-readlink, no-force-by-default,
  classification-before-mutation, settings-json-safe-mutation,
  byte-identical-refactor-gate, hook-fail-safe-pattern,
  script-location-convention, flag-parser-globals-match-semantic).
- `.claude/team-memory/architect/` — present, 4 entries
  (aggregator-as-classifier, opt-out-bypass-trace-required,
  reviewer-verdict-wire-format, scope-extension-minimal-diff).
- `~/.claude/team-memory/shared/` — present, 2 entries
  (local-only-env-var-boundary-carveout,
  skip-inline-review-scope-confirmation).
- `.claude/team-memory/shared/` — present, 1 entry
  (dogfood-paradox-third-occurrence).

Applied:

- **`architect/no-force-by-default` (global)** — drove D8's
  read-merge-write-tmp + atomic-rename discipline for
  `settings.json` and the §4 "Settings file corrupt" recovery
  posture (rename corrupt file aside, never overwrite without
  backup).
- **`architect/classification-before-mutation` (global)** —
  drove D12's closed-enum classifier for repository discovery
  (`SessionKind = Session | Template | NotASession`); also
  shaped Seam 1 (`status_parse::parse()` as a pure function
  with no I/O).
- **`architect/settings-json-safe-mutation` (global)** —
  drove D8's exact pattern (read → backup → merge → write-tmp
  → atomic rename) and the schema-versioning approach for
  forward-compatibility with B2.
- **`shared/dogfood-paradox-third-occurrence`** — drove §8
  Test seams in full; every AC that depends on the app being
  running and observing real sessions has a structural seam
  enumerated, with runtime verification explicitly deferred
  to the next feature after archive + fresh app launch.

Considered, not load-bearing:

- **`architect/shell-portability-readlink` (global)** —
  considered for any helper bash scripts that might ship
  alongside the app. None are scoped in B1's tech doc;
  packaging / installer scripts (if any) are TPM's call at
  /specflow:plan and the rule will apply there, not here.
- **`architect/script-location-convention` (global)** —
  same as above. If TPM scopes a `bin/flow-monitor-helper`
  or similar, the convention applies. No bin script in B1
  tech.
- **`architect/byte-identical-refactor-gate` (global)** —
  not applicable; this is greenfield, not a pure refactor.
- **`architect/hook-fail-safe-pattern` (global)** — not
  applicable; B1 ships no Claude Code hooks (B2 may).
- **`architect/flag-parser-globals-match-semantic` (global)** —
  not applicable; no multi-subcommand CLI in scope.
- **`shared/local-only-env-var-boundary-carveout`** —
  applied lightly in §4 Security ("Operator boundary
  carveout" paragraph). The tool is local-only single-user
  no-auth; standard input-validation discipline still applies
  but the threat model is the user's own filesystem.
- **`shared/skip-inline-review-scope-confirmation`** —
  not applicable at /specflow:tech; relevant when
  `--skip-inline-review` is invoked during implement.

Memory proposal (filed-candidate, not yet authored):

- **`architect/forward-compat-schema-version-key`** — when a
  feature ships a settings file format that a follow-on
  feature (B2 in this case) may need to extend, top-level
  `schema_version` + "preserve unknown keys on rewrite" is
  the load-bearing pattern that makes B2 → B1 downgrade
  safe. This is at least the second occurrence in this repo
  series (the prior one is the `settings.json` hook-merge
  discipline in `prompt-rules-surgery`), but the
  schema-version discipline specifically is a discrete
  addition. Hold off authoring until a third occurrence.

# Tech — flow-monitor B2 (control plane)

_2026-04-20 · Architect_

## 1. Context & Constraints

### Existing stack (inherited from B1)

B1's archived tech (`.spec-workflow/archive/20260419-flow-monitor/04-tech.md`)
committed this form factor, which B2 inherits unchanged:

- **Desktop framework**: Tauri 2.x (currently `tauri = "2.2"` in
  `flow-monitor/src-tauri/Cargo.toml`; toolchain Rust 1.88.0 per the
  most recent `/specflow:update-plan` on B1 Q-plan-1).
- **Renderer**: React 19 + TypeScript + Vite (frontend in
  `flow-monitor/src/`, mounted from `flow-monitor/dist/`).
- **Core plugins already linked**: `tauri-plugin-clipboard-manager`,
  `tauri-plugin-dialog`, `tauri-plugin-notification`,
  `tauri-plugin-opener`, `tauri-plugin-window-state`.
- **Existing capability manifest**:
  `flow-monitor/src-tauri/capabilities/default.json` currently grants
  `core:default`, `dialog:default`, `clipboard-manager:default`,
  `notification:default`. Per B1 AC7.d the shell-execute capability
  was deliberately withheld.
- **Existing Rust modules**: `ipc.rs` (read-only IPC surface),
  `poller.rs`, `notify.rs` (with `NotificationSink` trait and
  `MockSink` test double already in place), `store.rs`,
  `settings.rs`, `repo_discovery.rs`, `tray.rs`, `status_parse.rs`,
  `lib.rs::run_session_polling` (async tokio loop).
- **B1 residual gap that B2 must close**: `run_session_polling`
  does not yet call `store::diff` or
  `notify::fire_stalled_notification`. B2 R1 is the wiring; no new
  module is needed for it.

Bias-toward-existing-stack governs: **every B2 decision reuses a B1
module or plugin where possible. New dependencies are only introduced
when no existing surface supports the requirement**, and are
justified against a specific R.

### Hard constraints from PRD

- **R1** — wire `store::diff` + `notify::fire_stalled_notification`
  into the live polling loop; the two pure modules already ship. No
  new state shape is needed beyond a `prev_stalled_set`.
- **R4 / R5 / R7** — user-reachable write commands (Advance, Message,
  ⌘K palette, card context menu, compact-panel ▶ Next) must all
  invoke through a single Rust-side dispatcher. Terminal-spawn is the
  v1 delivery; clipboard is a user-selectable fallback; all
  invocations must be argv-form (AC4.d — no shell string-cat).
- **R6** — per-repo append-only audit log at
  `<repo>/.spec-workflow/.flow-monitor/audit.log`, tab-separated,
  1 MB rotation to `audit.log.1`, gitignore idempotent-add on first
  write.
- **R7** — in-process (per-app) in-flight lock keyed on
  `(repo, slug)`. Not on disk (AC7.c). Cross-window disable signalled
  via a Tauri event.
- **R8** — confirmation modal (Screen 4) and WRITE/DESTROY
  classification map both ship in B2 but are not user-reachable
  (DESTROY entries exist only in the classification map; no palette
  / menu / button exposes them).
- **R9** — Tauri capability surface opened to the **narrowest**
  possible opening: a shell-plugin scope limited to
  `/usr/bin/open` with a locked argv schema, plus an fs-plugin scope
  limited to `<repo>/.spec-workflow/.flow-monitor/**`. Path-traversal
  guard in `ipc.rs::read_artefact` pattern is extended to audit-log
  writes.
- **R10 / R11** — every new string exists in both `en` and `zh-TW`
  i18n bundles; no new theme tokens introduced.
- **R12** — B1 nits absorbed: `ipc.rs` line-length, WHAT-comments,
  unused `navigatedPaths` state, dead `markdown.footer` i18n key, 6
  non-BEM classes — all in-stream per housekeeping-sweep-threshold.

### Forward constraints from B3 (carved out)

- **B3 will add** DESTROY-command reachability (`archive`,
  `update-*`). **B2 must ship the scaffold but not the entry
  points**: the modal component exists, the DESTROY classification
  exists, but no palette / context-menu / button references a
  DESTROY command. B3 wires entry points into an already-built
  modal. No placeholder greyed-out DESTROY buttons anywhere in B2
  (same discipline as B1's no-stub posture for B2).
- **B3 may also revisit** notification re-fire after N minutes of
  continued staleness (PRD §8 Q-ux-future). B2 must not pre-wire a
  re-fire timer; `store::diff` remains the single source of
  transition truth.

### Soft preferences

- **One dispatcher module, one delivery abstraction.** All write
  surfaces (R2, R3, R4, R5, R7) route through a single
  `invoke.rs::invoke_command` Rust function plus a single
  renderer-side `invokeCommand()` TS wrapper. Terminal-spawn,
  clipboard, and the future pipe tab are three
  `DeliveryMethod` enum variants, not three parallel code paths.
- **Dogfood paradox is live (ninth occurrence).** 15 of 31 ACs are
  runtime-deferred to the next feature per PRD §6. Test seams (see
  §4 Testing strategy) must structurally cover every runtime AC so
  the validate stage can PASS without a live B2 app.

## 2. System Architecture

### Module layout (additions / changes to B1)

```
flow-monitor (Tauri app — B1 baseline + B2 additions)
│
├── src-tauri/
│   ├── capabilities/
│   │   ├── default.json                    # CHANGED: + shell scope, + fs scope
│   │   └── [no new file; one manifest]
│   ├── src/
│   │   ├── lib.rs                          # CHANGED: wire stalled diff + notify (R1)
│   │   ├── invoke.rs                       # NEW: dispatcher for write commands (R4,R5,R7)
│   │   ├── audit.rs                        # NEW: append + rotate + gitignore bootstrap (R6)
│   │   ├── lock.rs                         # NEW: in-flight lock state (R7)
│   │   ├── command_taxonomy.rs             # NEW: WRITE/DESTROY/safe enum + allow-list (R5,R8)
│   │   ├── ipc.rs                          # CHANGED: + 3 commands (invoke_command, get_audit_tail, get_in_flight_set)
│   │   ├── notify.rs                       # UNCHANGED (B1 shape already sufficient)
│   │   ├── store.rs                        # UNCHANGED (store::diff already present)
│   │   └── [other B1 files unchanged]
│   └── Cargo.toml                          # CHANGED: + tauri-plugin-shell, + tauri-plugin-fs
│
└── src/ (renderer)
    ├── components/
    │   ├── ActionStrip.tsx                 # NEW: 2-button strip on stalled cards (R2)
    │   ├── CommandPalette.tsx              # NEW: ⌘K overlay (R5)
    │   ├── SendPanel.tsx                   # NEW: inline message panel with 3 tabs (R3)
    │   ├── PreflightToast.tsx              # NEW: 3s post-WRITE confirmation surface (R5.c)
    │   ├── ConfirmModal.tsx                # NEW: DESTROY scaffold (R8; unreachable in B2)
    │   ├── AuditPanel.tsx                  # NEW: left-rail audit viewer in Card Detail (R6)
    │   └── [B1 components unchanged]
    ├── stores/
    │   ├── invokeStore.ts                  # NEW: in-flight set + dispatch wrapper
    │   └── [B1 stores unchanged]
    ├── i18n/
    │   ├── en.json                         # CHANGED: new B2 keys (Q8 list)
    │   └── zh-TW.json                      # CHANGED: new B2 keys (Q8 list)
    └── [other renderer files per B1]
```

Net file-count delta: **5 new Rust files, 6 new TSX components, 1 new
TS store, 2 i18n bundles touched, 2 Cargo deps added, 1 capabilities
JSON touched**. No B1 module is replaced.

### Data flow — stalled detection wiring (R1)

```
                        [3s poll tick]
                             │
                             ▼
   ┌───────────────────────────────────────────────────┐
   │ run_session_polling (lib.rs)                      │
   │  1. collect new_list from repo_discovery + parse  │ (already exists)
   │  2. build new_map: HashMap<SessionKey, State>     │ (NEW — R1)
   │  3. diff_event = store::diff(prev_map, new_map,   │ (NEW wiring)
   │                              prev_stalled_set,    │
   │                              threshold_mins)      │
   │  4. for k in diff_event.stalled_transitions:      │ (NEW — R1)
   │        notify::fire_stalled_notification(…)       │
   │  5. prev_map = new_map                            │ (NEW — R1)
   │     prev_stalled_set = diff_event.next_stalled_set│
   │  6. emit "sessions_changed" with diff payload     │ (PAYLOAD EXTENDED)
   └───────────────────────────────────────────────────┘
```

No new module; two existing modules (`store`, `notify`) stitched into
the loop that already owns the tick. The previous-tick state
(`prev_map`, `prev_stalled_set`) lives as locals inside the async
task's `loop {}` — no `Mutex` needed, no IPC-visible state added.

### Data flow — write command dispatch (R2/R3/R4/R5/R7)

```
   [UI click: ActionStrip / Palette / Context menu / Compact ▶]
                             │
                             ▼
   ┌───────────────────────────────────────────────────┐
   │ invokeStore.dispatch(command, slug, repo, entry)  │ (renderer)
   │  1. classify(command) → Safe | Write | Destroy    │
   │  2. if Destroy → open ConfirmModal (B2: unreachable│
   │     because no caller emits Destroy)              │
   │  3. if (repo, slug) ∈ in_flight_set →             │
   │        show toast "action already in flight"      │
   │        return                                     │
   │  4. in_flight_set.add((repo, slug))               │
   │  5. await tauri.invoke('invoke_command', {…})     │
   │  6. show PreflightToast for 3s (WRITE only)       │
   └───────────────────────────────────────────────────┘
                             │ (Tauri invoke)
                             ▼
   ┌───────────────────────────────────────────────────┐
   │ ipc::invoke_command (Rust, tauri::command)        │
   │  1. taxonomy::classify(command)                   │
   │     → if Destroy: return Err("destroy unreachable │
   │        in B2") — belt-and-braces guard           │
   │  2. taxonomy::allow_list_contains(command)?       │
   │     else return Err("unknown command")            │
   │  3. lock::acquire(repo, slug)                     │
   │     → if already held: return Err("in-flight")   │
   │  4. spawn via invoke::dispatch(delivery, cmd,     │
   │     slug, repo)                                   │
   │     ├── Terminal: plugin-shell exec open -a       │
   │     │   Terminal.app <script-file>                │
   │     ├── Clipboard: plugin-clipboard-manager write │
   │     └── Pipe: deferred; Err("not available in v1")│
   │  5. audit::append_line(repo, slug, command, entry,│
   │     delivery, outcome)                            │
   │  6. return Ok(InvokeResult{outcome})              │
   └───────────────────────────────────────────────────┘
                             │
                             ▼ (async)
   ┌───────────────────────────────────────────────────┐
   │ poll tick observes STATUS.md mtime change         │
   │   → emit "session_advanced"                       │
   │   → lock::release(repo, slug)                     │
   │   → renderer clears in_flight_set entry           │
   │   OR 60s timeout fires → same cleanup             │
   └───────────────────────────────────────────────────┘
```

Every write surface shares this pipeline. The renderer side is one
`invokeStore.dispatch` call; the Rust side is one `invoke_command`
handler. **No string-concatenation of commands anywhere in the
pipeline — the spawn call is argv-form throughout (AC4.d).**

### IPC surface (additions to B1)

| Direction | Name | Payload | Purpose |
|---|---|---|---|
| R→C | `invoke_command` | `{repo, slug, command, delivery, entry_point}` | dispatch a write command; returns `{outcome, audit_line}` |
| R→C | `get_audit_tail` | `{repo, limit}` | read last N audit lines for the Card Detail panel |
| R→C | `get_in_flight_set` | — | return current `(repo, slug)` tuples in-flight |
| C→R | `in_flight_changed` | `{locks: [(repo,slug)], timestamp}` | every window updates button state |
| C→R | `audit_appended` | `{repo, line}` | renderer appends to Card Detail audit panel |
| C→R | `session_advanced` | `{repo, slug}` | polling observed STATUS.md change; release lock |

**Deleted**: none. **Breaking-changed**: none. All B1 commands retain
their signatures (R7 contract from B1 archived §7).

### Component responsibilities (B2 additions)

- **`invoke.rs`** — owns `dispatch(delivery, cmd, slug, repo)`. Three
  arms: `Terminal` (calls `tauri-plugin-shell` with argv-form `/usr/bin/open
  -a Terminal.app <script-file>`), `Clipboard` (calls plugin-clipboard-manager
  `write_text`), `Pipe` (returns `Err(NotAvailable)` in v1). On
  Terminal failure, returns `Err(SpawnFailed)` — the renderer handles
  fallback to Clipboard (AC4.c) so the audit log can emit **two**
  lines (AC6.b) rather than one.
- **`audit.rs`** — owns `append_line(…)` (build TSV record, check
  size, rotate if ≥1 MB, write-append), `ensure_gitignore(…)`
  (idempotent line-add to top-level `.gitignore` on first write per
  AC6.d), `read_tail(repo, limit)` (tail N lines for the UI panel).
  **No writes outside `<repo>/.spec-workflow/.flow-monitor/`** — the
  path is validated against the set of registered repo roots before
  any write (AC9.b; extends the `ipc.rs::read_artefact`
  boundary-check pattern from B1).
- **`lock.rs`** — owns a `Mutex<HashSet<(PathBuf, String)>>` inside a
  `LockState` managed by Tauri. Methods: `acquire(repo, slug) →
  bool` (false if already held), `release(repo, slug)`, `current()`.
  Emits `in_flight_changed` event on every mutation so all open
  windows refresh simultaneously. A per-lock 60s watchdog timer
  releases the lock if `session_advanced` has not arrived (AC7.b).
- **`command_taxonomy.rs`** — **single source of truth** for the
  WRITE / DESTROY / Safe classification. Hardcoded list per D3 below.
  One pure function `classify(&str) → Classification` plus one
  `allow_list_contains(&str) → bool`. No I/O, no reading from disk.
  The UI imports the same list via a small generated TS file (see D3
  for the generation shape).
- **`ActionStrip.tsx`** — two-button strip rendered only when the
  parent `SessionCard` has `card.stalled === true`. Primary button
  label computed from the i18n key
  `action.advance_to.<next_stage>` (AC2.a/2.c); secondary button
  is "Message" opening Card Detail. Does not render on non-stalled
  cards (AC2.b).
- **`CommandPalette.tsx`** — overlay registered on ⌘K (Cmd+K on
  macOS, Ctrl+K on non-macOS — v1 target is mac). Lists the 11
  WRITE+safe commands pulled from `command_taxonomy`'s TS
  projection. DESTROY commands absent (AC5.b; AC8.b).
- **`SendPanel.tsx`** — 3-tab strip rendered in Card Detail; tab 1
  "pipe" disabled with tooltip "Deferred to future release" (AC3.b),
  tab 2 "terminal-spawn" is the default selection, tab 3 "clipboard"
  is functional.
- **`PreflightToast.tsx`** — 3s auto-dismissing toast in the toolbar
  (AC5.c). React-side `setTimeout(3000)` + manual dismiss; no
  cancellation semantic (the command has already been dispatched;
  the toast is feedback, not a gate).
- **`ConfirmModal.tsx`** — DESTROY scaffold per Screen 4 (R8). Lands
  as a component with tests but **no caller** in B2 — the
  classification map is the only B2 reference to DESTROY names. B3
  adds the first caller.
- **`AuditPanel.tsx`** — Card Detail left-rail section rendering
  `get_audit_tail(repo, limit=50)`. Appends via the
  `audit_appended` event. Read-only UI.

## 3. Technology Decisions

### D1. Tauri capability manifest — narrowest reversal of B1 (R9)

**Resolves Q-arch-1.** The concrete manifest shape below replaces
the single grant line B1 withheld.

- **Options considered**: (A) add `shell:allow-execute` with a
  wildcard argv + `fs:allow-write` with no scope restriction (same
  as accepting the full Tauri plugin defaults); (B) add
  `shell:allow-execute` with an exact-path allow-list to
  `/usr/bin/open` + per-binary argv schema, and `fs:allow-write`
  scoped to each registered repo's `.flow-monitor/` subdirectory via
  Tauri 2's scoped-permission mechanism; (C) skip the plugins and
  call `std::process::Command` + `std::fs::write` directly from
  `invoke.rs` without any capability grant (permissions bypass).
- **Chosen**: **(B) exact-path shell allow-list + per-repo scoped
  fs:allow-write.**
- **Why**: (1) (A) would grant the write side of the app authority
  to invoke any binary with any argv — a security regression far
  beyond what R9 allows. (2) (C) bypasses Tauri's capability
  system, which means `cargo deny` / capability-static-check
  (AC9.a) cannot verify the minimum surface from
  `capabilities/default.json` alone — a reviewer reading the
  manifest would not see the full shell surface. (3) (B) is the
  only option that makes AC9.a's grep-verifiable: a reviewer sees
  exactly one binary on the allow-list (`/usr/bin/open`) and
  exactly one argv schema; no string-cat is possible because the
  plugin enforces the schema at invoke time.
- **Concrete manifest delta** (appended to
  `flow-monitor/src-tauri/capabilities/default.json`):

  ```json
  {
    "permissions": [
      "core:default",
      "dialog:default",
      "clipboard-manager:default",
      "notification:default",
      {
        "identifier": "shell:allow-execute",
        "allow": [
          {
            "name": "open-terminal",
            "cmd": "/usr/bin/open",
            "args": [
              "-a",
              "Terminal.app",
              { "validator": "^/(private/)?(var|tmp)/flow-monitor-[a-z0-9-]+/invoke-[a-f0-9]{16}\\.command$" }
            ]
          }
        ]
      },
      {
        "identifier": "fs:allow-write-text-file",
        "allow": [
          { "path": "$APPLOCALDATA/tmp/invoke-*.command" }
        ]
      },
      {
        "identifier": "fs:allow-append-file",
        "allow": [
          { "path": "$REPOS/.spec-workflow/.flow-monitor/audit.log" },
          { "path": "$REPOS/.spec-workflow/.flow-monitor/audit.log.1" }
        ]
      }
    ]
  }
  ```

  **Note on `$REPOS`**: Tauri 2's static capability scope does not
  natively understand "any registered repo root". The manifest
  above is therefore paired with a **runtime guard in `audit.rs`**
  that canonicalises the write path and checks it sits under one of
  the `settings.repos` roots (extending `ipc.rs::read_artefact`'s
  check from B1). The static scope uses the
  `$APPLOCALDATA/.flow-monitor-repos-scope` path-list file
  (written by `add_repo` / `remove_repo` IPCs to mirror the live
  repo list). This two-layer scoping — static manifest + runtime
  boundary check — is the same belt-and-braces pattern B1 used for
  `read_artefact`. AC9.b's negative test targets the runtime guard,
  not the static manifest.
- **Terminal-spawn invocation shape**: `invoke.rs` writes the
  specflow command to a temp `.command` script (mode 0755) under
  `$APPLOCALDATA/tmp/invoke-<16hex>.command`, then execs
  `/usr/bin/open -a Terminal.app <script-path>`. The `.command`
  extension makes macOS Terminal.app execute the file as a shell
  script on double-click or `open` — this is the standard
  Terminal-spawn idiom on macOS and avoids the brittleness of
  `osascript` AppleScript-tell chains. Temp files live under
  `$APPLOCALDATA/tmp/` (Tauri-sandboxed) and are removed on next
  app launch via a `purge_stale_temp_files()` setup hook. `tmux`
  was rejected: it requires user installation (not on stock macOS)
  and breaks the "the user sees the invocation in their usual
  terminal" AC from Scenario F.
- **Tradeoffs accepted**: (1) the temp-file step means one extra
  write per invocation, which is bound to the user's action
  cadence (not the polling loop) so budget-irrelevant. (2) the
  regex validator on `args[2]` must match the runtime-generated
  path exactly — a brittle coupling that is captured in one place
  (the generator in `invoke.rs` and the regex in the manifest).
  (3) No additional argv schema per-stage (the specflow command
  name is in the script body, not on the open-a-Terminal argv) —
  this keeps the manifest surface minimal. The **only** thing
  going across the `/usr/bin/open` boundary is a path to a temp
  file the app owns.
- **Reversibility**: medium. Swapping Terminal.app for iTerm or
  Alacritty later requires one new plugin-shell allow entry plus a
  Settings → Terminal chooser UI; no re-architecture. The
  temp-file approach is the load-bearing part — keep it.
- **Requirement link**: R4, R9, AC4.a, AC4.d, AC9.a.

### D2. In-flight lock — in-process Mutex, 60s watchdog

**Resolves Q-arch-2.** R7 requires cross-window disable but
explicitly scopes the lock to "in-process" (AC7.c: closing and
reopening a window clears the lock).

- **Options considered**: (A) filesystem lock file at
  `<repo>/.spec-workflow/.flow-monitor/<session>.lock` with
  `O_EXCL`; (B) in-process `Mutex<HashSet<(PathBuf, String)>>` in a
  Tauri-managed state, broadcast to all windows via a Tauri event;
  (C) Tauri's built-in `single-instance` plugin to enforce
  single-writer-per-machine.
- **Chosen**: **(B) in-process lock + Tauri-event broadcast.**
- **Why**: (1) AC7.c explicitly says "The in-flight lock is
  in-process (not on disk); closing and reopening a window clears
  the lock. Two independent app launches do not coordinate." (A)
  violates that AC directly. (2) (C) single-instance would
  block legitimate multi-window use (Carol's Scenario H) — flow-
  monitor is designed for multiple simultaneous windows. (3) (B)
  matches Tauri's idiomatic pattern of managed-state + emit-event:
  all open windows subscribe to `in_flight_changed` and update
  button state in one place. The 60s watchdog (AC7.b) is a simple
  `tokio::time::sleep_until` per acquired lock; on timeout, emit
  `release` + `in_flight_changed`.
- **Stale-lock recovery**: if a window crashes mid-command, the
  `LockState` outlives the window (it's Tauri-app-managed, not
  window-managed). The crash itself doesn't release the lock; the
  60s watchdog does. This is acceptable because (a) the window
  crash is rare, (b) the user can continue with the other windows,
  (c) full app crash (all windows) means the next launch starts
  with an empty `LockState` — matches AC7.c "two independent
  launches do not coordinate".
- **Tradeoffs accepted**: if the app crashes *and* the `.command`
  script hasn't spawned yet, the audit log records nothing —
  no lost-action trace. Acceptable: the crash itself is the
  diagnostic event. Logging a pre-spawn "attempt" line plus a
  post-spawn "outcome" line was considered and rejected — two
  lines per invocation for every success is noise; the
  AC6.b two-line case is explicitly the *failed* path, not the
  happy path.
- **Reversibility**: high. Switching to a lock file later is a
  new `lock.rs` implementation behind the same trait.
- **Requirement link**: R7, AC7.a, AC7.b, AC7.c.

### D3. Command taxonomy — hardcoded list, derived TS projection

**Resolves Q-arch-3.** R5 / R8 / AC5.b / AC8.b all depend on a
stable WRITE / DESTROY / Safe classification.

- **Options considered**: (A) hardcode the list in
  `src-tauri/src/command_taxonomy.rs` as a Rust `const`, generate a
  TS projection at build time via a small build script; (B)
  discover commands at runtime by reading
  `.claude/commands/specflow/*.md` frontmatter; (C) store the list
  in `settings.json` so users can customise.
- **Chosen**: **(A) hardcoded Rust `const` + build-time TS
  projection.**
- **Why**: (1) (B) runtime discovery would require flow-monitor to
  know the path to `.claude/commands/specflow/` — but that path
  differs between global install (`~/.claude/commands/specflow/`)
  and per-project install (`<repo>/.claude/commands/specflow/`),
  and per-project install was the focus of a prior feature
  (`20260418-per-project-install`). Introducing a third install
  layout discovery is out of B2 scope. (2) (B) also means a newly-
  installed specflow command silently appears in the palette with
  the wrong classification (unknown = Safe by default is
  dangerous). (3) (C) user-customisable classification moves the
  safety invariant into runtime user data — a regression vs R8
  which says DESTROY must never be reachable in B2. (4) (A) drifts
  when new commands are added, but this is a **one-line PR** and
  the drift is visible in git history — preferable to runtime
  indirection.
- **The list** (B2 lock, matching PRD §2 Q2):
  - **Safe** (no pill, no confirmation): `request`, `brainstorm`,
    `gap-check`, `verify`
  - **WRITE** (yellow pill, no confirmation): `design`, `prd`,
    `tech`, `plan`, `tasks`, `implement`, `next`
  - **DESTROY** (red pill, confirmation required): `archive`,
    `update-prd`, `update-plan`, `update-tech`, `update-tasks`
  - Total: 4 + 7 + 5 = 16 commands. Palette lists 4 + 7 = 11
    (AC5.b). DESTROY-5 exists only in the classification map
    (AC8.b).
- **TS projection shape**: `src-tauri/build.rs` writes
  `src/generated/command_taxonomy.ts` — a single TS file with the
  same three arrays exported as `as const`. On CI, a grep check
  asserts the file was regenerated in sync with the Rust source.
  Both the Rust and TS consumers read from the same generated
  artefact so AC8.b's "no user-reachable entry point references a
  DESTROY command" can be structurally verified by a cross-file
  grep that checks every caller's string literal against the TS
  projection's `SAFE + WRITE` subset.
- **Tradeoffs accepted**: adding a new specflow command requires a
  flow-monitor release. Acceptable: new-command cadence is low
  (the last net-new specflow command was `verify` in the tier
  model, and any future net-new command needs the flow-monitor
  palette to opt in deliberately).
- **Reversibility**: medium. Swapping to runtime discovery is one
  module replacement + a settings key to point at the commands
  dir. The TS projection is the load-bearing part.
- **Requirement link**: R5, R8, AC5.b, AC8.a, AC8.b.

### D4. Audit log rotation — on-write size check

**Resolves Q-arch-4.** R6 / AC6.c require 1 MB rotate.

- **Options considered**: (A) on-write size check — before every
  append, `metadata().len()` the file; if `≥ 1_048_576`, rename to
  `audit.log.1` (overwriting any existing `.1`) then create a
  fresh `audit.log` starting with the current write; (B)
  cron-triggered logrotate (external); (C) Tauri-side periodic
  check in a separate tokio task.
- **Chosen**: **(A) on-write size check.**
- **Why**: (1) (B) introduces an external dependency (cron /
  launchd config) — a huge scope creep for a single-file rotate.
  (2) (C) means rotation can race with an append; two tasks writing
  to the same file is a classify-and-mutate anti-pattern. (3) (A)
  is one `metadata` syscall per append — negligible cost, since
  appends happen only on user action (not polling). Classify-
  before-mutate applies cleanly: classify(`size ≥ 1 MB`) → rotate;
  classify(`size < 1 MB`) → append directly. Single code path.
- **Rotation mechanics**: the rotate step is `std::fs::rename(
  "audit.log", "audit.log.1")` (atomic on POSIX + NTFS same-volume)
  **then** open the new `audit.log` with `O_APPEND | O_CREAT` and
  write the new line. No data lost even on mid-rotate crash: the
  old data survives in `.1`, the new line either lands or doesn't,
  but there is no window where both files are missing.
- **No backup of `audit.log.1` before overwrite**: N-file rotation
  (`.log`, `.log.1`, `.log.2`…) is out of scope; AC6.c specifies
  exactly two files. A user who wants a longer tail should copy
  `audit.log.1` aside manually or rely on a B3+ rotation
  enhancement.
- **Tradeoffs accepted**: losing the oldest 1 MB of audit history
  per rotation. Acceptable per PRD R6 (rotated `.1` is the
  retention unit). The rotation is deterministic and visible in
  the left-rail panel (it re-reads `audit.log + audit.log.1` per
  AuditPanel mount).
- **Reversibility**: high. Upgrading to N-file rotation is one
  rename-cascade loop.
- **Requirement link**: R6, AC6.a, AC6.c.

### D5. Notification dedup + banner details (R1)

**Resolves Q-arch-5.** PRD R1 says one-shot per transition via
`DiffEvent.stalled_transitions`; the architect concretises
"dedup key" and "already-read" semantics.

- **Options considered for dedup key**: (A) session slug alone; (B)
  `(slug, stage)` tuple; (C) `(slug, stalled_crossing_timestamp)`.
- **Chosen**: **(A) session slug alone, tracked inside
  `stalled_set: HashSet<SessionKey>` (the store's existing
  data).** `store::diff` already emits `stalled_transitions`
  containing exactly the keys that crossed the threshold on this
  tick — the dedup is a consequence of the diff's
  `prev_stalled_set` parameter, which B2 passes in from `lib.rs`.
  No new state is needed.
- **Why**: (1) (B) would re-fire on stage change while still
  stalled (e.g. user manually advanced STATUS one line without
  finishing the stage) — noise. (2) (C) would re-fire after
  crossing-out-and-back-in within a short window — correct per
  AC1.d but already handled by the `stalled_set.insert()`
  returning true on re-entry. (3) (A) matches the B1 `notify.rs`
  contract exactly (it takes a slug-keyed call already) and lets
  the diff module own transition semantics. Everything flows from
  the already-tested `store::diff` output.
- **Already-read tracking**: none. macOS Notification Center
  manages the banner lifecycle; flow-monitor does not track
  read-state. Clicking the banner focuses the flow-monitor main
  window (Tauri's notification action default — the app receives a
  `tauri://notification` activation event and the `notify.rs`
  handler calls `focus_main_window`). No in-app "unread counter" is
  introduced (scope guard — scope creep risk if added).
- **Sound / vibrate**: silent (`.silent(true)` on the notification
  builder — B1 default, B2 keeps). Per-user sound override is out
  of B2 scope; if PRD R11 changes allow new settings keys,
  revisit. PRD R11 forbids new theme tokens but Settings keys are
  separate — nevertheless, B2 does not add a `notification_sound`
  setting (scope guard).
- **Banner click-through**: when the user clicks the Notification
  Center banner, the app receives a notification-clicked event and
  calls `focus_main_window` (B1 IPC already exists) with the
  stalled slug focused. Focus the card in the grid if possible;
  else open Card Detail. Runtime-tagged (AC1.b already covers fire
  + banner body; the focus-on-click is a quality-of-life extension
  and is **not** a new AC — if the user reports it doesn't work,
  that's a B3 polish).
- **Tradeoffs accepted**: no re-fire on continued staleness (PRD
  Q-ux-future). Acceptable for v1; revisit in B3+ if operator
  feedback asks for it.
- **Reversibility**: high. Adding (C) re-fire is one
  extra field on the `DiffEvent` and one extra check per tick.
- **Requirement link**: R1, AC1.a, AC1.b, AC1.c, AC1.d.

### D6. Terminal spawn + clipboard fallback mechanics (R4)

**Concretises** PRD's "terminal-spawn default with clipboard
fallback".

- **Terminal spawn**: per D1, `invoke.rs` writes the command to a
  `.command` script and execs `/usr/bin/open -a Terminal.app
  <script>`. The renderer's `invokeStore.dispatch` path:
  1. Call `invoke_command` IPC; get back `InvokeResult`.
  2. If `outcome === "spawned"` → show PreflightToast (3s).
  3. If `outcome === "failed"` → call `invoke_command` again with
     `delivery = "clipboard"` (AC4.c fallback); show error toast
     "Terminal unavailable — copied to clipboard instead". This
     second call writes a second audit line (AC6.b).
- **Clipboard fallback**: uses `tauri-plugin-clipboard-manager`
  (already linked in B1). The clipboard write is one argv-free
  plugin call `writeText(command_string)`. No shell, no spawn.
- **3s pre-flight toast** (R5.c): `PreflightToast` is a React
  component with `setTimeout(3000)` dismiss. The toast is
  **informational, not cancelable** — the command is already
  dispatched by the time the toast shows (the `invoke_command`
  returned `spawned` first). Cancelling the spawn after
  Terminal.app has already opened is not feasible without killing
  the Terminal process, which the app has no authority to do.
  This matches AC5.c's "No modal" wording: the toast is feedback,
  not a gate. The gate semantic was resolved in PRD §2 Q3 —
  modal for DESTROY only, no modal for WRITE.
- **DESTROY modal scaffold** (R8): `ConfirmModal.tsx` ships as a
  component, accepts `{command, slug, onConfirm, onCancel}` props,
  is tested with component tests (AC8.a). **No caller imports it in
  B2.** The unreachability is enforced structurally: (a) a grep
  verifies no file under `src/` (other than the component's own
  file + its test file) imports `ConfirmModal`; (b) a grep verifies
  the DESTROY command names only appear inside
  `command_taxonomy.ts`, never in any palette / menu file.
  Toggle lives nowhere in B2 — there is no env var, no feature
  flag. B3 will author a PR that adds the caller + removes the
  "unreachable" grep assertion in one commit.
- **Requirement link**: R4, R5.c, R8, AC4.a–d, AC5.c, AC8.a–b.

### D7. Audit log format — 6-field TSV (R6)

- **Format** (per AC6.a, one line per invocation):

  ```
  <iso8601>\t<slug>\t<command>\t<entry_point>\t<delivery>\t<outcome>\n
  ```

  Example:

  ```
  2026-04-22T14:32:01+08:00\tdata-pipeline\tverify\tcard-action\tterminal\tspawned
  ```

- **Field validation**: `entry_point ∈ {card-action,
  card-detail, palette, context-menu, compact-panel}`; `delivery ∈
  {terminal, clipboard, pipe}`; `outcome ∈ {spawned, copied, failed}`
  (plus future `destroy-confirmed` for B3 — reserved in the
  `Outcome` enum but not written by any B2 code path per R8).
- **Character escaping**: slug is ASCII per B1 discipline (designer
  note 11); command and entry-point are enum values (no user
  input); timestamp and delivery/outcome are enum values. There is
  no free-text field, so no escaping / quoting logic is required.
  If a future enum gains a value containing `\t` or `\n`, fail
  loud in the enum parser (compile error).
- **Gitignore bootstrap** (AC6.d): before the first write,
  `audit.rs::ensure_gitignore(repo)` reads `<repo>/.gitignore`,
  checks for an existing line matching `^\.spec-workflow/\.flow-monitor/$`
  (or similar), and appends if absent. Read-modify-write via
  atomic rename (same pattern as `settings.rs` from B1 D8) — a
  partial write to `.gitignore` would be a regression. **The
  append happens only once per repo**: if the file already
  contains the line, no write occurs. Idempotent.
- **Requirement link**: R6, AC6.a, AC6.b, AC6.c, AC6.d, AC9.b.

### D8. Plugin additions to Cargo.toml (R9)

- Add `tauri-plugin-shell = "2"` (sibling of the other `tauri-
  plugin-*` deps; required for the locked-argv `shell:allow-execute`
  scope).
- Add `tauri-plugin-fs = "2"` (required for
  `fs:allow-append-file` scoped to audit.log). B1 did not ship
  this plugin because no fs-write surface existed.
- No other crates added. `tokio::time::sleep_until` (for the 60s
  watchdog) is already available via B1's `tokio` dep. HashSet is
  in `std`.
- **Reversibility**: high — remove both plugins + their
  `capabilities/default.json` entries; write commands collapse to
  an explicit Err.
- **Requirement link**: R4, R6, R7, R9.

### D9. i18n key list and en/zh-TW symmetry enforcement (R10)

- **New keys** (per designer notes Q8):

  ```
  action.advance_to.design      "Advance to Design"         "進入設計階段"
  action.advance_to.prd         "Advance to PRD"            "進入 PRD 階段"
  action.advance_to.tech        "Advance to Tech"           "進入技術階段"
  action.advance_to.plan        "Advance to Plan"           "進入計畫階段"
  action.advance_to.tasks       "Advance to Tasks"          "進入任務階段"
  action.advance_to.implement   "Advance to Implement"      "進入實作階段"
  action.advance_to.validate    "Advance to Validate"       "進入驗證階段"
  action.advance_to.archive     "Advance to Archive"        "封存工作階段"
  action.message                "Message / Choice"          "訊息 / 選擇"
  action.send_panel.title       "Send Message or Make Choice" "傳送訊息或作出選擇"
  audit.panel.title             "Control-Plane Audit"       "控制面稽核"
  audit.entry.via               "via"                       "透過"
  stalled.badge                 "Stalled · {duration}"      "已停滯 · {duration}"
  palette.group.control         "Control Actions"           "控制動作"
  palette.group.specflow        "Specflow Commands"         "Specflow 指令"
  palette.group.destroy         "Destructive Commands"      "破壞性指令"
  modal.destroy.title           "Destructive command"       "破壞性指令"
  modal.destroy.cancel          "Cancel"                    "取消"
  modal.destroy.confirm         "Proceed"                   "繼續"
  pill.write                    "WRITE"                     "WRITE"
  pill.destroy                  "DESTROY"                   "DESTROY"
  toast.in_flight               "Action already in flight"  "動作進行中"
  toast.terminal_failed         "Terminal unavailable — copied to clipboard instead" "無法開啟終端機 — 已複製到剪貼簿"
  toast.preflight               "{command} — {slug}"        "{command} — {slug}"
  notification.stalled.title    "Session Stalled"           "工作階段已停滯"
  notification.stalled.body     "{slug} · idle {duration}"  "{slug} · 閒置 {duration}"
  ```

- **Pill strings**: WRITE / DESTROY are kept untranslated (English)
  per designer note — these are product-taxonomy labels not
  natural-language UI text; matches the convention of keeping the
  slug ASCII (designer note 11).
- **Symmetry check**: reuse B1's Seam 6 pattern (load both JSONs,
  assert every top-level key present in one is present in the
  other). AC10.a is structural (grep), AC10.b is runtime
  (zh-TW walkthrough — deferred per dogfood paradox).
- **Requirement link**: R10, AC10.a, AC10.b.

### D10. Theme token reuse (R11)

- **No new tokens.** Every new CSS class uses existing B1 tokens.
  Concrete mapping:
  - ActionStrip primary button → existing `--button-primary-bg`,
    `--button-primary-fg` (used by B1 Card Detail Reveal button).
  - ActionStrip secondary button → existing `--button-secondary-*`.
  - Palette overlay background → existing `--overlay-bg`.
  - Stalled badge red → existing `--color-status-stalled` (already
    defined in B1 for the card top bar).
  - WRITE pill yellow → existing `--color-status-stale` (reused;
    both are "warn" semantic).
  - DESTROY pill red → existing `--color-status-stalled` (reused;
    both are "danger" semantic).
- **Verification**: AC11.a's grep asserts no new `--(color|space|
  font|radius)-` declarations in any B2-touched CSS file.
- **Requirement link**: R11, AC11.a.

### D11. Dogfood paradox — opt-out not applicable, runtime handoff only

- B1 spent D11's equivalent slot on notification dedup-across-
  restarts. B2's dogfood-paradox concern is different: this
  feature reshapes nothing in specflow itself (it extends
  `flow-monitor/` only), so there is **no self-bootstrap hybrid
  mode** needed during implement. The flow-monitor app is being
  *modified* during implement, not *executed*, so the control
  plane cannot run against this feature's own session.
- Therefore **no opt-out flag** (the `architect/opt-out-bypass-trace-required`
  memory does not apply here — no bypass exists to trace). Runtime
  verification of the 15 runtime-tagged ACs defers to the **next
  feature** after B2 archives, per PRD §6.
- **TPM must pre-commit in B2 archive notes** the STATUS opening line
  the next feature should emit ("B2 control plane exercised on this
  feature's first live session" or equivalent) — this is a plan
  deliverable, not a tech one.
- **Requirement link**: PRD §6, §9 handoff clause.

## 4. Cross-cutting Concerns

### Error handling (additions to B1)

- **`invoke_command` errors** are typed: `UnknownCommand`,
  `DestroyUnreachable`, `InFlight`, `SpawnFailed`, `ClipboardFailed`,
  `PathTraversal` (for audit write). Each maps to a user-visible
  toast string (i18n-keyed) and a structured audit line (where
  appropriate). No untyped `String`-error escape hatch.
- **Audit write failures** (disk full, permission denied): log at
  `warn` level, show a toast "Audit log write failed", but **the
  command still dispatches**. Rationale: the audit log is a
  diagnostic aid; losing one line is preferable to refusing the
  user's action. Two-line AC6.b on spawn-fail still applies — if
  the audit write itself fails, the log has zero lines instead of
  two; the toast tells the user the audit is incomplete.
- **60s lock timeout**: emits one WARN log line per timeout. The
  user sees the button re-enable; no error toast (the timeout is
  benign per PRD §6 "session mid-archive" edge case).

### Logging

- B1's `tracing` setup carries over. Add a new `invoke` target for
  every dispatch (`tracing::info!(target: "invoke", …)`). Audit log
  is the **user-facing** operator trace; `tracing` is the
  **debug-time** developer trace. They are deliberately different
  channels (the tracing output is off by default; the audit log is
  per-repo and gitignored).

### Security (delta from B1)

- **Path-traversal guard extended** (AC9.b): `audit.rs::append_line`
  canonicalises the target path and asserts it sits under one of
  the registered repo roots + the exact subpath
  `.spec-workflow/.flow-monitor/`. A negative unit test targets
  `/tmp/escape.log` and expects a `PathTraversal` error (same
  pattern as B1's `ipc.rs::read_artefact`).
- **Argv-only invocation** (AC4.d): `invoke.rs::spawn_terminal`
  builds the argv array as a Rust `Vec<String>` and passes it to
  `tauri-plugin-shell` which does not interpolate through a shell.
  A repo-level grep asserts no `OpenOptions::execute` nor
  `std::process::Command::new("sh"…)` patterns exist in
  `src-tauri/src/`.
- **DESTROY unreachability** (AC8.b): the structural check is two
  greps: (a) no import of `ConfirmModal` other than the component
  file and its test; (b) DESTROY command names appear only in
  `command_taxonomy.rs` and its TS projection. Both checks run in
  CI and block merge on violation.

### Testing strategy (feeds TPM's 05-plan)

Test seams aligned with PRD §9 verification tags:

#### Structural-only seams (cover 15 structural ACs during B2 validate)

- **Seam A — `store::diff` prev-set membership** (AC1.c): reuse
  B1's existing diff unit test; add one fixture where
  `prev_stalled_set` already contains the key and `stalled_transitions`
  is empty for a still-stalled session.
- **Seam B — command_taxonomy classification + absence** (AC5.b,
  AC8.b): unit test that asserts the 11 WRITE+safe names, the 5
  DESTROY names, total=16; + grep assertion that DESTROY names
  appear nowhere in `src/` except `generated/command_taxonomy.ts`.
- **Seam C — audit rotate at 1 MB** (AC6.c): unit test that writes
  a line, injects a 1 MB file to the fixture path, calls
  `append_line`, asserts `audit.log.1` exists and `audit.log` is
  1 line.
- **Seam D — gitignore idempotent** (AC6.d): unit test that calls
  `ensure_gitignore` twice on a tempdir; asserts the file has
  exactly one line added, not two.
- **Seam E — in-process lock** (AC7.c): unit test that creates a
  `LockState`, acquires `(repo, slug)`, asserts second `acquire`
  returns false; drops the `LockState`; creates a new one; asserts
  `acquire` returns true. Models "closed-and-reopened window".
- **Seam F — ConfirmModal renders with Cancel default** (AC8.a):
  component test that mounts the modal with props, asserts
  `document.activeElement === cancelButton`, asserts pressing
  Enter does not call `onConfirm`.
- **Seam G — capability manifest shape** (AC9.a): a CI test that
  parses `capabilities/default.json` and asserts (a) `shell:allow-
  execute` has exactly one entry named `open-terminal`, (b)
  `fs:allow-append-file` entries target exactly the audit-log
  paths.
- **Seam H — audit path-traversal guard** (AC9.b): unit test that
  calls `audit::append_line(repo, slug, …)` with a slug containing
  `../../../tmp/escape` and asserts `PathTraversal` error.
- **Seam I — argv-form invocation structural** (AC4.d): grep
  asserts no `Command::new("sh")` nor `exec("sh …")` in
  `src-tauri/src/`.
- **Seam J — i18n parity** (AC10.a): unit test loads en.json +
  zh-TW.json, asserts every new B2 key present in both with
  non-empty values.
- **Seam K — theme token reuse** (AC11.a): repo-level grep asserts
  no new `--(color|space|font|radius)-` declarations in any B2-
  touched CSS file.
- **Seam L — stage label lookup table** (AC2.c): unit test that
  every stage in the enum has an `action.advance_to.<stage>` key
  in both i18n bundles.
- **Seam M — B1 nits list cleared** (AC12.a): grep / lint
  assertions for each of the 5 B1 nits (ipc.rs line-length,
  WHAT-comments in listed files, unused `navigatedPaths`, dead
  `markdown.footer`, 6 non-BEM classes).

#### Runtime-deferred seams (15 runtime ACs; see PRD §6)

These are NOT exercised during B2 validate. The next feature after
B2 archives must include a "B2 control plane exercised" STATUS
Notes line. The seams for the next feature's QA-tester to use:

- AC1.a, AC1.b, AC1.d-runtime: first real stalled session after
  B2 merge + session restart.
- AC2.a, AC2.b: visual verification on a real grid view.
- AC3.a, AC3.b: click through Card Detail on a live session.
- AC4.a, AC4.b, AC4.c: terminal-spawn + clipboard fallback
  end-to-end (AC4.c requires simulating a Terminal.app failure —
  doable by temporarily renaming /Applications/Utilities/Terminal.app
  or using Settings → force-clipboard).
- AC5.a, AC5.c: ⌘K palette open/close + preflight toast timing.
- AC6.a, AC6.b: tail the real `audit.log` after a real invocation.
- AC7.a, AC7.b: two-window Scenario H test.
- AC10.b: zh-TW walkthrough of screens 1–7.

### Performance

- **Invoke dispatch latency**: user-action-bound (click → terminal
  appears). Target is "visible within 500 ms" (not a PRD AC; soft
  target). Temp-file write is ~5 ms, argv-form exec is ~100–300 ms
  for Terminal.app cold start. Well within the target.
- **Audit log append**: one `metadata` + one `write_all` + one
  `rename` (only on rotate). ~1 ms per invocation. Not in the
  polling hot path.
- **Polling loop budget unchanged**: B1's AC13.c budget (3 s tick,
  20 sessions, 5 repos) is not affected by B2 additions — the diff
  + notify wiring adds one `HashMap::clone`, one diff call, and up
  to N `Notification::show()` calls per tick where N is the number
  of stalled-transitions (typically 0; rarely >1 if a threshold
  change newly-stalls multiple sessions simultaneously). A
  diff-log line records the per-tick cost; if it exceeds 50 ms, a
  warn triggers.

## 5. Blocker questions

**None.** Q-arch-1 through Q-arch-5 are resolved in D1–D5 above.
D6–D11 cover the additional carry-forwards (terminal-spawn
mechanics, clipboard fallback, preflight toast, DESTROY scaffold,
audit format, plugin deps, i18n, theme, dogfood). Proceed to
`/specflow:plan`.

## 6. Non-decisions (deferred)

Things explicitly NOT decided in B2, with the trigger that would
force the decision later:

- **N-file audit-log rotation** (`.log.2`, `.log.3`, …). Trigger:
  operator reports 1 MB rotation loses necessary history.
- **Configurable terminal app** (iTerm, Alacritty, Kitty). Trigger:
  user requests; one new plugin-shell allow entry + Settings
  chooser.
- **Notification re-fire after N minutes** (PRD §8 Q-ux-future).
  Trigger: operator feedback that one-shot is insufficient.
- **Notification action buttons** (inline Advance on the macOS
  banner). Trigger: Apple Developer ID + entitlement review; B3+.
- **Pipe delivery method** (Q1 candidate (a)). Trigger: explicit
  need for in-flight stdout streaming back to the card; the tab
  is already rendered-but-disabled.
- **Palette context menu extensibility** (e.g. "All stalled →
  Advance"). Trigger: bulk-action request; explicitly out of B2
  per PRD §3 non-goals.
- **Single-instance enforcement** (Tauri's single-instance plugin).
  Trigger: user reports multi-window confusion; currently
  multi-window is by design (Scenario H).
- **Windows / Linux terminal-spawn variants**. Trigger: Windows or
  Linux becomes a blocking target. Currently macOS-only per B1.
  Windows would spawn `cmd.exe`/`wt.exe`; Linux would spawn
  `x-terminal-emulator` or the user's `$TERMINAL`. Each requires
  its own capability allow-list entry and regex validator per D1.
- **DESTROY command reachability** — B3 scope (PRD §3).
- **Flow-monitor UI rendering of a B2 "command in flight" visual
  cue beyond the button-disabled + spinner pattern**. Trigger:
  user requests progress indicator; polishing pass.

## Team memory

- Applied **architect/classification-before-mutation** (global) —
  shaped D3 (closed `Classification` enum + pure `classify()`
  function), D4 (classify-file-size-then-rotate before
  append), D7 (`Outcome` enum closed set), and the command taxonomy
  module's pure-function posture. Mutation (spawn / write) happens
  only in dispatch arms, never inside classifiers.
- Applied **architect/no-force-by-default** (global) — drove
  the refusal in D7 to overwrite `.gitignore` wholesale:
  `ensure_gitignore` reads existing content and appends only if
  absent. Also shaped D4's rotation (rename, not overwrite) and the
  no-`--force` posture on the temp-script cleanup.
- Applied **architect/settings-json-safe-mutation** (global) —
  drove D7's read-modify-write discipline for `.gitignore` (atomic
  rename via `.tmp`) and confirmed B1's settings pattern carries
  over unchanged (no new settings keys introduced in B2).
- Applied **shared/dogfood-paradox-third-occurrence** (ninth
  occurrence) — shaped §4 Testing strategy's structural-vs-runtime
  split and D11's no-opt-out rationale (the feature modifies the
  app but doesn't run it during implement, so no bypass flag is
  needed). The 15 runtime-deferred ACs are enumerated by AC id for
  the next-feature handoff.
- Consulted but not load-bearing: **architect/opt-out-bypass-trace-required**
  (no bypass exists to trace in B2; runtime handoff is a PRD §6
  mechanism, not a code flag), **architect/reviewer-verdict-wire-format**
  (not applicable to tech doc), **architect/script-location-convention**
  (no new `bin/` script in B2), **architect/scope-extension-minimal-diff**
  (applied implicitly: the `DeliveryMethod` enum has 3 variants —
  terminal / clipboard / pipe — but only terminal + clipboard are
  implemented; pipe is a single enum slot returning `Err(NotAvailable)`,
  which is scope-extension-minimal-diff in practice — one enum arm,
  not a re-taxonomy).

**Proposed memory entry**: at B2 archive, propose `architect/tauri-capability-static-plus-runtime-boundary`
— a pattern for Tauri 2 features where the static capability manifest
cannot express the full runtime boundary (e.g. "any registered repo
root"). The pairing of a narrow static manifest + a runtime-path
boundary check is worth capturing if a third feature needs it (B1's
`read_artefact` was the first occurrence; B2's `audit.rs` is the
second; one more and it's promotable).

---

**Tech doc author return**:

- **D-count**: **11** (D1–D11), covering Q-arch-1 through Q-arch-5
  plus 6 additional carry-forwards.
- **§5 blockers**: **0**. All five Q-arch questions resolved.
- **Applied team memory**: 4 entries load-bearing
  (classification-before-mutation, no-force-by-default,
  settings-json-safe-mutation, dogfood-paradox-third-occurrence).
- **PRD requirements technically impractical**: **none**. All 12 R
  are achievable with the stack and decisions above. Note: R9's
  "per-repo write scope" required a two-layer static-manifest +
  runtime-boundary pattern because Tauri 2 static scopes can't
  express "any registered repo" natively — this is a
  decision-complexity finding, not an R-level impracticality. No
  `/specflow:update-req` needed.

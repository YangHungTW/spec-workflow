<!-- scaff-lint: allow-cjk reason="中文 is the display name for Traditional Chinese in the language-toggle smoke check; intentional UI terminology" -->
# Flow Monitor

Native macOS desktop application for monitoring multiple parallel scaff
sessions across one or more git repositories. Read-only dashboard (B1 scope);
control plane is a separate follow-up feature (B2).

## Status

In active development. See `.specaffold/features/20260419-flow-monitor/`
for full specs.

## Build

```sh
cd flow-monitor
npm install
npm run tauri build -- --target universal-apple-darwin
```

Output: `src-tauri/target/universal-apple-darwin/release/bundle/dmg/flow-monitor_0.1.0_universal.dmg`

The binary is **unsigned** (ad-hoc). Signing and notarisation are planned as a
follow-up (Q-plan-3 post-B1). On first launch macOS will show a Gatekeeper
warning; open via right-click → Open to bypass it.

### Build wall-clock reference

Full cold build (Rust + frontend): approximately 3 minutes 20 seconds on an
Apple Silicon Mac with both `aarch64-apple-darwin` and `x86_64-apple-darwin`
targets installed.

## Smoke verification procedure

After building, verify the DMG before distributing:

```sh
DMG="src-tauri/target/universal-apple-darwin/release/bundle/dmg/flow-monitor_0.1.0_universal.dmg"

# Mount
hdiutil attach "$DMG" -readonly
ls /Volumes/flow-monitor/    # must show: flow-monitor.app  Applications

# Copy to /Applications (or drag in Finder)
cp -R /Volumes/flow-monitor/flow-monitor.app /Applications/

# Launch
open /Applications/flow-monitor.app

# Detach when done
hdiutil detach /Volumes/flow-monitor
```

### Six manual smoke checks (W5 acceptance)

After launch, verify all six items before declaring the build good:

1. **Empty state** — no settings file exists on a fresh sandbox; the main window
   must show the empty-state placeholder, not a crash or a blank white screen.
2. **Add a repo** — click the folder-picker button, select a git repository root;
   the sidebar must populate with a repo card within 2 seconds.
3. **Theme toggle** — open Settings → General; toggle between light/dark mode;
   the entire window must re-theme without a reload.
4. **Language toggle** — Settings → General; switch between English and 中文
   (zh-TW); all UI labels must change language without a reload.
5. **Compact panel** — click the toolbar compact-panel button; a smaller overlay
   window must open showing the active session count.
6. **Tray icon** — the macOS menu-bar tray icon must appear after launch; clicking
   it must show a popover with active session count.

Confirmed 2026-04-26: the graph-view feature (W2–W5) does not alter any of the
six smoke procedures above. All six checks remain identical in procedure and
pass criteria after the graph-view integration lands.

## Dogfood handoff

### First-run onboarding

1. Open `flow-monitor.app` (right-click → Open on first launch to bypass Gatekeeper).
2. Click **Add Repository** in the empty-state screen.
3. Select the root of any repository that runs scaff sessions (e.g. this
   `specaffold` repo itself).
4. Enable macOS notifications when prompted: System Settings → Notifications →
   flow-monitor → Allow Notifications.
5. Start a scaff session in the monitored repo; the sidebar card should
   appear within the polling interval (default 5 s).

### Where settings live

Settings and application state are stored under macOS Application Support:

```
~/Library/Application Support/com.flow-monitor.app/
  settings.json        ← repo list, theme, language, notification prefs
  window-state.json    ← last window size / position (tauri-plugin-window-state)
```

To reset to factory defaults, quit the app and delete
`~/Library/Application Support/com.flow-monitor.app/settings.json`.

### Filing bugs against the app itself

The recommended workflow is self-dogfood: use flow-monitor to observe the
scaff sessions that are building flow-monitor. Open an issue by running a
new scaff session in this repo and letting the app surface it, then file the
bug in the repo's issue tracker with the SESSION_ID from the sidebar card.

However, this creates the **dogfood paradox** (see
`.claude/team-memory/shared/dogfood-paradox-third-occurrence.md`): the app
cannot observe its own development sessions while it is being built, because
the mechanism (the running app) does not exist until after the build ships.

Concretely:

- **Structural verification** (the gate for the B1 verify stage) confirms that
  all code paths, IPC handlers, UI components, and test seams exist and conform
  to their contracts. This is what the QA-tester signs off on before archive.
- **Runtime verification** — live session cards appearing in a real running app,
  notifications firing, compact panel updating — is deferred to the **next
  feature after archive + first app launch**.

The next feature's developer must add an early STATUS Notes line confirming:

```
- YYYY-MM-DD Developer — B1 flow-monitor runtime confirmed: first real session
  appeared in sidebar within 5 s; tray icon showed session count; notifications
  delivered.
```

Until that line is written, treat all AC coverage involving live data as
structural-only.

### Known B1 limitations

- **No control plane** — the app is read-only; you cannot start, stop, or
  interact with sessions from within the app. Control plane is planned for B2.
- **No cross-platform** — macOS only in B1. Linux and Windows support are
  post-B1 follow-ups.
- **Unsigned binary** — Gatekeeper will warn on first launch. Right-click →
  Open to bypass. Production signing and notarisation are a Q-plan-3 follow-up.
- **Local only** — the app reads `.specaffold/` state files from the local
  filesystem; remote or SSH-mounted repos are not supported in B1.
- **No auto-update** — manual reinstall required for new builds. A Sparkle-based
  auto-updater is a post-B1 consideration.
- **Polling, not FS events** — session state is polled every 5 s; real-time push
  via FSEvents is a B2 enhancement.

### Upgrade notes

Pre-rename audit logs under `.spec-workflow/.flow-monitor/audit.log` are preserved on disk but are not surfaced in the new UI; see `docs/rename-migration.md` for the migration path.

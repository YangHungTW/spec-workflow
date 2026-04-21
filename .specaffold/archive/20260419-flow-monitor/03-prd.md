# PRD — flow-monitor (B1: read-only dashboard)

_2026-04-19 · PM_

## 1. Summary

A specflow user frequently runs more than one feature at a time — multiple
Claude Code sessions, each driving a different feature directory under
`.spec-workflow/features/`. Today, knowing which session is mid-stage,
which is waiting on user input, and which has stalled requires manually
tabbing between terminals or hand-reading STATUS.md files. This feature
ships a **native desktop application** that observes every active
specflow feature directory across one or more registered repositories and
surfaces, in one view, the current stage, last activity time, and
stalled/stale state of each. It is **read-only**: the app polls the
filesystem, parses STATUS.md, renders cards, and notifies once when a
session crosses into the stalled threshold. It does not write into live
Claude Code sessions, does not invoke specflow CLI commands, and does
not edit any specflow artefact — those affordances are explicitly carved
out as feature B2 (`flow-monitor-control`) for a later cycle. The split
between read (B1) and write (B2) follows
`pm/split-by-blast-radius-not-item-count`: B1's worst case is a stale UI;
B2's worst case is a corrupted in-flight feature. They are different
features with different verify harnesses.

## 2. Goals

- **One pane, N sessions.** A single desktop window shows every active
  specflow feature across every registered repository, with stage and
  last-activity time visible at a glance — no tab-switching to
  individual terminals.
- **Stalled sessions are loud.** Sessions that cross a configurable
  idle threshold are flagged visually on their card and trigger a
  one-shot macOS Notification Center banner so the user notices without
  staring at the dashboard.
- **Always-visible operator surface.** A floating, always-on-top
  compact panel lets the user keep stage status in peripheral vision
  while working in the IDE — the reference-project pattern adapted for
  specflow's slug-and-stage data.
- **Multi-repo by default.** A user with several specflow consumer
  repositories can register all of them and watch every active feature
  in one place; the "All Projects" combined view is the default
  landing state.
- **Bilingual operator UI.** Both English and zh-TW are first-class —
  the user can switch language in Settings; both renderings are visual
  parity per the design mockups.
- **Zero impact on observed sessions.** Polling is read-only; the app
  never writes to STATUS.md or any specflow artefact, never holds a
  lock, and never spawns a `bin/specflow-*` process. The worst the app
  can do to an observed session is show stale data.
- **Drill-in is read-only.** Clicking a card opens a detail view that
  shows the session's stage progress and renders every existing
  markdown artefact in the feature directory; nothing is editable.

## 3. Non-goals

Pulled from `00-request.md` §Out of scope and reinforced by the B1/B2
split locked at brainstorm:

- **Control plane (B2).** Sending instructions into a live Claude Code
  session, invoking `bin/specflow-*` from the UI, advancing a stage
  command from the dashboard, or any other action that writes into
  user-owned state is out of B1. These are the entire content of
  feature B2 (`flow-monitor-control`). B1 ships only read-only
  affordances ("Open in Finder", "Copy path"); it does not paint a
  button that would later belong to B2.
- **Editing artefacts.** No PRD/plan/tasks editor inside the app. The
  drill-in detail view is read-only markdown rendering. Editing stays
  in the IDE.
- **Replacing Claude Code.** No chat UI for the assistant
  conversation; no transcript display.
- **Multi-user / team features.** Single-user local tool only. No
  shared dashboard, no presence, no comments, no cloud sync, no
  authentication.
- **Reimplementing the specflow CLI.** The app is a passive observer
  of `.spec-workflow/features/**` filesystem state; it never
  re-implements any logic from `bin/specflow-*`.
- **Mobile / tablet / web form factor.** Native desktop only. No
  browser-served UI, no mobile companion, no terminal TUI, no VS Code
  panel — all explicitly rejected at brainstorm.
- **Sidecar daemon.** No background launchd / systemd / Task
  Scheduler process in v1. Polling runs inside the desktop app's own
  process. (Brainstorm A5 rejected the daemon as premature for
  single-user local scale.)
- **Translating archived features.** Sessions in
  `.spec-workflow/archive/**` are excluded by definition (see R2);
  the dashboard does not show, count, or notify on archived work.
- **Tailing Claude Code transcripts or hooking into Claude Code's
  process.** Stop-detection in B1 is filesystem polling only;
  transcript-tailing and SessionStart/Stop hook integration are
  deferred to B2.
- **Framework prescription.** This PRD does not pick the desktop
  framework (Tauri vs. Electron vs. native). Architect decides at
  `/specflow:tech`. PRD only states framework-agnostic requirements.
- **OS appearance auto-follow (B2).** [CHANGED 2026-04-19]
  Auto-following the OS `prefers-color-scheme` setting (so the app
  switches theme when the OS does) is out of B1 — R15 ships a
  user-toggle-only theme. OS-follow is reserved for B2 to avoid
  coupling B1's theme persistence semantics to OS-event listeners
  before the dogfood loop has confirmed the user-toggle UX is
  load-bearing.

## 4. Personas and scenarios

### Personas

- **Solo specflow operator** — one user, one machine, one or more
  consumer repos under `~/code/`. Runs 1–6 specflow sessions in
  parallel through the working day.
- **Multi-repo specflow operator** — same user shape, but actively
  works across two or more consumer repos (e.g. work repo + a
  side-project repo) with specflow features in flight in each.

### Scenario A — Multi-session catch-up after lunch

Alice has three specflow features in flight. Before lunch she launched
each in a separate terminal and walked away. She returns, opens the
flow-monitor app (already running in compact mode in the corner of her
screen), and sees: feature `auth-rework` is on `gap-check` and updated
2 min ago (green), feature `billing-port` is on `implement` and
updated 8 min ago (amber, "stale"), feature `report-export` is on
`tech` and updated 47 min ago (red, "stalled"). She had a macOS
notification 17 minutes ago for `report-export` crossing the stalled
threshold — that is the one she opens her terminal for first.

### Scenario B — Single-glance peripheral monitoring

Bob keeps the compact panel always-on-top in the top-right corner of
his screen while working in his IDE. The panel shows a one-line row
per active session: coloured dot (green/amber/red), slug, stage, and
relative time. He doesn't actively look at it; he glances when a
notification fires.

### Scenario C — Multi-repo combined view

Carol works across two repos: `~/code/work-app/` and
`~/code/side-project/`. She registers both in Settings → Repositories.
The app's left sidebar shows both repos plus an "All Projects" entry
(the default). When viewing All Projects, sessions are grouped by
repo with a collapsible header per repo (R8.b), so she can scan both
contexts in one window.

### Scenario D — Drill into a stalled session for context

Dan gets a stalled-session notification for feature `data-pipeline`.
He clicks the card. A detail view opens showing the stage checklist
(currently on `implement`, 4/9 tasks checked) and the full Notes
timeline from STATUS.md. Below that is a tab/list of every markdown
file present in the feature directory (`00-request.md`,
`01-brainstorm.md`, `03-prd.md`, `06-tasks.md`); he clicks
`06-tasks.md` and reads the rendered markdown to see which tasks
remain. He cannot edit anything from the app — he switches to his
terminal/IDE to act. (B2 will add the in-app action affordance.)

### Scenario E — Default-language English user

Erik installs the app fresh. UI is in English. He never opens
Settings → General → Language. Everything stays English. zh-TW is an
opt-in toggle, not a locale-detection auto-switch (R10.b).

## 5. Requirements

Each R has a one-line statement plus 1–4 acceptance criteria. R-numbers
are stable; AC IDs are scoped per R.

### Discovery and session model

**R1 — A "session" is a non-archived feature directory containing a
STATUS.md.** The app's unit of observation is one directory under a
registered repository's `.spec-workflow/features/<slug>/` whose
`STATUS.md` exists. The `_template/` directory is excluded by name.
Directories under `.spec-workflow/archive/**` are excluded by
location.

- **AC1.a (positive: feature dir with STATUS.md is shown).** Given a
  registered repo with `.spec-workflow/features/foo/STATUS.md`
  present and stage value not `archive`, the app's session list
  contains a card for `foo` within one polling interval of app
  launch.
- **AC1.b (negative: no STATUS.md = not a session).** A directory
  under `.spec-workflow/features/` that lacks a `STATUS.md` is not
  shown — verifiable by creating an empty `tmpdir/` under
  `features/` and observing no card appears.
- **AC1.c (negative: archive excluded).** A directory under
  `.spec-workflow/archive/<slug>/` (with or without STATUS.md) is
  not shown, regardless of its contents.
- **AC1.d (negative: template excluded).** The directory
  `.spec-workflow/features/_template/` is never shown as a session,
  even though it contains a STATUS.md skeleton (verified against
  the existing `_template/STATUS.md` baseline at `.spec-workflow/
  features/_template/STATUS.md`).

### Repository registration

**R2 — Multiple repositories can be registered; "All Projects" is the
default view.** The user adds one or more consumer-repo paths via a
folder-picker in Settings → Repositories. Registered repos persist
across app restarts. The sidebar lists each repo plus an "All
Projects" entry that combines sessions from every registered repo.
"All Projects" is the default landing view on first launch (after at
least one repo is registered).

- **AC2.a (add and persist).** Adding a repo via the folder picker
  causes its sessions to appear in the sidebar within one polling
  interval; quitting and relaunching the app shows the same repo
  still registered.
- **AC2.b (remove).** Removing a repo from Settings →
  Repositories causes its sessions to disappear from the session
  list within one polling interval; the entry vanishes from the
  sidebar.
- **AC2.c (validation).** Adding a path that does not contain a
  `.spec-workflow/` directory shows an inline validation message in
  Settings ("not a specflow repository") and the path is not
  added; existing registrations are unaffected.
- **AC2.d ("All Projects" default).** First launch after the user
  registers at least one repo lands on the "All Projects" view; in
  the empty-state (no repos registered), the empty state from R12
  is shown instead.

### Polling and freshness

**R3 — Filesystem polling reads STATUS.md fields and reports a single
"last activity" timestamp per session.** The app polls each registered
repo on a configurable interval (R4). For each session, it reads three
signals from STATUS.md and resolves them to one **last-activity**
timestamp: (1) the `updated:` field's date; (2) the date prefix of the
most recent line under `## Notes`; (3) the file's mtime as a fallback.
The most recent of the three is the session's last-activity time. No
write operation is ever issued against STATUS.md or anything in the
feature directory.

- **AC3.a (parses updated field).** A STATUS.md whose `updated:
  YYYY-MM-DD` line is the most recent of the three signals causes
  the card to render that date as last-activity. Verifiable
  against the schema in `.spec-workflow/features/_template/STATUS.md`
  (the `updated` field is the second item in the front-matter
  bullet list).
- **AC3.b (parses last Notes line).** A STATUS.md whose most recent
  Notes line carries a more recent date prefix than the `updated:`
  field causes that Notes-line date to be used. (The Notes line
  format is `- YYYY-MM-DD <role> — <action>` per the existing
  convention in
  `.spec-workflow/features/20260419-language-preferences/STATUS.md`.)
- **AC3.c (mtime fallback).** A STATUS.md whose `updated:` field
  and Notes lines are stale (older than file mtime) causes the
  mtime to be used as last-activity. This case covers a session
  where the file was touched but the conventional fields were not
  updated.
- **AC3.d (no writes).** Across an entire app session of arbitrary
  length, the modification time of every observed STATUS.md is
  unchanged by the app — verifiable by snapshotting mtimes before
  app launch and after app quit on a sandbox repo.

**R4 — The polling interval is user-configurable in the 2–5 second
range with a 3 s default.** Settings → General exposes a polling
interval slider (2 s minimum, 5 s maximum, 1 s granularity, 3 s
default). The current interval is displayed in the sidebar footer
(e.g., "Polling · 3s") with a green dot indicating live polling.

- **AC4.a (default 3 s).** Fresh install with no settings file shows
  polling interval 3 s in Settings and "Polling · 3s" in the
  sidebar footer.
- **AC4.b (range enforced).** The slider does not permit values
  below 2 s or above 5 s; programmatic config edits outside this
  range are clamped to the nearest bound on next read.
- **AC4.c (live indicator).** The sidebar footer shows a polling
  indicator that updates within one second of the user changing
  the interval in Settings.

### Idle states and notification

**R5 — Two-tier idle severity: stale (5 min default) and stalled
(30 min default).** Each session has an idle-time computed as `now -
last-activity`. When idle-time crosses the **stale threshold** the
card displays an amber stale badge. When idle-time crosses the
**stalled threshold** the card displays a red stalled badge with a
top accent bar (per design notes item 3). Both thresholds are
user-configurable in Settings → General. Default values: stale =
5 minutes, stalled = 30 minutes.

- **AC5.a (default thresholds).** Fresh install shows stale = 5 min
  and stalled = 30 min in Settings.
- **AC5.b (stale crossing).** A session whose last-activity is
  between the stale and stalled thresholds renders with the amber
  stale badge; observable by aging a STATUS.md in a sandbox repo
  past 5 min and confirming card colour transitions on next poll.
- **AC5.c (stalled crossing).** A session whose last-activity
  exceeds the stalled threshold renders with the red stalled badge
  and the top accent bar (per design notes item 3); the card sorts
  to the top under the "Stalled-first" sort axis (R7).
- **AC5.d (threshold ordering).** The Settings UI prevents
  configuring stalled < stale (the larger threshold cannot be set
  below the smaller); programmatic config violations fall back to
  defaults with a warning logged to the app's diagnostic log.

**R6 — One-shot macOS Notification Center banner per stalled
transition; no recurring notifications; no sound.** When a session
transitions from non-stalled to stalled (idle-time crosses the
stalled threshold), the app posts exactly one macOS Notification
Center banner naming the repo, slug, and stage. The notification
fires **once per crossing**: a session that stays stalled does not
re-notify. A session that leaves stalled (last-activity refreshes)
and later re-enters stalled fires a new notification. Notifications
carry no sound flag (per design notes item 4 and user lock-in).

- **AC6.a (single fire on transition).** A session that crosses
  from non-stalled to stalled produces exactly one notification —
  observable by a stalled-banner counter in the app's diagnostic
  log incrementing by exactly 1 on the polling tick where the
  transition happens.
- **AC6.b (no recurrence while stalled).** A session that remains
  stalled across N subsequent polls produces zero additional
  notifications; counter stays flat.
- **AC6.c (re-notify on re-cross).** A session that goes
  stalled → not-stalled → stalled fires a second notification on
  the second crossing; counter is now 2.
- **AC6.d (no sound).** Notifications are posted with the macOS
  Notification API's silent flag set; no sound plays. (Design
  notes item 4.)
- **AC6.e (user-disablable).** Settings → Notifications has a
  toggle that, when off, suppresses all stalled-transition
  notifications without affecting the visual badge on the card.

### Card list, sort, and combined view

**R7 — Sessions display as cards in a 2-column grid with a defined sort
axis.** The session list renders each session as a card (per design
decision 1, locked at brainstorm: "card-based session list, not
table, not tree"). Each card shows: slug, stage pill, last-activity
relative time (e.g., "3 min ago"), idle badge (none/stale/stalled),
contextual last-note excerpt (first ~80 chars of the most recent
Notes line), and the read-only "Open in Finder" / "Copy path" actions
on hover. Sort options exposed in the toolbar: **Last Updated DESC**
(default), **Stage**, **Slug A–Z**, **Stalled-first** (stalled cards
above stale above normal, then last-updated DESC within each band).

- **AC7.a (card grid renders).** With ≥1 session, the main window
  shows a 2-column card grid; each card carries the six elements
  enumerated above (slug, stage pill, relative time, idle badge,
  note excerpt, hover actions).
- **AC7.b (default sort).** With sort dropdown untouched, cards
  are ordered last-activity DESC across the visible set.
- **AC7.c (sort axes available).** The sort dropdown exposes
  exactly the four axes named above; selecting each reorders the
  visible cards within one frame (no polling round-trip needed
  since data is already in memory).
- **AC7.d (hover actions are read-only).** The hover actions on a
  card are exactly "Open in Finder" (opens the feature directory
  in the OS file browser) and "Copy path" (copies the absolute
  path of the feature directory to the clipboard). No other
  hover-actions appear in B1.

**R8 — "All Projects" combined view groups sessions by repo with
collapsible headers.** When the sidebar selection is "All Projects",
the card grid is segmented by repository: each registered repo
contributes a labelled, collapsible section header above its
sessions. Within a section, sort applies (R7); across sections, repos
appear in registration order. Collapsing a repo header hides its
section but preserves its sessions in the polling set.

- **AC8.a (grouped layout).** With ≥2 repos registered and sessions
  in each, "All Projects" view shows one labelled section per repo
  in registration order; each section contains its repo's
  sessions sorted per R7.
- **AC8.b (collapsible).** Clicking a repo header toggles its
  section's visibility; the toggle state is remembered across app
  restarts.
- **AC8.c (single-repo selection bypass).** Selecting an
  individual repo in the sidebar shows that repo's sessions
  without the section header (the header is only the "All
  Projects" disambiguator).

### Card detail / drill-in

**R9 — Clicking a card opens a read-only detail view with stage
checklist, Notes timeline, and rendered markdown of every artefact
present.** A card click opens a detail view (modal or split-pane —
Architect's call) that contains: (a) the session's stage checklist
parsed from STATUS.md (showing `[x]` checked vs `[ ]` unchecked) plus
the Notes timeline (rendered as a chronological list); (b) a
file-list of every markdown document in the feature directory that
**exists** out of the canonical set (`00-request.md`,
`01-brainstorm.md`, `02-design/notes.md`,
`02-design/mockup.html`, `03-prd.md`, `04-tech.md`, `05-plan.md`,
`06-tasks.md`, `07-gaps.md`, `08-verify.md`); (c) a markdown
preview pane that renders the selected file. Everything is
read-only — no edit affordance, no save button, no inline editing.
[CHANGED 2026-04-19] The detail view is rendered as a master-detail
navigation (full main window, breadcrumb back-nav), not a modal — the
breadcrumb back arrow returns to the last filter / sort / repo state
the user had on the Main Window, not a hard reset to All Projects.
[CHANGED 2026-04-19] The left-rail stage checklist highlights the
current stage using the active theme's primary token (`#4F46E5` light,
`#1B4332` dark) — see R15 for the theme-token contract.
[CHANGED 2026-04-19] When the 9 markdown-doc tabs do not fit at
narrow window widths, the tab strip becomes horizontally scrollable
(no wrap, no overflow menu); the active tab always stays visible
(auto-scrolls into view on switch). [CHANGED 2026-04-19] The
`02-design` tab shows a file index of the folder's sub-files
(`mockup.html`, `notes.md`, `README.md`); each sub-file row's only
action is "Reveal in Finder" for that specific file. The
header-strip "Open in Finder" button opens the **feature directory**,
not any single file. [CHANGED 2026-04-19] The Notes timeline renders
newest-first with no truncation in B1 (practical ceiling assumed
<100 entries; revisit if QA finds 200+ in the wild). [CHANGED
2026-04-19] The stalled/stale badge in the detail-header is static —
no animation or pulse. [CHANGED 2026-04-19] The markdown preview
pane carries a footer reading literally `Read-only preview. Open in
Finder to edit.`

- **AC9.a (detail opens on click).** Clicking any card opens the
  detail view; the view's title carries the session's slug and
  repo.
- **AC9.b (stage checklist parsed).** The stage checklist
  rendered in the detail view matches the checked/unchecked state
  of the source STATUS.md `## Stage checklist` block, line for
  line. Verifiable against
  `.spec-workflow/features/_template/STATUS.md`'s 11-line stage
  checklist (request/brainstorm/design/prd/tech/plan/tasks/
  implement/gap-check/verify/archive).
- **AC9.c (Notes timeline rendered).** Every line under
  `## Notes` is rendered in the detail view in source order; date
  prefixes are preserved verbatim.
- **AC9.d (file list reflects existence).** The artefact file
  list shows exactly the canonical files that exist on disk; a
  feature with only `00-request.md` and `01-brainstorm.md`
  present shows only those two entries. The
  `02-design/mockup.html` entry, if present, is shown as a link
  that opens the file in the OS default browser (HTML is not
  rendered in-app).
- **AC9.e (read-only invariant).** The detail view contains no
  editable input field, no "save" button, no command-trigger
  affordance. Every actionable control on the detail view is
  read-only or scoped to file-system-safe operations (open
  externally, copy path).
- **AC9.f (back-nav restores filter state).** [CHANGED 2026-04-19]
  Setting a non-default filter, sort, or repo selection on the Main
  Window, drilling into a card via click, and clicking the breadcrumb
  back arrow returns the user to the Main Window with the same
  filter, sort, and repo selection still applied — verifiable by
  changing each control to a non-default value, drilling in,
  returning, and asserting each control's state matches what it was
  pre-drill-in.
- **AC9.g (tab overflow scrolls, active stays visible).** [CHANGED
  2026-04-19] At a window width narrow enough that the 9-tab strip
  exceeds the available space, the strip becomes horizontally
  scrollable (no wrap, no collapse-into-menu). Switching to a tab
  outside the visible band auto-scrolls that tab into view —
  verifiable at a narrow window width by tabbing through all 9 slots
  and confirming the active tab is on screen at every step.
- **AC9.h (02-design tab — per-file Reveal in Finder).** [CHANGED
  2026-04-19] The `02-design` tab renders a file index of the
  folder's sub-files. Each sub-file row's single action is "Reveal in
  Finder" for that specific file (mapping to `open -R <absolute
  path>` on macOS, equivalent on other platforms). The header-strip
  "Open in Finder" button opens the **feature directory** itself,
  not any specific sub-file. Verifiable against the `open -R`
  baseline behaviour (selects the file in a new Finder window) for
  the existing
  `.spec-workflow/features/20260419-flow-monitor/02-design/notes.md`
  file.
- **AC9.i (Notes timeline newest-first, untruncated).** [CHANGED
  2026-04-19] The Notes timeline renders all entries from the source
  STATUS.md `## Notes` block in newest-first order with no
  truncation in B1. Verifiable against the existing 4-entry Notes
  timeline in
  `.spec-workflow/features/20260419-flow-monitor/STATUS.md` (the
  newest-dated entry sorts to the top).
- **AC9.j (stalled badge static in detail header).** [CHANGED
  2026-04-19] The stalled / stale badge rendered in the detail-view
  header strip is static — no CSS animation, no opacity pulse, no
  blink. Verifiable by inspecting the rendered DOM/style for the
  badge element on a session that is in the stalled state and
  asserting no `animation` / `transition` property drives a repeating
  visual change.
- **AC9.k (markdown pane footer literal copy).** [CHANGED
  2026-04-19] The markdown preview pane carries a footer reading
  literally `Read-only preview. Open in Finder to edit.` The text
  is a verifiable string match (no parameterisation, no
  localisation in B1 — see R11 carve-out below if QA flags zh-TW
  parity). Verifiable by string-matching the rendered footer text
  on any tab.

### Compact panel

**R10 — A floating, always-on-top compact panel renders one line per
session.** A separate window — the **compact panel** — can be opened
from the main window's toolbar (and closed back to it). The compact
panel: is always-on-top by default (toggle in Settings), is
free-floating and draggable (no edge-snap or dock in v1), shows one
row per active session with `coloured-dot · slug · stage-pill ·
relative-time`, and provides a single "Open main" affordance to
re-focus the main window. Both the main window and the compact panel
must function correctly and stay in sync (same poll cycle, same
session set).

- **AC10.a (panel opens and closes).** Toggling the compact-mode
  button in the main window toolbar opens the compact panel as a
  separate top-level window; toggling again closes it. The main
  window stays open and functional throughout.
- **AC10.b (always-on-top default).** The compact panel sits above
  the active foreground window of any other application by
  default; Settings → General has a toggle to disable
  always-on-top.
- **AC10.c (sync with main).** A session's row in the compact
  panel reflects the same stage, idle badge, and relative time as
  its card in the main window within one polling interval; a
  newly-discovered session appears in both within one polling
  interval.
- **AC10.d (free-floating).** The panel is draggable to any screen
  position; it does not snap to screen edges (edge-snap and
  dock-mode are explicitly out of scope for B1 — see open
  decisions §7).
- **AC10.e ("Open main" affordance).** The compact panel exposes
  a control that brings the main window to the foreground; if
  the main window was minimised, it is restored.

### Localisation

**R11 — UI ships in English and Traditional Chinese (zh-TW); language
toggle in Settings.** Both English and zh-TW are first-class. Settings
→ General has a language selector with two options: English (default)
and 繁體中文 (zh-TW). Switching language updates every visible UI
string — sidebar labels, stage pills, idle badges, button labels,
empty-state copy, settings labels, notification title and body —
without restarting the app. Default is English; the app does not
auto-detect OS locale in v1.

- **AC11.a (default English).** Fresh install with no settings file
  renders all UI in English.
- **AC11.b (toggle to zh-TW).** Selecting 繁體中文 in Settings
  re-renders every visible string in zh-TW within one frame; no
  app restart required.
- **AC11.c (parity coverage).** Each of the screens enumerated in
  the design `notes.md` "Flows covered" table has a zh-TW
  rendering that matches the EN rendering structurally (same
  layout, same data, same controls — only the strings differ).
  Verifiable by side-by-side comparison against the design
  mockups (Designer covered both EN and zh-TW for Main Window and
  Compact Panel).
- **AC11.d (notification language).** The macOS notification
  banner's title and body are emitted in the currently-selected
  UI language (R6 fires under whatever language is active at the
  time of the crossing).
- **AC11.e (no auto-detect).** The app does not read OS locale
  to choose initial language; default is English unless the user
  explicitly switches.

### Empty state and first-run UX

**R12 — Empty state when no repositories are registered.** On first
launch, with zero registered repositories, the main window shows an
empty state with: an illustration, an explanatory message ("no
repositories registered"), a primary CTA button to add the first
repo (opens the folder picker), and an explainer box describing
what the app watches (per the design `notes.md` Empty State row).

- **AC12.a (empty state shows).** With no repositories registered,
  the main window does not render the card grid; it renders the
  empty state with the elements above.
- **AC12.b (CTA functional).** Clicking the primary "Add
  repository" CTA opens the same folder picker used in Settings →
  Repositories; on successful add, the main window transitions to
  the All Projects view (R2.d).
- **AC12.c (sidebar mirrors).** While in empty state, the sidebar
  shows the dashed-border ghost "Add repo…" item from design notes
  decision 8; once at least one repo is registered, the ghost item
  is replaced by the populated repo list and the normal italic
  "Add repo…" link.

### Resource and observation budget

**R13 — Polling overhead stays within a budget that does not
destabilise observed sessions.** The polling cycle for one repo with N
sessions performs at most one stat + one read of each session's
STATUS.md per cycle; no other files in the feature directory are
read during polling (the detail view, R9, reads files on demand at
click time). The app does not hold open file handles between cycles.
At the 3 s default interval with up to 20 sessions across 5 repos
(realistic upper bound for a single-user setup), polling completes
within one polling interval (does not back up). The app does not
spawn any subprocess as part of polling.

- **AC13.a (read-once per cycle).** Per polling cycle, the app
  performs exactly one open + read + close per STATUS.md across
  all registered repos; no recursive directory walks of feature
  contents during polling. (Detail-view file reads are not
  polling reads and are excluded from this budget.)
- **AC13.b (no subprocess in polling).** The polling code path
  spawns no `git`, no `bin/specflow-*`, no shell process — it is
  in-process filesystem I/O only. Verifiable by `dtruss` /
  process-spawn audit on macOS during a polling-only session.
- **AC13.c (cycle completion within interval).** With 20 sessions
  across 5 repos and the polling interval at the 3 s default, the
  measured polling cycle wall-clock stays under the interval —
  i.e., poll cycles do not back up. Verifiable by an internal
  per-cycle wall-clock log entry.

### Settings persistence

**R14 — All user-configurable settings persist across app restarts.**
The app stores settings (registered repositories, polling interval,
stale threshold, stalled threshold, notifications-enabled toggle,
always-on-top toggle, UI language, repo-section collapse state) in
a single user-owned settings file (Architect picks location and
format). The file is read once at app launch and rewritten only when
the user changes a setting. Concurrent app instances are out of
scope for v1 (single instance assumed).

- **AC14.a (round-trip).** Setting each user-configurable option
  to a non-default value, quitting, and relaunching shows every
  option restored to the chosen value.
- **AC14.b (read-once at launch).** The settings file is read at
  app launch; runtime polling never re-reads the settings file —
  Settings UI is the only mutator.
- **AC14.c (atomic write).** Settings writes use the
  write-temp-then-rename pattern (per
  `.claude/rules/common/no-force-on-user-paths.md`) so a crash
  during write does not leave a corrupt settings file.

### Theming

**R15 — App ships with two themes (light default, dark) selectable
in Settings; persisted across restarts; no OS auto-follow in B1.**
[CHANGED 2026-04-19] The app implements two themes — a **light**
theme (default) and a **dark** theme. Light-mode primary token is
`#4F46E5` (indigo); dark-mode primary token is `#1B4332` (ink
green). The theme selector is exposed in **Settings → General**
(not in the toolbar / nav bar — that placement was a mockup-only
preview affordance). The user's selection persists across app
restarts via the same settings store as R14. First-run with no
stored preference defaults to **light**. The app does **not**
auto-follow the OS `prefers-color-scheme` setting in B1 — this is a
user-toggle-only feature; OS-follow is reserved for B2 (see §3
Non-goals OS-follow carve-out below). Both themes apply to all
seven mockup screens — Main Window (EN), Main Window (zh-TW),
Stalled state, Card Detail, Compact Panel, Settings, Empty state —
including stage pills, idle badges, the compact panel surface, and
the markdown preview pane in Card Detail. Text-on-surface contrast
meets WCAG AA in both themes.

- **AC15.a (Settings → General theme control toggles theme within
  one frame).** [CHANGED 2026-04-19] Settings → General contains a
  Light / Dark control (radio or toggle). Selecting Dark applies
  the ink-green theme to the active window within one frame (no
  app restart, no full re-mount); selecting Light reverts. The
  control is the only in-app theme switcher in B1.
- **AC15.b (selection persists across restart).** [CHANGED
  2026-04-19] After selecting Dark (or Light, if the user toggled
  away from default), quitting and relaunching the app shows the
  theme matching the last selection. Persisted alongside the rest
  of R14's settings.
- **AC15.c (first-run defaults to Light).** [CHANGED 2026-04-19]
  Fresh install with no stored settings file renders the app in
  the light theme on first launch, regardless of OS appearance.
- **AC15.d (both themes apply to all 7 screens).** [CHANGED
  2026-04-19] Switching to Dark while viewing any of the seven
  mockup screens — Main Window (EN), Main Window (zh-TW), Stalled
  state, Card Detail, Compact Panel, Settings, Empty state — re-
  tones every surface (page background, sidebar, cards, stage
  pills, idle badges, compact panel glass, markdown preview pane);
  no element retains its light-theme colour after the toggle.
- **AC15.e (primary tokens match the locked palette).** [CHANGED
  2026-04-19] The dark-theme primary CSS variable (or framework-
  equivalent token) resolves to `#1B4332`; the light-theme primary
  resolves to `#4F46E5`. Verifiable by inspecting the rendered
  computed style of the Settings → General active sidebar item (or
  any primary-tokened element) under each theme. Baseline for the
  exact hex values is the design `02-design/notes.md` "Theming"
  table row "Sidebar active item".
- **AC15.f (WCAG AA contrast for body text and pill labels).**
  [CHANGED 2026-04-19] Body text on surface and stage-pill label
  text on pill background both meet WCAG AA contrast (≥4.5:1 for
  body text, ≥3:1 for large text and UI components) in both
  themes. Verifiable per-pill against the design `02-design/
  notes.md` "Stage pills dark-mode re-toning" guidance and the
  surface-tone table; an automated contrast check on the rendered
  computed colours is acceptable.

## 6. Edge cases

### Dogfood paradox

Per `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md`:
this feature ships an app whose first useful exercise depends on the
app itself existing. **The flow-monitor cannot observe its own
development sessions** — there is no `.spec-workflow/features/
20260419-flow-monitor/` card in any dashboard until the app ships and
runs against this very repo. Implications:

- Verify (08-verify.md) is **structural-only** for any AC that
  depends on the app being running and observing real specflow
  sessions over time (AC3.a–c, AC5.b–c, AC6.a–c, AC8.a, AC10.a–e,
  AC11.b–d, AC13.a–c). Structural verification means: the polling
  code path correctly parses a fixture STATUS.md; the sort code
  correctly orders an in-memory list; the notification code
  correctly fires on a synthetic state transition.
- Runtime verification (the app actually surfaces real ongoing
  features in this very repo) happens **on the next feature after
  archive + a fresh app launch** — that next feature should add an
  early STATUS Notes line confirming first-real-session
  observation.
- Long polling soak tests (AC13.c with 20 real sessions) cannot be
  exercised on this repo (which has 1–2 active features at any
  time) and are structural / synthetic-fixture verification only;
  realistic load comes from the user's eventual multi-repo daily
  use, not from the verify stage.

### Session moves to archive while app is running

When a session is archived (moved from `.spec-workflow/features/<slug>/`
to `.spec-workflow/archive/<slug>/`) during a running app session, its
card disappears on the next polling cycle (default behaviour: fade
out on next poll, do not live-remove mid-interaction, per design open
decision item 9). No notification is fired for the disappearance. The
detail view, if currently open on that session, falls back to a
"session was archived" message rather than crashing.

### STATUS.md is malformed or partial mid-write

A STATUS.md whose `updated:` field cannot be parsed, or whose `##
Notes` block is absent, or which is mid-write (truncated) at the
moment of polling: the app falls back to mtime as the last-activity
signal (R3.c) and renders the card with a "stage: unknown" pill
rather than crashing or omitting the card. The card is still counted
for stale/stalled thresholds. A diagnostic log entry records the
parse failure but does not surface to the user as a notification.

### Repository moves or is deleted while running

A registered repo whose path no longer exists on disk (user moved or
deleted the directory): the repo's session set becomes empty on the
next polling cycle; the sidebar entry remains (with a small "path
not found" indicator) until the user removes it via Settings. The
app does not auto-unregister.

### macOS Notification Center permission denied

The user has denied notification permission to the app at the OS
level: stalled-state visual badges still render correctly (the badge
mechanism does not depend on notification permission); only the
banner suppression occurs. The app does not retry permission
prompting on every cycle. A one-line in-app banner (or settings
indicator) surfaces the denied permission state.

### Clock skew / future-dated STATUS lines

A STATUS.md whose `updated:` field or most-recent Notes line carries
a date in the future relative to system time: the app uses the
future date as last-activity (treats as fresh — idle-time clamps to
0). No special validation; this is treated as observer-side noise.

### Two app instances launched against the same settings file

Out of scope for v1 (R14). The second instance may overwrite the
first's settings on quit; users are expected to run a single
instance. A future feature (or B2) may add multi-instance lock /
detection.

## 7. Open decisions for architect

PRD picks defaults for visual-decision items 1–9 from the design
`notes.md`'s "Open visual decisions" list (per the user's PRD
instruction: pick sensible defaults rather than defer); these are
**baked into requirements** above and are not architect questions.
Items genuinely deferred to `/specflow:tech` are listed below.

1. **Desktop framework choice.** Tauri vs. Electron vs. native
   per-platform. PRD does not prescribe; brainstorm noted Tauri as
   the default lean. Architect picks based on bash-32-portability
   constraints for the surrounding tooling, binary-size budget,
   cross-platform (mac/Windows/Linux) story, and ease of meeting
   R10 (always-on-top floating panel) and R6 (macOS Notification
   Center API).
2. **Card-detail surface shape (R9).** Modal overlay vs.
   split-pane vs. separate window. Architect's call; PRD only
   requires read-only invariant (AC9.e) and the file-list +
   markdown-preview shape (AC9.a–d).
3. **Settings file location and format (R14).** Likely
   `~/Library/Application Support/<app>/settings.json` on macOS
   (and platform-equivalent on Windows/Linux), but Architect picks
   per framework conventions and bash-32-portability constraints
   for any reader scripts.
4. **Markdown rendering library (R9).** PRD requires read-only
   markdown rendering of the canonical artefact files; Architect
   picks the library/component, with the constraint that no
   inbound JS execution from untrusted markdown (the rendered
   files are user-owned, but XSS-safe defaults are still expected
   per `reviewer/security.md`).
5. **HTML mockup file (`02-design/mockup.html`) display.** PRD
   says "open in OS default browser" (AC9.d) — but Architect may
   propose an in-app webview if the framework offers a sandboxed
   one with no security cost. Default stays "open externally" if
   the in-app option carries any sandbox concern.
6. **macOS menu-bar icon with stalled-count badge.** PRD picks
   "yes, show menu-bar icon with stalled count" as the design
   default; Architect implements with whatever framework
   primitive is appropriate. If the framework forces a Dock icon
   instead (e.g., Tauri's tray support is platform-specific),
   that is a tech-stage trade-off to surface, not a PRD blocker.
7. **Polling implementation primitive.** `setInterval`, async
   timer, OS-native FSEvents/inotify, or a dedicated polling
   thread — Architect picks per framework and per the R13
   resource budget.
8. **Notification dedupe key (R6).** PRD specifies "one per
   stalled crossing"; Architect picks the dedupe state structure
   (per-session stalled-flag in memory; persistence not required
   across app restarts since a relaunch is a legitimate
   re-evaluation).

## 8. Defaults baked from design open-questions

For traceability — these design `notes.md` items had open visual
decisions; PRD has chosen a default for each and they are now
encoded in the requirements above. Each is "default chosen, revisit
at QA if it surfaces issues" (per PM instruction).

| Design notes item | PRD default chosen | Encoded in |
|---|---|---|
| 1. Min window width / responsive reflow | Default: 2-col grid above 720 px, reflow to 1-col below; min window width 480 px | Implicit in R7 (architect implements responsive reflow) |
| 2. zh-TW abbreviation table for stage pills | Default: short zh-TW labels per design mockup (實作, 設計, PRD, etc.); architect produces full mapping | R11.c (parity with design mockups) |
| 3. Compact panel attach/dock | Default: free-floating, always-on-top toggle in Settings | R10.b, R10.d |
| 4. Compact panel collapse target | Default: minimise to macOS menu-bar icon (item 5 default below) | R10 + item 5 below |
| 5. Menu-bar / Dock icon stalled-count badge | Default: yes, menu-bar icon with stalled-count badge | §7.6 (architect implements) |
| 6. Sort axis enumeration | Default: Last Updated DESC, Stage, Slug A–Z, Stalled-first | R7 + AC7.c |
| 8. "All Projects" layout | Default: grouped by repo with collapsible repo headers | R8 + AC8.a–c |
| 9. Archive disappearance | Default: fade out on next poll; do not live-remove mid-interaction | §6 "Session moves to archive" |

Item 7 (click behaviour) was answered by the user this turn and is
encoded in R9 in full.

## 9. Blocker questions

None — proceed to `/specflow:tech`.

## Team memory

Tier listing performed at task start:

- `~/.claude/team-memory/pm/` — present, contains
  `split-by-blast-radius-not-item-count.md` (global).
- `.claude/team-memory/pm/` — present, contains
  `ac-must-verify-existing-baseline.md`,
  `housekeeping-sweep-threshold.md`.
- `~/.claude/team-memory/shared/` — directory present, no
  index.md (dir not present: `~/.claude/team-memory/shared/index.md`).
- `.claude/team-memory/shared/` — present, contains
  `dogfood-paradox-third-occurrence.md`.

Applied:

- **`pm/split-by-blast-radius-not-item-count` (global)** — drove the
  B1/B2 split at brainstorm (already cited there) and is reinforced
  in this PRD §3 Non-goals: every "control plane" affordance is
  explicitly carved out as B2's surface, not absorbed into B1. The
  blast-radius rationale (B1 worst case = stale UI; B2 worst case
  = corrupted in-flight feature) is the load-bearing reason ACs
  like AC7.d and AC9.e exclude any write affordance from card
  hover-actions and the detail view.
- **`pm/ac-must-verify-existing-baseline`** — applied throughout
  R1, R3, R9. Where ACs reference STATUS.md schema parity (AC1.d,
  AC3.a, AC9.b), each cites a single concrete baseline file
  (`.spec-workflow/features/_template/STATUS.md` for the schema;
  `.spec-workflow/features/20260419-language-preferences/STATUS.md`
  for the Notes-line convention) rather than vague "match
  existing STATUS.md format" language. Verified before writing the
  ACs that both baselines align on the relevant fields (front-matter
  bullets, stage-checklist 11-line form, Notes line `- YYYY-MM-DD
  <role> — <action>` shape). [CHANGED 2026-04-19] Re-applied for
  the 2026-04-19 update: AC9.h cites the existing
  `.spec-workflow/features/20260419-flow-monitor/02-design/notes.md`
  file as the `open -R` baseline; AC9.i cites the existing
  STATUS.md Notes block in the same feature as the newest-first
  ordering baseline; AC15.e cites the design `02-design/notes.md`
  "Theming" table as the locked source of the `#4F46E5` /
  `#1B4332` primary-token hexes; AC15.f cites the same file's
  "Stage pills dark-mode re-toning" guidance as the contrast
  baseline. No vague "match the design" phrasing remains.
- **`shared/dogfood-paradox-third-occurrence`** — applied in §6
  Edge Cases under "Dogfood paradox". This feature ships a UI that
  observes specflow features but cannot observe its own development
  session before it ships; verify is structural-only for the
  runtime ACs enumerated, with runtime confirmation deferred to the
  next feature's first session after archive + app launch. This is
  the eighth-or-later occurrence of the pattern in this repo
  series; the existing memory file already covers six occurrences
  and the rule applies cleanly without requiring an update.

Considered, not load-bearing:

- **`pm/housekeeping-sweep-threshold`** — does not apply. This is a
  greenfield functional feature, not a review-nits sweep; no
  accumulated nit pool to threshold against.

Memory proposal (filed-candidate, not yet authored):

- **`pm/read-vs-write-feature-pair`** — when a request bundles
  observation and action over the same domain, splitting into a
  read-only B1 and a write-bearing B2 is the load-bearing
  application of `split-by-blast-radius-not-item-count` and
  recurs cleanly enough to deserve its own memory. This is a
  candidate second occurrence (the first was the
  `prompt-rules-surgery` series example in the existing global
  memory — session-wide vs. per-stage orchestration); a third
  occurrence would justify promoting. Hold off authoring until
  then.

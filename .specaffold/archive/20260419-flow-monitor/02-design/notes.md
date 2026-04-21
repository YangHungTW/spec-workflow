# Design Notes — flow-monitor B1

## Flows covered

| Screen | What it covers |
|---|---|
| Main Window (EN) | Multi-repo project switcher (left sidebar), session card grid, per-card display with all required fields, toolbar with sort and compact-mode toggle, language toggle in window chrome |
| Main Window (zh-TW) | Same layout with zh-TW UI copy; demonstrates language parity — stage pills, status badges, sidebar labels, timestamps all localised |
| Stalled State | Enlarged stalled card showing: top red accent bar, stalled badge with idle duration, contextual last-note excerpt, read-only actions (Open in Finder / Copy path); two-level severity legend (stale vs stalled); macOS Notification Center banner simulation |
| Compact Panel | Floating always-on-top panel in both EN and zh-TW; 1-line per session with coloured dot, slug, stage pill, relative time; "Open main" affordance; annotation notes for tooltip, drag, and click behaviour |
| Settings | General tab (language selector, idle thresholds with two severity levels, notification toggles, polling interval slider); Repositories tab (add/remove repos, folder-picker CTA, validation note) |
| Empty State | No repos registered; illustration, explanatory copy, primary CTA to add first repo, "what the app watches" explainer box |

## Design decisions locked in this pass

1. **Card grid (2-col)** over table or single-column list — allows quick scanning of stage + status at a glance without horizontal eye travel.
2. **Two-tier idle severity**: "Stale" (amber, mtime > stale threshold) and "Stalled" (red, pulsing badge, notification). Not a single level — avoids notification fatigue for minor lulls.
3. **Top accent bar on stalled card** — a 4px coloured bar at the card top edge provides a fast scannable signal even when the card is small in a dense grid.
4. **No sound** — locked by user; notification is visual only (banner, no sound flag).
5. **Read-only actions on stalled card**: "Open in Finder" and "Copy path" — both safe with no writes to user-owned state, consistent with B1 scope.
6. **Language toggle in window chrome** (top-right, two-state pill) — visible on every screen without occupying sidebar real estate.
7. **Project switcher as sidebar** — left sidebar holds repos + filter shortcuts; "All Projects" combined view is the default landing state.
8. **Sidebar "Add repo…" item** — styled as a dashed-border ghost item in empty state; normal italic link in populated state. Keeps CRUD affordance in context.
9. **Settings split into tabs**: General / Notifications / Repositories / About — keeps the panel manageable as more options accumulate in future.
10. **Compact panel dark glass style** — high contrast against both light (IDE) and dark (desktop wallpaper) backgrounds; avoids window-chrome clash.
11. **Polling indicator in sidebar footer** — "Polling · 3s" with green dot gives user confidence the app is live without cluttering card chrome.

## Open visual decisions for PRD / Architect input

1. **Card single-col vs 2-col at narrow window widths** — the 2-col grid breaks below ~720px. Should the app enforce a minimum window width, or does the grid reflow to 1-col? PRD should specify minimum window dimensions or responsive behaviour.
2. **Stage pill localisation depth** — zh-TW screen uses short labels ("實作", "設計", "PRD"). English uses full stage names. Some stages (gap-check, verify) are long in EN. PRD should specify whether zh-TW pills use the English slug, a short zh-TW label, or a defined abbreviation.
3. **Compact panel dock vs free-float** — currently shown as a free-floating draggable panel. Alternative: snap-to-screen-edge (like macOS Dock). PRD/Architect should decide since this affects window management API surface.
4. **Compact panel expand/collapse** — no collapse affordance is mocked. If the user wants to hide the panel without closing it, is that a minimise-to-menubar-icon UX, or a collapse-to-title-bar? Needs decision.
5. **Tray icon / menu bar icon** — not mocked. The brainstorm mentions dock/tray icon behaviour as a UX default the Designer stage should surface. Should a tray icon show a badge count for stalled sessions? PRD must decide.
6. **Sort options** — toolbar shows "Sort: Last Updated" but the full sort menu is not mocked (options could include: Stage, Project, Stalled-first, Slug alphabetical). PRD should enumerate valid sort axes.
7. **Click behaviour on a card** — mocked as "cursor: pointer" with hover shadow, but no card-detail slide-out or drill-down screen is in scope for B1. PRD should confirm: click = open in Finder, or click = expand inline detail, or click = nothing (B2)?
8. **"All Projects" combined view ordering** — when multiple repos are shown together, what is the interleaving order? Per-repo grouping with headers, or flat sorted by last-updated ignoring repo boundary? Not mocked either way; PRD to specify.
9. **Archive exclusion visual** — brainstorm specifies sessions in `archive/` are excluded. What happens if a session moves to archive while the app is running? Does the card disappear immediately, animate out, or stay until next poll? Edge case, but UX consistency requires a decision.
10. **Notification repeat policy** — mock notes "fires once per stalled transition". PRD must define: does it re-fire if the session stays stalled for another N minutes? Or only on first crossing? Silence vs repeat is a UX policy.

## Uncovered states / out-of-scope for B1 mockup

- Card detail expand / drill-down (B1 click = open in Finder only)
- Multi-select cards (B2)
- Control-plane actions (send instruction, invoke specflow command) — B2 feature
- Start-on-login setting (Settings > General; not mocked — PRD policy question)
- Windows / Linux window chrome (only macOS traffic-lights mocked; cross-platform chrome TBD by Architect)

## Theming (added 2026-04-19)

### Dark-mode primary colour chosen

`#1B4332` — deepest ink green from the provided palette. Rationale: it reads as unmistakably green (not teal, not olive) while being dark enough to serve as a sidebar active-item background, brand accent, and button fill against a very dark `#0F1411` page background without burning contrast. WCAG AA is satisfied: `#D4EDE1` text on `#1B4332` exceeds 4.5:1 on the active sidebar item and primary button.

### Decision: ship both light and dark modes in B1

Both modes are implemented in the mockup via CSS custom properties on `html.dark` and a localStorage-persisted toggle in the nav bar. This removes "dark mode" from the uncovered-states list. PRD should formally capture this as a B1 AC.

### Surfaces re-toned for dark mode

| Element | Light value | Dark value |
|---|---|---|
| Page background | `#F1F5F9` | `#0F1411` (very dark, slight green tint) |
| Card / surface | `#FFFFFF` | `#1A211D` |
| Surface secondary | `#F8FAFC` | `#141C18` |
| Sidebar background | `#1E293B` | `#111A15` |
| Sidebar active item | `#4F46E5` (indigo) | `#1B4332` (ink green) |
| Sidebar borders | `#334155` | `#1F2E24` |
| Sidebar text (muted) | `#94A3B8` | `#6B9176` |
| Nav bar | `#FFFFFF` | `#111A15` |
| Window chrome | `#F8FAFC` | `#141C18` |
| Text primary | `#1E293B` | `#E8F0EB` (near-white, warm-green tint) |
| Text muted | `#94A3B8` | `#5C7A68` |
| Card border | `#E2E8F0` | `#1F2E24` |
| Stalled card bg | `#FEF2F2` | `#1F1212` |
| Stale card bg | `#FFFBEB` | `#1F1A0E` |
| Compact panel bg | `rgba(15,23,42,0.92)` | `rgba(10,18,13,0.94)` (ink-green dark glass) |
| Compact panel logo accent | `#4F46E5` | `#1B4332` |
| Stalled red | `#EF4444` | `#C53030` (slightly desaturated) |
| Stale amber | `#F59E0B` | `#D97706` (slightly desaturated) |

### Stage pills dark-mode re-toning

All 8 stage pills were re-toned: light pill backgrounds were replaced with dark, low-saturation equivalents that do not look like stickers against the dark surface. Each pill retains a readable, distinct hue — blue family for brainstorm/verify, purple for design, green family for implement/tech, amber for prd, pink for plan, red for gap-check.

### Open question for PRD

Should the app follow the OS appearance (system dark mode via `prefers-color-scheme`) as the default, or always open in light mode until the user explicitly toggles? Current mockup defaults to **light mode** (user-only toggle, no OS detection). Recommendation: keep user-only toggle in B1 to avoid complexity; add OS-follow as a B2 enhancement. PRD should capture this decision explicitly.

### Toggle placement decision

The light/dark toggle sits at the far-right end of the mockup nav bar (alongside the screen-switch buttons). In the shipped app it would live in the window title bar or a Settings > General row — not in the mock nav bar which is a preview-only affordance. PRD should specify the in-app toggle location (Settings > General is the natural home; a persistent icon in the toolbar is a UX option).

## Card Detail (added 2026-04-19)

### Layout pattern

Master-detail: the card detail view occupies the full main window (same macOS chrome, same sidebar-less content area). It is a navigation, not a modal — clicking a session card in the Main Window navigates to this view; the back arrow in the breadcrumb returns to the all-sessions grid.

Three zones:

1. **Breadcrumb bar** (sticky, 1-line): `← All Sessions / [repo] / [slug]`. The back arrow and "All Sessions" link are the only navigation affordances. Slug is plain text (non-clickable end of path).
2. **Header strip**: slug in monospace, large stage pill, has-ui badge, last-updated relative time, active/stale/stalled badge. Right side: "Open in Finder" and "Copy path" action buttons (B1 safe actions only; no edit/advance buttons).
3. **Two-pane body**:
   - Left rail (260px fixed): stage checklist + Notes timeline.
   - Right pane (flex-1): tab strip + markdown preview + read-only footer.

### Stage checklist orientation decision

**Vertical list chosen** (11 rows). Rationale: 11 stages do not fit horizontally without truncation at normal window widths; a vertical list in the left rail is the natural rail pattern and pairs cleanly with the Notes timeline below it. Each row shows a 16×16 rounded-square checkbox (purely visual — no click handler; B1 read-only) and the stage slug. The current stage is highlighted with the brand accent background and a "CURRENT" label on the right. Future stages are italic and faint.

### Tab navigation across markdown docs

Nine tab slots correspond to the eight numbered document slots (00–08) that specflow generates:

| Tab | File | Behaviour when file exists | Behaviour when not yet generated |
|---|---|---|---|
| 00 request | `00-request.md` | Renders markdown preview | — (always exists if session started) |
| 01 brainstorm | `01-brainstorm.md` | Renders markdown preview | Muted + italic tab, tooltip "Not yet generated" |
| 02 design | `02-design/*` | Shows folder file index (not parsed markdown — design stage is a directory) | Muted + italic tab |
| 03 prd | `03-prd.md` | Renders markdown preview | Muted + italic tab |
| 04 tech | `04-tech.md` | Renders markdown preview | Muted + italic tab |
| 05 plan | `05-plan.md` | Renders markdown preview | Muted + italic tab |
| 06 tasks | `06-tasks.md` | Renders markdown preview | Muted + italic tab |
| 07 gaps | `07-gaps.md` | Renders markdown preview | Muted + italic tab |
| 08 verify | `08-verify.md` | Renders markdown preview | Muted + italic tab |

Default tab on open: the latest existing document (highest slot number that exists). In the mockup example (flow-monitor at PRD stage), default is `03 prd`.

### Example session chosen

`20260419-flow-monitor` (the flow-monitor feature itself — dogfood case). Rationale: (a) it is the most populated session in this repo at design time — stages 00–03 complete, current stage PRD — giving a realistic checklist and timeline; (b) using the feature being designed makes the read-only nature of the detail view self-evident; (c) the Notes timeline entries are real history from the STATUS.md log, so reviewers can validate the format against the actual file.

### Read-only reinforcement

Footer of the markdown pane: `"Read-only preview. Open in Finder to edit."` — small, muted, italic. Appears on every tab. Anchors PRD R7 / AC7.f for every reviewer seeing the mockup.

### Design for 02-design tab (folder case)

The `02-design` tab cannot render a single markdown document because the stage produces a directory. The mockup shows a simple file-index list (filename + description in monospace, one row per file with a document icon). This hints to the Architect that the rendering layer must detect directory-type stages and switch to a file-index view rather than a markdown parser.

### Compact panel click behaviour (annotation)

The compact panel screen (Screen 4) already shows 1-line session rows. Clicking a session row in the compact panel is annotated as "opens main window, navigates to card detail for that session" — no separate compact-detail screen is needed or designed. This is noted on the Compact Panel screen and in the annotation box below Screen 7.

### Visual decisions still open for PRD update

1. **Breadcrumb back-navigation target**: does clicking `← All Sessions` always return to the last-viewed project filter, or always to "All Projects" combined view? Not specified in PRD; recommend "last-viewed filter" as the natural expectation (browser back-button parity), but PRD must lock this.
2. **Stage checklist — current-stage row highlight**: mockup uses a brand-light background tint on the current row. If the brand token changes between light and dark mode (indigo in light, ink-green in dark), the highlight also shifts. PRD should confirm this is acceptable or specify a fixed accent.
3. **Tab strip overflow behaviour**: at narrow window widths, the 9-tab strip will overflow. The mockup uses `overflow-x: auto` (hidden scrollbar). Should there be a scroll-fade indicator, or should tabs wrap? PRD/Architect to decide for implementation.
4. **02-design folder tab — sub-file click**: in the file-index list for the design folder, should individual files (mockup.html, notes.md, README.md) be clickable to "Open in Finder" for that specific file, or is the only affordance the header "Open in Finder" button (which opens the folder)? B1 read-only contract does not block a per-file "reveal in Finder" action, but PRD should specify.
5. **Notes timeline cap**: the mockup shows all timeline entries. For sessions with many STATUS.md notes (e.g. 50+), should the rail show "latest 10 — see Finder for full log" with a cap? Or scroll without cap? UX + performance question for PRD.
6. **Stalled/stale badge in card detail header**: the mockup shows an "Active" badge. For a stalled session viewed in card detail, should the red stalled badge pulse here too (consistent with card grid), or remain static in the detail header? Recommend static (pulsing in detail is distracting), but PRD should decide.

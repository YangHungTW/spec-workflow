# PRD — 20260422-monitor-ui-polish

## 1. Summary

As the repo owner watching my scaff feature runs in the flow-monitor Tauri app, I want four small polish items so that day-to-day observation is faster and less ambiguous: (1) every scaff agent shows up in a consistent, scannable colour so I know at a glance which role is driving the current stage; (2) archived features under `.specaffold/archive/` are reachable from the sidebar without hiding them behind a separate flow; (3) stage tabs whose underlying file has not been produced yet are visibly disabled so I don't click into empty/error views; and (4) the 10 scaff agent markdown files under `.claude/agents/scaff/` carry a `color:` frontmatter entry that acts as the single source of truth for the agent palette, so a role appears in the same colour in CLI transcripts and in the monitor.

## 2. Personas / users

- **Primary**: the repo owner (sole user), observing active feature runs and occasionally auditing archived ones. Uses the flow-monitor as the primary surface; reads CLI transcripts as a secondary surface.
- **Secondary (implicit)**: any future contributor or reviewer reading a Notes timeline or a CardDetail view — they benefit from consistent role colour cues without needing to memorise any mapping.

## 3. Goals

- Make the active role on each feature card and CardDetail instantly identifiable by colour, with a palette that is stable across sessions.
- Surface archived features in the sidebar as read-only entries so the owner can inspect history without leaving the monitor.
- Prevent navigation into empty/non-existent stage artefacts by visibly disabling the corresponding tabs.
- Bind the CLI and monitor palettes to one authoritative source (`color:` frontmatter), eliminating drift between the two rendering surfaces.
- Keep all four items scoped to the flow-monitor frontend plus the 10 agent files — no CLI behaviour, no features-tree schema, no archive-layout changes.

## 4. Non-goals

- Editing, re-opening, mutating, or advancing archived features from the monitor (inspection only).
- Changing the set of stages, the on-disk feature layout, or anything under `.specaffold/features/*` schemas.
- Theming / dark-mode / broader monitor restyle beyond the items listed here. Dark-mode treatment of the agent palette is explicitly deferred — see §7 blocker (d).
- Dark-mode agent palette — deferred to a follow-up theming feature (resolved 2026-04-22). [RESOLVED 2026-04-22]
- Accessibility (WCAG) audit of the final palette beyond the existing 4.5:1 contrast target already documented in `02-design/palette.md`.
- Providing a dedicated archive browser, search, or cross-repo archive aggregation.
- Teaching the CLI anything new about `color:`; the CLI already consumes the frontmatter. This feature only writes the values.

## 5. Requirements

### Group A — CLI agent colour frontmatter (item 4, source of truth)

- **R1 (must)**: Each of the 10 scaff agent files listed in `02-design/notes.md` §"Scaff agent files that will receive `color:` frontmatter additions" carries exactly one `color:` key in its YAML frontmatter. The value for each file matches the mapping table in that section (authoritative source: `02-design/palette.md` "Role-to-color mapping"). Files affected: `.claude/agents/scaff/{pm,architect,tpm,developer,designer,qa-analyst,qa-tester,reviewer-security,reviewer-performance,reviewer-style}.md`.
- **R2 (must)**: The `color:` value on every file is one of the 8 Claude Code predefined names: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`. No other string is accepted.
- **R3 (must)**: The three reviewer files (`reviewer-security`, `reviewer-performance`, `reviewer-style`) all carry `color: red`. The remaining 7 non-reviewer agents each carry a unique colour not used by any other non-reviewer.
- **R4 (must)**: No other frontmatter keys (`name`, `model`, `description`, `tools`) are altered by this change. The `color:` key is additive. Content below the frontmatter is unchanged.
- **R5 (should)**: `.appendix.md` files under `.claude/agents/scaff/` do NOT receive `color:` frontmatter — they are not agent definitions (confirmed by `02-design/notes.md`).

### Group B — Monitor agent palette and pill (item 1)

- **R6 (must)**: flow-monitor exposes a single TypeScript source-of-truth module (e.g. `flow-monitor/src/agentPalette.ts` or equivalent) that maps each of the 10 role identifiers (`pm`, `architect`, `tpm`, `developer`, `designer`, `qa-analyst`, `qa-tester`, `reviewer-security`, `reviewer-performance`, `reviewer-style`) to: (a) the Claude Code colour name from R1/R3, and (b) the CSS variable prefix / hex tokens defined in `02-design/mockup.html` lines 52–100 and tabulated in `02-design/palette.md`. Every component that needs to render an agent identity consumes this module; no hex literal for an agent colour appears in any component outside this module.
- **R7 (must)**: A new `AgentPill` component renders a role pill with the same border-radius, font-size, and padding as the existing `StagePill` (see `flow-monitor/src/components/StagePill.tsx` + the `.stage-pill` shape reproduced in `02-design/mockup.html` lines 394–404). The pill contains: a 5px leading dot coloured by `--agent-<role>-dot`, the role label, and (for reviewer roles only) an axis sub-badge of `sec` / `perf` / `style` rendered per the `.agent-pill__axis` shape in `02-design/mockup.html` lines 424–434.
- **R8 (must)**: The axis sub-badge text length is 3–5 characters (`sec`, `perf`, `style`); it is present iff the role is one of the three reviewer axes. Non-reviewer roles render the pill without an axis sub-badge.
- **R9 (must)**: `SessionCard` renders an `AgentPill` for the active role of the session. Placement is a new row below the slug/stage row, matching the mockup (`02-design/mockup.html` lines 1160–1162). `SessionCard` must not drop its existing `StagePill`, `UI` badge, `Active` badge, relative time, or note excerpt. [RESOLVED 2026-04-22]
- **R10 (must)**: CardDetail's header renders an `AgentPill` next to the existing `StagePill` for the feature's current active role, matching the composite view in `02-design/mockup.html` lines 1280–1284.
- **R11 (should)**: `NotesTimeline` entries colour the role name span using the palette's `--agent-<role>-dot` hex (see `02-design/mockup.html` lines 648–658 and the in-context example lines 794–821). The role name remains plain text weight-wise; only the colour changes.
- **R12 (should)**: `RepoSidebar` entries render a 7px coloured dot next to the feature slug using `--agent-<role>-sidebar-dot`, per the mockup's "Composite" view (`02-design/mockup.html` lines 1092–1113). The dot reflects the feature's current active role.
- **R13 (must)**: Role identification for a given feature is a pure function of inputs already available to the frontend today (session state + stage, plus a resolvable "current active role" signal). No new IPC, no backend schema change. If the backend does not yet surface a role field, the resolver uses a documented heuristic from stage → default role (e.g. `prd → pm`, `tech → architect`, `plan → tpm`, `implement → developer`, `verify → qa-tester`, `gap-check → qa-analyst`, `design → designer`); the heuristic lives in the same palette module from R6.

### Group C — Archived features visibility (item 2)

- **R14 (must)**: `RepoSidebar` renders a new "Archived" section below the active projects list, per the mockup (`02-design/mockup.html` lines 871–876 collapsed state, lines 921–939 expanded state). The section header shows the label `Archived`, the archived count, and a disclosure chevron (`▶` collapsed, `▼` expanded).
- **R15 (must)**: The Archived section is collapsed by default on first render. Its expansion state is persisted across app restarts using the same store mechanism already used for other sidebar UI state (e.g. theme, selectedRepoId, collapsedRepoIds in `flow-monitor/src/stores/sessionStore.ts`); a user's expand/collapse choice survives app restart.
- **R16 (must)**: Archived entries are enumerated from `.specaffold/archive/<slug>/` across the currently registered repos. The discovery mechanism is additive to the existing active-features discovery and is confined to the same repos the monitor already watches; no new repo registration flow.
- **R17 (must)**: Each archived entry renders as a sidebar row with: italic slug, an `arch` badge, and reduced opacity (0.65) matching `02-design/mockup.html` lines 927–938. Archived entries do NOT carry a coloured role dot (archived features have no active role).
- **R18 (must)**: Clicking an archived entry opens CardDetail in read-only mode: the header shows an `ARCHIVED` badge and a `Read only` indicator per `02-design/mockup.html` lines 960–972. The CardDetail body renders existing artefacts from the archived feature directory as read-only markdown; no Advance, Send, or Edit affordance is present.
- **R19 (must)**: CardDetail for an archived feature MUST NOT trigger any IPC that would mutate the feature directory (no `advance_stage`, no writes). Read IPCs for artefact content are allowed and unchanged.
- **R20 (must)**: Hover actions on archived sidebar entries retain both "Open in Finder" and "Copy path" — the same 2 hover actions as active entries — because both are read-only operations and useful for inspecting archived content on disk. [RESOLVED 2026-04-22]

### Group D — Disabled tabs when artefact missing (item 3)

- **R21 (must)**: For any feature (active or archived), stage tabs whose underlying artefact file does not exist on disk render with: `opacity: 0.38`, `cursor: not-allowed`, `border-bottom-color: transparent`, and the existing `tab-strip__tab--missing` class retained per `02-design/mockup.html` lines 558–569. (The current implementation uses `opacity: 0.5`; this R tightens it to 0.38 for clearer non-interactivity signalling, per `02-design/notes.md` §"Item 3 — Disabled tab visual treatment".)
- **R22 (must)**: Disabled tabs show the tooltip "Not yet produced" via a CSS `::after` pseudo-element on hover, matching `02-design/mockup.html` lines 571–589, replacing the current native `title` attribute behaviour. The tooltip appears immediately (no native delay). The `title` attribute MAY remain as an accessibility fallback but the CSS tooltip is the primary treatment.
- **R23 (must)**: Tab existence is computed per-feature from the actual on-disk files. For the 9 tabs defined in `flow-monitor/src/views/CardDetail.tsx` (`00-request`, `01-brainstorm`, `02-design`, `03-prd`, `04-tech`, `05-plan`, `06-tasks`, `07-gaps`, `08-verify`), `exists` is `true` iff the referenced `.file` path is present in the feature directory. The `02-design` tab's `exists` is `true` iff the `02-design/` directory exists with at least one indexed file. All 9 entries must receive a real `exists` value — the current hardcoded `exists: true` for all 9 (see lines 20–30 of CardDetail.tsx) is replaced with a computed value.
- **R24 (must)**: Clicking a disabled tab (`exists=false`) does NOT change the active tab and does NOT invoke `onSelect`. The click is blocked inside the `TabStrip` component — when a user clicks a tab with `exists=false`, `TabStrip` does not fire `onSelect(tab.id)` (the current code in `flow-monitor/src/components/TabStrip.tsx` line 80 unconditionally calls `onSelect` and must be guarded). [RESOLVED 2026-04-22]
- **R25 (should)**: Disabled tabs remain in the DOM (not hidden) so the user can see the full stage progression; this matches the current behaviour and `02-design/notes.md` §"Item 3".

### Group E — Cross-cutting

- **R26 (must)**: No hex literal for any agent colour appears outside the palette module from R6. Sidebar dot, pill background, pill foreground, notes-timeline role colour all flow through CSS variables or the TypeScript palette map.
- **R27 (should)**: All existing `SessionCard`, `CardDetail`, `TabStrip`, `RepoSidebar` behaviours not explicitly modified in R6–R25 remain unchanged — visual regression baseline is the monitor's state at commit `06432ce` (HEAD on 2026-04-22).

## 6. Acceptance criteria

Each AC is observable by a QA-tester running the monitor against a local specaffold checkout with at least one active feature and at least one archived feature.

- **AC1 (agent files)**: `grep -E '^color:' .claude/agents/scaff/{pm,architect,tpm,developer,designer,qa-analyst,qa-tester,reviewer-security,reviewer-performance,reviewer-style}.md` returns exactly 10 lines, each matching the mapping in `02-design/notes.md` §"Scaff agent files that will receive `color:` frontmatter additions".
- **AC2 (colour names valid)**: Every `color:` value found by AC1 is one of `{red, blue, green, yellow, purple, orange, pink, cyan}`. No other string appears.
- **AC3 (reviewer grouping)**: The three reviewer files all have `color: red`. The 7 non-reviewer files have 7 distinct colour names among the remaining 7 values.
- **AC4 (frontmatter intact)**: `git diff` for the 10 files modified in AC1 shows only additions of a single `color:` line within the existing `---` frontmatter block; no other lines are changed.
- **AC5 (appendix untouched)**: `grep -l '^color:' .claude/agents/scaff/*.appendix.md` returns no matches (appendix files carry no `color:` key).
- **AC6 (palette module)**: A single TypeScript module under `flow-monitor/src/` exports a palette map with all 10 role keys; at most one file in `flow-monitor/src/` contains an agent hex literal (e.g. `#7C3AED`); all other components reference the palette via the module's exports or via the CSS custom properties the module defines.
- **AC7 (AgentPill shape)**: In the running monitor, inspecting an `AgentPill` in DevTools shows the pill has `border-radius: 9999px` (same as `.stage-pill`), font-size matching the existing `.stage-pill` token (9px per mockup), and an inner 5px round dot element. Visual parity with the mockup's `.agent-pill` (lines 406–423 of `02-design/mockup.html`) is confirmed by side-by-side comparison.
- **AC8 (reviewer sub-badge)**: When a reviewer role is active, the `AgentPill` renders an inner axis sub-badge with text exactly `sec`, `perf`, or `style` (uppercase or lowercase per the mockup's `.agent-pill__axis { text-transform: uppercase; }` — final casing must match the mockup). Non-reviewer roles render the pill with no axis sub-badge.
- **AC9 (palette applied — SessionCard)**: On the MainWindow card grid, every `SessionCard` displays an `AgentPill` whose colour matches the palette mapping for its active role. The pill is positioned on a new row below the slug/stage row, matching `02-design/mockup.html` lines 1160–1162. [RESOLVED 2026-04-22]
- **AC10 (palette applied — CardDetail)**: On CardDetail, the header contains an `AgentPill` rendered next to the `StagePill`, matching the composite in `02-design/mockup.html` line 1284.
- **AC11 (palette applied — NotesTimeline)**: In CardDetail's left rail NotesTimeline, each entry's role name is rendered in the colour from the palette for that role. Changing a Note's role (e.g. from `PM` to `Developer`) changes the displayed colour; verified by swapping a test feature's notes and reloading.
- **AC12 (palette applied — sidebar dot)**: In `RepoSidebar`, every active-feature row shows a 7px coloured dot to the left of the slug whose fill matches `--agent-<role>-sidebar-dot` for the feature's current active role. Archived entries do NOT display this dot.
- **AC13 (archive section renders)**: `RepoSidebar` renders an "Archived" section with label, count, and chevron below the active Projects list. With 0 archived features the section renders with count `0` and an inactive chevron (or is hidden — final behaviour: render with count `0` visible to preserve spatial memory).
- **AC14 (archive default collapsed)**: On first app launch after this change is installed, the Archived section is collapsed (chevron `▶`, no entries visible). Clicking the header expands it (chevron `▼`, archived entries visible). Clicking again collapses it.
- **AC15 (archive state persists)**: After expanding the Archived section and restarting the app, the section is still expanded on next launch. After collapsing it and restarting, it is still collapsed.
- **AC16 (archive discovery)**: For a repo that has N subdirectories under `.specaffold/archive/`, the Archived section's count equals N and, when expanded, N rows are rendered (one per slug). Verified by adding/removing an archive directory and refreshing.
- **AC17 (archive row styling)**: Each archived row renders the slug in italic, shows an `arch` badge, and has opacity 0.65 relative to active rows. Hover raises opacity to ≥0.9 (per `02-design/mockup.html` line 293).
- **AC18 (archived CardDetail — read only)**: Clicking an archived row navigates to CardDetail and displays an `ARCHIVED` badge plus a `Read only` indicator in the header, matching `02-design/mockup.html` lines 960–972. No Advance / Send / Edit control is rendered anywhere on the archived CardDetail.
- **AC19 (archived — no mutate IPC)**: While viewing an archived feature's CardDetail, the network/IPC tab shows ONLY read commands (`read_artefact`, `get_settings`, `list_sessions`, `open_in_finder`); no `advance_stage`, no mutate command fires. Verified by interacting with every visible control (tab selection, back button).
- **AC20 (disabled tab visual)**: In CardDetail for a feature whose current stage is `prd`, the `Tech`, `Plan`, `Tasks`, `Gaps`, and `Verify` tabs (whose backing files do not exist) render with opacity 0.38, `cursor: not-allowed`, and no active underline. The `Request`, `Brainstorm`, `Design`, `PRD` tabs remain at full opacity and clickable.
- **AC21 (disabled tooltip)**: Hovering a disabled tab reveals a tooltip "Not yet produced" within the same hover-frame (no ≥0.5s OS delay), positioned above the tab per `02-design/mockup.html` lines 571–589.
- **AC22 (disabled click blocked)**: Clicking a disabled tab does NOT change the visible tab content, does NOT highlight the clicked tab as active, and does NOT fire `onSelect` from `TabStrip`. The previously-active tab's content and highlight remain. Verified by clicking `Tech` (disabled) while `PRD` is active — `PRD` stays active and its content stays rendered; `TabStrip`'s `onSelect` handler is not called. [RESOLVED 2026-04-22]
- **AC23 (exists computed)**: For a synthetic feature directory containing only `00-request.md` and `03-prd.md`, opening the feature in CardDetail renders `Request` and `PRD` as enabled tabs; the other 7 tabs render as disabled. Adding `04-tech.md` to disk and reloading the feature switches `Tech` to enabled.
- **AC24 (no regressions — baseline)**: The MainWindow card grid, sort toolbar, polling footer, compact panel toggle, `Open in Finder` / `Copy path` hover actions, repo picker, and theme toggle all function identically to commit `06432ce` (HEAD on 2026-04-22) — verified by a manual pass through the smoke flow.

## 7. Open questions / blockers

No blockers — all 4 prior questions resolved 2026-04-22 (defaults accepted: a=new-row, b=keep-hover-actions, c=block-onSelect, d=defer-dark-mode).

## 8. Test plan hooks (brief)

- **Agent frontmatter**: shell-level grep / awk checks against `.claude/agents/scaff/*.md` for AC1–AC5. No TypeScript involved.
- **Palette module**: a unit test in `flow-monitor/src/` that imports the palette and asserts all 10 role keys resolve to one of the 8 colour names; asserts reviewer-{security,performance,style} all map to `red` and the remaining 7 map to distinct non-red names.
- **AgentPill component**: render-test coverage — renders pill with dot, renders axis sub-badge for the 3 reviewer roles and omits it for the other 7, applies the correct CSS variables / class names.
- **SessionCard / CardDetail / RepoSidebar**: integration coverage verifying the pill / dot appears in each surface with the correct role mapping.
- **Archived features**: fixture repo with a populated `.specaffold/archive/<slug>/` directory; tests cover discovery, default-collapsed state, expand/collapse persistence, read-only CardDetail rendering, and the absence of mutate IPC calls.
- **Disabled tabs**: fixture feature directory with a known subset of artefact files; tests cover `exists` computation, visual state of disabled tabs, tooltip rendering, and the `onSelect` guard in `TabStrip`.
- **Regression**: the existing flow-monitor smoke-test suite runs unchanged (AC24).

# Design Notes — 20260422-monitor-ui-polish

## Flows covered

- Item 1: Agent role pill (all 10 roles) on light background; role dot on dark sidebar;
  role-colored role name in the NotesTimeline left rail.
- Item 2: Sidebar "Archived" section in collapsed state (default), expanded state, and
  archived feature selected in CardDetail header with read-only banner.
- Item 3: Tab strip before/after comparison; disabled state with CSS ::after tooltip;
  full composite with tabs disabled beyond the current stage.

## Decisions

### Item 1 — Where agent color appears

The agent/role color appears in three places:
1. A small colored dot next to the feature slug in the sidebar (7px dot, no full pill —
   keeps the sidebar compact).
2. A pill badge (`AgentPill`) in the `SessionCard` body, below the slug/stage pill row.
   This is a new row; it does not replace the StagePill.
3. Colored role name in the `NotesTimeline` entries in the CardDetail left rail. This
   reuses the existing `notes-timeline__role` span; only the color changes.

The pill shape is identical to `StagePill` (border-radius 9999px, same font-size/padding).
A small lead dot (5px circle) inside the pill provides a secondary cue beyond hue alone.

### Item 2 — Archive surfacing: collapsible section (recommended)

**Chosen:** Collapsible "Archived" section label in the sidebar, collapsed by default,
below active projects. Count badge on the section header ("Archived 3"). Archived entries
carry an italic slug and an "arch" badge; they are visually muted (opacity 0.65).

**Rationale:** The user rarely browses archives (they are finished features). A collapsed
section is zero visual noise in the normal case and one click to expand. The alternative —
an "Archived" filter toggle in the Filter section — would require the user to first toggle
the filter and then wait for a list refresh, adding two interactions. The collapsible
section is also spatially stable: expanding it pushes content below it rather than
replacing the active list, which preserves spatial memory.

**Alternative not chosen:** Filter toggle ("Show archived") in the Filter section.
This is the simpler implementation but adds an extra interaction step. Noted as a fallback
if the sidebar height becomes a concern on small screens.

### Item 3 — Disabled tab visual treatment

The existing `tab-strip__tab--missing` class (opacity 0.5, cursor not-allowed) is tightened
to opacity 0.38 for clearer non-interactivity signaling. A CSS `::after` tooltip replaces
the native `title` attribute tooltip for two reasons:
1. Native title tooltips have a 0.5–1s OS-imposed delay on macOS.
2. The CSS tooltip appears immediately on hover, matching the app's existing hover affordance
   on action buttons.

Disabled tabs remain in the DOM (not hidden) so the user can see what stages exist and how
many are still pending. The tab strip already supports horizontal scroll (overflow-x: auto),
so adding disabled tabs does not change the strip's layout contract.

## CLI alignment (option B)

### Decision

The user selected option B: the agent color palette is constrained to the 8 predefined
`color:` values supported by Claude Code's subagent frontmatter (`red`, `blue`, `green`,
`yellow`, `purple`, `orange`, `pink`, `cyan`). This means:

1. The monitor's palette map uses these 8 names as keys (not arbitrary hex), and
   renders each name with the CSS hex defined in `palette.md`.
2. Each of the 10 scaff agent files receives a `color:` frontmatter addition as part
   of this feature's implementation — this is not a follow-up task.
3. The CLI transcript and the monitor will display the same role in the same color
   because they share the same `color:` value source.

The chosen mapping (all 3 reviewers share `red`; 7 other roles each get a unique color)
is detailed in `palette.md` under "Chosen split".

### Scaff agent files that will receive `color:` frontmatter additions

These 10 files are the Developer's implementation targets. Each file needs one new
frontmatter key: `color: <name>` using the mapping from `palette.md`.

| Agent file | `color:` value |
|---|---|
| `.claude/agents/scaff/pm.md` | `purple` |
| `.claude/agents/scaff/architect.md` | `cyan` |
| `.claude/agents/scaff/tpm.md` | `yellow` |
| `.claude/agents/scaff/developer.md` | `green` |
| `.claude/agents/scaff/designer.md` | `pink` |
| `.claude/agents/scaff/qa-analyst.md` | `orange` |
| `.claude/agents/scaff/qa-tester.md` | `blue` |
| `.claude/agents/scaff/reviewer-security.md` | `red` |
| `.claude/agents/scaff/reviewer-performance.md` | `red` |
| `.claude/agents/scaff/reviewer-style.md` | `red` |

Note: `.appendix.md` files are not agent definition files and do not receive `color:` frontmatter.

---

## Open questions for user

1. **Agent pill placement in SessionCard:** The mockup places the agent pill on a new row
   below slug/stage. Should it instead replace the "Active" badge on the meta row, or sit
   inline next to the StagePill? The current card is already compact; a new row adds ~20px.

2. **Archived feature: click-through behavior.** The mockup shows archived features open
   in CardDetail with a "Read only" banner and no write actions. Should archived tabs be
   further restricted (e.g. no "Open in Finder" hover action), or is full read access
   acceptable?

3. **Disabled tabs: click behavior.** Currently the mockup treats disabled tabs as
   truly non-clickable (`pointer-events: none` equivalent via `cursor: not-allowed`
   + no `onClick`). The existing `TabStrip.tsx` code actually calls `onSelect(tab.id)`
   even for `exists=false` tabs (the `--missing` class is cosmetic only). Should we
   block the click event entirely at the component level, or let the existing behavior
   stand (tab selected, content pane shows empty/error state)?

4. **Dark-mode agent colors:** The mockup covers light theme only. Dark-mode equivalents
   follow the existing pattern (darker pill bg, lighter pill fg) but need a second pass.
   Should dark-mode palette be included in PRD scope or deferred?

# Tech — 20260422-monitor-ui-polish

Scope: the flow-monitor Tauri app (`flow-monitor/`) plus 10 scaff-agent
markdown files under `.claude/agents/scaff/`. No CLI behavioural change,
no features-tree schema change, no archive-layout change (per 03-prd.md
§4 non-goals).

Cross-refs to 02-design:
- Role→colour table: `02-design/palette.md` "Role-to-color mapping"
- Visual spec: `02-design/mockup.html`
- Decisions log: `02-design/notes.md`

No hex literals appear in this doc; all colours are referenced by Claude
Code colour name (one of the 8 per 03-prd R2) or by CSS variable name.

## 1. Tech stack / framework

Confirmed from `flow-monitor/package.json` and `src-tauri/`:

- **Frontend**: React 19 + TypeScript 5.7 + Vite 6.
- **State**: hook-based stores (`useState` + `useEffect` + `useCallback`)
  per the existing `sessionStore.ts` / `invokeStore.ts` / `themeStore.ts`
  shape. No Zustand, no Redux — the repo deliberately avoids a new
  state library (see `invokeStore.ts` header comment). This feature
  follows the same pattern.
- **Tests (frontend)**: Vitest + @testing-library/react + jsdom;
  existing suite under `flow-monitor/src/**/__tests__/`.
- **Backend**: Tauri 2 (`@tauri-apps/api` 2.10) + Rust (tokio). Existing
  IPC surface in `src-tauri/src/ipc.rs`; discovery in `repo_discovery.rs`;
  parsing in `status_parse.rs`.
- **Tests (backend)**: Rust cargo tests under `src-tauri/tests/`.
- **i18n**: existing `src/i18n/` wrapper with `useTranslation()`.

No new runtime dependency is introduced by this feature.

## 2. Decisions

### D1 — Palette module: single-file TS SSOT (R6, R26, AC6)

Create **one** new TypeScript module at
`flow-monitor/src/agentPalette.ts`. It exports:

1. `type CCColorName = "red" | "blue" | "green" | "yellow" | "purple" | "orange" | "pink" | "cyan"` — the closed enum of the 8 Claude Code colour names (R2).
2. `type Role = "pm" | "architect" | "tpm" | "developer" | "designer" | "qa-analyst" | "qa-tester" | "reviewer-security" | "reviewer-performance" | "reviewer-style"` — the 10 roles (R1, R6).
3. `const ROLE_TO_COLOR: Record<Role, CCColorName>` — the authoritative role→colour map (values taken verbatim from `02-design/notes.md` §"Scaff agent files that will receive `color:` frontmatter additions"; the three reviewers map to `red` per R3).
4. `const COLOR_TOKENS: Record<CCColorName, { bgVar: string; fgVar: string; dotVar: string; sidebarDotVar: string }>` — maps each colour name to the four CSS custom-property **names** (not hex). Consumers read `var(--agent-<name>-bg)` etc.
5. `const AXIS_LABEL: Record<Role, "sec" | "perf" | "style" | null>` — sub-badge text (R7, R8); non-reviewer roles return `null`.
6. `function roleForSession(session: Pick<SessionState, "stage"> & { activeRole?: Role | null }): Role` — resolver documented in D3.

Hex literals (exact RGB values from `02-design/palette.md`) live in the
companion CSS file `flow-monitor/src/styles/agent-palette.css` as
CSS custom properties under a `:root` block (e.g.
`--agent-purple-bg`, `--agent-purple-fg`, `--agent-purple-dot`,
`--agent-purple-sidebar-dot`). The CSS file is the single authorised
hex-bearing artefact (AC6: "at most one file in `flow-monitor/src/`
contains an agent hex literal"). Every other consumer reads via
`var(--agent-<colour>-<slot>)` or via the TS module's exports.

**Rationale**: keeping the hex in CSS (not JS) means React components
never inject inline hex; they apply classes or inline-CSS-variable
references that resolve against `:root`. This matches the existing
`components.css` discipline for `--stage-<key>-bg/fg` (see
`flow-monitor/src/styles/components.css` L630+). The TS module holds
the *name* mapping; the CSS holds the *hex* rendering.

### D2 — Agent colour frontmatter addition, single wave (R1–R5, AC1–AC5)

All 10 scaff-agent markdown files receive one `color:` key each in a
single task (low-risk, pure YAML, no Rust). The key is added inside
the existing `---` frontmatter block; no other key is modified (R4,
AC4). `.appendix.md` files are untouched (R5, AC5).

The authoritative mapping table is `02-design/notes.md` §"Scaff agent
files…"; the task MUST copy values verbatim. No additional logic is
introduced on the CLI side — Claude Code already consumes the
`color:` key natively per the user's Option B selection.

### D3 — Role identification: stage→role heuristic, no new IPC (R13)

The PRD permits either a resolved "current active role" signal from
the backend **or** a documented stage→role heuristic, and explicitly
forbids new IPC for this purpose (R13: "pure function of inputs
already available to the frontend today").

Decision: **use the stage→role heuristic only**. The backend surfaces
`stage` via the existing `SessionRecord.stage` field
(`src-tauri/src/ipc.rs` L22–28) and `status_parse::Stage` enum. The
mapping lives in `agentPalette.ts`:

| Stage key (from `status_parse::Stage` / `StagePill.STAGE_KEYS`) | Default role |
|---|---|
| `request` | `pm` (no artefact-driver; PM owns request intake) |
| `brainstorm` | `pm` |
| `design` | `designer` |
| `prd` | `pm` |
| `tech` | `architect` |
| `plan` | `tpm` |
| `tasks` | `tpm` |
| `implement` | `developer` |
| `gap-check` | `qa-analyst` |
| `verify` | `qa-tester` |
| `archive` | `qa-analyst` (closes the feature) |

Stages `unknown` or any unmapped value fall back to `pm` with a
console warning (fail-loud but non-fatal — matches the
`invokeStore.ts` "shape-guard: silently ignore" posture for rendering
paths).

Reviewer axis roles (`reviewer-security`, `reviewer-performance`,
`reviewer-style`) are NOT produced by the heuristic — no single
stage maps to a reviewer. They exist in the palette module for
completeness (the CLI needs the frontmatter value, and
NotesTimeline entries written by a reviewer role will colour
themselves through D6). The UI pill on SessionCard / CardDetail
only displays non-reviewer roles via the heuristic.

**No wiring task needed** — this is a pure TS helper consumed by
already-existing components. (Per team-memory
`setup-hook-wired-commitment-must-be-explicit-plan-task.md`:
no lifecycle hook is promised, so no orphan risk.)

### D4 — AgentPill component: new file, StagePill-parity geometry (R7, R8, AC7, AC8)

Create `flow-monitor/src/components/AgentPill.tsx`. Shape parity with
`StagePill.tsx`:

- `border-radius: 9999px` (pill)
- font-size / padding inherited from shared `.stage-pill` / a new
  `.agent-pill` class that reuses the same token values
- 5 px leading dot (inner `<span>`), coloured by
  `var(--agent-<colour>-dot)`
- Axis sub-badge `<span>` rendered iff `AXIS_LABEL[role] !== null`;
  text is the AXIS_LABEL value (`sec` / `perf` / `style`); casing and
  geometry follow `.agent-pill__axis` in `02-design/mockup.html`
  L424–434.

Props: `{ role: Role }`. Pure presentational, no hooks beyond
`useTranslation()` for the role label. The CSS class list consumes
data attributes (`data-role={role}`, `data-color={color}`) so the
`agent-palette.css` can scope selectors without parameterising
styles in JS.

### D5 — SessionCard and CardDetailHeader integration (R9, R10, AC9, AC10)

- `SessionCard.tsx` gains a new row (between existing slug/stage row
  and `.session-card__note`) rendering `<AgentPill role={role} />`.
  `role` is derived via `roleForSession({ stage })`. The existing
  elements (slug, StagePill, UI badge, Active badge, relative time,
  note excerpt, two hover actions, stalled ActionStrip) are unchanged.
- `CardDetailHeader.tsx` gains an `<AgentPill>` next to the existing
  `<StagePill>` in the header block (mockup L1280–1284). The header
  component already receives `stage` as a prop; it resolves the role
  through `roleForSession`. No new props are required at
  `CardDetail.tsx` call sites.

### D6 — NotesTimeline role colouring (R11, AC11)

`NotesTimeline.tsx` currently renders each role string inside
`<span className="notes-timeline__role">`. Extend the component to:

1. Normalise the Notes `role` string (as parsed from STATUS.md by
   `status_parse::NotesEntry`) via a `normaliseRoleLabel()` helper
   that lowercases and replaces whitespace with `-`, so `PM`, `Pm`,
   and `pm` all resolve to role key `pm`. Reviewer labels like
   `Reviewer (security)` or `reviewer-security` map to
   `reviewer-security`; a missing match returns `null`.
2. If the normalised role exists in `ROLE_TO_COLOR`, the span sets
   inline `style={{ color: "var(--agent-" + colourName + "-dot)" }}`.
   Otherwise the span renders with default colour (no change).

Font weight, italic, layout remain untouched (R11: "The role name
remains plain text weight-wise; only the colour changes").

**No new state, no IPC** — the Notes array is already available to
the component from `CardDetail.tsx`.

### D7 — RepoSidebar: coloured dot per active entry + "Archived" section (R12, R14–R17, AC12–AC17)

`RepoSidebar.tsx` changes:

1. For each active-feature row under a repo group, prepend a 7 px
   coloured dot (`<span className="repo-sidebar__agent-dot"
   style={{ backgroundColor: "var(--agent-<colour>-sidebar-dot)" }}/>`).
   The role is resolved by the same `roleForSession()` helper from D3
   (the sidebar already receives each session's `stage` via the
   session-list prop). Archived entries do NOT get this dot (R17,
   AC12).

2. Append a new `<section className="repo-sidebar__archived">` after
   the existing Projects list (and before the Filter section), with:
   - a header row showing label "Archived", a count badge, and a
     disclosure chevron (`▶` collapsed, `▼` expanded) per mockup
     L871–939
   - when expanded, one row per archived feature — italic slug,
     `arch` badge, opacity 0.65 (hover 0.9) per mockup L927–938
   - hover actions identical to active rows: "Open in Finder" and
     "Copy path" (R20)

Expand/collapse state is stored via the **existing**
`themeStore`-alike settings mechanism — specifically, it is persisted
the same way `collapsedRepoIds` is persisted today: lifted to
`sessionStore.ts` (add `archiveExpanded: boolean` and
`setArchiveExpanded`) and mirrored to the Tauri settings store on
change (R15, AC14, AC15).

**Default collapsed** on first launch (R15, AC14) — the default value
of `archiveExpanded` is `false` when no setting is persisted yet.

### D8 — Archive discovery: new Tauri read-only command (R16, AC13, AC16)

Add a new Tauri command to `src-tauri/src/ipc.rs`:

```rust
#[tauri::command]
pub fn list_archived_features(
    settings: tauri::State<'_, SettingsState>,
) -> Result<Vec<ArchivedFeatureRecord>, IpcError>
```

Returns, for every currently registered repo, a flat list of
`ArchivedFeatureRecord { repo: PathBuf, slug: String, dir: PathBuf }`
entries. Implementation: `fs::read_dir("<repo>/.specaffold/archive/")`
for each registered repo, skip hidden/non-dir entries, no recursion.
This mirrors `repo_discovery::discover_sessions` structurally (one
read_dir per repo, classifier-then-dispatch) — in fact, we **reuse**
the existing `classify_entry` logic by extracting a
`classify_archive_entry()` that returns
`ArchivedKind::{Feature(slug), Hidden, NotADir}`.

No STATUS.md probe: archived directories may or may not contain one;
a `slug` is any non-hidden subdirectory. This keeps discovery O(N)
across the archive directory with zero file opens beyond `read_dir`.

**Why a new command rather than extending `list_sessions`**:

1. **Schema isolation**: `SessionRecord` carries live-feature fields
   (`stage`, `last_activity_secs`, `has_ui`) that are meaningless for
   archived entries. Extending with nullables muddles the read
   contract; reviewers have historically held this boundary tight.
2. **Invalidation cadence**: the live-session list is polled every
   2–5 s (`poller.rs`). Archived contents don't change during a
   session. A dedicated command can cache its result per-repo with
   invalidation only on `add_repo` / `remove_repo` and on an explicit
   user refresh — avoiding wasted `read_dir` per poll tick.
3. **Call-site legibility**: renderer code paths for archived
   features (sidebar expand, CardDetail read-only) are distinct from
   active-feature paths; a separate command expresses that split at
   the IPC boundary.

**Caching**: renderer-side — `sessionStore.ts` holds an
`archivedFeatures` array and re-invokes `list_archived_features` on
mount, on repo add/remove, and when the user expands the Archived
section after a collapse cycle (cheap; acceptable UX). No Rust-side
cache is needed at this scale (typical archive count is << 100 per
repo; `read_dir` cost is negligible).

**No mutate branch**: the command is read-only; no archived feature
is written or modified (R19, AC19).

### D9 — CardDetail read-only mode for archived features (R18, R19, AC18, AC19)

`CardDetail.tsx` currently derives `repoFullPath` from `get_settings`
and renders a header + tabs + content. Extend:

1. Add a URL query flag `?archived=1` (or reuse routing: the
   archived-row click builds a route like
   `/:repoId/archived/:slug` vs. `/:repoId/:slug` for active). The
   router change is minimal in `App.tsx`. An archived query/route
   triggers `isArchived: true` in the component.
2. When `isArchived` is true:
   - Compute the feature directory as
     `<repoFullPath>/.specaffold/archive/<slug>` instead of
     `.specaffold/features/<slug>` — this single path swap is the
     only logic branch needed; existing `read_artefact` accepts any
     relative file under the feature directory.
   - `CardDetailHeader` renders an `ARCHIVED` badge and `Read only`
     label (mockup L960–972). Control buttons that would trigger
     `invokeStore.dispatch(...)` (Advance, Send, Edit) are
     conditionally omitted — the safe default is to *not* render
     them rather than disable them, to ensure no IPC is invocable
     even through DOM inspection.
   - `AgentPill` is not rendered on the archived header (the role
     resolver returns `null` for archived features; archived entries
     have no active role per R17).

3. `read_artefact` (existing IPC) is reused unchanged. Its
   path-traversal guard (`ipc.rs` L80+) already enforces that the
   requested file sits under a registered repo root; the
   `archive/` subtree is under the repo root so access is permitted
   without any backend change.

4. No `advance_stage`, `invoke_command`, or other write IPC is
   wired to the archived CardDetail (AC19). The existing
   `invokeStore.dispatch` classifier already rejects unknown
   commands, but the **primary** enforcement here is to not render
   the triggering controls — a belt-and-braces posture that matches
   team-memory `aggregator-as-classifier.md` (fail-loud, deny by
   construction).

### D10 — Disabled-tab click block + computed `exists` + CSS tooltip (R21–R25, AC20–AC23)

Three linked changes:

1. **Computed `exists`** — `CardDetail.tsx` replaces the hardcoded
   `TAB_DEFINITIONS[i].exists = true` (L20–30) with a computed value
   per feature. Source of truth is the **frontend** (TypeScript):
   on mount, `CardDetail` invokes a new **read-only** Tauri command
   `list_feature_artefacts(repo, slug, archived)` that returns
   `{ files_present: Record<string, boolean> }` keyed by the 9 tab
   `file` strings (plus `"02-design"` directory presence). This is
   one round-trip per feature-open, cached in local component state.

   **Why a backend command rather than `fs.existsSync` in
   TypeScript**: the Tauri webview has no direct Node `fs`
   module — filesystem probing must go through a Tauri command or
   through `read_artefact` (which reads content unnecessarily).
   A dedicated tiny command is the cheap path.

   Implementation sketch (Rust):
   ```rust
   #[tauri::command]
   pub fn list_feature_artefacts(
       repo: String, slug: String, archived: bool,
       settings: tauri::State<'_, SettingsState>,
   ) -> Result<ArtefactPresence, IpcError>
   ```
   with the same path-traversal guard pattern as
   `read_artefact_inner` (the registered-root enumeration already
   exists in ipc.rs ~L1156). Returns a simple
   `Record<string, boolean>` / `HashMap<String, bool>` for the
   9 fixed artefact names.

2. **TabStrip guard** — `TabStrip.tsx` adds an early return in the
   button's `onClick`:
   ```ts
   onClick={() => { if (!tab.exists) return; onSelect(tab.id); }}
   ```
   plus `aria-disabled={!tab.exists}` and `tabIndex={tab.exists ? 0 : -1}`
   for keyboard parity. The existing `tab-strip__tab--missing` class
   is retained (R21, R25 — the strip keeps disabled tabs in the DOM).
   `onSelect` is not called for disabled tabs (R24, AC22).

3. **CSS `::after` tooltip + opacity 0.38** — add a CSS rule in
   `flow-monitor/src/styles/components.css` for
   `.tab-strip__tab--missing` that:
   - sets `opacity: 0.38` (R21, AC20)
   - sets `cursor: not-allowed`
   - sets `border-bottom-color: transparent`
   - on `:hover`, adds a `::after` pseudo-element positioned above
     the tab with text "Not yet produced" (mockup L571–589)

   The existing `title` attribute in `TabStrip.tsx` remains as an
   a11y fallback (R22: "The `title` attribute MAY remain as an
   accessibility fallback").

**Scope note**: for archived features, `exists` is similarly computed
but reads from the `archive/<slug>/` directory; the same
`list_feature_artefacts` command with `archived=true` covers both.

### D11 — Wiring of the new commands into the Tauri handler

New commands from D8 and D10 must be registered in
`src-tauri/src/lib.rs` under `tauri::Builder::default()
.invoke_handler(tauri::generate_handler![...])`. **Wiring task**:
`lib.rs` `.invoke_handler` tuple must include both
`list_archived_features` and `list_feature_artefacts`. Per
team-memory
`setup-hook-wired-commitment-must-be-explicit-plan-task.md`, the
TPM MUST surface this as an explicit acceptance clause on the task
that authors each command — the function-authoring task and the
handler-registration task are the same task-scope item only if the
acceptance clause calls it out by name.

## 3. Component / module boundaries

New files (9):

| Path | Purpose |
|---|---|
| `flow-monitor/src/agentPalette.ts` | TS SSOT for role↔colour↔CSS-var names (D1, D3) |
| `flow-monitor/src/styles/agent-palette.css` | CSS `:root` custom properties carrying hex values (D1) — the one authorised hex-bearing TS/CSS file for agents (AC6) |
| `flow-monitor/src/components/AgentPill.tsx` | New pill component (D4) |
| `flow-monitor/src/components/__tests__/AgentPill.test.tsx` | Vitest coverage (§7) |
| `flow-monitor/src/__tests__/agentPalette.test.ts` | Palette-map invariants (§7) |
| `flow-monitor/src-tauri/src/archive_discovery.rs` | `list_archived_features` command + classifier (D8) |
| `flow-monitor/src-tauri/src/artefact_presence.rs` | `list_feature_artefacts` command (D10) |
| `flow-monitor/src-tauri/tests/archive_discovery_tests.rs` | Rust unit tests (§7) |
| `flow-monitor/src-tauri/tests/artefact_presence_tests.rs` | Rust unit tests (§7) |

Files changed (existing):

| Path | Change |
|---|---|
| `.claude/agents/scaff/{pm,architect,tpm,developer,designer,qa-analyst,qa-tester,reviewer-security,reviewer-performance,reviewer-style}.md` | Add one `color:` key to frontmatter (D2) |
| `flow-monitor/src/components/TabStrip.tsx` | Guard `onClick` when `exists=false`; add `aria-disabled`; keep `--missing` class (D10) |
| `flow-monitor/src/components/SessionCard.tsx` | Render `<AgentPill>` on a new row (D5) |
| `flow-monitor/src/components/CardDetailHeader.tsx` | Render `<AgentPill>` next to `<StagePill>`; in archived mode show ARCHIVED + Read only badges; omit mutate controls (D5, D9) |
| `flow-monitor/src/components/NotesTimeline.tsx` | Colour the role span via normalised role lookup (D6) |
| `flow-monitor/src/components/RepoSidebar.tsx` | Coloured dot per active row; new "Archived" section (D7) |
| `flow-monitor/src/views/CardDetail.tsx` | Computed `exists` via `list_feature_artefacts`; archived mode path-swap and control omission (D9, D10) |
| `flow-monitor/src/views/MainWindow.tsx` | Wire archived-row click to CardDetail archived route (D9) |
| `flow-monitor/src/App.tsx` (routing) | Add `/:repoId/archived/:slug` route (D9) |
| `flow-monitor/src/stores/sessionStore.ts` | Add `archiveExpanded` state + persisted setter; carry `archivedFeatures` array (D7, D8) |
| `flow-monitor/src/styles/components.css` | Extend `.tab-strip__tab--missing` with opacity 0.38 + `::after` tooltip; add `.agent-pill`, `.agent-pill__axis`, `.repo-sidebar__agent-dot`, `.repo-sidebar__archived*` styles (D4, D7, D10) |
| `flow-monitor/src-tauri/src/ipc.rs` | Register the two new commands; add `ArchivedFeatureRecord` + `ArtefactPresence` types if placed here rather than in their own module (D8, D10) |
| `flow-monitor/src-tauri/src/lib.rs` | Add `list_archived_features`, `list_feature_artefacts` to `generate_handler!` tuple (D11 wiring task) |
| `flow-monitor/src/i18n/` | Add strings: `tab.notYetProduced` (if different from existing `tab.notYetGenerated`), `sidebar.archived`, `card.readOnly`, `card.archivedBadge` |

## 4. Data flow sketch

```
     user opens MainWindow
               │
               ▼
   sessionStore — useSessionStore()
       ├─ sessions: SessionState[]   (from list_sessions IPC, poller)
       ├─ archivedFeatures[]         (from list_archived_features IPC)
       └─ archiveExpanded: boolean   (persisted via settings)
               │
    ┌──────────┴──────────┐
    ▼                     ▼
 RepoSidebar           MainWindow grid
    │                     │
    │ for each active:    │ for each active session:
    │   role =            │   role = roleForSession({ stage })
    │     roleForSession  │   ▼
    │   ▼                 │ SessionCard
    │ <span dot            │   ├─ StagePill  (existing)
    │  style=var(--agent- │   ├─ AgentPill role={role}
    │    <c>-sidebar-dot) │   │   └─ dot uses var(--agent-<c>-dot)
    │ />                   │   └─ AgentPill axis-sub-badge iff reviewer
    │                     │
    │ archived section:   │
    │   italic + arch-    │
    │   badge, no dot     │
               │
         click archived row
               ▼
   CardDetail(?archived=1)
       ├─ list_feature_artefacts(repo, slug, archived=true) →
       │    TAB_DEFINITIONS[i].exists = files_present[file]
       ├─ TabStrip: disabled tabs render --missing; onClick guarded
       ├─ read_artefact(...) unchanged — archive/ subtree allowed
       └─ header: ARCHIVED badge + Read only; no mutate controls

palette module = agentPalette.ts
   ROLE_TO_COLOR    : Role → CCColorName         (authoritative)
   COLOR_TOKENS     : CCColorName → CSS-var-name (no hex)
   AXIS_LABEL       : Role → "sec"|"perf"|"style"|null
   roleForSession() : stage → Role               (heuristic)

hex bodies = agent-palette.css (only hex-bearing artefact per AC6)
   :root {
     --agent-purple-bg / -fg / -dot / -sidebar-dot
     --agent-cyan-bg   / -fg / -dot / -sidebar-dot
     ... (8 colour names × 4 slots)
   }
```

## 5. Open questions / blockers

**No blockers.** All 4 prior §7 questions from 03-prd.md were resolved
2026-04-22 (a=new-row, b=keep-hover-actions, c=block-onSelect,
d=defer-dark-mode). The technical choices above follow directly from
those resolutions and the locked palette.

One minor detail the architect surfaces for the TPM's awareness (not a
blocker, does not require user input):

- **Archived-feature route shape**: whether the archived route is
  `/:repoId/:slug?archived=1` (query-flag) or
  `/:repoId/archived/:slug` (separate route) is a routing preference;
  D9 proposes the separate-route form because it makes the
  read-only branch unambiguous at `useParams()` time. If the TPM or
  developer prefers the query-flag form, the rest of the design is
  unaffected. Either way, the behavioural contract (R18, R19, AC18,
  AC19) is identical.

## 6. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Palette hex and TS role map drift apart (e.g., palette file edited, TS not) | medium | visible colour mismatch CLI↔monitor | Single vitest asserts `Object.keys(ROLE_TO_COLOR) === 10 roles`; a second vitest loads `agent-palette.css` and asserts every `--agent-<name>-*` var is defined for every name in `CCColorName`. Drift fails at build. |
| Archive scan slow with very many archived features (>100) | low | sidebar render delay | `read_dir` is O(N) with no per-entry file open; empirically fast. If ever an issue, add mtime-keyed in-memory cache in Rust; out of scope for v1. |
| `roleForSession` heuristic mis-attributes a role when the real active role differs from the stage default | medium | user sees "wrong" colour momentarily during stage transitions | Accepted — the PRD explicitly permits the heuristic (R13). A future feature can surface a real `active_role` field from STATUS parse if the user finds the drift annoying; today no such signal exists in STATUS.md by contract. |
| Archived CardDetail accidentally wires a mutate control | low | broken read-only invariant | Tests (§7) assert no mutate IPC is callable from archived path; `invokeStore` classifier already rejects unknown commands — belt-and-braces. |
| Tab disable affects keyboard navigation (tab key lands on disabled button) | medium | a11y degradation | `tabIndex={-1}` on disabled tabs (D10) makes Tab key skip them; `aria-disabled=true` reports state to screen readers. |
| New Rust commands not registered in `lib.rs` invoke_handler | medium | runtime IPC error "command not found" | Explicit `**Wiring task**` on D11 (per team-memory lesson); TPM surfaces as an acceptance clause on the task that authors each command. |

## 7. Test strategy

### Shell-level (agent frontmatter)

A single assertion script (pattern per
`.claude/rules/bash/bash-32-portability.md` + `sandbox-home-in-tests.md`
where it touches tests) runs:

- `grep -E '^color:' .claude/agents/scaff/<10 names>.md` returns
  exactly 10 lines, each matching the mapping table (AC1).
- Every value is in the 8-name closed enum (AC2).
- The three reviewer files all map to `red`; the 7 non-reviewers are
  pairwise distinct (AC3).
- `grep -l '^color:' .claude/agents/scaff/*.appendix.md` returns
  nothing (AC5).

These live alongside existing self-referencing assertion scripts (per
team-memory `self-referencing-assertion-script-allow-list.md` — this
script does not grep for forbidden strings so no self-allow-list is
needed).

### Vitest / component tests

- `flow-monitor/src/__tests__/agentPalette.test.ts`:
  - `ROLE_TO_COLOR` has all 10 role keys and no others.
  - All values are in `CCColorName`.
  - Reviewer-{security,performance,style} all map to `red`; the 7
    remaining roles map to 7 distinct names.
  - `roleForSession({ stage })` returns the correct role for every
    StageKey; `"unknown"` falls back to `pm` (verifiable via a
    warning spy).

- `flow-monitor/src/components/__tests__/AgentPill.test.tsx`:
  - Renders a pill with `border-radius` matching `.stage-pill`.
  - Renders the 5 px inner dot.
  - Renders the axis sub-badge iff the role is one of the three
    reviewers; sub-badge text matches AXIS_LABEL.
  - Uses `var(--agent-<colour>-bg)` / `-dot` references (snapshot or
    style-assertion).

- `TabStrip.test.tsx` (extend): clicking a `--missing` tab does NOT
  call `onSelect` (AC22); `aria-disabled` is set; `tabIndex === -1`.

- `NotesTimeline.test.tsx` (extend): role span for a known role
  carries `color: var(--agent-<colour>-dot)`; unknown role falls back
  to default colour.

- `RepoSidebar.test.tsx` (new or extend): coloured dot renders per
  active row; archived section defaults to collapsed; click toggles;
  state persists through remount with the same sessionStore;
  archived rows render italic + `arch` badge + no dot.

- `CardDetail.test.tsx` (extend): archived route renders ARCHIVED
  badge, Read only label, no Advance/Send/Edit buttons in the DOM;
  `list_feature_artefacts` is invoked on mount and its response
  drives `exists`; clicking a disabled tab leaves active tab
  unchanged.

### Rust / cargo tests

- `src-tauri/tests/archive_discovery_tests.rs`:
  - Empty `.specaffold/archive/` → empty result.
  - N slug directories → N records in discovery order.
  - Hidden directories / files are skipped.
  - Unregistered repo yields an error without touching the filesystem.

- `src-tauri/tests/artefact_presence_tests.rs`:
  - For a synthetic feature with only `00-request.md` and `03-prd.md`,
    `files_present` returns the two present entries as `true` and the
    rest as `false` (covers AC23).
  - `archived=true` variant reads from `.specaffold/archive/<slug>/`.
  - Path-traversal attempt via `slug="../foo"` is rejected with the
    same guard pattern as `read_artefact_inner`.

### Regression

AC24 (baseline from commit `06432ce`) is covered by the existing
flow-monitor smoke-test suite running unchanged. Any UI change above
that would alter pre-existing tests must be justified in the wave
review.

## Team memory

- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md` — applied to D11: the two new Tauri commands require an explicit handler-registration acceptance clause in the plan, so the functions don't ship as dead code (per T93 orphan retrospective).
- `common/classify-before-mutate.md` (via `architect/aggregator-as-classifier.md`) — applied to D8's `classify_archive_entry()` closed-enum classifier and to D9's read-only dispatch (render-no-mutate-control is the classify-then-dispatch discipline applied to the UI layer).
- `architect/scope-extension-minimal-diff.md` — applied throughout: every change extends an existing closed taxonomy (tab list, stage enum, CSS-token family, Tauri command tuple) by appending, not by re-cutting.

---

## Report to orchestrator

- **§5 blockers**: no.
- **Decisions**: D1 palette SSOT (TS+CSS pair); D2 10-file frontmatter add in one wave; D3 stage→role heuristic, no new IPC; D4 AgentPill component with StagePill-parity geometry; D5 SessionCard + CardDetailHeader integration; D6 NotesTimeline role colouring via normalised lookup; D7 RepoSidebar dot + collapsible Archived section; D8 new read-only Tauri `list_archived_features` command; D9 archived CardDetail read-only via route branch + path swap; D10 disabled-tab click block + computed `exists` via new `list_feature_artefacts` command + CSS `::after` tooltip; D11 handler-registration wiring task for the two new commands.
- **File written**: `/Users/yanghungtw/Tools/specaffold/.specaffold/features/20260422-monitor-ui-polish/04-tech.md`.

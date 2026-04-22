# Plan — 20260422-monitor-ui-polish

- **Feature**: 20260422-monitor-ui-polish
- **Stage**: plan
- **Author**: TPM
- **Date**: 2026-04-22
- **Tier**: standard

## Section 1 — Wave plan (narrative)

### 1.1 Goal restatement

Deliver four small polish items on top of the flow-monitor app and the 10 scaff
agent markdown files (see 03-prd.md §1):

1. Agent role is visually identifiable by colour on every surface (SessionCard,
   CardDetailHeader, NotesTimeline, RepoSidebar).
2. Archived features under `.specaffold/archive/` are browsable (read-only) from
   the sidebar.
3. Stage tabs whose backing artefact file does not yet exist are visibly
   disabled and non-clickable.
4. The 10 scaff agent files carry a `color:` YAML frontmatter key that is the
   single source of truth for the role palette, mirrored into the monitor's
   `agentPalette.ts` + `agent-palette.css` pair.

No CLI behaviour change, no features-tree schema change, no archive-layout
change (03-prd.md §4, 04-tech.md §preamble).

### 1.2 Wave rationale (why 5 waves, in this order)

- **W0 — Foundations** (palette SSOT + agent frontmatter). Pure config / token
  work, no component coupling. Every later wave reads from the palette module
  or relies on `color:` frontmatter being present. Ships as the gate because
  both TS palette map tests (AC6, AC8 invariants) and shell-level frontmatter
  tests (AC1–AC5) are self-contained and run green without any frontend or
  backend work landing.
- **W1 — Rust backend** (two new Tauri commands + handler registration). Per
  `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md`, because
  D8 and D10 both create Rust commands that W2/W3 consume, a wave-boundary
  enforces producer-before-consumer ordering automatically; no per-task
  `Depends on:` chain is needed across the layer. D11's handler-registration is
  its own explicit task inside this wave — architect memory
  `setup-hook-wired-commitment-must-be-explicit-plan-task` plus the observed
  risk in 04-tech.md §6 row 6 ("New Rust commands not registered in `lib.rs`
  invoke_handler") require it.
- **W2 — Core frontend consumption** (AgentPill component + SessionCard +
  CardDetailHeader + NotesTimeline integration + styles). Once the palette
  module from W0 and the Rust commands from W1 are in place, these four
  consumers can land in parallel across disjoint files.
- **W3 — Sidebar + archived route** (RepoSidebar dot + collapsible Archived
  section + archived CardDetail path swap + routing). These changes touch
  shared files (`RepoSidebar.tsx`, `CardDetail.tsx`, `App.tsx`,
  `sessionStore.ts`) that W2 also edits; placing them in a later wave avoids
  same-file collisions with the W2 consumers.
- **W4 — Disabled-tab block + computed `exists`** (TabStrip guard, CSS tooltip,
  CardDetail `exists` wiring). `CardDetail.tsx` is already edited in W3 (path
  swap), so this wave serialises after W3 to keep that file's edits ordered.
  `TabStrip.tsx`, `components.css` (disabled-tab block), and the CardDetail
  `exists` integration are scoped here.

### 1.3 Wave dependency graph

```
  W0 (palette SSOT + agent frontmatter)
    │
    ├──────────────► W1 (Rust: list_archived_features, list_feature_artefacts, lib.rs wiring)
    │                      │
    │                      ▼
    └──────────────► W2 (AgentPill + SessionCard + CardDetailHeader + NotesTimeline + CSS)
                           │
                           ▼
                      W3 (RepoSidebar dot + Archived section + archived route + CardDetail path swap)
                           │
                           ▼
                      W4 (TabStrip guard + CSS tooltip + computed exists wiring)
```

W2 depends on both W0 (palette) and W1 (commands only if a W2 task invokes one;
see per-task notes). W3 depends on W2 because W3 edits files W2 already
touched (`CardDetailHeader.tsx`, `sessionStore.ts`). W4 depends on W3 because
W4 edits `CardDetail.tsx` which W3 also edits.

### 1.4 Parallelism plan

Per `.claude/agents/scaff/tpm.appendix.md` §"Wave schedule format" and the
memory `parallel-safe-requires-different-files` (paraphrased: tasks are
parallel-safe only when they write disjoint file sets), each wave's
parallel-safety analysis appears in §2. Summary:

- **W0**: 2 tasks in parallel (palette SSOT = new files only; frontmatter edits
  = 10 existing files in a dedicated dir). No file overlap.
- **W1**: 3 tasks. Two new Rust modules (different files) run in parallel; the
  wiring task (ipc.rs + lib.rs) serialises because both consumer modules must
  register into the same `ipc.rs`/`lib.rs` — D11 spells this out.
- **W2**: 4 tasks. `AgentPill.tsx` new file (parallel-safe with all),
  `SessionCard.tsx` (parallel-safe with CardDetailHeader + NotesTimeline —
  disjoint files), `CardDetailHeader.tsx`, `NotesTimeline.tsx`. CSS extension
  task serialises because every consumer reads the new classes (`.agent-pill`,
  `.agent-pill__axis`) — put CSS ahead of the consumers within the wave via
  `Depends on:` or split into T-CSS first.
- **W3**: 3 tasks. `RepoSidebar` dot + archived section (one task —
  sessionStore.ts edit in same task), archived-route + CardDetail path swap
  (one task), tests (one task).
- **W4**: 2 tasks. `TabStrip.tsx` + CSS, then CardDetail `exists` wiring;
  sequential within the wave via `Depends on:`.

### 1.5 Risk log

1. **Palette drift TS↔CSS** (from 04-tech.md §6 row 1). Mitigation: T4's vitest
   asserts `CCColorName` enum × 4 slots × matching `--agent-<name>-<slot>` CSS
   custom-property names. Drift fails the build.
2. **Archive scan performance** (04-tech.md §6 row 2). Mitigation:
   `list_archived_features` uses a single `read_dir` per registered repo with
   no per-entry file opens (D8). Rust test covers N=100 sub-dirs.
3. **A11y regression in TabStrip disable** (04-tech.md §6 row 5). Mitigation:
   T19 sets `aria-disabled={!exists}` and `tabIndex={exists ? 0 : -1}`; T20 CSS
   tooltip uses `::after` so screen readers still get the `title` fallback.
4. **Existing test baseline holds (AC24)**. The regression envelope is the
   flow-monitor smoke suite at commit `06432ce`; T22 re-runs the suite
   unchanged. Any new failure is treated as a `must` blocker.
5. **New Rust commands not registered in `lib.rs`** (04-tech.md §6 row 6,
   `setup-hook-wired-commitment-must-be-explicit-plan-task`). Mitigation: T7
   is a dedicated wiring task with the two command names named in the
   acceptance clause.

### 1.6 Sequencing rationale

W0 ships first because both its outputs (palette SSOT module + `color:`
frontmatter) are pure additions with no downstream visual consumer active yet;
they fail loud in isolation if mis-specified, and every later wave reads from
them. W1 follows because W2 (frontend consumers of `list_feature_artefacts`) and
W3 (consumer of `list_archived_features`) both invoke Rust commands that must
exist and be wired before the frontend calls them. W2→W3→W4 is serial on
shared file edits (`CardDetail.tsx`, `CardDetailHeader.tsx`, `sessionStore.ts`,
`App.tsx`) — same-file serialisation is cheaper than breaking the feature into
tiny parallel diffs that re-converge on one file.

### 1.7 Out-of-scope deferrals

None newly introduced at plan time. PRD §4 already defers: editing archived
features, re-opening archives, archive-tree schema changes, dark-mode palette,
accessibility audit beyond 4.5:1 contrast, cross-repo archive aggregation.
`.appendix.md` files remain untouched (R5, AC5).

### 1.8 Escalations

None. No blockers in PRD §7 or tech §5. All 4 prior PRD open questions were
resolved 2026-04-22 with defaults accepted by the user.

---

## Section 2 — Wave schedule

### Wave 0 — Foundations (palette SSOT + agent frontmatter)

- **T1**: Palette SSOT module (`agentPalette.ts` + companion CSS + tests) — new
  files only, no existing-file coupling.
- **T2**: Add `color:` frontmatter to the 10 scaff agent `.md` files — touches
  only `.claude/agents/scaff/*.md` (not the appendix files).
- **T3**: Shell-level frontmatter assertion script (`test/t76_agent_color_frontmatter.sh`)
  verifying AC1–AC5.

**Parallel-safety analysis**:
- T1 writes only new files under `flow-monitor/src/` → no overlap with T2.
- T2 writes 10 distinct `.md` files under `.claude/agents/scaff/` → no overlap
  with T1.
- T3 depends on T2 (reads its written-out frontmatter) but writes a different
  file; it can run parallel with T1 once T2 is merged. Scheduling T3 in this
  wave is safe only if it runs after T2; otherwise promote to post-W0. Simpler:
  keep T3 with `Depends on: T2` inside W0.

Effective within-W0 parallelism: T1 ∥ T2, then T3 runs after T2 in the same
wave.

### Wave 1 — Rust backend + handler registration

- **T4**: `src-tauri/src/archive_discovery.rs` — new module with
  `list_archived_features` command + `classify_archive_entry` classifier (D8).
- **T5**: `src-tauri/src/artefact_presence.rs` — new module with
  `list_feature_artefacts` command (D10 part 1).
- **T6**: Rust tests — `tests/archive_discovery_tests.rs` +
  `tests/artefact_presence_tests.rs` — both authored in one task (one file per
  suite; pre-declared per `tpm/pre-declare-test-filenames-in-06-tasks.md`).
- **T7**: Wire both commands into `src-tauri/src/lib.rs` `.invoke_handler`
  tuple + declare modules in `ipc.rs` / `mod.rs` as required (D11).

**Parallel-safety analysis**:
- T4 and T5 author different new files, no shared edit → parallel-safe.
- T6 authors two new test files (different paths) → parallel-safe with T4 + T5
  only if tests compile without the modules landed. Because the tests `use`
  the modules by name, T6 declares `Depends on: T4, T5` so the test files land
  after the modules exist. Keeping T6 in W1 still works — it just waits for T4
  and T5 to merge before starting.
- T7 edits `lib.rs` (and may touch `ipc.rs` to export from the new modules) —
  file-shared with neither T4/T5/T6's deliverables, but it registers the
  commands; `Depends on: T4, T5`. T7 is the wave-close wiring task.

Effective W1 parallelism: T4 ∥ T5; then T6 ∥ T7 after both merge.

### Wave 2 — Frontend consumers (AgentPill + SessionCard + CardDetailHeader + NotesTimeline + CSS)

- **T8**: Extend `flow-monitor/src/styles/components.css` with `.agent-pill`,
  `.agent-pill__axis`, `.repo-sidebar__agent-dot`, and (for W3 continuity)
  the class hooks needed by AgentPill. Also import the new
  `styles/agent-palette.css` once (from W0 T1) into the style entry-point if
  not already done by T1.
- **T9**: New component `flow-monitor/src/components/AgentPill.tsx` +
  co-located test `AgentPill.test.tsx` (D4, AC7, AC8).
- **T10**: Integrate `<AgentPill>` into `SessionCard.tsx` (D5, R9, AC9) — new
  row between slug/stage row and note excerpt. Extend
  `SessionCard.test.tsx` for role rendering parity.
- **T11**: Integrate `<AgentPill>` into `CardDetailHeader.tsx` next to the
  existing `<StagePill>` (D5, R10, AC10). Extend `CardDetailHeader.test.tsx`.
- **T12**: Colour the role span in `NotesTimeline.tsx` via `normaliseRoleLabel`
  helper (D6, R11, AC11). Extend `NotesTimeline.test.tsx`.

**Parallel-safety analysis**:
- T8 edits `components.css` — shared-file risk with no other W2 task (only T8
  touches `components.css` in this wave). T9 imports `.agent-pill` from T8's
  additions → T9 declares `Depends on: T8`.
- T9 writes new files (`AgentPill.tsx`, `AgentPill.test.tsx`) → parallel-safe
  with T10, T11, T12 once T8 is merged.
- T10, T11, T12 each edit a distinct existing file → parallel-safe with one
  another once T9 is merged (they all import `AgentPill`).

Effective W2 parallelism: T8 first; then T9 after T8; then T10 ∥ T11 ∥ T12
after T9.

### Wave 3 — Sidebar dot + Archived section + archived route + CardDetail path swap

- **T13**: `sessionStore.ts` — add `archivedFeatures: ArchivedFeatureRecord[]`
  + `archiveExpanded: boolean` + persisted setter; invoke
  `list_archived_features` on mount and on repo add/remove (D7 + D8
  renderer cache). Extend any existing store test.
- **T14**: `RepoSidebar.tsx` — add 7px coloured dot per active feature row
  using `roleForSession()`; add collapsible Archived section (header, chevron,
  count, italic rows, `arch` badge, reduced opacity, 2 hover actions)
  (D7, R12, R14–R17, AC12–AC17). Extend `RepoSidebar.test.tsx`.
- **T15**: Routing + archived CardDetail path swap — add
  `/:repoId/archived/:slug` route in `App.tsx`; wire `MainWindow.tsx`
  archived-row click; add `isArchived` branch in `CardDetail.tsx` (path swap
  `.specaffold/archive/<slug>` + header `ARCHIVED`+`Read only` + omit mutate
  controls + skip `AgentPill` rendering) (D9, R18–R20, AC18, AC19). Extend
  `CardDetail.test.tsx` with archived-route coverage.

**Parallel-safety analysis**:
- T13 edits `sessionStore.ts` exclusively.
- T14 edits `RepoSidebar.tsx` + its test; reads the store shape from T13 →
  `Depends on: T13`.
- T15 edits `App.tsx` + `MainWindow.tsx` + `CardDetail.tsx` + its test; also
  calls `roleForSession` (already in palette module from W0). T15 edits
  `CardDetail.tsx` but W2 did not touch `CardDetail.tsx` (W2 touched
  `CardDetailHeader.tsx` instead), so no file-level conflict with W2.
  `Depends on: T13` only if T15 reads `archivedFeatures` from the store
  (yes — MainWindow wires the archived-row click via store lookup); keep the
  dep.

Effective W3 parallelism: T13 first; then T14 ∥ T15 after T13.

### Wave 4 — Disabled-tab block + computed exists + CSS tooltip

- **T16**: `TabStrip.tsx` — add `onClick` guard, `aria-disabled`,
  `tabIndex={exists ? 0 : -1}`; keep `--missing` class (D10 part 2, R24, AC22).
  Extend `TabStrip.test.tsx` for the click-guard and a11y attributes.
- **T17**: `components.css` — tighten `.tab-strip__tab--missing` to
  `opacity: 0.38`, add `::after` tooltip with text "Not yet produced",
  `cursor: not-allowed`, `border-bottom-color: transparent` (D10 part 3, R21,
  R22, AC20, AC21).
- **T18**: `CardDetail.tsx` — replace hardcoded `exists: true` with computed
  values from `list_feature_artefacts(repo, slug, archived)`; pass into
  `TabStrip` (D10 part 1, R23, AC23). Extend `CardDetail.test.tsx` for the
  exists-wiring coverage.
- **T19**: End-to-end regression pass (AC24) — re-run the existing
  flow-monitor smoke suite (vitest + cargo test) unchanged; confirm zero
  failures. Pure verification task, no file edits.

**Parallel-safety analysis**:
- T16 edits `TabStrip.tsx` exclusively.
- T17 edits `components.css` exclusively (different file from T16).
- T18 edits `CardDetail.tsx` exclusively; declares `Depends on: T16` because
  T18's CardDetail test needs the TabStrip guard wired to assert AC22 via the
  CardDetail integration path.
- T19 is a read-only verification step over the whole repo; runs after T16,
  T17, T18 all merge.

Effective W4 parallelism: T16 ∥ T17; then T18 after T16; T19 after T16+T17+T18.

---

## Section 3 — Task checklist

## T1 — Author palette SSOT module (TS + companion CSS + unit test)
- **Milestone**: M1 (W0)
- **Requirements**: R2, R6, R7 (AXIS labels), R8, R13, R26, AC6, AC8
- **Decisions**: D1, D3
- **Scope**:
  - Create `flow-monitor/src/agentPalette.ts` exporting:
    - `type CCColorName = "red" | "blue" | "green" | "yellow" | "purple" | "orange" | "pink" | "cyan"` (04-tech D1.1, verbatim from R2).
    - `type Role = "pm" | "architect" | "tpm" | "developer" | "designer" | "qa-analyst" | "qa-tester" | "reviewer-security" | "reviewer-performance" | "reviewer-style"` (04-tech D1.2, verbatim from R1).
    - `const ROLE_TO_COLOR: Record<Role, CCColorName>` with values copied verbatim from `02-design/notes.md` §"Scaff agent files that will receive `color:` frontmatter additions" (pm=purple, architect=cyan, tpm=yellow, developer=green, designer=pink, qa-analyst=orange, qa-tester=blue, reviewer-security=red, reviewer-performance=red, reviewer-style=red).
    - `const COLOR_TOKENS: Record<CCColorName, { bgVar: string; fgVar: string; dotVar: string; sidebarDotVar: string }>` mapping each name to the 4 CSS-var names (no hex).
    - `const AXIS_LABEL: Record<Role, "sec" | "perf" | "style" | null>` with only the three reviewer roles non-null (R7, R8, AC8).
    - `function roleForSession(input: { stage: StageKey; activeRole?: Role | null }): Role` per 04-tech D3 heuristic table (request/brainstorm/prd→pm, design→designer, tech→architect, plan/tasks→tpm, implement→developer, verify→qa-tester, gap-check→qa-analyst, archive→qa-analyst; unknown→pm + `console.warn`).
  - Create `flow-monitor/src/styles/agent-palette.css` as `:root { --agent-<name>-bg/-fg/-dot/-sidebar-dot: <hex>; }` for the 8 names × 4 slots. Hex values are copied verbatim from `02-design/palette.md` "Role-to-color mapping" and "Sidebar dot variants" tables.
  - Import `agent-palette.css` from the top-level style entry-point (`src/main.tsx` or `src/App.css` — whichever already imports `components.css`) so the variables are available globally.
  - Create `flow-monitor/src/__tests__/agentPalette.test.ts` asserting: all 10 `Role` keys present; every value ∈ `CCColorName`; the 3 reviewers all map to `red`; the 7 non-reviewers map to 7 distinct non-`red` colours; `AXIS_LABEL[reviewer-*]` returns `sec`/`perf`/`style`; `roleForSession` returns expected mapping for each stage; unknown stage falls back to `pm` with `console.warn` fired.
- **Deliverables**:
  - `flow-monitor/src/agentPalette.ts` (new)
  - `flow-monitor/src/styles/agent-palette.css` (new)
  - `flow-monitor/src/__tests__/agentPalette.test.ts` (new)
  - Import line added to `flow-monitor/src/main.tsx` or `src/App.css` (whichever loads `components.css`)
- **Verify**: `cd flow-monitor && npm run test -- src/__tests__/agentPalette.test.ts`
- **Depends on**: —
- **Parallel-safe-with**: T2
- [x]

## T2 — Add `color:` frontmatter to the 10 scaff agent files
- **Milestone**: M1 (W0)
- **Requirements**: R1, R2, R3, R4, R5, AC1, AC2, AC3, AC4, AC5
- **Decisions**: D2
- **Scope**:
  - Edit each of the 10 files under `.claude/agents/scaff/` (NOT `.appendix.md`) to add exactly one new line `color: <name>` inside the existing `---` frontmatter block, preserving all other keys (`name`, `model`, `description`, `tools`) and all body content verbatim (R4, AC4).
  - Values per the authoritative table in `02-design/notes.md` §"Scaff agent files that will receive `color:` frontmatter additions":
    - `.claude/agents/scaff/pm.md` → `color: purple`
    - `.claude/agents/scaff/architect.md` → `color: cyan`
    - `.claude/agents/scaff/tpm.md` → `color: yellow`
    - `.claude/agents/scaff/developer.md` → `color: green`
    - `.claude/agents/scaff/designer.md` → `color: pink`
    - `.claude/agents/scaff/qa-analyst.md` → `color: orange`
    - `.claude/agents/scaff/qa-tester.md` → `color: blue`
    - `.claude/agents/scaff/reviewer-security.md` → `color: red`
    - `.claude/agents/scaff/reviewer-performance.md` → `color: red`
    - `.claude/agents/scaff/reviewer-style.md` → `color: red`
  - Do NOT edit any `*.appendix.md` file (R5, AC5).
- **Deliverables**:
  - 10 edited files: `.claude/agents/scaff/{pm,architect,tpm,developer,designer,qa-analyst,qa-tester,reviewer-security,reviewer-performance,reviewer-style}.md`
- **Verify**: `bash test/t76_agent_color_frontmatter.sh` (sibling test task T3) — verifies AC1–AC5 including appendix-file untouched check.
- **Depends on**: —
- **Parallel-safe-with**: T1
- [x]

## T3 — Shell-level frontmatter assertion script
- **Milestone**: M1 (W0)
- **Requirements**: R1, R2, R3, R5, AC1, AC2, AC3, AC5
- **Decisions**: D2
- **Scope**:
  - Create `test/t76_agent_color_frontmatter.sh` per `.claude/rules/bash/bash-32-portability.md` (bash 3.2 / BSD userland; no `readlink -f`, no GNU-only flags) and `.claude/rules/bash/sandbox-home-in-tests.md` pattern (sandbox HOME preamble even though this script is read-only — the rule is a template discipline).
  - Assertions:
    - `grep -E '^color:' .claude/agents/scaff/{10 files}.md | wc -l` == 10 (AC1).
    - Every value is in `{red, blue, green, yellow, purple, orange, pink, cyan}` (AC2).
    - The 3 `reviewer-*.md` files all have `color: red`; the 7 non-reviewer files have 7 distinct non-red values (AC3).
    - `grep -l '^color:' .claude/agents/scaff/*.appendix.md` returns no matches (AC5).
  - Script must exit 0 on pass, non-zero with a clear message on any failure.
- **Deliverables**:
  - `test/t76_agent_color_frontmatter.sh` (new, executable)
- **Verify**: `bash test/t76_agent_color_frontmatter.sh` — exits 0 after T2 merges.
- **Depends on**: T2
- **Parallel-safe-with**: T1
- [x]

## T4 — Rust module: `list_archived_features` + classifier
- **Milestone**: M2 (W1)
- **Requirements**: R14, R16, R19, AC13, AC16, AC19
- **Decisions**: D8
- **Scope**:
  - Create `flow-monitor/src-tauri/src/archive_discovery.rs` with:
    - `enum ArchivedKind { Feature(String), Hidden, NotADir }` (04-tech D8 closed-enum classifier, per `.claude/rules/common/classify-before-mutate.md`).
    - `fn classify_archive_entry(entry: &DirEntry) -> ArchivedKind` — pure classifier, no side effects.
    - `pub struct ArchivedFeatureRecord { pub repo: PathBuf, pub slug: String, pub dir: PathBuf }` with Serde derives matching existing `SessionRecord` style in `ipc.rs`.
    - `#[tauri::command] pub fn list_archived_features(settings: tauri::State<'_, SettingsState>) -> Result<Vec<ArchivedFeatureRecord>, IpcError>` — iterates registered repos from settings, reads `<repo>/.specaffold/archive/`, dispatches `classify_archive_entry` per entry, collects `Feature(slug)` results; no recursion, no file opens beyond `read_dir`.
  - Declare the module via `mod archive_discovery;` in `src-tauri/src/lib.rs` in the `mod` declaration region (not the `invoke_handler!` region — T7 handles that). Declaration edit only; no command wiring here.
- **Deliverables**:
  - `flow-monitor/src-tauri/src/archive_discovery.rs` (new)
  - `mod archive_discovery;` declaration line added to `src-tauri/src/lib.rs`
- **Verify**: sibling test file at T6 (`src-tauri/tests/archive_discovery_tests.rs`) — `cd flow-monitor/src-tauri && cargo test archive_discovery` passes after T6 lands.
- **Depends on**: —
- **Parallel-safe-with**: T5
- [x]

## T5 — Rust module: `list_feature_artefacts` with path-traversal guard
- **Milestone**: M2 (W1)
- **Requirements**: R21, R23, AC20, AC23
- **Decisions**: D10
- **Scope**:
  - Create `flow-monitor/src-tauri/src/artefact_presence.rs` with:
    - `pub struct ArtefactPresence { pub files_present: HashMap<String, bool> }` with Serde derives.
    - `#[tauri::command] pub fn list_feature_artefacts(repo: String, slug: String, archived: bool, settings: tauri::State<'_, SettingsState>) -> Result<ArtefactPresence, IpcError>` that:
      - Validates `repo` against the registered-root list using the same guard pattern as `read_artefact_inner` in `ipc.rs` (~L1156) — do not accept an unregistered repo root.
      - Validates `slug` is a simple identifier (no `/`, no `..`) — reject `slug="../foo"` with the same path-traversal guard pattern (see 04-tech §D10, PRD Group D).
      - Resolves the feature directory to `<repo>/.specaffold/<archive|features>/<slug>` depending on `archived`.
      - For the 9 known tab file keys (`00-request.md`, `01-brainstorm.md`, `02-design` (directory), `03-prd.md`, `04-tech.md`, `05-plan.md`, `06-tasks.md`, `07-gaps.md`, `08-verify.md`) — matching 03-prd.md R23's enumeration — probes existence via `std::fs::metadata` and fills `files_present` with `true`/`false`. For `02-design` the `true` branch additionally requires at least one indexed file inside the directory (R23 verbatim: "`02-design` tab's `exists` is `true` iff the `02-design/` directory exists with at least one indexed file").
      - Returns `Ok(ArtefactPresence { files_present })` or an `IpcError` for the guard failures.
  - Declare the module via `mod artefact_presence;` in `src-tauri/src/lib.rs` (declaration region, not `invoke_handler!` tuple — T7 wires that).
- **Deliverables**:
  - `flow-monitor/src-tauri/src/artefact_presence.rs` (new)
  - `mod artefact_presence;` declaration line added to `src-tauri/src/lib.rs`
- **Verify**: sibling test file at T6 (`src-tauri/tests/artefact_presence_tests.rs`) — `cd flow-monitor/src-tauri && cargo test artefact_presence` passes after T6 lands.
- **Depends on**: —
- **Parallel-safe-with**: T4
- [x]

## T6 — Rust tests for the two new commands
- **Milestone**: M2 (W1)
- **Requirements**: R16, R19, R23, AC13, AC16, AC19, AC23
- **Decisions**: D8, D10
- **Scope**:
  - Create `flow-monitor/src-tauri/tests/archive_discovery_tests.rs` with cases (per 04-tech §7 "Rust / cargo tests" list):
    - Empty `.specaffold/archive/` → empty result.
    - N slug directories → N records.
    - Hidden directories and files are skipped.
    - Unregistered repo yields an error without touching the filesystem.
  - Create `flow-monitor/src-tauri/tests/artefact_presence_tests.rs` with cases:
    - Synthetic feature with only `00-request.md` + `03-prd.md` → `files_present` returns those two as `true`, other 7 as `false` (covers AC23).
    - `archived=true` variant reads from `<repo>/.specaffold/archive/<slug>/`.
    - Path-traversal attempt with `slug="../foo"` is rejected (same guard as `read_artefact_inner`).
  - Test fixtures can reuse the pattern in existing `src-tauri/tests/fixtures/`; use `tempfile::TempDir` for isolation.
  - Test filenames pre-declared here per `tpm/pre-declare-test-filenames-in-06-tasks.md`.
- **Deliverables**:
  - `flow-monitor/src-tauri/tests/archive_discovery_tests.rs` (new)
  - `flow-monitor/src-tauri/tests/artefact_presence_tests.rs` (new)
- **Verify**: `cd flow-monitor/src-tauri && cargo test archive_discovery artefact_presence` passes.
- **Depends on**: T4, T5
- **Parallel-safe-with**: T7
- [x]

## T7 — Wire new commands into the Tauri invoke_handler
- **Milestone**: M2 (W1)
- **Requirements**: R14, R19, R23, AC13, AC19, AC23
- **Decisions**: D11
- **Scope**:
  - Edit `flow-monitor/src-tauri/src/lib.rs` `.invoke_handler(tauri::generate_handler![...])` tuple to add BOTH of the following command handles in alphabetical order relative to existing entries (or per the file's current convention):
    - `archive_discovery::list_archived_features`
    - `artefact_presence::list_feature_artefacts`
  - If the crate style requires re-exporting commands through `ipc.rs` (the existing pattern for `ipc::list_sessions`, `ipc::read_artefact`, etc.), add `pub use archive_discovery::list_archived_features;` and `pub use artefact_presence::list_feature_artefacts;` in `ipc.rs` and reference via `ipc::list_archived_features` / `ipc::list_feature_artefacts` instead. Follow whichever pattern is already used in `lib.rs` L59–L80 (currently `ipc::<command>`).
  - Architect memory `setup-hook-wired-commitment-must-be-explicit-plan-task.md` applies — this task's acceptance explicitly names BOTH commands so they cannot ship as dead code.
  - Run `cargo check` to confirm no unresolved symbol.
  - **Acceptance clause**: after this task, `grep -c 'list_archived_features' src-tauri/src/lib.rs` ≥ 1 and `grep -c 'list_feature_artefacts' src-tauri/src/lib.rs` ≥ 1, with each symbol referenced inside the `.invoke_handler(tauri::generate_handler![...])` macro body.
- **Deliverables**:
  - Edited `flow-monitor/src-tauri/src/lib.rs` (invoke_handler tuple extended)
  - Edited `flow-monitor/src-tauri/src/ipc.rs` IF the re-export pattern is used
- **Verify**: `cd flow-monitor/src-tauri && cargo check && cargo test` — both new commands resolve at build time; all tests pass.
- **Depends on**: T4, T5
- **Parallel-safe-with**: T6
- [x]

## T8 — CSS: add `.agent-pill`, `.agent-pill__axis`, sidebar-dot, archive-row styles
- **Milestone**: M3 (W2)
- **Requirements**: R7, R8, R12, R17, R21, R22, AC7, AC8, AC12, AC17
- **Decisions**: D4, D7
- **Scope**:
  - Edit `flow-monitor/src/styles/components.css` to add:
    - `.agent-pill` — same border-radius (9999px), font-size, padding as `.stage-pill` (token values from existing `.stage-pill` block). Reads `var(--agent-<colour>-bg)` / `var(--agent-<colour>-fg)` via a `[data-color="<name>"]` attribute selector pattern (D4: "data attributes … so the `agent-palette.css` can scope selectors without parameterising styles in JS"). Mirror the mockup `02-design/mockup.html` L406–423.
    - `.agent-pill__dot` — 5px round inner dot, uses `var(--agent-<colour>-dot)`.
    - `.agent-pill__axis` — sub-badge geometry per mockup L424–434 (uppercase text-transform, small inset padding).
    - `.repo-sidebar__agent-dot` — 7px round dot uses `var(--agent-<colour>-sidebar-dot)` per mockup L1092–1113 composite view.
    - `.repo-sidebar__archived` section styles + `.repo-sidebar__archived-row` (italic slug, `arch` badge, opacity 0.65, hover 0.9) per mockup L871–939, L927–938.
  - NO hex literals in this edit (R26, AC6) — all colour values come from `var(--agent-*)` custom properties.
- **Deliverables**:
  - Edited `flow-monitor/src/styles/components.css`
- **Verify**: `cd flow-monitor && npm run build` succeeds (CSS is valid); AgentPill snapshot/DevTools parity will be verified by T9's test.
- **Depends on**: T1
- **Parallel-safe-with**: — (T8 gates T9, T10, T11, T12 within W2)
- [x]

## T9 — New `AgentPill` component + component test
- **Milestone**: M3 (W2)
- **Requirements**: R7, R8, AC7, AC8
- **Decisions**: D4
- **Scope**:
  - Create `flow-monitor/src/components/AgentPill.tsx`:
    - Props: `{ role: Role }` (imported from `agentPalette.ts`).
    - Reads `color = ROLE_TO_COLOR[role]` and renders `<span className="agent-pill" data-role={role} data-color={color}>` containing:
      - inner `<span className="agent-pill__dot" />` (5px dot).
      - role label text from `useTranslation()` i18n key (e.g. `t("role." + role)`).
      - if `AXIS_LABEL[role] !== null`, append `<span className="agent-pill__axis">{AXIS_LABEL[role]}</span>` (casing handled by CSS `text-transform: uppercase`, D4).
    - No hooks beyond `useTranslation()`; pure presentational.
  - Create `flow-monitor/src/components/__tests__/AgentPill.test.tsx` (per `tpm/pre-declare-test-filenames-in-06-tasks.md`) asserting:
    - Renders pill with `.agent-pill` class and `data-color` matching palette for `role="developer"` → `"green"`, `role="pm"` → `"purple"`, etc.
    - Dot element present.
    - Axis sub-badge present iff role is reviewer (`sec` / `perf` / `style` — check text content for each reviewer variant, absence for non-reviewers).
  - Add i18n strings `role.pm`, `role.architect`, …, `role.reviewer-style` in `flow-monitor/src/i18n/` (ship English defaults; existing i18n convention per 04-tech §3 file-changes row).
- **Deliverables**:
  - `flow-monitor/src/components/AgentPill.tsx` (new)
  - `flow-monitor/src/components/__tests__/AgentPill.test.tsx` (new)
  - i18n additions under `flow-monitor/src/i18n/`
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/AgentPill.test.tsx` passes.
- **Depends on**: T8
- **Parallel-safe-with**: — (gates T10, T11, T12 within W2)
- [x]

## T10 — Integrate AgentPill into SessionCard (new row)
- **Milestone**: M3 (W2)
- **Requirements**: R9, R27, AC9, AC24
- **Decisions**: D5
- **Scope**:
  - Edit `flow-monitor/src/components/SessionCard.tsx` to render `<AgentPill role={roleForSession({ stage })} />` on a NEW row inserted between the existing slug/stage-pill row and the `.session-card__note` element, matching mockup `02-design/mockup.html` L1160–1162.
  - PRESERVE every other element currently in the card: slug text, existing `<StagePill>`, UI badge, Active badge, relative time, note excerpt, 2 hover actions, stalled ActionStrip (R9 verbatim + R27).
  - Import `AgentPill` from `./AgentPill` and `roleForSession` from `../agentPalette`.
  - Extend `flow-monitor/src/components/__tests__/SessionCard.test.tsx` with a case asserting the card renders an `AgentPill` for a known stage (e.g. stage `"implement"` → role `"developer"`), and that the pre-existing elements (stage pill, note excerpt, UI badge) remain present.
- **Deliverables**:
  - Edited `flow-monitor/src/components/SessionCard.tsx`
  - Edited `flow-monitor/src/components/__tests__/SessionCard.test.tsx`
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/SessionCard.test.tsx` passes.
- **Depends on**: T9
- **Parallel-safe-with**: T11, T12
- [x]

## T11 — Integrate AgentPill into CardDetailHeader
- **Milestone**: M3 (W2)
- **Requirements**: R10, AC10
- **Decisions**: D5
- **Scope**:
  - Edit `flow-monitor/src/components/CardDetailHeader.tsx` to render `<AgentPill role={roleForSession({ stage })} />` next to the existing `<StagePill>` in the header block, matching mockup `02-design/mockup.html` L1280–1284.
  - The header component already receives `stage` as a prop (04-tech D5); no new prop needed. Do NOT render AgentPill when `isArchived` prop is true — T15 will handle that branch when it lands; for now, this task's diff is unconditional (W2 scope). T15 will guard on `isArchived` in its own edit.
  - Extend `flow-monitor/src/components/__tests__/CardDetailHeader.test.tsx` with a case asserting the AgentPill renders next to the StagePill for a known stage; assert the DOM order (StagePill first, AgentPill second) or the mockup-matching order — use the mockup as source of truth.
- **Deliverables**:
  - Edited `flow-monitor/src/components/CardDetailHeader.tsx`
  - Edited `flow-monitor/src/components/__tests__/CardDetailHeader.test.tsx`
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/CardDetailHeader.test.tsx` passes.
- **Depends on**: T9
- **Parallel-safe-with**: T10, T12
- [x]

## T12 — Colour NotesTimeline role span
- **Milestone**: M3 (W2)
- **Requirements**: R11, AC11
- **Decisions**: D6
- **Scope**:
  - Edit `flow-monitor/src/components/NotesTimeline.tsx` to:
    - Add a local helper `normaliseRoleLabel(raw: string): Role | null` that lowercases `raw`, replaces whitespace with `-`, and matches one of the 10 role keys. Reviewer variants like `"Reviewer (security)"`, `"reviewer-security"`, `"REVIEWER-SECURITY"` must all normalise to `reviewer-security`; unknown strings return `null`.
    - For each Notes entry, compute `const role = normaliseRoleLabel(entry.role)` and, if `role !== null` and `role in ROLE_TO_COLOR`, set inline `style={{ color: "var(--agent-" + ROLE_TO_COLOR[role] + "-dot)" }}` on the existing `<span className="notes-timeline__role">` element. If `role === null`, render the span with no inline style (default colour falls through).
    - Do NOT change font-weight, italic, or layout (R11 verbatim: "only the colour changes").
  - Extend `flow-monitor/src/components/__tests__/NotesTimeline.test.tsx`:
    - Known role entry renders with `style.color` containing `var(--agent-<colour>-dot)`.
    - Unknown role entry renders without inline colour style.
    - Entries with case-varied role strings (`pm`, `PM`, `Pm`) all colour identically.
- **Deliverables**:
  - Edited `flow-monitor/src/components/NotesTimeline.tsx`
  - Edited `flow-monitor/src/components/__tests__/NotesTimeline.test.tsx`
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/NotesTimeline.test.tsx` passes.
- **Depends on**: T9
- **Parallel-safe-with**: T10, T11
- [x]

## T13 — sessionStore: archivedFeatures array + archiveExpanded setting
- **Milestone**: M4 (W3)
- **Requirements**: R15, R16, AC14, AC15, AC16
- **Decisions**: D7, D8
- **Scope**:
  - Edit `flow-monitor/src/stores/sessionStore.ts` to add:
    - State: `archivedFeatures: ArchivedFeatureRecord[]` (type mirrored from the Rust struct — define TS interface `{ repo: string; slug: string; dir: string }` locally).
    - State: `archiveExpanded: boolean` with default `false` (R15: "Archived section is collapsed by default on first render").
    - Setter `setArchiveExpanded(next: boolean)` that mirrors `collapsedRepoIds`'s existing persistence pattern (Tauri settings store write + in-memory update). Follow 04-tech D7 verbatim: "lifted to `sessionStore.ts` (add `archiveExpanded: boolean` and `setArchiveExpanded`) and mirrored to the Tauri settings store on change".
    - On mount + on `add_repo` / `remove_repo` events (wire through the same channel as existing discovery), invoke `list_archived_features` and populate `archivedFeatures`. Renderer-side cache per 04-tech D8.
    - Also invoke `list_archived_features` when `archiveExpanded` flips from `false` → `true` after having been false (cache refresh on expand cycle, per 04-tech D8).
  - Add i18n strings if needed (`sidebar.archived`, `sidebar.archivedCount`).
  - Extend existing store test file (if present — check `flow-monitor/src/stores/__tests__/` or co-located) with shape assertions; if no store tests exist, add minimal coverage in a new file `flow-monitor/src/stores/__tests__/sessionStore.archive.test.ts` (pre-declared per `pre-declare-test-filenames-in-06-tasks.md`).
- **Deliverables**:
  - Edited `flow-monitor/src/stores/sessionStore.ts`
  - Edited or new `flow-monitor/src/stores/__tests__/sessionStore.archive.test.ts`
  - Edited `flow-monitor/src/i18n/` string additions
- **Verify**: `cd flow-monitor && npm run test -- src/stores/__tests__/sessionStore.archive.test.ts` passes.
- **Depends on**: T7
- **Parallel-safe-with**: —
- [ ]

## T14 — RepoSidebar: coloured dot + collapsible Archived section
- **Milestone**: M4 (W3)
- **Requirements**: R12, R14, R15, R16, R17, R20, AC12, AC13, AC14, AC15, AC16, AC17
- **Decisions**: D7
- **Scope**:
  - Edit `flow-monitor/src/components/RepoSidebar.tsx`:
    - For each active-feature row, prepend `<span className="repo-sidebar__agent-dot" data-color={ROLE_TO_COLOR[roleForSession({stage})]} />` — 7px dot (styling from T8). Archived rows do NOT get the dot (R17, AC12).
    - Append a new `<section className="repo-sidebar__archived">` below the Projects list and above the Filter section with:
      - header row: label (`t("sidebar.archived")`), count `archivedFeatures.length`, disclosure chevron `▶` when `archiveExpanded=false` else `▼` (mockup L871–939).
      - when expanded, one `<div className="repo-sidebar__archived-row">` per entry — italic slug, `arch` badge, opacity 0.65 (hover 0.9) per mockup L927–938.
      - 2 hover actions identical to active rows: "Open in Finder" and "Copy path" (R20, PRD resolved 2026-04-22).
    - Click on header toggles `archiveExpanded` via `setArchiveExpanded` (from T13).
    - Click on an archived row navigates to `/:repoId/archived/:slug` (route added by T15; use the router's navigation helper — couple to T15 via the shared route shape but implement the click handler independently).
  - Extend `flow-monitor/src/components/__tests__/RepoSidebar.test.tsx`:
    - Active row renders dot with `data-color` matching `ROLE_TO_COLOR[roleForSession({stage})]`.
    - Archived section is collapsed by default (chevron `▶`, no rows visible).
    - Click on header expands (chevron `▼`, N rows visible for N archived features).
    - Archived rows render italic slug + `arch` badge + no dot.
    - 2 hover actions present on archived rows.
    - State persists: simulate a remount with the same `sessionStore`; `archiveExpanded` reflects the last set value.
- **Deliverables**:
  - Edited `flow-monitor/src/components/RepoSidebar.tsx`
  - Edited `flow-monitor/src/components/__tests__/RepoSidebar.test.tsx`
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/RepoSidebar.test.tsx` passes.
- **Depends on**: T13
- **Parallel-safe-with**: T15
- [x]

## T15 — Archived route + CardDetail path swap + header read-only badges
- **Milestone**: M4 (W3)
- **Requirements**: R18, R19, R20, AC18, AC19
- **Decisions**: D9
- **Scope**:
  - Edit `flow-monitor/src/App.tsx` routing to add `/:repoId/archived/:slug` alongside the existing `/:repoId/:slug` route. Per 04-tech §5 open minor detail, the separate-route form is chosen (vs. query-flag); this is a routing preference only, not a PRD D-id decision re-open.
  - Edit `flow-monitor/src/views/MainWindow.tsx` to wire archived-row click (from T14 RepoSidebar) to the new route.
  - Edit `flow-monitor/src/views/CardDetail.tsx`:
    - Read `isArchived` from `useParams()` (true iff path is `/archived/*`).
    - When `isArchived === true`, compute feature directory as `<repoFullPath>/.specaffold/archive/<slug>` instead of `.specaffold/features/<slug>` — ONE logic branch, one path string (04-tech D9).
    - Pass `isArchived` down to `CardDetailHeader` (new optional prop, default false).
    - Conditionally omit Advance, Send, Edit controls when `isArchived === true` — omit (not disable), per D9: "the safe default is to not render them rather than disable them".
  - Edit `flow-monitor/src/components/CardDetailHeader.tsx`:
    - When `isArchived === true`, render `<span className="card-detail__archived-badge">ARCHIVED</span>` + `<span className="card-detail__read-only">Read only</span>` per mockup L960–972.
    - Skip `<AgentPill>` rendering when `isArchived === true` (04-tech D9: "AgentPill is not rendered on the archived header").
  - Add CSS styles for `.card-detail__archived-badge` and `.card-detail__read-only` in `components.css` (or in `agent-palette.css` if scoped there — prefer `components.css`).
  - Extend `flow-monitor/src/components/__tests__/CardDetail.test.tsx` with archived-route cases:
    - Navigating to `/:repoId/archived/:slug` renders ARCHIVED badge + Read only label.
    - No Advance / Send / Edit buttons in the DOM.
    - `AgentPill` not rendered on archived header.
    - `read_artefact` is called with a path under `.specaffold/archive/<slug>/` (mock the IPC).
    - No mutate IPC (`advance_stage`, any write command) fires during any interaction — assert via IPC-mock spy (AC19).
- **Deliverables**:
  - Edited `flow-monitor/src/App.tsx`
  - Edited `flow-monitor/src/views/MainWindow.tsx`
  - Edited `flow-monitor/src/views/CardDetail.tsx`
  - Edited `flow-monitor/src/components/CardDetailHeader.tsx`
  - Edited `flow-monitor/src/styles/components.css` (archived + read-only styles)
  - Edited `flow-monitor/src/components/__tests__/CardDetail.test.tsx`
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/CardDetail.test.tsx` passes.
- **Depends on**: T13
- **Parallel-safe-with**: T14
- [x]

## T16 — TabStrip: guard onClick + a11y attributes
- **Milestone**: M5 (W4)
- **Requirements**: R24, R25, AC22
- **Decisions**: D10
- **Scope**:
  - Edit `flow-monitor/src/components/TabStrip.tsx` (per 04-tech §3 file-changes row + D10 part 2):
    - Current code (line 80) unconditionally calls `onSelect(tab.id)` on click — replace with an early return:
      ```ts
      onClick={() => { if (!tab.exists) return; onSelect(tab.id); }}
      ```
      (quoted verbatim from 04-tech D10 part 2 to eliminate paraphrase drift per `tpm/briefing-contradicts-schema.md`).
    - Add `aria-disabled={!tab.exists}` and `tabIndex={tab.exists ? 0 : -1}` on the button element for keyboard parity (04-tech §6 risk row 5).
    - KEEP the existing `tab-strip__tab--missing` class application (R21, R25 — strip retains disabled tabs in the DOM).
    - `title` attribute remains as a11y fallback (R22).
  - Extend `flow-monitor/src/components/__tests__/TabStrip.test.tsx` (existing file):
    - Click on a `--missing` tab does NOT call `onSelect` (spy assertion) (AC22).
    - `aria-disabled` is `true` when `exists=false`, `false` when `exists=true`.
    - `tabIndex` is `-1` when `exists=false`, `0` when `exists=true`.
    - Enabled tab click still fires `onSelect` normally (regression guard).
- **Deliverables**:
  - Edited `flow-monitor/src/components/TabStrip.tsx`
  - Edited `flow-monitor/src/components/__tests__/TabStrip.test.tsx`
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/TabStrip.test.tsx` passes.
- **Depends on**: —
- **Parallel-safe-with**: T17
- [ ]

## T17 — CSS: tighten disabled-tab opacity + `::after` tooltip
- **Milestone**: M5 (W4)
- **Requirements**: R21, R22, AC20, AC21
- **Decisions**: D10
- **Scope**:
  - Edit `flow-monitor/src/styles/components.css` `.tab-strip__tab--missing` rule (existing rule currently at `opacity: 0.5`) to:
    - `opacity: 0.38` (R21, AC20 verbatim — 04-tech D10 part 3).
    - `cursor: not-allowed`.
    - `border-bottom-color: transparent`.
  - Add a `.tab-strip__tab--missing:hover::after` rule that renders a tooltip with text "Not yet produced" positioned above the tab per mockup L571–589 (no native OS tooltip delay — CSS tooltip appears immediately on hover per AC21).
  - Tooltip text must be EXACTLY "Not yet produced" (R22 verbatim). If i18n is required for this string, add `tab.notYetProduced` under `flow-monitor/src/i18n/` and use a CSS `content: attr(data-tooltip)` pattern with the TabStrip passing the i18n string as `data-tooltip` attr — coordinate with T16 if this approach is chosen. Otherwise, hardcode the English string in CSS for v1 (match 04-tech §3 file-changes row: "Add strings: `tab.notYetProduced`").
- **Deliverables**:
  - Edited `flow-monitor/src/styles/components.css`
  - Optionally edited `flow-monitor/src/i18n/` for `tab.notYetProduced` string
- **Verify**: manual DevTools check (opacity 0.38 computed; hover reveals tooltip with correct text) — regression covered by T19 smoke run; CSS build validated by `cd flow-monitor && npm run build`.
- **Depends on**: —
- **Parallel-safe-with**: T16
- [ ]

## T18 — CardDetail: compute `exists` from `list_feature_artefacts`
- **Milestone**: M5 (W4)
- **Requirements**: R23, AC23
- **Decisions**: D10
- **Scope**:
  - Edit `flow-monitor/src/views/CardDetail.tsx`:
    - Replace the hardcoded `exists: true` values on all 9 `TAB_DEFINITIONS` entries (currently L20–30 per 04-tech D10 part 1) with computed values sourced from `list_feature_artefacts(repo, slug, archived)`.
    - Invoke `list_feature_artefacts` on mount with `archived = isArchived` (from T15). Cache the response in local `useState`; expose `exists` to `TabStrip` via the existing `TAB_DEFINITIONS` prop shape (so TabStrip does not need to change its API).
    - If the command fails, fall back to `exists: false` for all tabs AND emit a `console.warn` (fail-loud, non-fatal — matches the `invokeStore.ts` shape-guard posture per 04-tech D3).
  - Extend `flow-monitor/src/components/__tests__/CardDetail.test.tsx` (reuse the file from T15) with cases:
    - Synthetic feature with only `00-request.md` and `03-prd.md` on disk (mock the IPC response): `Request` and `PRD` tabs render enabled; the other 7 render as `--missing` (AC23).
    - Adding `04-tech.md` to the mock response and re-rendering: `Tech` tab switches to enabled.
    - Clicking a `--missing` tab does NOT change the active tab (integration check of T16's guard via CardDetail path).
- **Deliverables**:
  - Edited `flow-monitor/src/views/CardDetail.tsx`
  - Edited `flow-monitor/src/components/__tests__/CardDetail.test.tsx` (re-using T15's file)
- **Verify**: `cd flow-monitor && npm run test -- src/components/__tests__/CardDetail.test.tsx` passes (AC22 + AC23 both exercised).
- **Depends on**: T16
- **Parallel-safe-with**: —
- [ ]

## T19 — Regression sweep (AC24 baseline)
- **Milestone**: M5 (W4)
- **Requirements**: R27, AC24
- **Decisions**: — (validation task)
- **Scope**:
  - Run the full existing flow-monitor smoke suite unchanged:
    - `cd flow-monitor && npm run test`
    - `cd flow-monitor/src-tauri && cargo test`
  - Confirm zero failures and no baseline behaviours have regressed (MainWindow card grid, sort toolbar, polling footer, compact panel toggle, `Open in Finder` / `Copy path` hover actions on active rows, repo picker, theme toggle — AC24 verbatim).
  - No file edits in this task — pure verification. If any pre-existing test fails, file a BLOCK against the wave and surface in STATUS notes; do not flip checkboxes.
- **Deliverables**: — (no file edits; STATUS note on completion)
- **Verify**: `cd flow-monitor && npm run test && cd src-tauri && cargo test` — both suites exit 0.
- **Depends on**: T16, T17, T18
- **Parallel-safe-with**: —
- [ ]

---

## Team memory

- `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md` — applied as the W1 (Rust) → W2/W3 (frontend consumer) split; no per-task `Depends on:` needed across the layer because the wave boundary carries the ordering.
- `tpm/pre-declare-test-filenames-in-06-tasks.md` — applied: every test-authoring task names its exact test file path (`test/t76_agent_color_frontmatter.sh`, `src-tauri/tests/archive_discovery_tests.rs`, `src-tauri/tests/artefact_presence_tests.rs`, `src/components/__tests__/AgentPill.test.tsx`, `src/stores/__tests__/sessionStore.archive.test.ts`) in its `Deliverables:` / `Scope:` to avoid same-wave collisions.
- `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md` — applied: all 19 task checkboxes land as `- [ ]`; orchestrator is the sole `[x]` writer on per-wave bookkeeping.
- `tpm/briefing-contradicts-schema.md` — applied: T2's colour mapping and T16's TabStrip onClick body are both quoted verbatim from `02-design/notes.md` / 04-tech D10 rather than paraphrased.
- `tpm/parallel-safe-append-sections.md` — not present locally or globally (dir lookup: only the entries listed above exist under `tpm/`); absence noted. No alternate entry was a closer match for the shared-CSS parallel-write risk, which is instead handled by ordering T8 before T9/T10/T11/T12 within W2.

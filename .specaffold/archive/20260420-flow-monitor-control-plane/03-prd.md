# PRD — flow-monitor B2 (control plane)

_2026-04-20 · PM_

## 1. Summary

This feature (B2) ships the **writing half** of the user's original one-sentence
ask: "know when a session stalls, act on it in-app, and invoke specflow commands
without hunting for the originating terminal". B1 (`20260419-flow-monitor`)
shipped the read-only half; B1's archive retrospective pre-committed this B2
slug per `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap`. B2
closes three gaps, in order of user-visible payoff:

1. **Stalled detection and notifications actually fire.** B1 implemented
   `store::diff` and `notify::fire_stalled_notification` but did not wire them
   from `lib.rs::run_session_polling`. Every card shows "Active" regardless of
   staleness; no macOS Notification Center banner has ever fired in real use.
   B2 wires the two existing pure modules into the live polling task, so
   stalled state surfaces on cards and a one-shot banner fires per transition.
2. **A stalled card can be acted on from the UI.** A primary "Advance to
   [stage]" button on stalled cards, plus a "Message / Choice" send panel,
   invoke the next specflow stage command for that session without requiring
   the user to locate the originating terminal.
3. **Specflow commands are reachable from the main window.** A ⌘K command
   palette and per-card overflow menu expose the common safe + write
   commands; destructive commands (`archive`, `update-*`) are explicitly
   carved out to B3.

B2 keeps B1's read-only guarantees intact on machines that exercise no write
action — the polling loop, card grid, detail view, theme, and i18n behave
identically to archived B1.

## 2. Exploration

_Per tier-model R4, brainstorm is merged into the PRD for standard-tier
features. This section stress-tests the four carry-forward questions the
designer raised so the PRD can resolve them without a separate
`01-brainstorm.md`._

### Q1 — Delivery mechanism for "act on a stalled session"

Three candidates, from highest realtime / highest coupling to lowest:

| Candidate | Realtime | Audit trail | OS coupling | Failure mode |
|---|---|---|---|---|
| (a) Pipe into live Claude Code session | High | Low (transient) | High (per-OS IPC) | Session must be running + pipe must be accessible; fails silently if either is false |
| (b) Spawn terminal + slash command | Medium | High (user sees the invocation) | Low (`open -a Terminal` + argv) | Terminal app name hardcoded or user-configured; no in-flight feedback |
| (c) Clipboard paste, user presses Enter | Low | Medium (user observes) | None | Requires user to switch context and manually execute |

**v1 default: (b) spawn terminal.** Rationale: it is the only candidate that
produces a visible, user-auditable invocation without assuming the original
Claude Code session is still running or pipe-accessible. B1 never opened any
IPC surface into Claude Code sessions, and doing so now would widen the blast
radius beyond what B2's security posture can justify in one feature. (b) also
composes cleanly with B2's audit-log requirement (R6): the spawn line is
recorded and the user sees the terminal appear.

**Other two:** (c) clipboard is a **user-selectable fallback** — surfaced as a
Settings toggle "If spawn fails, fall back to clipboard" (R4.d). (a) pipe is
**deferred**, not abandoned — if B3 or later needs in-flight feedback (e.g.
streaming a command's stdout back to the card), (a) is the right vehicle. B2
does not build scaffolding for (a) beyond the delivery-method abstraction in
the UI (Screen 2 tabs remain as a surface placeholder).

### Q2 — Command scope in v1

Two candidates:

- **All commands including DESTROY** (`archive`, `update-prd`, `update-plan`,
  `update-tech`, `update-tasks`). Maximises user power, but every DESTROY
  command mutates user-owned artefacts under `.spec-workflow/features/` or
  `.spec-workflow/archive/`. A wrong invocation from the UI — wrong session
  focused, accidental click — loses work the user cannot recover without
  `git reflog`.
- **WRITE-only + safe** (`request`, `brainstorm`, `design`, `prd`, `tech`,
  `plan`, `tasks`, `implement`, `next`, `gap-check`, `verify`). Every one of
  these either creates a new artefact or advances a stage; none moves files
  out of the active feature directory, and none overwrites an existing
  artefact without the underlying CLI's own prompts. Worst case: a redundant
  command runs against a session that wasn't ready — the underlying CLI
  rejects it, no state change.

**v1 scope: WRITE + safe only. DESTROY deferred to B3.** Rationale: B2 is
the first feature where the flow-monitor app acquires a write surface at all.
Adding DESTROY commands in the same feature means B2's security posture has
to cover both "can invoke a command" and "can invoke a destructive command"
simultaneously — two distinct blast radii in one feature. Per
`pm/split-by-blast-radius-not-item-count`, those belong in different
features. The confirmation-modal scaffold, command taxonomy (WRITE vs
DESTROY pills), and audit trail all land in B2, so B3's work is
purely enabling the DESTROY arm, not building new infrastructure.

### Q3 — Confirmation boundary

Two candidates:

- **Modal for DESTROY only.** Matches the designer's mockup and minimises
  interruption for the common case (advancing a stage is the frequent
  action; most WRITE commands are the primary purpose of the button).
- **Modal for DESTROY + WRITE.** Every button click gates through a
  confirmation dialog. Safer, but introduces a modal on the primary flow
  (clicking "Advance to Design" now requires two clicks).

**v1: modal for DESTROY only.** Since Q2 defers DESTROY to B3, the modal
code path is **implemented and tested structurally** in B2 (per Screen 4
mockup) but is not user-reachable in B2. Rationale: the modal scaffold must
land in the same feature as the taxonomy that drives it, so B3 can
immediately wire DESTROY commands into an already-working modal. WRITE
commands are not gated; they are the primary purpose of the stalled-card
action button. A cancel-safe "pre-flight banner" (R5.c) surfaces in the
toolbar for 3 seconds after a WRITE command is issued so the user can hit
Undo-style feedback — this is the lightweight confirmation for WRITE, not a
modal. _Note on B1 baseline: per `pm/ac-must-verify-existing-baseline`, B1's
toast / banner components do not exist — R5.c authors a new component with
no pre-existing parity claim._

### Q4 — Audit trail storage

Three candidates:

| Storage | Pros | Cons |
|---|---|---|
| STATUS Notes | Human-readable, lives with the feature | Co-mingles control-plane trace with per-role stage notes; pollutes diff noise; violates separation-of-concerns |
| `flow-monitor-audit.log` per repo | Dedicated, greppable, per-machine local, out of the feature's git history | New file to design; needs rotation policy |
| Notification Center history only | No new file | Not programmatically queryable; cleared by user / OS; audit disappears |

**v1: dedicated `flow-monitor-audit.log` per repo, at
`<repo>/.spec-workflow/.flow-monitor/audit.log`.** Rationale: control-plane
invocations are a **machine-local operator concern**, not part of the
feature's shared history. Co-mingling with STATUS Notes would make feature
STATUS diffs noisy with per-click trace and would break the "STATUS Notes =
one line per role action" discipline from
`shared/status-notes-rule-requires-enforcement-not-just-documentation`.
Notification history is ephemeral. A dedicated log file preserves the
invocation sequence, is gitignored by default (added to the repo's top-level
`.gitignore` via a one-time setup line — R6.d), and supports a simple rotate-
at-N-MB policy (R6.c). The Card Detail left rail's "Control-Plane Audit"
section (designer's Screen 2) renders from this file.

### Scope boundaries carried forward

- **B1 Tauri capability reversal** (request §Known risks) — B2 opens the
  narrowest possible capability surface: an allow-list of binaries
  (`bin/specflow-*`) with per-binary argv schema. The specific opening is
  architect's call at `04-tech.md`; the PRD scopes the principle in R8.
- **Multi-window concurrency** (request §Q5) — v1 picks **per-session
  advisory lock**: an in-flight invocation on session `(repo, slug)` disables
  the Advance / Message buttons on every open window for that session. If
  two users (two windows) click simultaneously, the second click is a no-op
  with a toast "action already in flight". No queue, no retry — the user
  clicks again once the in-flight action resolves. This is lighter than a
  persistent lock file and heavier than "let the CLI deduplicate" (which
  provides no UI feedback). Concrete in R7.
- **Dogfood paradox — ninth occurrence of the pattern.** B2 ships the
  control-plane mechanism the flow-monitor app would itself exercise against
  a live session, but B2's own development cannot exercise the control
  plane against a real session — the first runtime exercise lands on
  **whichever feature the user drives after B2 archives**. §9 below splits
  ACs into `structural` vs `runtime` tags per the third-occurrence pattern;
  the runtime-exercise handoff discipline is per
  `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap`'s
  successor feature clause.

## 3. Non-goals

- **DESTROY commands** (`archive`, `update-prd`, `update-plan`, `update-tech`,
  `update-tasks`) — scaffold lands in B2 (modal, taxonomy, audit log
  columns), but user-reachable wiring is B3.
- **In-flight streaming of command stdout into the card** — the terminal
  spawn is fire-and-forget from the app's perspective; the card refreshes on
  the next polling tick when STATUS.md changes. Streaming is deferred.
- **Pipe-based delivery into a live Claude Code session** — deferred per Q1.
- **Cross-session bulk actions** ("Advance all stalled") — out of B2 per
  request §Out of scope.
- **Chat / transcript UI** — out of B2 per request §Out of scope.
- **Notification action buttons** (inline "Advance" on the macOS banner) —
  deferred per design notes; requires notification action entitlement.
- **Editing markdown artefacts in-app** — B1 posture preserved.
- **Windows / Linux window chrome parity** — macOS-first, matching B1.
- **OS appearance auto-follow** — still B3+ per B1 R15.

## 4. Personas and scenarios

Personas inherit unchanged from B1's §4 (solo operator, multi-repo
operator). Three new B2 scenarios:

### Scenario F — Stalled session actioned from the grid

Alice returns from lunch. The compact panel in her corner has two green
rows and one red "Stalled" row for feature `data-pipeline`. She clicks
"▶ Next" on the stalled row. A terminal window appears running
`/specflow:verify data-pipeline`. She watches it complete, switches back to
flow-monitor, and the card has flipped back to Active with stage=validate.
Entry in Card Detail "Control-Plane Audit": `2026-04-22 14:32 · advance ·
compact-panel · terminal-spawn`.

### Scenario G — Command palette launches a safe command

Bob hits ⌘K in the main window. Palette opens with no session focused. He
types "brainstorm". The palette shows `brainstorm` under "Specflow
Commands" with a WRITE pill. He selects it, is prompted for a feature slug
via a quick-input dropdown (populated from existing non-archived sessions),
picks `billing-port`, presses Enter. Terminal spawns with
`/specflow:brainstorm billing-port`. No modal — it is a WRITE command, not
DESTROY.

### Scenario H — Two windows, one action

Carol has two flow-monitor windows open (main + a secondary window). Both
show feature `report-export` as stalled. She clicks Advance on window A.
Button disables on both windows with a spinner; window B shows toast
"Advance in flight". When the polling tick detects STATUS.md has advanced,
both windows' buttons re-enable.

## 5. Requirements

Each R has a one-line statement plus 1–4 acceptance criteria. R numbers are
stable; AC IDs are scoped per R; every AC is tagged `[Verification:
structural | runtime | both]` per `shared/dogfood-paradox-third-occurrence`
(ninth occurrence).

### Stalled detection wiring (B1 residual gap)

**R1 — Stalled transitions fire on-screen and once in Notification
Center.** `run_session_polling` in `flow-monitor/src-tauri/src/lib.rs` must
call `store::diff` each tick using a persisted previous-`stalled_set`,
advance that set from `DiffEvent.next_stalled_set`, and call
`notify::fire_stalled_notification` once per entry in
`DiffEvent.stalled_transitions`. The threshold is read from the existing
`Settings.stalled_threshold_mins` (default 30).

- **AC1.a** — Given a session whose STATUS.md has not advanced past the
  configured threshold and was not previously stalled, the card renders a
  visible stalled indicator (red top bar + "Stalled · N min" badge per
  design Screen 1) within one polling tick.
  `[Verification: runtime]`
- **AC1.b** — For the same transition, exactly one macOS Notification
  Center banner fires with title "Session Stalled" (en) / "工作階段已停滯"
  (zh-TW) and body naming the slug and idle duration.
  `[Verification: runtime]`
- **AC1.c** — A session already in the stalled set on the previous tick
  does NOT fire a second notification on a subsequent tick while still
  stalled. Verified against the `store::diff` unit-test fixture that
  covers `prev_stalled_set` membership.
  `[Verification: structural]`
- **AC1.d** — A session that leaves stalled (STATUS.md advances) and
  later re-crosses the threshold fires the banner again.
  `[Verification: both]`

### Card-level control actions

**R2 — Stalled cards show an action strip in the grid.** A stalled card
renders a two-button row: primary "Advance to [stage]" (where `[stage]` is
computed from the workflow sequence based on current stage), secondary
"Message". Active and stale cards do NOT render the action strip in grid
view per designer's locked decision #1.

- **AC2.a** — Given a session at stage `prd` that has crossed stalled, its
  card's action strip primary button reads exactly "Advance to Tech" (en)
  / "進入技術階段" (zh-TW). The label is computed from stage sequence, not
  hardcoded per card.
  `[Verification: runtime]`
- **AC2.b** — A session at stage `implement` that is NOT stalled renders
  no action buttons in the grid view.
  `[Verification: runtime]`
- **AC2.c** — The "Advance to [stage]" label mapping is stored in a
  single lookup table in the i18n bundle and referenced by key; no
  component hardcodes the display string per stage.
  `[Verification: structural]`

**R3 — Card Detail adds an Advance + Message pair and an inline send
panel.** The Card Detail header gains "Advance" + "Message / Choice"
buttons; clicking "Message / Choice" toggles an inline send-panel
(designer's Screen 2) with the Q1 delivery-method tabs visible but with
terminal-spawn pre-selected as v1 default.

- **AC3.a** — Card Detail header renders Advance + Message buttons iff
  the session's current stage has a valid next stage (i.e. not
  `validate` pending archive); otherwise the buttons are hidden (not
  disabled, per designer's "hidden when inapplicable" convention).
  `[Verification: runtime]`
- **AC3.b** — The inline send-panel's delivery-method tab strip shows
  three tabs with "terminal-spawn" pre-selected and visible as default;
  the "pipe" tab is rendered but disabled with tooltip "Deferred to
  future release"; the "clipboard" tab is enabled and functional.
  `[Verification: runtime]`

### Command invocation surface

**R4 — Terminal-spawn is the v1 delivery mechanism for every command
invocation.** Every control-plane action from the UI (card action strip,
card detail buttons, command palette, context menu, compact-panel quick
action) invokes the underlying command by spawning a terminal window
running the corresponding `/specflow:<command> <slug>` line. Clipboard
fallback is user-selectable in Settings.

- **AC4.a** — Clicking "Advance to [stage]" on a stalled card in the
  grid causes a new terminal window to open running
  `/specflow:<next-stage> <slug>` with the session's slug substituted.
  `[Verification: runtime]`
- **AC4.b** — Settings → "Command delivery" offers two choices:
  "Terminal window (default)" and "Clipboard (I'll paste and run it
  myself)". Selecting Clipboard causes all subsequent invocations to
  copy the command string to the system clipboard and show a toast
  "Command copied — paste in your terminal".
  `[Verification: runtime]`
- **AC4.c** — If the terminal-spawn fails (non-zero exit from `open -a
  Terminal` or equivalent), the app falls back to clipboard-copy and
  surfaces an error toast "Terminal unavailable — copied to clipboard
  instead". This path is user-visible.
  `[Verification: runtime]`
- **AC4.d** — The spawn path never constructs a shell command via
  string concatenation of the slug; argv-form is used throughout.
  `[Verification: structural]`

**R5 — Command palette (⌘K) is the primary multi-command entry point.**
A keyboard-shortcut-triggered palette lists safe + WRITE specflow
commands grouped by classification, with context-sensitive pre-filling
when opened from a focused session.

- **AC5.a** — Pressing ⌘K (Ctrl+K on non-macOS builds, though macOS is
  the v1 target) opens the palette overlay. Pressing Esc closes it
  without side effects.
  `[Verification: runtime]`
- **AC5.b** — The palette lists `request`, `brainstorm`, `design`,
  `prd`, `tech`, `plan`, `tasks`, `implement`, `next`, `gap-check`,
  `verify` — exactly the WRITE + safe scope from §2 Q2. DESTROY
  commands (`archive`, `update-*`) are NOT listed.
  `[Verification: structural]`
- **AC5.c** — After a WRITE command issues, a 3-second pre-flight
  toast appears in the toolbar showing the command string and slug.
  No modal. The toast dismisses automatically or on click.
  `[Verification: runtime]`

### Confirmation + audit + concurrency

**R6 — Every control-plane invocation writes one line to
`<repo>/.spec-workflow/.flow-monitor/audit.log`.** The log file is
per-repo, append-only, created on first write, rotated when size
exceeds 1 MB (renamed to `audit.log.1`, new file started). Each line is
tab-separated: ISO-8601 timestamp, slug, command, entry-point, delivery
method, outcome (`spawned` | `copied` | `failed`).

- **AC6.a** — Every successful WRITE command invocation from the UI
  appends exactly one line to the per-repo audit log with the six
  tab-separated fields populated. Verified by grepping the file after
  a known invocation.
  `[Verification: runtime]`
- **AC6.b** — A failed spawn (AC4.c fallback) writes one line with
  outcome=`failed` AND a second line with outcome=`copied` when the
  clipboard fallback succeeds. Two lines, not one, so the operator can
  see the failure sequence.
  `[Verification: runtime]`
- **AC6.c** — When `audit.log` reaches 1 MB, the next write rotates the
  file: `audit.log` is renamed to `audit.log.1` (overwriting any
  existing `audit.log.1`), and a fresh `audit.log` is created starting
  with the current write.
  `[Verification: structural]`
- **AC6.d** — On first write of `audit.log` in a repo, the app ensures
  `.spec-workflow/.flow-monitor/` is added to the repo's top-level
  `.gitignore` (idempotent — check before append; no duplicate line).
  `[Verification: structural]`

**R7 — Multi-window in-flight actions are disabled across windows per
`(repo, slug)`.** When an invocation is in flight for session
`(repo, slug)`, every open flow-monitor window shows its Advance /
Message buttons for that session disabled with a spinner. The lock
releases when the polling tick observes a STATUS.md change for that
session, OR after a 60-second timeout (whichever comes first).

- **AC7.a** — Given two flow-monitor windows open on the same machine
  viewing session `(repo-a, slug-x)`, clicking Advance on window A
  immediately disables the Advance button on window B and shows a toast
  "Advance in flight" on window B.
  `[Verification: runtime]`
- **AC7.b** — The in-flight lock releases in both windows when the
  polling loop observes STATUS.md has advanced for
  `(repo-a, slug-x)`, OR 60 seconds have elapsed since the lock was
  acquired — whichever is earlier.
  `[Verification: runtime]`
- **AC7.c** — The in-flight lock is in-process (not on disk); closing
  and reopening a window clears the lock. Two independent app launches
  do not coordinate — the second launch has no way to observe the
  first's in-flight state.
  `[Verification: structural]`

### Confirmation-modal scaffold for B3

**R8 — Destructive-command confirmation modal is implemented but not
user-reachable in B2.** The modal component (designer's Screen 4), the
WRITE / DESTROY classification map, and the audit-log `outcome=destroy-
confirmed` code path all ship in B2 and are covered by component
tests. No UI entry point exposes a DESTROY command in B2; the
classification map is the only B2 surface that references
destructive-command strings.

- **AC8.a** — The confirmation-modal component renders correctly when
  passed a DESTROY command name and a slug (component test). The Cancel
  button is the default-focused element; no Enter-key shortcut confirms.
  `[Verification: structural]`
- **AC8.b** — The command-classification map lists `archive`,
  `update-prd`, `update-plan`, `update-tech`, `update-tasks` under
  DESTROY and none of the five appears in any user-reachable entry
  point (palette, context menu, button strip). Verified by
  cross-reference grep.
  `[Verification: structural]`

### Security: Tauri capability lockdown scope

**R9 — Tauri capability reversal from B1 is the narrowest possible
opening.** B1 denied `shell:allow-execute` and path-escape capabilities.
B2 opens only: (a) an allow-list of specflow binary invocations
(`open -a Terminal …`, clipboard writes) and (b) file-write permission
scoped to `<repo>/.spec-workflow/.flow-monitor/audit.log` and its
rotated variants. The path-traversal guard in `ipc.rs::read_artefact`
remains in force for all reads and is extended to cover audit-log
writes (a write cannot target a path outside any registered repo's
`.spec-workflow/.flow-monitor/`). Architect authors the concrete
capability manifest at `04-tech.md`; this R scopes the principle.

- **AC9.a** — The shell-execute capability is restricted to an
  allow-list of exact binary paths (macOS `/usr/bin/open`) with argv
  validated against a per-binary schema. No user input is concatenated
  into a shell command. Verified by reading
  `src-tauri/capabilities/*.json`.
  `[Verification: structural]`
- **AC9.b** — A write to the audit log rejects any path that does not
  start with the absolute path of a registered repo's
  `.spec-workflow/.flow-monitor/`. Verified by a negative unit test
  that attempts to write to `/tmp/escape.log` and expects a typed
  `PathTraversal` error.
  `[Verification: structural]`

### i18n / theme inheritance

**R10 — All new B2 strings have en + zh-TW translations in the i18n
bundle.** Every new user-visible string from designer's §Q8 list has
both locales populated before the feature ships. No component renders a
fallback English string in zh-TW mode.

- **AC10.a** — The new B2 i18n keys (enumerated in designer `notes.md`
  §Q8) each resolve to a non-empty string in both the `en` and
  `zh-TW` locale bundles; no key falls back across locales. Verified
  by a grep-based completeness test.
  `[Verification: structural]`
- **AC10.b** — Setting the app language to zh-TW and walking
  Screens 1, 2, 3, 4, 5, 6, 7 from the mockup shows no English text
  in the new B2 surfaces (excluding the immutable slug, which always
  stays ASCII per designer note #11).
  `[Verification: runtime]`

**R11 — Theme tokens inherit from B1 unchanged; no new token values
introduced.** B2 adds new CSS classes (action-button strip, command
palette, modal, audit panel) but every color / spacing / typography
value references an existing B1 token. No new `--color-*` or
`--space-*` variable is introduced in this feature.

- **AC11.a** — `grep -E '^\s*--(color|space|font|radius)-' src/styles/`
  for any file touched by B2 shows zero newly-declared tokens beyond
  the B1 set. Verified structurally against
  `archive/20260419-flow-monitor/`.
  `[Verification: structural]`

### B1 carry-forward nits (advisory; absorbed per housekeeping-sweep-threshold)

**R12 — The accepted B1 NITS list is cleared in-stream.** Per
`pm/housekeeping-sweep-threshold` the 10-item-or-less, all-advisory
list from B1 archive absorbs here rather than spawning a sweep.

- **AC12.a** — Each of: `ipc.rs` line-length violations, WHAT-comments
  in noted files, unused `navigatedPaths` state, dead `markdown.footer`
  i18n key, and the 6 non-BEM classes flagged in B1 archive are either
  fixed or marked `keep-with-justification` in a single PR-level
  commit. Verified by diffing against the B1 archive retrospective's
  NITS list.
  `[Verification: structural]`

## 6. Edge cases

### Dogfood paradox (ninth occurrence of the pattern)

B2 ships the control-plane mechanism flow-monitor itself would exercise.
During B2's own `/specflow:implement`, the flow-monitor app is not running
as a passive observer of this feature's live session (the implement task
is driving it). Therefore:

- **Structural-only in B2:** all `[Verification: structural]` ACs are
  fully covered by B2's validate stage.
- **Runtime-deferred to next feature:** all `[Verification: runtime]` ACs
  (AC1.a, AC1.b, AC1.d-runtime, AC2.a, AC2.b, AC3.a, AC3.b, AC4.a, AC4.b,
  AC4.c, AC5.a, AC5.c, AC6.a, AC6.b, AC7.a, AC7.b, AC10.b) are verified
  end-to-end on whichever feature the user drives **after** B2 archives.
  TPM must record this handoff in B2 archive notes; the first feature
  after B2 archive is expected to open with a STATUS Notes line "B2
  control plane exercised on this feature's first live session" or
  equivalent.
- **Both:** AC1.d is split — the `store::diff` re-fire unit case is
  structural; the end-to-end re-fire of the notification banner is
  runtime.

### Session mid-archive during an in-flight action

If the user triggers an Advance on a session and during the in-flight
window another agent archives the feature (moves it to
`.spec-workflow/archive/`), the in-flight lock releases on the 60-second
timeout since STATUS.md no longer exists at the expected path. The card
disappears from the grid on the next polling tick. No error surfaced —
this is an expected benign race.

### Repo becomes unregistered during in-flight

If the user removes a repo from Settings while an action is in flight for
a session in that repo, the lock releases on timeout; the audit log line
was already written before removal so the trace is preserved. No
attempt is made to continue observing the removed repo.

### Terminal app unavailable or wrong one configured

AC4.c covers the fallback: non-zero exit from `open -a Terminal` triggers
clipboard fallback + error toast + audit line with `outcome=failed`
(spawn) + `outcome=copied` (clipboard).

## 7. Blocker questions

_None._ Q1–Q4 and scope-boundary questions are resolved above in
§2 Exploration. Tauri capability concrete manifest is architect's
call at `04-tech.md`; this PRD scopes the principle in R9 and accepts
whatever narrow surface architect designs.

## 8. Open questions (non-blocking; architect may refine)

- **Q-arch-1** — Exact argv for terminal-spawn on macOS: is it
  `open -a Terminal <script>` or a temp file + `osascript`? PRD accepts
  either as long as AC4.a and AC4.d (no shell string-cat) hold.
- **Q-arch-2** — Whether the in-flight lock is a `Mutex<HashSet<…>>` in
  an existing state struct or a new dedicated `InvocationLockState`.
  Architect's call; R7 just requires the observable behavior.
- **Q-ux-future** — Should the notification banner re-fire after N
  minutes of continued staleness (designer Q9)? PRD says **no** for v1
  (one-shot per transition, already encoded in `store::diff`'s
  `stalled_transitions` semantic). B3+ can revisit with "re-fire after
  60 min of continued staleness" if operator feedback requests it. Not
  blocking.
- **Q-ux-future** — Q6 "Advance on a non-stalled session" and Q7
  "compact panel safe vs destructive advance" from designer notes are
  both side-effects of §2 Q2 resolution (DESTROY deferred). v1: Advance
  is only shown on stalled cards in the grid (R2), but the command
  palette and context menu allow invoking `next` / `verify` / etc. on
  any session regardless of stalled state (R5). Compact panel ▶ Next
  only appears on stalled rows and only triggers WRITE-scope commands.

## 9. Acceptance summary

| # | AC | Verification |
|---|---|---|
| 1 | AC1.a stalled indicator on card | runtime |
| 2 | AC1.b macOS banner fires once | runtime |
| 3 | AC1.c no second banner while still stalled | structural |
| 4 | AC1.d re-fire after recovery-then-restall | both |
| 5 | AC2.a stage-specific advance label (en/zh-TW) | runtime |
| 6 | AC2.b no action strip on non-stalled grid card | runtime |
| 7 | AC2.c label lookup is table-driven | structural |
| 8 | AC3.a detail buttons gated on next-stage validity | runtime |
| 9 | AC3.b send-panel tab defaults and disabled pipe tab | runtime |
| 10 | AC4.a Advance spawns terminal with correct argv | runtime |
| 11 | AC4.b clipboard fallback setting | runtime |
| 12 | AC4.c terminal-fail → clipboard + error toast | runtime |
| 13 | AC4.d no shell string-cat (argv form) | structural |
| 14 | AC5.a ⌘K palette open/close | runtime |
| 15 | AC5.b palette scope = WRITE + safe only | structural |
| 16 | AC5.c 3s pre-flight toast after WRITE | runtime |
| 17 | AC6.a one audit-log line per invocation | runtime |
| 18 | AC6.b two lines on spawn-fail + clipboard | runtime |
| 19 | AC6.c rotate at 1 MB | structural |
| 20 | AC6.d idempotent gitignore add | structural |
| 21 | AC7.a cross-window in-flight disable | runtime |
| 22 | AC7.b lock release on STATUS.md change or 60s | runtime |
| 23 | AC7.c lock is in-process (per-app) | structural |
| 24 | AC8.a modal scaffold — Cancel default | structural |
| 25 | AC8.b DESTROY commands unreachable in B2 | structural |
| 26 | AC9.a shell capability allow-list + argv schema | structural |
| 27 | AC9.b audit-log path-traversal guard | structural |
| 28 | AC10.a i18n coverage en + zh-TW | structural |
| 29 | AC10.b runtime zh-TW walkthrough | runtime |
| 30 | AC11.a no new theme tokens | structural |
| 31 | AC12.a B1 nits absorbed | structural |

**Totals:** 12 R; 31 ACs (15 runtime, 15 structural, 1 both).

_Runtime handoff:_ all 15 `runtime` ACs are deferred to the next feature
the user drives after B2 archives per
`shared/dogfood-paradox-third-occurrence` and
`pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap`. TPM
must pre-commit the successor feature's STATUS opening line at B2
archive time.

## Team memory

- Applied **pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap** —
  §1 summary explicitly frames this feature as "the writing half of the
  user's original one-sentence ask"; runtime handoff discipline invoked in
  §6 and §9.
- Applied **shared/dogfood-paradox-third-occurrence** (ninth occurrence) —
  every AC tagged `[Verification: structural | runtime | both]`; §6 splits
  coverage; §9 acceptance summary makes the handoff legible.
- Applied **pm/ac-must-verify-existing-baseline** — R11 cites
  `archive/20260419-flow-monitor/` as canonical for theme tokens; AC5.c's
  toast-banner component is called out as new (no pre-existing parity
  claim in B1).
- Applied **pm/housekeeping-sweep-threshold** — 5-item B1 nits list absorbs
  in-stream via R12 rather than spawning its own sweep feature (under the
  ~10-item threshold).
- Applied **pm/split-by-blast-radius-not-item-count** — DESTROY commands
  carved to B3 so B2's blast-radius stays at "can-invoke-WRITE" rather
  than "can-invoke-WRITE + can-invoke-DESTROY".
- Applied **shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds** —
  has-ui=true is respected: every user-visible control flow has at
  least one runtime-tagged AC; structural coverage alone does not close
  any user-facing requirement.
- Consulted but not directly applied: **pm/architect-recommends-accept-over-flip**
  (no architect output yet), **shared/status-notes-rule-requires-enforcement-not-just-documentation**
  (flagged in §2 Q4 as rationale for separate audit log, not co-mingling).

**Proposed memory entry:** at B2 archive, promote a new entry
`pm/terminal-spawn-as-v1-default-for-command-invocation.md` capturing
why spawn-terminal was chosen over pipe or clipboard as the default —
useful for any future feature that adds a new command invocation point.

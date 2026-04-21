# Design Notes — flow-monitor B2 (Control Plane)

## Flows covered

| Screen | What it covers |
|---|---|
| 1 Card Grid + Stalled | Card grid with B2 stalled state: top accent bar (4px red), pulsing badge, action-button strip ("Advance to [stage]" + "Message"); toolbar gains ink-green "Specflow ⌘K" launcher |
| 2 Card Detail + Actions | B1 detail header gains "Advance" + "Message / Choice" buttons; "Message / Choice" toggles an inline send-panel with Q1 delivery-method tabs (pipe / terminal-spawn / clipboard); left rail gains a "Control-Plane Audit" section |
| 3 Command Palette | ⌘K palette with context-sensitive header (active session slug + stage + stalled badge); grouped: Control Actions → Specflow Commands → Destructive Commands; WRITE and DESTROY pills; Q1 delivery-method abstraction |
| 4 Confirmation Modal | Fires for DESTROY-tagged commands (archive, update-*); shows exact command string, session slug, and target path; Cancel is the safe default; no Enter-to-confirm guard |
| 5 Notification Banner | macOS Notification Center banner mock (EN + zh-TW); silent-fire-once semantics annotated; compact panel header badge shown in context |
| 6 Compact Panel B2 | B1 compact panel with B2 "▶ Next" quick-action on stalled rows; B1 reference shown side-by-side for visual diff |
| 7 Card Context Menu | Right-click / "···" menu on a stalled card; full specflow command list with WRITE/DESTROY pills; "Archive session…" at bottom with danger styling |

## Design decisions locked in this pass

1. **Stalled-card action strip** — Two-button strip ("Advance to [stage]" primary + "Message" secondary) appears only on stalled cards in the grid view. Active and stale cards do not get action buttons in the grid; they must navigate to card detail. Rationale: avoids cluttering normal active cards with write affordances.

2. **"Advance to [stage]" is computed from current stage** — The button label always names the specific next stage (e.g. "Advance to Design" not "Advance to next step"). This makes the action unambiguous without needing the user to know the stage order. The label is computed from the workflow stage sequence at render time.

3. **Three Q1 delivery-method affordances mocked in parallel** — Screen 2's inline send-panel shows all three candidate mechanisms as a tab switcher (session-pipe / terminal-spawn / clipboard) with one-line descriptions. This lets the PRD author choose a default without the Designer pre-deciding; the UI shape is mechanism-agnostic.

4. **Toolbar "Specflow ⌘K" button** — Primary entry point to the command palette from the main window toolbar. Ink-green filled to distinguish it from secondary toolbar buttons. Keyboard shortcut ⌘K shown inline. Secondary entry points: "···" card overflow button → context menu; Card Detail header → individual action buttons.

5. **Command palette context-sensitivity** — The palette pre-fills the focused session when opened from a card action or card detail. "Control Actions" section at top ranks the most urgent action first (Advance for stalled sessions). If opened with no session context, Control Actions section is absent and only generic Specflow Commands appear.

6. **WRITE vs DESTROY pill taxonomy** — Commands are classified at two levels:
   - DESTROY: `archive`, `update-prd`, `update-plan`, `update-tech`, `update-tasks` — always trigger the confirmation modal.
   - WRITE: `next`, `design`, `prd`, etc. — flagged with a yellow WRITE pill but do not trigger confirmation by default (PRD may promote some to DESTROY).
   - Safe: `request`, `brainstorm`, `gap-check`, `verify` — no pill, no confirmation.

7. **Confirmation modal — Cancel as default** — The modal has no keyboard Enter-to-confirm shortcut. Cancel is the escape hatch; the "Archive Session" (or equivalent) button requires a deliberate click. Rationale: prevents muscle-memory from triggering destructive actions.

8. **Compact panel quick-action** — Stalled rows in the compact panel get a minimal "▶ Next" button (rightmost cell). This is the only write affordance in the compact panel; stale and active rows remain fully read-only (click = open main). Rationale: compact panel is used in always-on-top mode over the IDE; adding more than one button per row would make it too cluttered.

9. **Audit trail in Card Detail left rail** — A "Control-Plane Audit" section replaces no existing B1 content (it is appended below the Notes timeline). Each entry shows: action name, timestamp, entry point (toolbar / card-detail / compact-panel), and delivery method used. This is a read-only rendered view; the backing store is a PRD decision (Q4).

10. **Notification banner — no action buttons in v1** — The macOS Notification Center banner shows app name, title, and message only. Clicking the banner opens Flow Monitor (standard macOS behaviour). No inline "Advance" action button in the notification itself — this avoids requiring the notification action entitlement, which has its own review implications. Can be added as a post-v1 enhancement.

11. **zh-TW i18n confirmed for new strings** — The notification banner zh-TW variant shows "工作階段已停滯" (Session Stalled) and translated idle-duration message. Slug always stays in its original ASCII form even in zh-TW copy. All new UI strings (button labels, section titles, modal copy, command palette labels) require zh-TW translations in the i18n files — listed in Open Questions below.

## Open questions for PRD input

1. **Q1: "Operate next step" delivery mechanism** — Mocked as three parallel affordances (pipe / terminal-spawn / clipboard). PRD must pick the v1 default and whether the other two are user-selectable or hidden.

2. **Q2: Command invocation scope** — Mockup shows all standard specflow commands including DESTROY-tagged ones. PRD must decide whether destructive commands appear in v1 or are gated to a later slice.

3. **Q3: Confirmation boundary** — Mockup gates confirmation on DESTROY-tagged commands only. PRD must decide whether WRITE-tagged commands (`next`, `design`, etc.) also require confirmation, or whether confirmation is limited to file-moving/archive operations.

4. **Q4: Audit trail storage** — Card Detail shows a rendered audit trail. PRD must decide: STATUS Notes entries, a dedicated `flow-monitor-audit.log` per repo, or Notification Center history only.

5. **Q5: Concurrency** — Two windows, same session, both fire Advance simultaneously. The UI does not model a loading/locked state on the card. PRD + Architect must decide lock/queue/let-CLI-deduplicate, and whether the button should disable during an in-flight invocation.

6. **Q6: "Advance" on a non-stalled session** — The mockup only shows the Advance button on stalled cards. Should the command palette / context menu allow advancing any active session (not just stalled ones), or is the Advance action only ever triggered from a stalled state? PRD to decide.

7. **Q7: Compact panel "▶ Next" on non-destructive vs destructive advance** — If advancing from `implement` → `validate` is safe but `implement` → `archive` is destructive, the compact panel's "▶ Next" button must know which category applies. Does it always show a confirmation before advancing, or only for DESTROY-tagged stage transitions? PRD decides the threshold.

8. **Q8: i18n string list for new surfaces** — New strings introduced in B2 (needs zh-TW translation):
   - "Advance to [stage]", "Message / Choice", "Send Message or Make Choice"
   - "Control-Plane Audit", "Stalled · [duration]", "via toolbar / card-detail / compact-panel"
   - "Session Stalled" (already in B1 notification helper but needs zh-TW body text)
   - Command palette: all group labels ("Control Actions", "Specflow Commands", "Destructive Commands")
   - Modal: "Archive this session?", "Archive Session", "Cancel", detail box labels
   - WRITE / DESTROY pills

9. **Q9 (B1 carry): Notification re-fire policy** — Does the banner re-fire after N additional minutes of continued staleness? B1 noted this as open; B2 must close it since B2 wires the notification.

10. **Q10: Advance button label in zh-TW** — "Advance to Design" in zh-TW: "進入設計階段" (proposed) or follow the same short pill label convention ("設計")? PRD/i18n review needed.

## Uncovered states / deferred to PRD or B3

- Multi-window concurrency lock state on the card (button grayed-out while in-flight) — needs Architect input on Tauri state management before it can be designed.
- Message / Choice "history" — the send-panel shows no prior messages sent to the session. A conversation thread view is explicitly out of B2 scope (per request §Out of scope: "No chat UI").
- "Advance All Stalled" bulk action — explicitly out of B2 scope.
- Windows / Linux window chrome — macOS-only mocked; same as B1.
- Error / failure state for a failed command invocation — what the card or modal shows if the spawned command exits non-zero. Deferred; Architect must decide the error surface.
- Notification action buttons (inline "Advance" in the macOS banner) — deferred, requires notification action entitlement.

# Request

**Raw ask**: "然後需要知道那個 session 是不是停下來了，是的話要能夠在應用程式上操作下一步或做選擇。也希望能在介面上操作 specflow 的功能。" — the user wants flow-monitor to (a) actually tell them when a session has stalled, and (b) let them operate the next step / make a choice / invoke specflow commands directly from the app UI, instead of having to locate the originating terminal.

**Context**:

This is **B2**, the write-side follow-up to **B1 `20260419-flow-monitor`** (archived read-only dashboard). B1 delivered the observation half of the original request:

- Multi-repo session discovery, card grid, Card Detail with markdown preview.
- Compact always-on-top panel scaffold, tray icon, theme toggle, en / zh-TW i18n.
- A polling task that rebuilds session state from `.spec-workflow/features/*/STATUS.md` every few seconds.
- A notification helper (`notify::fire_stalled_notification`) and a stalled-transition computer (`store::diff`) — both **implemented but unwired**.

B1 archive explicitly carved the control plane out (B1 `03-prd.md` §3 "Non-goals → Control plane (B2)") and the B1 brainstorm picked approach A2 specifically so the write surface could ship on its own verify harness. B2 is that follow-up.

What B2 must close (in rough order of user-visible payoff):

1. **Wire stalled detection and notifications (B1 residual gap).** `run_session_polling` in `flow-monitor/src-tauri/src/lib.rs` currently rebuilds the session list every tick with no stale/stalled tagging and no notification call — so every card shows "Active" regardless of underlying staleness, and no macOS Notification ever fires. The backend exists; only the wire is missing. Without this, the "know when a session stalled" user outcome is not delivered end-to-end even after B1.
2. **Control plane — act on a stalled session from the app UI.** From a flagged card (or card-detail), the user must be able to advance the session to its next stage, or send a message / make a choice, without leaving the app and without hunting for the originating terminal window.
3. **Invoke specflow commands from the UI.** The common specflow commands (`request`, `brainstorm`, `design`, `prd`, `tech`, `plan`, `tasks`, `implement`, `next`, `gap-check`, `verify`, `archive`, `update-*`) should be reachable from the app — toolbar, card context-menu, or command-palette. B1 has **zero** command-invocation surface.

**Form factor locks inherited from B1** (not re-litigated in brainstorm):

- Native desktop (Tauri 2 + React 19), macOS-first.
- Dark mode with ink-green primary `#1B4332`; theme system and visual language reused.
- i18n en + zh-TW as first-class.
- Multi-repo session discovery as already delivered by B1's `repo_discovery` + `store::diff`.
- `has-ui: true` — B2 adds buttons / panels into the existing UI; Designer stage runs for the new surface area only.

**Known cross-cutting risks the brainstorm will need to resolve**:

- **Tauri capability lockdown reversal.** B1 T3 explicitly denied `shell:allow-execute` and path-escaping capabilities as part of its read-only security posture. B2 must open enough of that surface to invoke a command safely while preserving path-traversal discipline and the "never write to a path outside a registered repo" invariant.
- **Concurrency across multiple flow-monitor windows.** If two windows are open on the same machine and both fire a command against the same session, the app must not double-invoke or silently race.
- **Dogfood paradox — fifth+ occurrence.** B2's own development will be the **first real-time observation** of a specflow session by flow-monitor (the closing of the dogfood loop B1's retrospective documented). Structural verify during B2 implement will not exercise B2's control plane against a real session; runtime exercise arrives when a user drives a subsequent feature with B2 installed. Expect bugs in B1's polling / card UI to surface here precisely because this is the first time B1 watches a live session.

**B1 residual polish to scope in (small, advisory)**:

- The stalled-detection + notification wiring above (already in Goals).
- The accepted NITS from B1 archive retrospective: `line-length` in `ipc.rs`, WHAT-comments, unused `navigatedPaths`, dead `markdown.footer` i18n key, 6 non-BEM classes. None are blockers; brainstorm decides whether they absorb here or punt further.

**Success looks like**:

- **End-to-end stalled detection.** A session whose underlying feature STATUS.md has not advanced past a configurable threshold shows a distinct stalled state on its card, and a macOS Notification Center banner fires once (silent-fire-once semantics already implemented by `notify::fire_stalled_notification`).
- **At least one command invokable end-to-end from the UI.** Minimally: from a stalled card, the user clicks a button and the next-stage specflow command is issued (mechanism TBD at brainstorm — see Open questions); an audit trail records the invocation; the card refreshes to reflect the result at the next polling tick.
- **No regression in B1's read-only guarantees.** Read-only paths (card grid, Card Detail markdown rendering, theme, i18n, polling) remain functionally identical on machines that do not exercise any B2 control action.
- **Security posture preserved.** Path-traversal guard from B1's `ipc.rs` still rejects out-of-root paths even for write commands; any newly-opened Tauri capability is scoped to the minimum shell surface required.

**Out of scope** (hard carve-outs to preserve for B3+):

- Multi-user / shared dashboard, presence, comments, cloud sync — still single-user local only.
- Cross-repo merges, cross-feature orchestration, cross-session coordination (e.g. "advance all stalled sessions at once").
- Re-implementing `bin/specflow-*` inside the Tauri app. B2 is a thin bridge that invokes existing CLI entry points; it does not re-author their logic.
- Chat UI for the underlying Claude Code conversation (no transcript display, no message history UI).
- Editing PRDs / plans / tasks inside the app. Drill-in detail remains read-only markdown rendering; edits stay in the IDE.
- Mobile / tablet / web form factor.
- OS appearance auto-follow (deferred to its own slice if it ever lands — still B2+ per B1 R15 note).

**UI involved?**: yes. B2 adds new interactive surfaces (action buttons on cards, command palette or toolbar, possibly a confirmation dialog for destructive commands) to the existing B1 app. The Designer stage runs for these new surfaces; B1's card grid, theme, and markdown-render screens are inherited unchanged unless a control action mutates them visibly.

**Open questions to resolve at `/specflow:brainstorm`**:

1. **"Operate next step" semantics** — three candidates, each with very different blast radius:
   - (a) Send a message into the live Claude Code session via a control channel / stdin pipe. Most realtime, most fragile, OS-specific.
   - (b) Invoke the slash command on the user's behalf via a spawned terminal or a Claude Code SDK call. Simpler; less realtime; clearer audit trail.
   - (c) Open the originating terminal window and paste the command into the clipboard; user presses Enter themselves. Lowest-tech; keeps the human in the loop for every write.
2. **Command invocation scope**. Which specflow commands land in v1 — all of them, or only non-destructive (`request`, `brainstorm`, `next`, `update-*`) with destructive ones (`archive`, `update-*`) gated to a later slice?
3. **Confirmation for write actions**. Do destructive commands (`/specflow:update-*`, `/specflow:archive`) require an in-app confirmation modal?
4. **Audit trail**. Every command invoked from the UI needs a trace; where does it live — STATUS Notes, a separate `flow-monitor-audit.log`, or Notification Center only?
5. **Concurrency**. Two flow-monitor windows open on the same machine, both firing the same command on the same session — lock, queue, or let the underlying CLI deduplicate?
6. **Tauri capability surface**. How narrow can `shell:allow-execute` be while still invoking every command in scope? Allow-list of binaries? Per-binary argv schema?

## Team memory

- Applied: **pm/split-by-blast-radius-not-item-count** — B1 / B2 split already in force from the parent request; this intake reinforces the boundary so write-side stays bounded.
- Applied: **shared/dogfood-paradox-third-occurrence** — B2's development closes the observation loop B1 opened; structural verify during B2 implement will not exercise the control plane against a real session, and runtime exercise will land on whichever feature the user drives next after B2 archives. PRD will need an explicit structural-vs-runtime AC split (same pattern B1 used).
- Consulted but not directly applied at intake: **pm/ac-must-verify-existing-baseline** (will matter at PRD stage when new ACs reference B1 artefacts), **pm/housekeeping-sweep-threshold** (the B1 accepted-NITS list is <10 items so it absorbs here rather than spawning a sweep).

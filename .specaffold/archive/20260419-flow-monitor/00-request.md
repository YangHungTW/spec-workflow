# Request

**Raw ask**: Build an application that tracks the progress of multiple concurrent specflow sessions, surfaces when any session has stopped or is waiting on user input, and lets the user act on that session (advance the next step, make a choice, or invoke specflow commands) directly from the app's UI.

**Context**:

- The user frequently runs more than one specflow feature in parallel (multiple Claude Code sessions, each driving a different feature directory under `.spec-workflow/features/`). With current tooling, knowing which session is mid-stage, which is blocked awaiting input, and which has crashed requires manually tabbing between terminals or reading STATUS.md files by hand.
- Pain points implied by the ask:
  1. **Visibility** — no single pane shows progress across N parallel sessions.
  2. **Stop detection** — when a session stalls (idle, awaiting a user choice, or hard-stopped) the user only finds out by checking that terminal.
  3. **Action affordance** — once a stalled session is identified, the user wants to respond from the same UI rather than locating the right terminal window.
  4. **Command invocation** — the user wants to trigger specflow commands (`/specflow:request`, `/specflow:brainstorm`, etc.) from the UI instead of typing them into a terminal.
- Reference project: [`kaochenlong/spectra-app`](https://github.com/kaochenlong/spectra-app) — a desktop app (macOS `.dmg` / Windows `.exe`) for managing spec-driven workflows with a GUI, a "Compact Mode" floating panel for progress monitoring, slash-command integration with Claude Code, and multilingual UI (en / ja / zh-TW / zh-CN). Useful as a framing reference for: native desktop vs. web, multi-session list pattern, floating monitor panel, and slash-command bridge to Claude Code. Not a hard spec to copy — the underlying spec format and command set differ from this repo's specflow.
- Constraints / unknowns to resolve at brainstorm:
  - Form factor: native desktop, local web app, terminal TUI, or VS Code panel? Each has different blast radius and platform support.
  - "Session" definition: is it one specflow feature directory, one Claude Code chat thread, or one tmux pane? These do not map 1:1.
  - Stop-detection mechanism: poll filesystem (STATUS.md / mtimes), tail Claude Code transcripts, hook into SessionStart/Stop, or a sidecar daemon writing a shared state file.
  - "Operate next step from the UI": does the UI send a message into the live Claude Code session (requires a control channel), or does it just open the right terminal and copy a prompt to clipboard?
  - Single-user local tool vs. multi-user shared dashboard.

**Success looks like**:

- The user can see, in one view, the current stage and last activity time of every active specflow feature.
- When a session is stopped or idle past a threshold, that session is visibly flagged in the UI (badge, colour, sound — to be decided).
- For a flagged session the user can take at least one corrective action from the UI without switching to the terminal — minimally "jump to that session" or "send the next instruction"; ideally invoke a specflow stage command (e.g. advance from `request` to `brainstorm`).
- Running the monitor app does not destabilise or slow down active specflow sessions (no lock contention on STATUS.md, no excessive CPU on background polling).

**Out of scope**:

- Replacing Claude Code itself or providing a chat UI for the assistant conversation.
- Editing PRDs / plans / tasks inside the monitor (those stay in the IDE / editor of the user's choice).
- Multi-user / team collaboration features (shared dashboard, presence, comments) — single-user local tool only for v1.
- Authentication, accounts, cloud sync — local-only state for v1.
- A reimplementation of the specflow CLI (`bin/specflow-*`) — the monitor is a thin operator UI on top of the existing scripts.
- Mobile / tablet form factor.

**UI involved?**: yes — this is an interactive operator dashboard with multi-session list views, status badges, and command-trigger affordances. The Designer stage will run.

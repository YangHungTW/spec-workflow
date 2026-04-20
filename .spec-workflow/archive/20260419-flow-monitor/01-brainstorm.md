# Brainstorm — flow-monitor

## Locked decisions

**Form factor: native desktop application.** User instruction delivered with `/specflow:brainstorm` (zh-TW: "關於 1，我要原生桌面") closes Open Question 1 from the request stage. Terminal TUI / VS Code panel / local-web are out — see "Rejected at brainstorm" for one-line reasons.

**Native sub-decision (deferred to Architect, but framed here):** the default lean is **Tauri** (Rust core + system webview, small binary, cross-platform mac/Windows/Linux). Electron is the well-trodden alternative with more JS docs but a heavier runtime; SwiftUI is ruled out because the user works cross-platform (mac primary, but the spec-workflow repo is platform-agnostic and the reference project ships both `.dmg` and `.exe`). The Architect (`/specflow:tech`) owns the final pick — this brainstorm only flags that the PRD does not need to re-litigate framework choice.

## Approaches considered

The remaining open questions are **scope shape** (single feature vs split) and the three orthogonal mechanism choices (session definition, stop-detection, action semantics). Approaches A1–A4 below are scope-shape options; A5 surfaces the lowest-risk first-cut even if we choose to split.

### A1 — Single feature: read-only dashboard + control plane in one PRD

- **What it is**: one feature `flow-monitor` covering both visibility (list of sessions, status badges, idle flagging) and action affordance (jump-to-terminal, send-next-instruction, invoke specflow command from UI).
- **Blast radius**: medium-to-large. The control-plane half (sending instructions into a live Claude Code session, or invoking `bin/specflow-*` from the UI) touches user-owned state — STATUS.md writes, possibly Claude Code transcript pipes, possibly direct CLI shell-out. A bug there can corrupt a real feature mid-stage.
- **Build cost**: L. Single PRD with ~15+ requirements, mixed acceptance criteria (passive read vs active write), and a Designer stage covering both dashboard and command-trigger UI.
- **Main risk**: bundling read and write in one PRD violates `pm/split-by-blast-radius-not-item-count`. Read-only is reversible (close the app); control-plane writes are not. Different failure surfaces → different verify harnesses → merge churn.

### A2 — Split: B1 read-only dashboard, B2 control plane (RECOMMENDED)

- **What it is**: two features.
  - **B1 `flow-monitor-dashboard`** — read-only: discover sessions, parse STATUS.md, surface stage / last-activity / idle-flag, multi-session list view, optional floating compact panel. Action affordances limited to "open feature dir in Finder" and "copy STATUS path to clipboard" — both safe, no writes to user-owned state.
  - **B2 `flow-monitor-control`** — adds: send instruction into live Claude Code session (control channel TBD), invoke specflow stage commands from UI, possibly hook into SessionStart/Stop for live state. Lands after B1 archives and gets one real-session shake-down.
- **Blast radius**: B1 is local — worst case the dashboard shows stale data, user falls back to terminals as today. B2 is global — a bad write into a live session can derail an in-flight feature.
- **Build cost**: B1 = M (~10 requirements, dashboard + polling + idle detection); B2 = M (~8 requirements, control channel + command bridge + safety rails). Total slightly higher than A1 but each PRD is smaller and gap-checkable in isolation.
- **Main risk**: B1 ships and looks "done", B2 never gets prioritised → user is stuck with read-only forever. Mitigation: write B1's PRD with explicit "B2 will add X, Y, Z" pointer so the gap is visible in repo history.

### A3 — Split differently: B1 single-session detail view, B2 multi-session list

- **What it is**: cut by view shape rather than by read-vs-write. B1 = one polished session detail pane; B2 = grid/list aggregation across N sessions.
- **Blast radius**: same surface for both (read-only filesystem polling) → cut doesn't reduce risk per `split-by-blast-radius-not-item-count`. Both features fail in identical ways.
- **Build cost**: M each, but B1 has no standalone value (the user already has one terminal showing one session — a single-session GUI duplicates that without solving the visibility pain).
- **Main risk**: violates the team-memory rule (split must be by blast radius, not by feature-area slicing). Rejected as a split axis but kept here to make the rejection explicit.

### A4 — Single feature with hard scope ceiling: dashboard-only, no control plane ever

- **What it is**: one feature, but explicitly scope out the control plane in §Out-of-scope. UI surfaces information; user always returns to terminal to act.
- **Blast radius**: small. Read-only filesystem polling, no writes anywhere user-owned.
- **Build cost**: S-M (~8–10 requirements). Smallest viable shape.
- **Main risk**: only meets ~70% of the success criteria from `00-request.md` — the "act on flagged session from UI without switching to terminal" outcome is dropped. User would have to re-request that explicitly later.

### A5 — Sidecar daemon writes a shared state file; UI is a thin reader

- **What it is**: orthogonal to A1–A4 — addresses Open Question 3 (stop-detection mechanism). A small background daemon (started on login) tails Claude Code transcripts / hook events / STATUS.md mtimes and writes a normalised `state.json`. The UI reads only that file.
- **Blast radius**: introduces a new always-on process — adds an install/launch surface (launchd plist on mac, Task Scheduler on Windows, systemd on Linux). If the daemon dies, the UI silently shows stale data unless heartbeat is wired in.
- **Build cost**: M-L (the daemon itself is M, but cross-platform process management adds L tax).
- **Main risk**: heavy machinery for a single-user local tool. Polling STATUS.md mtimes from inside the desktop process is sufficient at v1 scale (single-digit concurrent sessions); the daemon is premature.

## Recommendation

**A2 — Split B1 (read-only dashboard) from B2 (control plane).**

Per `pm/split-by-blast-radius-not-item-count` (already cited in the prior round's memory), the read half and the write half have fundamentally different failure surfaces: B1's worst case is "stale UI"; B2's worst case is "corrupted in-flight feature". Bundling them produces a PRD that is hard to gap-check (different harnesses needed) and hard to verify (structural verification of writes is much weaker than for reads). Landing B1 first also produces a high-leverage dogfood payoff: the dashboard becomes the user's primary lens for watching B2 itself develop, which is the fastest way to surface UX gaps in the multi-session monitoring view before the riskier control-plane work begins.

Within B1, defer the stop-detection mechanism choice (Open Question 3) and the session-definition choice (Open Question 2) to PRD — both have testable acceptance criteria once locked, but neither is a brainstorm-level decision.

## Open questions deferred to PRD

PRD (`03-prd.md`) must lock:

1. **Session definition (Q2)** — recommend "one specflow feature directory under `.spec-workflow/features/` with `STATUS.md present and stage != archive`" as the v1 unit. Rationale: matches the artefact the user already reasons about; doesn't depend on Claude Code internals or tmux. Feature dirs in `archive/` are excluded.
2. **Stop-detection mechanism (Q3) for B1** — recommend filesystem polling: walk `.spec-workflow/features/*/STATUS.md`, read the `updated:` field and the latest Notes line's date, plus file mtime as a fallback. Polling interval: 2–5 seconds (PRD picks). Lock contention concern from request §Success: polling is read-only, no contention. Defer transcript-tailing and hook-based detection to B2.
3. **Idle threshold(s)** — what counts as "idle past a threshold"? PRD must enumerate: e.g. mtime > 5 min in an active stage = "stale"; > 30 min = "stalled". User input needed.
4. **Sessions discovery scope** — single repo (the one the app was launched from? a configured root?) vs multi-repo (user has multiple specflow projects across `~/code/`). Single-repo for v1 unless user signals otherwise.
5. **Floating "compact mode" panel** — reference project (`spectra-app`) has it; is it in scope for B1 or deferred to B2 polish? PM lean: include in B1 since it's still read-only.
6. **Multilingual UI** — `spectra-app` ships en/ja/zh-TW/zh-CN. Given `LANG_CHAT=zh-TW` is already a session-level preference, does the dashboard UI itself need i18n? Likely yes (zh-TW + en at minimum); confirm with user at PRD stage.
7. **Single-repo vs multi-repo state**, **dock/tray icon behaviour**, **start-on-login default** — UX defaults the Designer stage will surface; PRD records the policy questions and Designer mocks them.

## Rejected at brainstorm

- **Terminal TUI** — user explicitly chose native desktop. TUI also doesn't solve the "tab between terminals" pain because it lives in yet another terminal.
- **VS Code panel / extension** — user explicitly chose native desktop. Also forces a hard editor dependency the rest of specflow doesn't impose.
- **Local web app (browser-served)** — user explicitly chose native desktop. Browser-tab UX adds friction (lost among other tabs) and complicates the always-visible / floating-panel use case from the reference project.

## Team memory

- **Applied — `pm/split-by-blast-radius-not-item-count`**: drove A2 over A1; read-only and control-plane have different failure surfaces, so they belong in separate features (B1 / B2). Cited in Recommendation.
- **Considered, not yet load-bearing — `shared/dogfood-paradox-third-occurrence`**: the monitor watches specflow features, and one of those features will be the monitor's own development. Surface this in B1's PRD §Edge Cases so the QA-tester doesn't trip on "the dashboard can't show its own session because the dashboard isn't built yet". Not a brainstorm-level decision, but PRD must call it out.
- **Considered, not load-bearing now — `pm/ac-must-verify-existing-baseline`**: relevant when PRD writes ACs that reference STATUS.md schema parity across feature dirs; flag at PRD time, not now.
- **Considered, not load-bearing now — `pm/housekeeping-sweep-threshold`**: not applicable (no review-nit pool for this feature yet).
- **Memory proposal**: if A2 ships and B2 successfully lands later as a separate feature, consider a new pm memory entry "Split read-from-write for any feature touching live user state" promoted from this case + future reinforcing instances. Hold off authoring until a second occurrence.

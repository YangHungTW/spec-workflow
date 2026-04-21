# STATUS

- **slug**: 20260420-flow-monitor-control-plane
- **has-ui**: true
- **tier**: standard
- **stage**: plan
- **created**: 2026-04-20
- **updated**: 2026-04-20

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] prd           (03-prd.md)                  — PM  [includes `## Exploration` — brainstorm merged per R4]
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist per R19]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check per R4]
- [ ] archive       (moved to .spec-workflow/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-20 orchestrator — migrated STATUS stage checklist to new-shape post tier-model archive (retired brainstorm/tasks/gap-check/verify boxes; added validate box). Feature retains tier=standard.
- 2026-04-20 PM — request intaken (B2 follow-up to 20260419-flow-monitor)
- 2026-04-20 Designer — 02-design/ produced: 7-screen HTML mockup covering stalled card actions, card detail control plane, command palette, confirmation modal, notification banner, compact panel B2, and card context menu
- 2026-04-20 PM — 03-prd.md authored (new shape: `## Exploration` merged brainstorm per R4); 12 R, 31 ACs (15 runtime / 15 structural / 1 both); Q1 resolved terminal-spawn, Q2 resolved WRITE+safe only (DESTROY→B3), Q3 resolved modal-for-DESTROY-only (scaffold-only in B2), Q4 resolved per-repo audit.log; 0 blocker questions in §7
- 2026-04-20 Architect — 04-tech.md authored; 11 decisions (D1–D11) resolving all 5 Q-arch carry-forwards plus 6 additional items (terminal-spawn mechanics, clipboard fallback, preflight toast, DESTROY scaffold structural unreachability, audit format, plugin deps, i18n, theme token reuse, dogfood); 0 blocker questions in §5; adds `tauri-plugin-shell` + `tauri-plugin-fs` with exact-path `/usr/bin/open` allow-list + runtime `.flow-monitor/` boundary guard; new Rust modules invoke.rs / audit.rs / lock.rs / command_taxonomy.rs; 13 structural test seams enumerated, 15 runtime ACs handed off to next feature per dogfood paradox
- 2026-04-20 TPM — 05-plan.md authored (new merged shape per R19 — narrative + task checklist in one file, no 06-tasks.md); 7 waves W0–W6 / 30 tasks T91–T122; test range t91–t101 (avoids tier-model's t74–t90); W0 foundation (plugins+manifest), W1 4 parallel Rust modules, W2 lib.rs+ipc.rs+invokeStore (3 parallel; same-file region coordination flagged), W3 scaffold docs+tests+DESTROY grep, W4 6 parallel React components, W5 5a parallel integration+i18n then 5b B1 nits sweep serial, W6 structural tests + runtime handoff + smoke.sh append; 0 blockers; STATUS Notes enforcement elevated to reviewer-style check per shared/status-notes-rule-requires-enforcement-not-just-documentation; runtime handoff pre-committed in T113 for successor feature per dogfood-paradox-ninth-occurrence

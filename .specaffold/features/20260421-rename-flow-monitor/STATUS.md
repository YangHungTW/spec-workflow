# STATUS

- **slug**: 20260421-rename-flow-monitor
- **has-ui**: true
- **tier**: audited
- **stage**: implement
- **created**: 2026-04-21
- **updated**: 2026-04-22

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] design        (02-design/)                 — Designer
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [x] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-21 PM — request intake; raw ask covers flow-monitor rename scope; has-ui true due to i18n + component string changes; open questions flagged for /scaff:prd: (1) invoke-command rename, (2) .spec-workflow backward-compat, (3) Tauri capability transition, (4) audit-log migration.
- 2026-04-21 request — tier audited proposed (audited) accepted by user
- 2026-04-21 Designer — string-delta.md produced; 14 rename rows across en.json, zh-TW.json, 5 TSX files, README.md; 3 open questions raised
- 2026-04-21 design — approved by user; Q1→A (rename i18n key), Q2→yes (update path + coordinate backend order), Q3→yes (only path prefix, keep feature slug); decisions appended to 02-design/string-delta.md §6
- 2026-04-21 PM — 03-prd.md written; 11 requirements (R1–R11), 12 acceptance criteria (AC1–AC12, 2 runtime); 7 decisions (D1–D7) resolve all request-stage and design-stage questions; §7 empty
- 2026-04-21 Architect — 04-tech.md written; 6 tech decisions (D1 invoke shell rename, D2 inline Rust strategy, D3 capability swap, D4 inline React, D5 i18n key rename, D6 lazy audit-log migration); 0 §5 blockers; allow-list delta: −flow-monitor/** +flow-monitor/README.md; architect-gate (AC12) signed off
- 2026-04-21 TPM — 05-plan.md written; wave choice B (2 strictly-ordered waves); 16 tasks T1–T16 (W1: T1–T8 Rust backend/tests/capability; W2: T9–T16 React/i18n/docs/gates); 0 §5 blockers; T7 capability isolated for security reviewer; T11 depends on T2/T3 per D6 merge-order
- 2026-04-21 review dispatched — slug=20260421-rename-flow-monitor wave=1 tasks=T1,T2,T3,T4,T5,T6,T7 axes=security,performance,style
- 2026-04-21 review result — wave 1 verdict=PASS (21/21 reviewers PASS; one advisory on T4 security re: pre-existing slug comment interpolation at invoke.rs:301, not introduced by T4)
- 2026-04-21 implement wave 1 done — T1, T2, T3, T4, T5, T6, T7, T8 (T8 cargo-test gate: 153 tests all green; renamed seam4_no_write_call_references_specaffold_path appears in test listing); cargo clean needed once to clear stale ~/Tools/spec-workflow/ build cache from pre-rename directory
- 2026-04-22 review dispatched — slug=20260421-rename-flow-monitor wave=2a tasks=T9,T10,T11,T13 axes=security,performance,style
- 2026-04-22 review result — wave 2a verdict=PASS (12/12 reviewers PASS)
- 2026-04-22 implement wave 2a done — T9, T10, T11, T13 (sub-wave of W2; no intra-sub-wave deps)
- 2026-04-22 review dispatched — slug=20260421-rename-flow-monitor wave=2b tasks=T12,T14 axes=security,performance,style
- 2026-04-22 review result — wave 2b verdict=PASS (6/6 reviewers PASS)
- 2026-04-22 implement wave 2b done — T12 (deps T9, now satisfied), T14 (deps T13, now satisfied)
- 2026-04-22 Developer — T15 W2 vitest gate: 11 pre-existing test-env failures (Tauri @tauri-apps/api mocking); rename branch strictly improves baseline (5 fewer failing files vs main: 6 vs 11 files failing); 0 new rename-caused regressions; NITS accepted by user (option 1 per user reply); parked as separate follow-up (test infrastructure, not rename concern)
- 2026-04-22 Developer — T16 structural gates: T16.1 t_grep_allowlist.sh initially FAIL (plan gap per tpm/plan-gap-surfaces-at-reviewer-or-dry-run-not-at-plan-time); remediated by expanding .claude/carryover-allowlist.txt with 3 narrow carve-outs (flow-monitor/dist/**, .specaffold/features/20260421-rename-flow-monitor/**, .claude/team-memory/**); re-run PASS. T16.2–T16.5 (grep, capability JSON, i18n keys, SettingsRepositories path): PASS on first run.
- 2026-04-22 implement stage complete — 16/16 tasks checked; wave 1 + wave 2a + wave 2b merged into feature branch

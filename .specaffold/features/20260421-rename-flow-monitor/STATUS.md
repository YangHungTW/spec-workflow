# STATUS

- **slug**: 20260421-rename-flow-monitor
- **has-ui**: true
- **tier**: audited
- **stage**: plan
- **created**: 2026-04-21
- **updated**: 2026-04-21

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] design        (02-design/)                 — Designer
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
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

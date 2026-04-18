# STATUS

- **slug**: 20260418-per-project-install
- **has-ui**: false
- **stage**: tasks
- **created**: 2026-04-18
- **updated**: 2026-04-18

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] brainstorm    (01-brainstorm.md)           — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM
- [x] tasks         (06-tasks.md)                — TPM
- [ ] implement     (tasks checked off)          — Developer
- [ ] gap-check     (07-gaps.md, verdict PASS)   — QA-analyst
- [ ] verify        (08-verify.md, verdict PASS) — QA-tester
- [ ] archive       (moved to .spec-workflow/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-18 | pm | request intake filed
- 2026-04-18 | pm | brainstorm complete — recommends copy-at-pinned-ref with per-project update, flagged dogfood-paradox (5th occurrence)
- 2026-04-18 | pm | prd complete — R13 requirements, 0 blockers
- 2026-04-18 | architect | tech complete — D12 decisions, 0 blockers
- 2026-04-18 | orchestrator | design skipped (has-ui: false)
- 2026-04-18 | tpm | plan complete — 6 waves (incl W0 skeleton, W6 dogfood-final), 12–13 placeholder tasks, dogfood staging plan explicit (this repo stays on global-symlink through W5; W6 migrates-self as final act; runtime confirmation deferred to next feature after session restart per shared/dogfood-paradox-third-occurrence.md 6th occurrence)
- 2026-04-18 | tpm | tasks decomposed — T1..T21, widest wave 6 parallel (W5) across 7 wave slots (W0 skeleton, W1 library bundle, W2 init+tests, W3 update+tests, W4 migrate+tests, W5 skill+smoke+docs, W6=dogfood-final); D3 manifest schema + D4 classifier pseudocode + D4 dispatcher table quoted verbatim into T2 per tpm/briefing-contradicts-schema.md; AC2.c split into T6 (t41 real-file-conflict); R↔T trace fully populated (every R1–R13 covered; every T1–T21 maps to ≥1 R)

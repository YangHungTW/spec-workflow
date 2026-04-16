# STATUS

- **slug**: 20260416-prompt-rules-surgery
- **has-ui**: false
- **stage**: tasks
- **created**: 2026-04-16
- **updated**: 2026-04-16

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
- 2026-04-16 PM — intake complete, has-ui=false; big scope (6 items), brainstorm must confirm one-PRD vs split
- 2026-04-16 PM — brainstorm complete, recommending split into two features (B1 prompt+rules surgery, B2 implement/review orchestration) with Stop hook landing first for dogfood payoff
- 2026-04-16 PM — scope confirmed as B1 (items 1,2,3); renamed slug harness-upgrade → prompt-rules-surgery; items 4,5,6 deferred to B2 (PM memory candidate "split by blast radius" deferred to archive-time retro)
- 2026-04-16 orchestrator — design skipped (has-ui: false)
- 2026-04-16 PM — PRD written, R-count=16, AC-count=18, no blockers
- 2026-04-16 Architect — tech doc written, D-count=11, no blockers
- 2026-04-16 Architect — amended tech doc with D12 (safe settings.json read-merge-write); user flagged late constraint
- 2026-04-16 TPM — plan written, M-count=11, recommends fused agent-surgery tasks (slim + memory block per role)
- 2026-04-16 TPM — tasks broken down, T-count=25, first=T1, wave count=9

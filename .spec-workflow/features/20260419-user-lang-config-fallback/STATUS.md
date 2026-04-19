# STATUS

- **slug**: 20260419-user-lang-config-fallback
- **has-ui**: false
- **stage**: tasks
- **created**: 2026-04-19
- **updated**: 2026-04-19

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
- 2026-04-19 PM: intake complete; follow-up to 20260419-language-preferences addressing user-level vs project-level config gap; open questions on exact user-home path and precedence semantics deferred to brainstorm.
- 2026-04-19 PM: brainstorm complete; recommended approach = candidate list (project → user → XDG) with file-level override; open questions resolved except XDG-vs-simple-tilde (→ architect).
- 2026-04-19 orchestrator: design skipped (has-ui: false); advancing to prd.
- 2026-04-19 PM: PRD complete; R1..R7; architect decision open (XDG-aware vs simple-tilde final); no blocker questions.
- 2026-04-19 Architect: tech doc complete; D1..D8 decisions; XDG-aware chosen; 1 blocker question flagged for PM — AC4.a precedence semantics (stop-on-first-hit vs continue-past-invalid) require PM clarification before TPM locks tasks.
- 2026-04-19 PM update-req: AC4.a reworded to stop-on-first-hit per architect D6; PRD R4 body clarified; PRD and tech now aligned.
- 2026-04-19 TPM: plan complete; B1..B3 blocks across W1..W2 waves; handoff to /specflow:tasks.
- 2026-04-19 TPM: tasks complete; T1..T10 across W1..W2; handoff to /specflow:implement.

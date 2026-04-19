# STATUS

- **slug**: 20260419-user-lang-config-fallback
- **has-ui**: false
- **stage**: verify
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
- [x] implement     (tasks checked off)          — Developer
- [x] gap-check     (07-gaps.md, verdict PASS)   — QA-analyst
- [x] verify        (08-verify.md, verdict PASS) — QA-tester
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
- 2026-04-19 implement — wave 1 done (T1); review NITS (security advisory on $XDG_CONFIG_HOME absolute-path check; style should on CANDIDATES naming). T1 merged 40a3342.
- 2026-04-19 implement — wave 2 done (T2..T10, 9 parallel); 27 reviewers; 0 must, 3 NITS (T7 style, T8 perf+style). All merged.
- 2026-04-19 gap-fix: t53 exclusion list extended for new feature's spec dir + test files + .worktrees; smoke 71/72 → 72/72 PASS.
- 2026-04-19 implement stage complete — 10/10 tasks checked; smoke 72/72 PASS.
- 2026-04-19 qa-analyst — gap-check NITS; 0 must, 2 advisory (G1: AC6.c equivalent ordering, not exact string; G2: README §Precedence header added beyond tech D8 — both PRD-compliant); 18/18 ACs traced; advancing to verify.
- 2026-04-19 QA-tester — verify PASS; 18/18 ACs: 12 runnable, 5 structural (runtime deferred per dogfood paradox), 1 N/A; smoke 72/72; 08-verify.md written.

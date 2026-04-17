# STATUS

- **slug**: 20260416-prompt-rules-surgery
- **has-ui**: false
- **stage**: implement
- **created**: 2026-04-16
- **updated**: 2026-04-17

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] brainstorm    (01-brainstorm.md)           — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM
- [x] tasks         (06-tasks.md)                — TPM
- [x] implement     (tasks checked off)          — Developer
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
- 2026-04-16 Developer — T1 done (rules scaffold + README/index + classify-before-mutate exemplar)
- 2026-04-16 implement wave 1 done — T1
- 2026-04-16 implement wave 2 done — T2, T3, T4, T5, T6, T7 (6 parallel; 5 merge conflicts resolved mechanically: adjacent STATUS notes + index rows)
- 2026-04-17 Developer — T8 done: SessionStart hook fires; digest injection confirmed in real Claude Code session (5 rules visible incl. classify-before-mutate)
- 2026-04-17 implement wave 3 done — T8 (USER CHECKPOINT passed)
- 2026-04-17 Developer — T9 done: settings.json wired via T7 helper; all 5 verify checks pass incl. idempotence
- 2026-04-17 implement wave 4 done — T9
- 2026-04-17 implement wave 5 done — T10-T16 (7 parallel; all ≤ceiling; 5 appendix files created; 6 merge conflicts auto-resolved)
- 2026-04-17 T17 done: 1 hit on no-force slug in architect.md was legitimate meta-reference in Team memory section (naming entries, not duplicating rule content); remaining audit checks all clean
- 2026-04-17 implement wave 6 done — T17 (dedup audit)
- 2026-04-17 implement wave 7 done — T18-T22 (5 parallel test batches; 16 new tests all PASS)
- 2026-04-17 T23 done: smoke.sh registers t13-t28; ORIG_HOME preserved for asdf python3 shim; 28/28 PASS
- 2026-04-17 T24 done: rules/README contrast table + team-memory/README cross-ref
- 2026-04-17 T25 done: top-level README SessionStart hook section
- 2026-04-17 implement wave 8+9 done — T23 smoke, T24 T25 docs
- 2026-04-17 T15 checkbox fix (lost in merge, surgery was correct)
- 2026-04-17 implement stage complete — all 25 tasks merged on feature branch

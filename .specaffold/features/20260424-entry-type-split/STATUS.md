# STATUS

- **slug**: 20260424-entry-type-split
- **has-ui**: false
- **tier**: audited
- **stage**: plan
- **created**: 2026-04-24
- **updated**: 2026-04-24

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] design        (02-design/)                 — Designer — skipped (has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-24 PM — request intake; 3-way entry split (request/bug/chore); has-ui false (CLI workflow surface); tier audited supplied by user; open questions captured in Context for PRD stage.
- 2026-04-24 request — tier audited supplied by user via --tier flag
- 2026-04-24 user clarification — Q2 resolved: `/scaff:bug` accepts URL, ticket ID, or free-form description as one positional arg (auto-detected); no external fetch. Updated in 00-request.md Context §2.
- 2026-04-24 next — has-ui: false skips design
- 2026-04-24 PM — 03-prd.md authored: 15 Rs (R1..R15 with sub-numbered R7.1/R8.1/R10.1), 16 ACs (AC1..AC15 structural + AC-runtime-deferred), 8 Ds (D1..D8); §7 empty; runtime handoff bound in AC-runtime-deferred per dogfood paradox.
- 2026-04-24 Architect — 04-tech.md authored: 10 tech-Ds (stage-matrix carrier=new bin/scaff-stage-matrix; work-type=explicit STATUS field; legacy default=feature; command files=full duplication; pm.md=three parallel sections; keyword table=one 3-row master; template format=markdown + HTML-comment placeholders; backward-compat=grep shape assertion; matrix ABI=ternary stage_status; runtime handoff=pre-committed STATUS line in final wave); §5 empty; architect-gate APPROVED for tier=audited (security surface light — no network, no new auth, all writes under REPO_ROOT).
- 2026-04-24 TPM — 05-plan.md authored: 17 tasks across 3 waves (W1 foundation 7 tasks, W2 dispatch 7 tasks, W3 docs+handoff 3 tasks); T17 pre-commits RUNTIME HANDOFF STATUS Notes line per D8/tech-D10 dogfood-paradox handling; T14 backward-compat grep-shape assertion per tech-D8; T2 unit-tests all 72 stage_status cells; 0 §5 blockers.
- 2026-04-24 review dispatched — slug=20260424-entry-type-split wave=1 tasks=T1,T2,T3,T4,T5,T6,T7 axes=security,performance,style
- 2026-04-24 review result — wave 1 verdict=NITS (20/21 PASS + 1 advisory on T7 performance: assert_literal forks 3 times; cosmetic, 4 call sites)
- 2026-04-24 implement wave 1 done — T1, T2, T3, T4, T5, T6, T7; t102 78/78 PASS (72 cells + 4 asymmetries + malformed); t103 18/18 PASS
- 2026-04-24 PLAN GAP discovered at W1 close — `.claude/commands/scaff/prd-templates/*.md` (T3 output) are auto-registered by Claude Code harness as slash commands (`scaff:prd-templates:bug/chore/feature`). tech-D7 location conflicts with command-harvesting scope. Needs remediation before W2 consumers (T10/T11 bug.md/chore.md) reference the path.
- 2026-04-24 REMEDIATION — moved templates to `.specaffold/prd-templates/` (outside commands-harvest scope; semantically aligned with features/). Updated all path refs: 03-prd.md (R8/AC6/D7), 04-tech.md (tech-D7 addendum), 05-plan.md (T3/T5/T7 scope/verify), pm.md probe sections (2 lines), test/t103 (3 lines). t103 18/18 PASS with new path; skill list no longer shows scaff:prd-templates:* commands. ABI unchanged; just a path move.

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
- 2026-04-18 | implement | review dispatched — slug=20260418-per-project-install wave=W0 tasks=T1 axes=security,performance,style
- 2026-04-18 | implement | review result — wave W0 verdict=NITS (style: 5 should-findings re comment-restates-what + emit_summary dead-symbol; security PASS; performance PASS)
- 2026-04-18 | implement | wave W0 done — T1 (--one-wave mode, orchestrator halts for user checkpoint)
- 2026-04-18 | implement | W0 NITS hotfix — 5 style should-findings on bin/specflow-seed cleared via 20260418-per-project-install-T1-hotfix; comment-only changes, T1 Verify re-confirmed green, no re-review run
- 2026-04-18 | implement | review dispatched — slug=20260418-per-project-install wave=W1 tasks=T2 axes=security,performance,style
- 2026-04-18 | implement | review result — wave W1 verdict=BLOCK blocking-tasks=T2(security 2× must path-traversal on classify_copy_target:224 + manifest_read:163); performance PASS; style 9× should (4 dead-symbols, 5 WHAT-comments); worktree+branch 20260418-per-project-install-T2 preserved for retry via /specflow:implement 20260418-per-project-install --task T2
- 2026-04-18 | implement | T2 retry 1/2 — folded fix commit fa8c6dc; traversal guard at manifest_read boundary + defense-in-depth case-guard in classify_copy_target + 4 dead-symbol TODOs + 5 WHAT-comments cleaned; all 9 Verify assertions (7 original + 2 new traversal) pass; 621 LOC
- 2026-04-18 | implement | review result (retry) — wave W1 verdict=NITS (security 1× should on __probe manifest-roundtrip mpath arg, hidden internal verb; performance PASS; style 2× advisory); BLOCK cleared, merged as 7a38ee0
- 2026-04-18 | implement | wave W1 done — T2 (--one-wave mode, orchestrator halts for user checkpoint)
- 2026-04-18 | implement | review dispatched — slug=20260418-per-project-install wave=W2 tasks=T3,T4,T5,T6 axes=security,performance,style (12 reviewer agents parallel)
- 2026-04-18 | implement | review result — wave W2 verdict=NITS; T3 security 2× should (silent .bak clobber in drifted-ours + manifest paths) + performance 1× advisory (per-file python3 batch opportunity) + style 3× should (WHAT-comments); T4 all-PASS; T5 performance 1× advisory (find -exec); T6 style 1× advisory (WHAT-comment); no must findings, all 4 tasks merged
- 2026-04-18 | implement | wave W2 done — T3,T4,T5,T6 (--one-wave mode, orchestrator halts for user checkpoint); 6/21 tasks complete

# STATUS

- **slug**: 20260426-fix-init-missing-preflight-files
- **has-ui**: false
- **work-type**: bug
- **tier**: standard
- **stage**: archive
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] prd           (03-prd.md)                  — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [x] implement     (05-plan.md tasks checked off) — Developer
- [x] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [x] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 PM — seeded 00-request.md (Source: description) and 03-prd.md from bug template; tier standard set via --tier flag (no propose-and-confirm); 5 R-clauses, 7 ACs, 4 Decisions, 0 open questions.
- 2026-04-26 next — design skipped (has-ui: false; stage_status bug/standard/design = optional → skip)
- 2026-04-26 Architect — wrote 04-tech.md: 7 D-decisions (D1 default config heredoc + helper, D2 explicit preflight.md plan_copy entry, D3 reuse classifier states, D4 cmd_migrate parity, D5 byte-identical helper to prevent shim-style drift, D6 sibling-block plan_copy emit, D7 new t112 covering AC1-AC7 incl. migrate-path mirror); 0 blockers.
- 2026-04-26 TPM — wrote 05-plan.md: 1 wave / 2 tasks (T1 bin/scaff-seed plan_copy entry + emit_default_config_yml helper wired into cmd_init AND cmd_migrate; T2 test/t112_init_seeds_preflight_files.sh AC1-AC7 incl A7 migrate-path mirror). T1+T2 file-disjoint, parallel-safe. Folded architect's logical pieces (i) plan_copy entry and (ii) helper+call-sites into single T1 to avoid same-file conflict on bin/scaff-seed. Test counter t112 pre-declared. No --no-verify discipline needed (this fix does not ship its own gate enforcement). 0 blockers.
- 2026-04-26 review dispatched — slug=20260426-fix-init-missing-preflight-files wave=1 tasks=T1,T2 axes=security,performance,style
- 2026-04-26 review result — wave 1 verdict=NITS (T2-perf: A3 reads config.yml 3× via separate greps)
- 2026-04-26 implement — fixup W1: t112 grep-target mismatch (config.yml uses 'already:<path>' helper format; preflight.md uses 'already: <path>' plan_copy format; mixed convention inside scaff-seed itself — finding worth surfacing)
- 2026-04-26 implement wave 1 done — T1, T2; all 6 tests t107-t112 green
- 2026-04-26 validate — slug=20260426-fix-init-missing-preflight-files verdict=NITS (1 should + 2 advisory: scaff-seed already:<path> vs already: <path> token format inconsistency between helper and plan_copy; tech doc D3 stale)
- 2026-04-26 architectural-shift discovered post-validate — runtime exploration found that bin/* (scaff-tier, scaff-stage-matrix, scaff-lint, scaff-aggregate-verdicts) are also missing from scaff-seed manifest, so /scaff:next still fails in consumer repos. Decision: NOT expand this bug to copy bin/ (option A); instead pivot to thin-consumer architecture (option B) — command preambles source from $SCAFF_SRC, not $REPO_ROOT. This fix's emit_default_config_yml helper remains keep-worthy in B world (config.yml lives in consumer); plan_copy preflight.md becomes redundant but harmless. B-world fix lands in follow-up bug.
- 2026-04-26 archive — bug merged to main via riders pattern in commit bc24d7a (orchestrator's validate commit 6cf2b76 accidentally landed on parallel 20260426-flow-monitor-graph-view branch; user's other session carried both branches forward at merge time without history rewrite — see shared/orchestrator-rider-commit-recovery.md); 2 retro memory entries landed (shared/orchestrator-rider-commit-recovery.md, qa-analyst/wiring-trace-ends-at-user-goal.md); moved to .specaffold/archive/

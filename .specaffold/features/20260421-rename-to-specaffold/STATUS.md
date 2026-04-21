# STATUS

- **slug**: 20260421-rename-to-specaffold
- **has-ui**: false
- **tier**: standard
- **stage**: request
- **created**: 2026-04-21
- **updated**: 2026-04-21

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false) — skipped (has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .spec-workflow/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-21 request — intake drafted by PM; tier pending propose-and-confirm
- 2026-04-21 request — tier standard proposed (standard) accepted by user
- 2026-04-21 next — design skipped (has-ui: false)
- 2026-04-21 PM — 03-prd.md drafted: R1–R16, AC1–AC14; 3 blocker questions raised in §7 (Q1 slash prefix, Q2 agent prefix, Q3 .spec-workflow dir rename); PM-resolved defaults baked in §8 (D1 hard cutover, D2 repo-dir out-of-scope, D3 global paths migrate on next claude-symlink install)
- 2026-04-21 update-req — §7 blockers Q1/Q2/Q3 resolved by user; decisions recorded as D4/D5/D6 in §8
- 2026-04-21 next — prd checked off (§7 clean, R1–R17, AC1–AC15)
- 2026-04-21 Architect — 04-tech.md written: 6 decisions (git-mv-first 4-wave sequencing, allow-list at .claude/carryover-allowlist.txt, scaff-* canonical no wrapper, hook sed rewrites, compat symlink via scaff-seed classify-before-mutate, orphan cleanup in migration notes); §6 no blockers; 2 non-blocking flags noted for plan (validate-command self-reference at archive, transient W1-to-W3 path-resolution gap)
- 2026-04-21 TPM — 05-plan.md written: 32 tasks across 4 waves (W1=8, W2=8, W3=12, W4=4); architect flag #1 resolved via verify-invariant + standalone-shell escape hatch; flag #2 resolved by moving compat symlink forward into W1 (T8 serial after T6); self-directory-rename dogfood handled by path re-resolution at each stage invocation + T8 symlink; no blockers
- 2026-04-21 implement — skip-inline-review USED for wave 1 (reason: user-approved dogfood-paradox bypass; T1–T6 are pure git-mv with no reviewable body content, T7 is a 4-line JSON string replace, T8 is classify-before-mutate ln -s; all three axes (security/performance/style) trivially non-applicable)
- 2026-04-21 implement — orchestrator cleanup: removed untracked .DS_Store + empty dir shell under .spec-workflow/ post-T6 merge (git mv does not move untracked files or empty dirs; required to unblock T8 symlink target)
- 2026-04-21 implement wave 1 done — T1, T2, T3, T4, T5, T6, T7, T8 (W1 merged; --one-wave stop per user request; 24/32 tasks remain for W2+W3+W4)
- 2026-04-21 review dispatched — slug=20260421-rename-to-specaffold wave=2 tasks=T9,T10,T11,T12,T13,T14,T15 axes=security,performance,style
- 2026-04-21 review result — wave 2 verdict=BLOCK blocking-tasks=T15 (style axis; 2 must-severity findings — test/t39_init_fresh_sandbox.sh:155 and test/t42_update_no_conflict.sh:187 grep stale "specflow_ref" key after T15 renamed it to "scaff_ref"); merge loop NOT executed; worktrees/branches retained for retry
- 2026-04-21 implement — PLAN GAP surfaced by T15 review: 88 test/**/*.sh files contain specflow|spec-workflow references; no W2/W3 task covers test/ body rewrites; T28 (W4 grep-allow-list) will fail unless a new task is added via /specflow:update-plan before W4
- 2026-04-21 T15 retry — narrow scope (2 consumer test files, 10 lines) fixing scaff_ref awk-sniff + scaff.manifest path; commit e2740fb
- 2026-04-21 review result — wave 2 retry verdict=PASS (T15 re-reviewed all 3 axes; T9-T14 unchanged verdicts retained from first dispatch)
- 2026-04-21 implement wave 2 done — T9, T10, T11, T12, T13, T14, T15, T16 (W2 merged; 8 tasks done; 16/32 tasks remain for W3+W4); test/**/*.sh plan gap still open — /specflow:update-plan required before W4 T28
- 2026-04-21 update-plan — TPM added T21c: body rewrite in test/**/*.sh; W3 task count 12→13, total 32→33; closes plan gap surfaced by T15 review; dep chain binds to T3/T5/T11/T15 so path refs rewrite after renames complete; T24 now depends on T21c (both edit test/smoke.sh — serialised within W3)

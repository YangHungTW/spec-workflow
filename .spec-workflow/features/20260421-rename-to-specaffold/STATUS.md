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

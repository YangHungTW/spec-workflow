# STATUS

- **slug**: 20260426-fix-install-hook-wrong-path
- **has-ui**: false
- **work-type**: bug
- **tier**: standard
- **stage**: archive
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [~] design        (02-design/)                 — Designer (skip if has-ui: false) (skipped — bug × tiny matrix)
- [x] prd           (03-prd.md)                  — PM
- [~] tech          (04-tech.md)                 — Architect (skipped — bug × tiny matrix)
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [x] implement     (05-plan.md tasks checked off) — Developer
- [x] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [x] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 PM — request intake (bug); tier proposed=tiny, awaiting user confirmation
- 2026-04-26 request — tier tiny proposed (tiny) accepted by user
- 2026-04-26 next — stage_status bug/tiny/design = skipped
- 2026-04-26 next — prd accepted (03-prd.md complete; OQ1 deferred to tech stage, not a blocker)
- 2026-04-26 next — stage_status bug/tiny/tech = skipped
- 2026-04-26 next — plan stub hand-written from 03-prd.md (bug × tiny plumbing gap: /scaff:plan hard-requires 04-tech.md but tech is matrix-skipped; TPM short-circuit only covers chore. Workaround mirrors tpm/chore-tiny-plan-short-circuit-plumbing-gap.md legacy step-1 pattern. Surfaced as plumbing-gap follow-up.)
- 2026-04-26 Developer — T1 implement: TDD red→green; bin/scaff-install-hook default to .claude/settings.json + makedirs + idempotent-before-backup; bin/scaff-seed bash prefix on 4 command args; tests t7/t27/t28/t39/t114 updated to new path; A5 appended to t114 covering AC1-AC3; bug repro PASS
- 2026-04-26 implement wave 1 done — T1 (commit f031593, merged via 60d00c4); inline review skipped (tier=tiny default per R16)
- 2026-04-26 implement — auto-upgrade SUGGESTED tiny→standard (diff: 442 lines, 11 files; threshold 200/3); awaiting TPM confirmation
- 2026-04-26 implement complete — all tasks done; next is /scaff:next → validate

- 2026-04-26 orchestrator — tier upgrade tiny→standard: wave 1 threshold trip (442 lines / 11 files vs 200/3 limits, D7/R14)
- 2026-04-27 validate — slug=20260426-fix-install-hook-wrong-path verdict=NITS (advisory findings in 08-validate.md: 3 should + 1 advisory, all in test layer; tester=PASS, analyst=NITS)
- 2026-04-27 archive — feature merged to main (1594766) + archive complete; 5 retrospective memory entries (developer/idempotency-check-before-backup-not-after, developer/atomic-swap-must-bypass-user-aliases, tpm/bug-tiny-plan-plumbing-gap-mirrors-chore-tiny, qa-analyst/grep-substring-false-positive-in-path-assertions, pm/prd-acceptance-must-account-for-upstream-side-effects)

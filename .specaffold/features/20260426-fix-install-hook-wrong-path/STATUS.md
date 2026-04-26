# STATUS

- **slug**: 20260426-fix-install-hook-wrong-path
- **has-ui**: false
- **work-type**: bug
- **tier**: tiny
- **stage**: plan
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [~] design        (02-design/)                 — Designer (skip if has-ui: false) (skipped — bug × tiny matrix)
- [x] prd           (03-prd.md)                  — PM
- [~] tech          (04-tech.md)                 — Architect (skipped — bug × tiny matrix)
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 PM — request intake (bug); tier proposed=tiny, awaiting user confirmation
- 2026-04-26 request — tier tiny proposed (tiny) accepted by user
- 2026-04-26 next — stage_status bug/tiny/design = skipped
- 2026-04-26 next — prd accepted (03-prd.md complete; OQ1 deferred to tech stage, not a blocker)
- 2026-04-26 next — stage_status bug/tiny/tech = skipped
- 2026-04-26 next — plan stub hand-written from 03-prd.md (bug × tiny plumbing gap: /scaff:plan hard-requires 04-tech.md but tech is matrix-skipped; TPM short-circuit only covers chore. Workaround mirrors tpm/chore-tiny-plan-short-circuit-plumbing-gap.md legacy step-1 pattern. Surfaced as plumbing-gap follow-up.)

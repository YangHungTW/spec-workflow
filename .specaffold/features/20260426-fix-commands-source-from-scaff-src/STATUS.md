# STATUS

- **slug**: <slug>
- **has-ui**: false
- **work-type**: feature
- **tier**: standard
- **stage**: request
- **created**: <YYYY-MM-DD>
- **updated**: <YYYY-MM-DD>

## Stage checklist
- [x] request       (00-request.md)              — PM
- [ ] design        (02-design/)                 — Designer (skip if has-ui: false)
- [ ] prd           (03-prd.md)                  — PM
- [ ] tech          (04-tech.md)                 — Architect
- [ ] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 PM — seeded 00-request.md (Source: description; Context section references parent bug 20260426-fix-init-missing-preflight-files at .specaffold/archive/) and 03-prd.md from bug template; tier standard set via --tier flag (no propose-and-confirm); 7 R-clauses, 8 ACs, 4 D-placeholders for architect, 0 open questions.

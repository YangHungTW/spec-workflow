# STATUS

- **slug**: 20260426-fix-commands-source-from-scaff-src
- **has-ui**: false
- **work-type**: bug
- **tier**: standard
- **stage**: tech
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] prd           (03-prd.md)                  — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] tech          (04-tech.md)                 — Architect
- [ ] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 PM — seeded 00-request.md (Source: description; Context section references parent bug 20260426-fix-init-missing-preflight-files at .specaffold/archive/) and 03-prd.md from bug template; tier standard set via --tier flag (no propose-and-confirm); 7 R-clauses, 8 ACs, 4 D-placeholders for architect, 0 open questions.
- 2026-04-26 orchestrator — fixed STATUS.md placeholders left by PM (slug, work-type, dates) and reordered prd/design checklist to match bug-tier intake convention (request+prd both done at intake).
- 2026-04-26 next — design skipped (has-ui: false; stage_status bug/standard/design = optional → skip)
- 2026-04-26 Architect — wrote 04-tech.md; resolved D1–D4 (PM placeholders) and added D5–D7 (lint reuse, plan_copy cleanup, t113 sandbox test); 0 blockers; applied by-construction-coverage + commands-harvest-scope memory entries.

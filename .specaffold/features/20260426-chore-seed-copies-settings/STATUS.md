# STATUS

- **slug**: 20260426-chore-seed-copies-settings
- **has-ui**: false
- **work-type**: chore
- **tier**: tiny
- **stage**: prd
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [ ] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [ ] tech          (04-tech.md)                 — Architect
- [ ] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 request — tier tiny supplied by user via --tier flag (skips propose-and-confirm).
- 2026-04-26 PM — wrote 00-request.md and 03-prd.md from .specaffold/prd-templates/chore.md; tier=tiny (user-supplied); 4 acceptance checkboxes; 0 open questions; references parent archive 20260426-fix-commands-source-from-scaff-src for source incident.
- 2026-04-26 orchestrator — intake bookkeeping fixup: checked [x] prd (PM wrote 03-prd.md same turn but missed checkbox); advanced stage field request → prd. chore × tiny will skip design/tech/plan per stage_status matrix; next is implement (with hand-written minimal 05-plan.md per chore-tiny-plan-short-circuit memory).

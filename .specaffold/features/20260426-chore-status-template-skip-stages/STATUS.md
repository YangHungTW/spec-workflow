# STATUS

- **slug**: 20260426-chore-status-template-skip-stages
- **has-ui**: false
- **work-type**: chore
- **tier**: tiny
- **stage**: implement
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 request — tier tiny supplied by user via --tier flag (skips propose-and-confirm).
- 2026-04-26 PM — wrote 00-request.md and 03-prd.md from .specaffold/prd-templates/chore.md; tier=tiny (user-supplied); 4 checklist items; 0 open questions; remediates analyst Finding 2 from archived feature 20260426-chore-t114-migrate-coverage; chosen render shape `[~] <stage> (skipped — chore × tiny matrix)`; touched-files list does NOT include bin/scaff-stage-matrix (it is a pure verdict helper); checked [x] request; advanced stage field request → prd.
- 2026-04-26 chore intake — orchestrator bookkeeping: checked [x] prd (PM wrote 03-prd.md same turn but left checkbox unchecked, matching prior chore-tiny precedent). chore × tiny will skip design/tech/plan per stage_status matrix; next is implement (with hand-written minimal 05-plan.md per chore-tiny-plan-short-circuit memory).
- 2026-04-26 next — stage_status chore/tiny/design = skipped (also has-ui: false). Note: this feature initialised pre-fix; PRD §Out-of-scope explicitly forward-only, so the [x] render is intentional here.
- 2026-04-26 next — stage_status chore/tiny/tech = skipped.
- 2026-04-26 next — plan skipped (stage_status chore/tiny/plan = optional; /scaff:plan hard-requires 04-tech.md which is matrix-skipped; minimal 05-plan.md hand-written from 03-prd.md checklist for implement consumption — see tpm/chore-tiny-plan-short-circuit-plumbing-gap.md).
- 2026-04-26 next — advanced stage field prd → implement.

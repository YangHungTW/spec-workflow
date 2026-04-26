# STATUS

- **slug**: 20260426-chore-scaff-plan-chore-aware
- **has-ui**: false
- **work-type**: chore
- **tier**: standard
- **stage**: implement
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [~] design        (02-design/)                 — Designer (skip if has-ui: false) (skipped — chore × standard matrix)
- [x] prd           (03-prd.md)                  — PM
- [~] tech          (04-tech.md)                 — Architect (skipped — chore × standard matrix)
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 request — tier standard supplied by user via --tier flag (skips propose-and-confirm).
- 2026-04-26 PM — wrote 00-request.md and 03-prd.md (chore template); Option A chosen (relax /scaff:plan + TPM chore-tiny short-circuit); 5 checklist items; TPM short-circuit template pinned to live in .claude/agents/scaff/tpm.md per §Decisions(b); memory disposition = update (§Decisions(d)).
- 2026-04-26 next — stage_status chore/standard/design = skipped (rendered with new [~] shape; chore × standard suffix variant). First feature initialised post-chore-status-template-skip-stages archive — uses [~] shape from the start.
- 2026-04-26 next — stage_status chore/standard/tech = skipped.
- 2026-04-26 next — plan REQUIRED on chore × standard but /scaff:plan hard-requires 04-tech.md (matrix-skipped); applying the chore-tiny short-circuit memory's workaround one final time as a chore × standard variant; T1 of this very feature lands the plumbing fix that eliminates the workaround going forward.
- 2026-04-26 next — advanced stage field prd → implement.
- 2026-04-26 review dispatched — slug=20260426-chore-scaff-plan-chore-aware wave=1 tasks=T1 axes=security,performance,style
- 2026-04-26 implement wave 1 done — T1

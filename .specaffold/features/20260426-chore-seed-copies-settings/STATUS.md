# STATUS

- **slug**: 20260426-chore-seed-copies-settings
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
- 2026-04-26 PM — wrote 00-request.md and 03-prd.md from .specaffold/prd-templates/chore.md; tier=tiny (user-supplied); 4 acceptance checkboxes; 0 open questions; references parent archive 20260426-fix-commands-source-from-scaff-src for source incident.
- 2026-04-26 orchestrator — intake bookkeeping fixup: checked [x] prd (PM wrote 03-prd.md same turn but missed checkbox); advanced stage field request → prd. chore × tiny will skip design/tech/plan per stage_status matrix; next is implement (with hand-written minimal 05-plan.md per chore-tiny-plan-short-circuit memory).
- 2026-04-26 next — stage_status chore/tiny/design = skipped (also has-ui: false).
- 2026-04-26 next — stage_status chore/tiny/tech = skipped.
- 2026-04-26 next — plan skipped (stage_status chore/tiny/plan = optional; /scaff:plan hard-requires 04-tech.md which is matrix-skipped; minimal 05-plan.md hand-written from 03-prd.md checklist for implement consumption — see tpm/chore-tiny-plan-short-circuit-plumbing-gap.md).
- 2026-04-26 next — advanced stage field prd → implement.
- 2026-04-26 Developer — T1 done: bin/scaff-seed plan_copy enumerates .claude/settings.json for init/migrate (not update); read-merge-write atomic with .bak via bin/scaff-install-hook precedent; test/t114_seed_settings_json.sh covers fresh-install + merge + update-parity paths and exits 0.
- 2026-04-26 implement — skip-inline-review USED for wave 1 (reason: tiny-default).
- 2026-04-26 implement wave 1 done — T1.
- 2026-04-26 implement — auto-upgrade SUGGESTED tiny→standard (diff: 433 lines, 4 files; threshold 200/3); awaiting TPM confirmation.

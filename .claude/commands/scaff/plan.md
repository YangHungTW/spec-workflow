---
description: TPM produces implementation plan. Usage: /scaff:plan <slug>
---

1. Read STATUS. Require `03-prd.md` AND `04-tech.md` exist.
2. Invoke **scaff-tpm** subagent for plan mode → writes `05-plan.md`.
   - **New-shape features**: `05-plan.md` is the single merged file containing both the
     narrative plan (wave schedule, risks, sequencing rationale) and the task checklist
     (task blocks with `- [ ]` checkboxes). No separate `06-tasks.md` is produced.
   - **Legacy features** (a `06-tasks.md` already exists): behaviour is unchanged.
   - See `tpm.md` for authoring detail and task-block format.
3. Update STATUS: check `[x] plan`.
4. Next: `/scaff:implement <slug> <task-id>` (reads task checklist from `05-plan.md`).

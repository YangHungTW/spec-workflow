---
description: TPM produces implementation plan. Usage: /scaff:plan <slug>
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Read STATUS. Require `03-prd.md` AND `04-tech.md` exist.
2. Invoke **scaff-tpm** subagent for plan mode → writes `05-plan.md`.
   - `05-plan.md` is the single merged file containing both the narrative plan (wave schedule, risks, sequencing rationale) and the task checklist (task blocks with `- [ ]` checkboxes).
   - See `tpm.md` for authoring detail and task-block format.
3. Update STATUS: check `[x] plan`.
4. Next: `/scaff:implement <slug>` (reads task checklist from `05-plan.md`).

---
description: TPM revises the plan. Usage: /scaff:update-plan <slug>
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Ask user what's changing in `05-plan.md` and why.
2. Invoke **scaff-tpm** subagent in update mode. Edits plan, tags changes `[CHANGED YYYY-MM-DD]`.
3. Log to STATUS Notes.

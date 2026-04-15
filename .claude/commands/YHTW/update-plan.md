---
description: TPM revises the plan. Usage: /YHTW:update-plan <slug>
---

1. Ask user what's changing in `05-plan.md` and why.
2. Invoke **YHTW-tpm** subagent in update mode. Edits plan, tags changes `[CHANGED YYYY-MM-DD]`, marks `06-tasks.md` stale if it exists.
3. Log to STATUS Notes.

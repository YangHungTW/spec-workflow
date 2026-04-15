---
description: TPM adds, edits, or removes a task. Usage: /YHTW:update-task <slug>
---

1. Ask user: add / edit / remove which task?
2. Invoke **YHTW-tpm** subagent. New tasks get the next T-id; do not renumber existing tasks.
3. If removing a task after implementation started, require user confirmation on whether to revert code.
4. Log to STATUS Notes with reason.

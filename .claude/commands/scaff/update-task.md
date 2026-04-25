---
description: TPM adds, edits, or removes a task. Usage: /scaff:update-task <slug>
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Ask user: add / edit / remove which task?
2. Invoke **scaff-tpm** subagent. New tasks get the next T-id; do not renumber existing tasks.
3. If removing a task after implementation started, require user confirmation on whether to revert code.
4. Log to STATUS Notes with reason.

---
description: PM revises request or PRD mid-stream. Usage: /scaff:update-req <slug>
---

1. Ask user what changed and why.
2. Invoke **scaff-pm** subagent in update mode. PM edits `00-request.md` and/or `03-prd.md`, tagging changed lines `[CHANGED YYYY-MM-DD]`.
3. PM prepends `> ⚠ STALE since <date> — PRD changed, re-run <command>` to every downstream artifact that exists.
4. Log change to STATUS Notes.
5. Do NOT auto re-run downstream stages.

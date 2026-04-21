---
description: Architect revises tech/architecture decisions. Usage: /specflow:update-tech <slug>
---

1. Ask user what's changing in `04-tech.md` and why.
2. Invoke **specflow-architect** subagent in update mode. Tags changed decisions `[CHANGED YYYY-MM-DD]`, marks `05-plan.md` and downstream artifacts stale if they exist.
3. Log to STATUS Notes.
4. Do NOT auto re-run downstream stages.

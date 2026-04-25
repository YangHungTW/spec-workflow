---
description: Architect revises tech/architecture decisions. Usage: /scaff:update-tech <slug>
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Ask user what's changing in `04-tech.md` and why.
2. Invoke **scaff-architect** subagent in update mode. Tags changed decisions `[CHANGED YYYY-MM-DD]`, marks `05-plan.md` and downstream artifacts stale if they exist.
3. Log to STATUS Notes.
4. Do NOT auto re-run downstream stages.

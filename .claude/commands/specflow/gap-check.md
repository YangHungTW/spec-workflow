---
description: QA-analyst compares PRD ↔ tasks ↔ diff. Usage: /specflow:gap-check <slug>
---

1. Require all tasks in `06-tasks.md` checked (or user explicit override).
2. Invoke **specflow-qa-analyst** subagent → writes `07-gaps.md`.
3. If verdict = BLOCKED, surface blockers. Do NOT advance.
4. If PASS, check `[x] gap-check`. Next: `/specflow:verify <slug>`.

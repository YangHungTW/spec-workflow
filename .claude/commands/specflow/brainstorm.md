---
description: PM explores approaches before PRD. Usage: /specflow:brainstorm <slug>
---

1. Read `.spec-workflow/features/<slug>/STATUS.md`. Require stage ≥ request.
2. Invoke **specflow-pm** subagent for brainstorm mode → writes `01-brainstorm.md`.
3. Update STATUS: check `[x] brainstorm`.
4. Summarize the recommendation in 3 lines.
5. Next: `/specflow:design <slug>` if `has-ui: true`, else `/specflow:prd <slug>`.

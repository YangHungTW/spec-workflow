---
description: PM explores approaches before PRD. Usage: /YHTW:brainstorm <slug>
---

1. Read `docs/features/<slug>/STATUS.md`. Require stage ≥ request.
2. Invoke **YHTW-pm** subagent for brainstorm mode → writes `01-brainstorm.md`.
3. Update STATUS: check `[x] brainstorm`.
4. Summarize the recommendation in 3 lines.
5. Next: `/YHTW:design <slug>` if `has-ui: true`, else `/YHTW:prd <slug>`.

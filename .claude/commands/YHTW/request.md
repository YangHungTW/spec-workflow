---
description: PM intakes a new feature. Usage: /YHTW:request <slug> "<one-line ask>"
---

1. Parse `$ARGUMENTS` as `<slug> "<ask>"`. If slug missing, ask the user.
2. Copy `.spec-workflow/features/_template/` to `.spec-workflow/features/<slug>/`.
3. Invoke the **YHTW-pm** subagent to fill `00-request.md` and set `has-ui` in STATUS. PM will probe for missing context.
4. Update STATUS: stage=request, check `[x] request`, set dates.
5. Report: path created, has-ui value, and next command (`/YHTW:brainstorm <slug>`).

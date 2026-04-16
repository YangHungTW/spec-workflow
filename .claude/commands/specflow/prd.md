---
description: PM writes the PRD. Usage: /specflow:prd <slug>
---

1. Read STATUS. Require stage ≥ brainstorm. Warn (don't block) if `has-ui: true` and design not done.
2. Invoke **specflow-pm** subagent for PRD mode → writes `03-prd.md`.
3. If PRD §7 has blocker questions, STOP and surface them. Do NOT advance STATUS.
4. Otherwise update STATUS: check `[x] prd`.
5. Report requirement count (R1..Rn) and next: `/specflow:tech <slug>`.

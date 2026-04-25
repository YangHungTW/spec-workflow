---
description: PM writes the PRD. Usage: /scaff:prd <slug>
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Read STATUS. Require stage ≥ brainstorm. Warn (don't block) if `has-ui: true` and design not done.
2. Invoke **scaff-pm** subagent for PRD mode → writes `03-prd.md`.
3. If PRD §7 has blocker questions, STOP and surface them. Do NOT advance STATUS.
4. Otherwise update STATUS: check `[x] prd`.
5. Report requirement count (R1..Rn) and next: `/scaff:tech <slug>`.

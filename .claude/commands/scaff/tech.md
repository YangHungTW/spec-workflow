---
description: Architect selects tech and designs system architecture. Usage: /scaff:tech <slug>
---

<!-- preflight: required -->
Run the preflight from `.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

1. Read STATUS. Require `03-prd.md` exists.
2. Invoke **scaff-architect** subagent → writes `04-tech.md`.
3. If §5 has blocker questions, STOP and surface them. Do NOT advance STATUS.
4. Otherwise update STATUS: check `[x] tech`.
5. Summarize decisions (D1..Dn) in 3 lines. Next: `/scaff:plan <slug>`.

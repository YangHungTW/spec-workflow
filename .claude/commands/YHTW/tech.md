---
description: Architect selects tech and designs system architecture. Usage: /YHTW:tech <slug>
---

1. Read STATUS. Require `03-prd.md` exists.
2. Invoke **YHTW-architect** subagent → writes `04-tech.md`.
3. If §5 has blocker questions, STOP and surface them. Do NOT advance STATUS.
4. Otherwise update STATUS: check `[x] tech`.
5. Summarize decisions (D1..Dn) in 3 lines. Next: `/YHTW:plan <slug>`.

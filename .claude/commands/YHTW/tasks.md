---
description: TPM breaks plan into tasks. Usage: /YHTW:tasks <slug>
---

1. Read STATUS. Require `05-plan.md`.
2. Invoke **YHTW-tpm** subagent for tasks mode → writes `06-tasks.md`.
3. Update STATUS: check `[x] tasks`.
4. Report task count and the first task. Next: `/YHTW:implement <slug>`.

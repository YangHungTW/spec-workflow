---
description: TPM produces implementation plan. Usage: /YHTW:plan <slug>
---

1. Read STATUS. Require `03-prd.md` AND `04-tech.md` exist.
2. Invoke **YHTW-tpm** subagent for plan mode → writes `05-plan.md`.
3. Update STATUS: check `[x] plan`.
4. Next: `/YHTW:tasks <slug>`.

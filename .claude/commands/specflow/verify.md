---
description: QA-tester verifies acceptance criteria. Usage: /specflow:verify <slug>
---

1. Require `07-gaps.md` verdict = PASS.
2. Invoke **specflow-qa-tester** subagent → writes `08-verify.md`.
3. If verdict = FAIL, surface failing R-ids. Do NOT advance.
4. If PASS, check `[x] verify`. Next: `/specflow:archive <slug>`.

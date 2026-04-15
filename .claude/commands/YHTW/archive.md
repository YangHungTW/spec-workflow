---
description: TPM archives a completed feature. Usage: /YHTW:archive <slug>
---

1. Require `08-verify.md` verdict = PASS.
2. Invoke **YHTW-tpm** subagent for archive mode.
3. Check `[x] archive`, then `git mv docs/features/<slug> docs/archive/<slug>` (fall back to `mv` if not a git repo).
4. Report final archive path.

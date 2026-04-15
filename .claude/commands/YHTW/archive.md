---
description: TPM archives a completed feature. Usage: /YHTW:archive <slug>
---

1. Require `08-verify.md` verdict = PASS.
2. Invoke **YHTW-tpm** subagent for archive mode.
3. **Retrospective** — TPM polls each role that participated (check STATUS for who ran which stage):
   - Ask each: "Anything from this feature worth saving to team memory?"
   - For each proposed lesson: user approves, picks scope (local/global) and type.
   - Write approved entries via the same protocol as `/YHTW:remember`.
   - Skip roles that say "nothing new".
4. Check `[x] archive`, then `git mv docs/features/<slug> docs/archive/<slug>` (fall back to `mv` if not a git repo).
5. Report final archive path and any memory entries added.

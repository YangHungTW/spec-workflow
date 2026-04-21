---
description: Promote a repo-local team-memory entry to global. Usage: /scaff:promote <role>/<file>
---

1. Parse `$ARGUMENTS` as `<role>/<file>` (e.g. `developer/tdd-before-green.md`).
2. Verify source exists at `.claude/team-memory/<role>/<file>`.
3. Ask user: why is this ready to promote? (Usually "seen it apply in ≥2 repos"). Record the rationale.
4. Move file: `mv .claude/team-memory/<role>/<file> ~/.claude/team-memory/<role>/<file>`. Create global dir if missing.
5. Update both `index.md` files: remove from local, add to global.
6. In the promoted file, bump `updated` frontmatter date and append a note: `_Promoted to global <date>: <rationale>_`.
7. Report the new global path.

If the same filename already exists in global, STOP and show the conflict — ask user whether to merge, overwrite, or rename.

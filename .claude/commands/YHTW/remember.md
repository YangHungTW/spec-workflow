---
description: Manually save a team-memory entry. Usage: /YHTW:remember <role> "<lesson>" [--scope local|global]
---

1. Parse `$ARGUMENTS` for `<role>` (one of: pm, designer, architect, tpm, developer, qa-analyst, qa-tester, shared), `<lesson>` quoted text, and optional `--scope` flag.
2. If role unknown, list the valid roles and ask user.
3. Default scope: **local**. If `--scope global`, write to `~/.claude/team-memory/<role>/`; else to `.claude/team-memory/<role>/`.
4. Ask clarifying questions if the lesson is short on context:
   - What type? (feedback / pattern / decision-log / glossary)
   - A concrete trigger / when-to-apply?
   - Why? (the reason it matters, usually a past incident or explicit constraint)
5. Generate a filename slug from the lesson title.
6. Write the memory file with proper frontmatter (see `.claude/team-memory/README.md`).
7. Append a one-liner to the corresponding `index.md`.
8. Report: path written, scope, and which agents will read it.

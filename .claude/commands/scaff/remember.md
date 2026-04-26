---
description: Manually save a team-memory entry. Usage: /scaff:remember <role> "<lesson>" [--scope local|global]
---

<!-- preflight: required -->
# Resolve $SCAFF_SRC: env var, then user-global symlink, then fail.
if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
  _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
  SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
  unset _scaff_src_link
fi
[ -d "${SCAFF_SRC:-}" ] || { printf '%s\n' 'ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run `bin/claude-symlink install` from the scaff source repo' >&2; exit 65; }
Run the preflight from `$SCAFF_SRC/.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

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

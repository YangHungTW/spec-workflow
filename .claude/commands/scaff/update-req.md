---
description: PM revises request or PRD mid-stream. Usage: /scaff:update-req <slug>
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

1. Ask user what changed and why.
2. Invoke **scaff-pm** subagent in update mode. PM edits `00-request.md` and/or `03-prd.md`, tagging changed lines `[CHANGED YYYY-MM-DD]`.
3. PM prepends `> ⚠ STALE since <date> — PRD changed, re-run <command>` to every downstream artifact that exists.
4. Log change to STATUS Notes.
5. Do NOT auto re-run downstream stages.

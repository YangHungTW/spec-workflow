---
description: TPM produces implementation plan. Usage: /scaff:plan <slug>
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

1. Read STATUS. Require `03-prd.md` AND `04-tech.md` exist.
2. Invoke **scaff-tpm** subagent for plan mode → writes `05-plan.md`.
   - `05-plan.md` is the single merged file containing both the narrative plan (wave schedule, risks, sequencing rationale) and the task checklist (task blocks with `- [ ]` checkboxes).
   - See `tpm.md` for authoring detail and task-block format.
3. Update STATUS: check `[x] plan`.
4. Next: `/scaff:implement <slug>` (reads task checklist from `05-plan.md`).

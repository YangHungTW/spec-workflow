---
name: Shell alias intercepts rm — use /bin/rm for unattended deletes
description: `rm` is commonly aliased to `rm -i` or prompted interactively; in unattended hooks or orchestrator scripts, call `/bin/rm` by absolute path to bypass aliasing.
type: feedback
created: 2026-04-20
updated: 2026-04-20
---

## Rule

In unattended scripts, hooks, and orchestrator flows (anything that runs without a human to answer prompts), call `rm` by absolute path: `/bin/rm -f <path>`, not bare `rm`. Shell aliases (`alias rm='rm -i'`) or safe-rm wrappers may intercept bare `rm` and hang the script on a confirmation prompt the orchestrator cannot answer.

## Why

Observed in 20260420-tier-model validate-cycle: the orchestrator ran `rm 06-tasks.md` to delete a bootstrap symlink as part of migrating to the new-shape stage checklist. The command prompted for confirmation (`rm: remove symbolic link '06-tasks.md'?`) and never returned because the user's shell had an interactive `rm` alias in scope. A prior STATUS Notes line claimed the symlink was removed when in fact it wasn't — a drift between reported state and filesystem state that only surfaced during qa-analyst gap-check.

Fix: re-ran with `/bin/rm -f 06-tasks.md`, confirmed removal, backfilled STATUS Notes.

The failure mode is: bash alias is user-config dependent, varies by machine, and doesn't apply inside non-interactive subshells EXCEPT where the calling shell explicitly enables alias expansion (`shopt -s expand_aliases`, sourced profile) — which orchestrator agents sometimes do. Defensive programming is cheaper than per-machine debugging.

## How to apply

1. **In scripts that delete files non-interactively, use `/bin/rm -f`**. The `-f` suppresses non-existence errors; `/bin/rm` bypasses alias lookup.
2. **Same discipline for `/bin/mv`, `/bin/cp`, `/bin/ln`** in orchestrator scripts when user shells commonly alias them.
3. **Do not set STATUS Notes "done" until the post-action `ls` confirms the mutation**. Report state based on filesystem observation, not command exit code.
4. **In tests**, use `command rm -f` as an alternative to `/bin/rm -f` — `command` bypasses alias and function lookup, and is POSIX-portable.

## Example

Bad (observed during 20260420-tier-model validate):

```bash
rm 06-tasks.md                              # hangs on alias prompt
echo "2026-04-20 orchestrator — symlink removed" >> STATUS.md   # reports state that didn't happen
```

Good:

```bash
/bin/rm -f 06-tasks.md
[ -e 06-tasks.md ] && { echo "FAIL: still present" >&2; exit 1; }
echo "2026-04-20 orchestrator — symlink removed" >> STATUS.md
```

Cross-reference: `.claude/rules/common/no-force-on-user-paths.md` covers the overall "no silent clobber" discipline; this memory is the narrower tool-path angle.

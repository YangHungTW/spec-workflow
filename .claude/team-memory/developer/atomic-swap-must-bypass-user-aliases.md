---
name: Atomic-swap shell helpers must bypass user cp/mv aliases
description: bash atomic-swap (cp .bak; sed > tmp; mv tmp file) silently fails on shells with cp -i / mv -i aliases — the interactive prompt sees no stdin and declines the overwrite, but adjacent printf >> appends still land, producing inconsistent state. Use `command cp` / `command mv` (or rewrite in Python with os.replace) for any repo-shipped script.
type: feedback
created: 2026-04-27
updated: 2026-04-27
---

## Rule

Repo-shipped bash scripts that perform atomic swap (`cp original .bak; <transform> > tmp; mv tmp original`) MUST invoke `cp` and `mv` via the `command` builtin (`command cp ...`, `command mv ...`), or shell out to a Python `os.replace` wrapper, to bypass any user-side `cp -i` / `mv -i` aliases that would prompt for confirmation, see no stdin, and silently decline the overwrite.

## Why

A common interactive shell setup aliases `cp='cp -i'` and `mv='mv -i'` to guard against accidental clobbers. When a non-interactive script (driven by Claude Code's Bash tool, a CI runner, or any pipeline without a controlling TTY) shells out to `cp` or `mv`, the prompt is emitted to stderr and the answer slot reads as empty → "not overwritten" → the script silently continues with a return code that often looks like success.

If the script ALSO has a non-aliased side-effect step (`printf '...' >> $status_file`, `echo ... | tee -a ...`), those steps DO land. The result: an inconsistent state — the audit/log line claims a mutation happened, but the mutation itself didn't. Fixing the ledger to match the missed mutation requires manual intervention.

This bit `bin/scaff-tier set_tier` during `20260426-fix-install-hook-wrong-path` archive: tier was supposed to upgrade tiny→standard via `cp ... .bak; sed > .tmp.$$; mv .tmp.$$ STATUS.md`, but `cp -i` and `mv -i` declined both prompts. The function exited 0, yet the `tier:` line was unchanged while the audit Notes line ("orchestrator — tier upgrade tiny→standard") was already appended via `printf >>`.

## How to apply

1. **In repo-shipped bash scripts** (bin/, hooks/, helpers under .claude/), wrap any `cp`/`mv` in a function or use `command` directly:

   ```bash
   # Bad (subject to user alias):
   cp "$file" "$file.bak"
   mv "$tmp" "$file"

   # Good:
   command cp "$file" "$file.bak"
   command mv "$tmp" "$file"
   ```

2. **For atomic swap specifically**, prefer a Python one-liner via `python3 -c` so the swap inherits Python's `os.replace` semantics (cross-fs atomic on POSIX, no shell layer):

   ```bash
   python3 - <<PY
   import os, shutil
   shutil.copyfile("${file}", "${file}.bak")
   os.replace("${tmp}", "${file}")
   PY
   ```

3. **Tests**: when verifying scripts that do atomic swap, run them with `cp` and `mv` aliased to `cp -i` and `mv -i` in the test harness's shell. The bug surfaces only under interactive-alias conditions; default `bash` test runs miss it.

## Cross-reference

- `.claude/rules/common/no-force-on-user-paths.md` — the rule that motivates atomic swap with backup. This memory is the portability addendum: HOW to do the swap reliably across user shells.
- `.claude/rules/bash/bash-32-portability.md` — same family (BSD vs GNU). The `command` prefix discipline is portability-class.

## Source

`20260426-fix-install-hook-wrong-path` archive step: `bin/scaff-tier set_tier` invocation silently produced inconsistent STATUS state (tier unchanged + audit line written) on a shell with `cp -i` / `mv -i` aliases. Manual recovery via `Edit` + `command rm` of the orphan `.STATUS.md.tmp.$$`. The fix to scaff-tier itself is a follow-up chore — see archive STATUS Notes for the trail.

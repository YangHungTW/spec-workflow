---
description: Execute the next wave of tasks in parallel via worktrees. Usage: /YHTW:implement <slug> [--task T<n>] [--serial]
---

Wave-based parallel execution. Each task in the current wave runs in its own git worktree under `.worktrees/<slug>-T<n>/` so developer agents can't collide.

## Steps

1. Read `06-tasks.md`. Parse the **Tasks** list and **Wave schedule**.
2. **Select target**:
   - `--task T<n>` → run only that task (debugging / retry).
   - `--serial` → run the next unchecked task serially in main repo (fallback if worktree isn't usable).
   - Default: determine the **current wave** = the first wave whose tasks are all either checked or in the unchecked set with all deps satisfied. Run every unchecked task in that wave in parallel.
3. **Pre-flight**:
   - Verify we're in a git repo. If not, warn and fall back to `--serial` in main working tree.
   - Verify feature branch exists: `<slug>`. If not, create it from current HEAD: `git checkout -b <slug>`.
   - Confirm no uncommitted changes (worktree creation is safe but developer agents need a clean slate).
4. **Spawn parallel developers**:
   - For each task T<n> in the wave:
     - `git worktree add .worktrees/<slug>-T<n> -b <slug>/T<n> <slug>` (branches from current feature head)
     - Invoke **YHTW-developer** subagent with parameters:
       - `WORKTREE=.worktrees/<slug>-T<n>` (absolute path preferred)
       - `TASK_ID=T<n>`
       - `SLUG=<slug>`
     - All developer invocations go in **one message with multiple Agent tool calls** so they run concurrently.
5. **Wave collection** (after all developers return):
   - `git checkout <slug>`
   - For each completed task in merge-any-order:
     - `git merge --no-ff <slug>/T<n> -m "Merge T<n>: <title>"`
     - If merge conflicts: stop, surface the conflict, ask user — conflicts mean TPM's parallel-safety analysis was wrong. Suggest `/YHTW:update-task` to revise wave schedule.
     - `git worktree remove .worktrees/<slug>-T<n>`
     - `git branch -d <slug>/T<n>`
6. **Status update (orchestrator, not developers)**:
   - In the main working tree, edit `.spec-workflow/features/<slug>/06-tasks.md` to check `[x]` for every task that just completed.
   - Append to `STATUS.md` Notes: `YYYY-MM-DD implement wave <N> done — T<a>, T<b>, T<c>`.
   - `git add -A && git commit -m "wave <N>: check off completed tasks"`.
7. Report: wave completed, task count, next wave preview. If all waves done, check `[x] implement` in STATUS and tell user next is `/YHTW:next <slug>` (→ gap-check).

## Failures

- One developer fails → keep the others' worktrees; report which succeeded. User can retry the failed task with `/YHTW:implement <slug> --task T<n>` after fixing the cause.
- Merge conflict → surface the conflicting files; do NOT auto-resolve. Escalate to TPM for wave-schedule revision.

## Rules
- Never skip `Parallel-safe-with:` constraints — if TPM said they can't run together, they can't, even if user forces it.
- Never run two waves concurrently — wave N+1 depends on wave N's merge state.
- Clean up worktrees even on failure. Never leave orphan `.worktrees/<slug>-T<n>/` around.
- Add `.worktrees/` to `.gitignore` if not already.

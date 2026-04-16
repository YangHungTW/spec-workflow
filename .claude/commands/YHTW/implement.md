---
description: Run all remaining waves in parallel until done or blocked. Usage: /YHTW:implement <slug> [--one-wave] [--task T<n>] [--serial]
---

Wave-based parallel execution. Default behaviour: run **every remaining wave** end-to-end, stopping only on task failure, merge conflict, or user interrupt. TPM's dependency graph is the plan — no reason to pause between healthy waves.

## Steps

1. Read `06-tasks.md`. Parse the **Tasks** list and **Wave schedule**.
2. **Select mode**:
   - `--task T<n>` → run only that task (debug / retry single task in its own worktree).
   - `--serial` → run the next unchecked task serially in the main working tree (fallback if worktrees aren't usable).
   - `--one-wave` → run just the next wave, then stop and report.
   - Default: loop waves until all tasks done or something stops us.
3. **Pre-flight** (once, before the loop):
   - Verify git repo. If not, fall back to `--serial`.
   - Ensure feature branch `<slug>` exists; create from current HEAD if missing.
   - Confirm clean working tree.
   - Ensure `.worktrees/` is in `.gitignore`.

## Per-wave loop

4. Identify the **current wave** = first wave whose tasks are all either checked OR unchecked-with-all-deps-checked.
5. **Spawn parallel developers**:
   - For each task T<n> in the wave:
     - `git worktree add .worktrees/<slug>-T<n> -b <slug>-T<n> <slug>` (note branch name: `<slug>-T<n>`, flat — **not** `<slug>/T<n>`, which collides with the `<slug>` leaf ref)
     - Invoke **YHTW-developer** subagent with parameters `WORKTREE`, `TASK_ID`, `SLUG`.
     - All developer invocations in **one message with multiple Agent tool calls** → concurrent execution.
6. **Wave collection** (after all developers return):
   - `git checkout <slug>`
   - For each completed task (any order):
     - `git merge --no-ff <slug>-T<n> -m "Merge T<n>: <title>"`
     - On conflict: STOP the whole loop. Surface conflicting files. TPM's parallel-safety analysis was wrong → recommend `/YHTW:update-task`.
     - `git worktree remove .worktrees/<slug>-T<n>`
     - `git branch -d <slug>-T<n>`
7. **Status update** (orchestrator):
   - In main tree, check off `[x]` for every completed task in `06-tasks.md`.
   - Append STATUS Notes: `YYYY-MM-DD implement wave <N> done — T<a>, T<b>, …`.
   - Commit: `wave <N>: check off completed tasks`.
8. **Continue or stop**:
   - If `--one-wave` → stop. Report current state + preview next wave.
   - If any task failed or merge conflicted → stop. Report failure + recovery command.
   - Else if more waves remain → loop to step 4 for the next wave.
   - Else all done → check `[x] implement` in STATUS, commit, tell user next is `/YHTW:next <slug>`.

## Failures

- **One developer fails** → stop the wave loop immediately (other completed tasks in this wave still merged). Report which task failed + how to retry: `/YHTW:implement <slug> --task T<n>`.
- **Merge conflict** → stop. Conflicts during a wave = TPM's parallel-safety analysis was wrong. Don't auto-resolve.
- **Interrupted mid-wave** → clean up any hanging worktrees before exiting.

## Rules
- Never skip `Parallel-safe-with:` constraints.
- Never run two waves concurrently — wave N+1 depends on wave N's merged state.
- Clean up worktrees even on failure. No orphan `.worktrees/<slug>-T<n>/`.
- Branch naming: **flat** `<slug>-T<n>` to avoid colliding with the feature branch `<slug>` leaf ref.

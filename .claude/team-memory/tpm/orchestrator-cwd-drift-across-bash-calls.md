## Rule

Every merge / branch-state bash call the orchestrator issues must use absolute paths or an explicit `cd "$REPO_ROOT"` prefix; never trust that cwd is the main worktree after any earlier `cd .worktrees/<task>`.

## Why

In the rename-to-specaffold feature (2026-04-21), a `cd .worktrees/20260421-rename-to-specaffold-T20` issued for a single typo-fix amendment persisted across ten following bash calls. Ten W3 batch-1 merges ran on branch `20260421-rename-to-specaffold-T20` instead of main. Recovered via `git merge --ff-only` from main, but the near-miss would have been silent on a non-ff repo or on branches with divergent history.

## How to apply

1. Prefix merge-loop bash calls with `cd "$REPO_ROOT" &&` or use `git -C "$REPO_ROOT" merge …` — never rely on inherited cwd.
2. After any worktree-local edit (e.g. `sed -i '' ...` on a `.worktrees/<task>/...` file), emit an explicit `cd "$REPO_ROOT"` before the next non-worktree call.
3. Treat persistent-cwd assumptions as a hazard on par with persistent-env-var assumptions: never mix single-shot bash calls with compound commands that include an enduring `cd`.
4. When doing a sequence of git operations against different trees, prefer `git -C <path>` argv form over `cd <path> && git ...` to keep each call explicit.

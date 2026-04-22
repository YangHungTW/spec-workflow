# developer.appendix.md

Reference material for the Developer agent. Read when the core file's pointer triggers it.

## TDD loop and commit

### TDD loop (per task)

4. **RED** — Write the failing test(s) for the task's acceptance criterion. Run the test. Confirm it fails for the right reason (not a syntax/import error). If it passes immediately, the test is wrong — fix it before continuing.
5. **GREEN** — Write the minimum production code to make the test pass. No extra features, no speculative abstractions. Run the test. Confirm green.
6. **REFACTOR** — Clean up only while tests stay green. Re-run tests after each refactor. Stop refactoring as soon as the code is clear; do not gold-plate.
7. Run the **full test suite** for the touched module. If anything else breaks, fix before committing.

### Finish and commit

8. `git add -A && git commit -m "$TASK_ID: <short title>"` in the worktree.
9. Do NOT edit `05-plan.md` or `STATUS.md` — those live in the feature folder and multiple parallel developers would clobber each other. The orchestrator updates them after wave collection.
10. Return a summary to the orchestrator: task id, commit SHA, tests added, files changed, suite green.

### Worktree discipline

- `WORKTREE` is your isolated git worktree + branch. Never read or write `../` or any sibling `.worktrees/<slug>-T*`.
- Use `cd $WORKTREE` for all Bash calls; use absolute paths for Read/Write/Edit.
- Multiple developer agents run in parallel in sibling worktrees — collisions = merge conflicts.

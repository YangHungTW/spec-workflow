---
name: Confirm a "regression" is actually yours before claiming it
description: Before reporting an adjacent test failure as caused by your task, stash your changes and re-run on the parent commit; pre-existing failures must be surfaced as STATUS notes, not flagged as regressions.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When an adjacent test (not the one your task ships) fails during developer self-verify, run it once more with your changes stashed (or against the parent commit SHA in a worktree) before claiming or denying responsibility. If it fails on the parent commit too, it is pre-existing — record one STATUS Notes line naming the test, the parent SHA, and the failure mode; do NOT extend your task scope to fix it.

## Why

Conflating a pre-existing failure with one you introduced wastes Developer cycles on speculative debugging and can spook the reviewer into BLOCK-ing a task whose diff is innocent. It also lets a real pre-existing breakage stay unnoticed because everyone assumes "the new feature broke it." The check is cheap (~10 seconds) and the cost of getting it wrong is large.

## How to apply

1. On any unexpected adjacent-test failure during self-verify, run one of:
   - `git stash && bash test/<failing>.sh; git stash pop` — when the failure is on staged or working-tree changes.
   - `git worktree add /tmp/baseline <parent-SHA> && bash /tmp/baseline/test/<failing>.sh; git worktree remove /tmp/baseline --force` — when the failure shape depends on multi-file state your stash can't isolate.
2. If it fails clean on the parent: STATUS Notes line `<test> pre-existing failure on <SHA>; not in T<N> scope`. Do NOT extend the task scope.
3. Cross-reference the failure to a future chore via `/scaff:chore` if it warrants its own followup; the chore's parent-archive reference is the parent commit SHA.
4. If it passes on the parent but fails on your branch: yes, it is your regression — fix in the current task.

## Example

This feature (`20260426-chore-seed-copies-settings`): t114 (the new test) passed; t112 failed during developer self-verify. The developer ran `git worktree add /tmp/baseline c0fd5f5 && bash /tmp/baseline/test/t112_init_seeds_preflight_files.sh` and confirmed t112 was already broken on the parent commit (`.specaffold/preflight.md not present after scaff-seed init`). STATUS line at validate noted "t112 was pre-existing failure on parent commit c0fd5f5 (verified by orchestrator); not a T1 finding". Reviewer / qa-tester accepted the classification cleanly; no scope creep on T1.

Source: 08-validate.md tester axis + STATUS.md Notes line "Note: t112 was not run per the constraint that it was already failing before this feature landed" (this feature, archived as `20260426-chore-seed-copies-settings`).

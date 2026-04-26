---
name: status-notes-collide-with-orchestrator-on-worktree-branch
description: Append-collision between orchestrator dispatch lines on the parent feature branch and Developer task notes on a worktree branch produces a merge conflict on STATUS.md with no semantic disagreement; treat STATUS.md as orchestrator-owned and surface task notes via the commit-message body instead.
type: gotcha
created: 2026-04-26
updated: 2026-04-26
---

## Rule

Do not append to `STATUS.md` Notes from inside a worktree branch during a task. The orchestrator appends `review dispatched` and `wave done` lines to STATUS.md on the parent feature branch concurrently with the task; both writers append to the same trailing region, so `git merge --no-ff` produces a textual conflict with no semantic disagreement. Surface task-level observations through the commit message body or via `/scaff:update-task` instead. The orchestrator backfills a Developer Notes line at wave bookkeeping time — that is the contract.

## Why

Observed in `20260426-chore-scaff-plan-chore-aware` T2 merge: Developer authored a STATUS Notes line on the worktree branch describing the T2 changes; orchestrator independently appended a `review dispatched` line on the parent branch. Both lines target the trailing region of STATUS.md `## Notes`, so `git merge --no-ff` produced a conflict that took manual resolution (kept both). No content disagreed; the conflict was purely positional. The append-collision class is structural — every parallel-safe wave amplifies it because each task's worktree races the orchestrator's dispatch line.

Cross-reference: `shared/status-notes-rule-requires-enforcement-not-just-documentation.md` documents the broader STATUS-Notes drift class; this entry adds the worktree-vs-parent collision sub-pattern. Companion entry: `orchestrator/status-notes-append-collision-defer-dispatch-log.md` covers the orchestrator-side fix (defer the dispatch log to post-merge).

## How to apply

1. **Default**: do NOT touch STATUS.md from a worktree branch. The orchestrator owns the file during the wave; developers log task-level context via commit message body.
2. **If a Notes line is genuinely necessary** (e.g. the task involved a non-obvious decision the validate axes need to read): commit it as a SEPARATE commit at the very top of the worktree, on a line clearly marked `[Developer note]`, and inform the orchestrator in the task return so the orchestrator merges it before its own appending.
3. **At merge conflict on STATUS.md trailing region only**: the resolution is keep-both (in chronological-or-as-found order) — both lines are typically correct; the conflict is positional, not semantic. Log the resolution via STATUS Notes after merge.
4. **Do not** rebase or amend to "win" the position; both lines are part of the audit trail.

## Example

Conflict in `20260426-chore-scaff-plan-chore-aware` T2 merge — Developer wrote:

```
- 2026-04-26 Developer — T2: generalised next.md matrix-skip suffix wording; ...
```

on the worktree branch. Orchestrator concurrently wrote on parent:

```
- 2026-04-26 review dispatched — slug=... wave=2 tasks=T2 axes=...
```

Both lines append to `## Notes`. `git merge --no-ff` flagged the trailing region. Resolution: kept both in chronological order; STATUS Notes recorded the collision and root cause.

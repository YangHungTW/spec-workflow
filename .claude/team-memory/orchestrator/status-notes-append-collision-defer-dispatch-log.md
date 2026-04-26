---
name: status-notes-append-collision-defer-dispatch-log
description: Orchestrator appending `review dispatched` lines to STATUS.md on the parent feature branch concurrently with a Developer worktree races the worktree's own STATUS.md edits at merge; defer the dispatch log to one commit AFTER the wave merge so the Notes file has a single writer per wave-window.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When dispatching a task to a worktree under inline review, the orchestrator should NOT write a `review dispatched` Notes line to STATUS.md on the parent branch while the worktree commit is in flight. Instead: dispatch first, await task completion, merge, and log the dispatch + outcome together in the post-merge bookkeeping commit. This collapses the two-writer window so STATUS.md has a single writer per wave-step.

## Why

In `20260426-chore-scaff-plan-chore-aware` T2 (single-task wave, not even a parallel wave), `git merge --no-ff` of the worktree onto the parent branch flagged a textual conflict on the STATUS.md trailing region. Cause: orchestrator had appended a `review dispatched` line at dispatch time; Developer had appended a task-completion line on the worktree branch (covered by `developer/status-notes-collide-with-orchestrator-on-worktree-branch.md`). Both targeted the same trailing region with no semantic disagreement.

The fix is one-sided: orchestrator can defer the dispatch log without losing audit-trail value, because the bookkeeping commit lands within seconds of merge anyway. Asking developers to never touch STATUS.md is a different rule (covered by the developer-side memory) but is not sufficient on its own — sub-agents will occasionally write Notes lines despite the rule, and the orchestrator's own discipline should not depend on developer compliance.

## How to apply

1. **Defer the dispatch log**: at task dispatch time, do NOT commit a `review dispatched — slug=... wave=N tasks=...` line to STATUS.md. Hold it in memory.
2. **Combine into bookkeeping**: at the post-merge bookkeeping commit, write the dispatch line and any wave-outcome lines together in a single STATUS.md edit on the parent branch. STATUS.md now has one writer per wave-window (the orchestrator post-merge), which eliminates the append race.
3. **Trade-off acknowledged**: if the dispatch step crashes mid-flight before the bookkeeping commit, the dispatch is unrecorded in STATUS.md until manual recovery. Mitigation: the orchestrator's own session log + `git reflog` carries the dispatch event; STATUS.md is a digest, not the primary audit trail.
4. **Applies to all inline-review waves** (R16 default for tier=standard / audited), single-task or N-task — the collision class is structural, not parallel-width-dependent.

## Example

T2 of `20260426-chore-scaff-plan-chore-aware` merge produced a STATUS.md trailing-region conflict despite being a single-task wave. Orchestrator's dispatch line on parent:

```
- 2026-04-26 review dispatched — slug=20260426-chore-scaff-plan-chore-aware wave=2 tasks=T2 axes=security,performance,style
```

Developer's task line on worktree:

```
- 2026-04-26 Developer — T2: generalised next.md matrix-skip suffix wording; ...
```

Both lines correct; collision was positional. Had the orchestrator deferred its dispatch line to the bookkeeping commit, the merge would have been clean and the bookkeeping commit would have written both lines (chronologically: dispatch first, then Developer note) in one edit.

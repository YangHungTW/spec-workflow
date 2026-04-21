---
name: Pre-checked `[x]` boxes without commits are a plan-drift anti-pattern
description: TPM must never write `[x]` at plan-authoring time; unflip pass must leave 100% `[ ]` boxes; orchestrator's per-wave bookkeeping is the sole `[x]` writer.
type: feedback
created: 2026-04-21
updated: 2026-04-21
---

## Rule

When authoring 05-plan.md's task list, every task checkbox MUST land as `- [ ]` (unchecked). The TPM is forbidden from writing `- [x]` even on tasks that appear "obviously already done from inspection" (e.g. a doc-touch task whose deliverable is trivially present in the starting tree). The unflip-all pass that corrects pre-checked boxes at plan-finalisation must leave the file at 100% unchecked. The `[x]` writer is the per-wave bookkeeping commit, never the plan-authoring commit.

## Why

`20260420-flow-monitor-control-plane` saw two related drift events:

1. Commit `a268d2f` was a "B2 plan: unflip spurious [x] on all 30 tasks (TPM wrote pre-checked)" — the original plan-authoring commit (`2f80937`) shipped with checkboxes already marked `[x]`, which required an explicit unflip pass.
2. Despite the unflip pass, commit trail at W5a shows T112a and T112b had `[x]` in 05-plan.md §3 at a moment when no real task commits existed for them (STATUS 2026-04-21 noted "plan drift: T112a and T112b marked [x] … but no commits"). The `[x]` marks survived the unflip because the unflip was a global sweep, but somewhere between unflip and W5a dispatch those two boxes were re-ticked by an unknown writer (likely a stale orchestrator read or a manual human edit).

The `checkbox-lost-in-parallel-merge` memory covers the parallel-merge class. This is a distinct class: the TPM (or a human editor) manually `[x]`-ing a box outside the orchestrator's per-wave bookkeeping discipline. The symptom is indistinguishable from merge loss at archive inspection, but the root cause is authoring-time leakage, not merge-time loss.

## How to apply

1. TPM plan-authoring commits MUST grep themselves before push: `grep -c '^- \[x\]' 05-plan.md` and `grep -c '^## T[0-9]*.*\[x\]' 05-plan.md` both return 0. Any non-zero count is a pre-check bug; fix in the same commit, do not push.
2. When hand-editing 05-plan.md between plan and implement stages (e.g. to fix a typo or correct a scope line), the editor MUST NOT flip any checkbox. If a flip is needed (e.g. to record a task done out-of-band), the edit must go through `/specflow:update-plan` with an explicit rationale, not a free-form text edit.
3. Orchestrator's per-wave bookkeeping commit is the sole authorised `[x]`-writer. A reviewer-axis check could enforce: "any commit that flips an `[x]` in 05-plan.md must have 'wave W{n}' in its subject line or task-archive context".
4. When the post-wave audit discovers an `[x]` on a task without a corresponding task-implementation commit, the orchestrator must STOP and investigate before flipping further. In this feature the drift was resolved by the real W5a commits landing and overwriting the spurious state, but that only worked because W5a was about to run; if a drifted `[x]` lands on a task that is not being worked this wave, it would silently propagate to archive.

## Example

The chain in this feature:
- `2f80937` authored plan with `[x]` on all 30 tasks (TPM bug).
- `a268d2f` unflipped all 30 boxes (orchestrator fix).
- Sometime between `a268d2f` and W5a dispatch, T112a + T112b boxes were re-ticked (source unclear from git log).
- STATUS drift note 2026-04-21 flagged the mismatch.
- W5a real commits (`0021573`, `27f09f8`) landed and re-cemented the `[x]` state with real task work behind them — accidentally "resolved" the drift without root-cause investigation.

Lesson: the resolve-by-accident outcome only worked because W5a was the next wave. Treat pre-checked boxes as a first-class defect class, not a cosmetic issue.

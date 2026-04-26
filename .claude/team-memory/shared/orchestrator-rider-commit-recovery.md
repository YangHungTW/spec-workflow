---
name: Rider-commit recovery — when an orchestrator commits to the wrong parallel branch
description: When an orchestrator accidentally commits to a parallel feature's branch (common with multi-terminal sessions sharing one checkout), do NOT cherry-pick or reset; let the errant commit ride forward as part of that branch's history, and annotate the merge commit "(carries <other-feature> commits as riders)" so both branches' work lands on main without history rewrite.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When an orchestrator session accidentally commits to a branch other than the intended one — typically because a parallel terminal switched the shared checkout to a different feature's branch — do NOT attempt to fix the history with `git cherry-pick` and `git reset --hard`. Instead:

1. Treat the errant commit as part of whatever branch it landed on.
2. When that branch is merged forward (to its parent feature's tip or to main), annotate the merge commit with a parenthetical `(carries <other-feature> commits as riders)` line in the title.
3. The errant commit's content lands on main alongside the host branch's work, no history rewrite required.

## Why

Multi-terminal sessions on a single checkout are common (orchestrator + user + parallel agent in their own terminals). Branch state in a shared checkout is whoever-touched-last. When the orchestrator runs `git commit` after another terminal switched branches, the commit lands wherever HEAD currently points — not where the orchestrator's plan said.

The instinct is to fix the history: cherry-pick the errant commit onto the correct branch, reset the host branch back to before. This is destructive (`git reset --hard` drops the errant commit + any subsequent commits on top of it) and high-coordination — both terminals must pause to align on the recovery, and any work done on top of the errant commit must be preserved separately.

The riders pattern avoids all of that:
- The errant commit's content (typically self-contained: a STATUS update, a doc edit) is harmless on the host branch — it doesn't conflict with anything.
- The host branch's other work continues unaffected, layered on top.
- At merge time, the merge commit's title carries the "(carries X commits as riders)" annotation so future readers searching commit history can find the context.
- Both feature branches' work reaches main; no commit is dropped or duplicated.

Source: `20260426-fix-init-missing-preflight-files` validate-stage commit `6cf2b76` accidentally landed on the parallel `20260426-flow-monitor-graph-view` branch (shared checkout was switched between commits without orchestrator noticing). The other terminal's session noticed at merge time, used the riders pattern in `bc24d7a`: `Merge feature 20260426-flow-monitor-graph-view (carries 20260426-fix-init-missing-preflight-files commits as riders)`. Both branches' work landed on main cleanly.

## How to apply

1. **At commit time** — the orchestrator should sanity-check the current branch BEFORE committing on parallel-session work:
   ```bash
   if [ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]; then
     printf 'WARN: HEAD is on %s, not %s — refusing commit\n' "$(git branch --show-current)" "$EXPECTED_BRANCH" >&2
     exit 1
   fi
   ```
   This is the prevention layer. When the check fails the orchestrator stops and surfaces to the user instead of silently committing to the wrong branch.

2. **When the prevention layer wasn't in place and the errant commit happened** — diagnose, don't panic:
   - `git log --oneline <errant-branch> | head` — confirm the errant commit is at the tip and any subsequent commits depend on it.
   - `git log --oneline <intended-branch> | head` — confirm the intended branch is missing the work.
   - Check whether the errant commit's content is harmful on the host branch (most STATUS / doc commits are not).

3. **If the content is harmless on the host branch** (most cases): take no immediate action. Note the discrepancy in STATUS Notes:
   ```
   YYYY-MM-DD orchestrator — validate commit <sha> landed on <wrong-branch> (parallel terminal switched checkout); will ride forward to main via merge annotation
   ```
   Continue the host branch's work normally. At merge time, annotate the merge commit:
   ```
   Merge feature <slug> (carries <other-slug> commits as riders)
   ```

4. **If the content IS harmful on the host branch** (rare — e.g. it modifies a file the host branch is also editing, creating conflict surface): then a cherry-pick + revert IS warranted. Cherry-pick onto the intended branch first, then `git revert <sha>` on the host branch (a non-destructive revert commit, not a `reset --hard`). This leaves history intact but neutralises the errant content on the host.

5. **Never `git reset --hard`** on a branch shared with another active session — even if the reset only drops "your" commit, the other session may have committed work on top in the meantime, and reset destroys that.

## Example

**The recovery on `20260426-fix-init-missing-preflight-files`** (verbatim from session):

The orchestrator committed `6cf2b76 validate: 08-validate.md verdict NITS` while HEAD was on `20260426-flow-monitor-graph-view` (a parallel terminal had switched the checkout). The orchestrator noticed at the next `git log` and proposed two recovery paths to the user: (a) cherry-pick + reset (destructive) or (b) cherry-pick + revert (non-destructive). The user chose to defer until the parallel session completed.

The parallel session, on its side, noticed `6cf2b76` sitting at its branch tip while continuing wave 5 work. Rather than ask the orchestrator to clean up, it kept layering its own work on top (`824f1de`, `e46700f`, `fa5768e`). When merging to main, it titled the merge commit:

```
Merge feature 20260426-flow-monitor-graph-view (carries 20260426-fix-init-missing-preflight-files commits as riders)
```

The merge brought BOTH branches' work to main in one commit. No cherry-pick, no reset, no history rewrite. The orchestrator on its side resumed by running `/scaff:archive` on the bug feature directly (its work was already on main via the riders ride).

The decision-cost saved: ~3 confirm-prompt rounds + ~10 minutes of back-and-forth to coordinate a destructive reset.

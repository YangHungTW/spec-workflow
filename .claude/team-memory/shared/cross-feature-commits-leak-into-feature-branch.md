---
name: Cross-feature commits leak into a feature branch — detect at validate / archive
description: Feature branches occasionally accumulate commits and files belonging to a *different* feature when a developer worktree is reused or a `git rebase` picks up unrelated work. Pre-archive should diff branch deliverables against the plan's declared scope.
type: feedback
created: 2026-04-26
updated: 2026-04-26
source: 20260426-flow-monitor-graph-view
---

## Rule

Feature branches occasionally accumulate commits and files belonging to a
**different** feature — typically when a developer worktree is reused, when
a `git rebase` picks up unrelated work, or when parallel sibling features
are developed in the same workspace. Pre-archive (or pre-merge) should
diff the branch's touched-file list against the feature's plan-declared
scope and require explicit acknowledgement of any extras.

## Why

Cross-feature leakage:

- Inflates the blast radius of the merge-to-main step (one feature's
  branch silently lands two features' code).
- Confuses retrospective scoping (which lessons trace to which feature?).
- Pollutes archive history (the archived feature folder describes feature
  A, but the merged code includes work from feature B).
- Can land work that was never reviewed under the right feature's review
  axes (e.g. a security-axis review focused on feature A's surface won't
  catch issues introduced by feature B's untracked code).

## How to apply

**Detection** — at validate-time or pre-archive, run:

```sh
# Files touched by this branch
git diff --name-only main..HEAD | sort -u > /tmp/branch-files

# Files declared in plan deliverables
grep -E '^[[:space:]]+- Files:' "$FEATURE_DIR/05-plan.md" \
  | sed 's/.*Files:[[:space:]]*//' \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[`(].*//' \
  | sort -u > /tmp/plan-files

# Any branch file not in plan?
comm -23 /tmp/branch-files /tmp/plan-files
```

Any file in the branch but not declared in the plan is suspect.
Mitigation paths:

1. **Fold into plan via `/scaff:update-task`** — the file is legit work
   for *this* feature that the plan didn't anticipate; record it.
2. **Revert the cross-feature commits** — `git revert <sha>` if the
   commits clearly belong to a sibling feature; ideally those should be
   on their own branch.
3. **Acknowledge and merge anyway** — accept the leakage with an explicit
   STATUS Notes line so the retrospective can name it (e.g. "branch
   carries riders from <other-feature-slug>; merging together because
   …").

## Example

Surfaced in `20260426-flow-monitor-graph-view` validate as F4:

The branch contained commits and files from a separate feature
`20260426-fix-init-missing-preflight-files`:

- `bin/scaff-seed` — new helper from the bug-fix feature
- `test/t112_init_seeds_preflight_files.sh` — its regression test
- `.specaffold/features/20260426-fix-init-missing-preflight-files/{05-plan.md,08-validate.md,STATUS.md}`

Commits identified by trace:

```
077b24d T1: bin/scaff-seed — plan_copy preflight.md + emit_default_config_yml helper
1dcbb30 T2: test/t112_init_seeds_preflight_files.sh — regression cover AC1-AC7
b1a6d40 fixup W1: t112 — match actual scaff-seed emit format
6cf2b76 validate: 08-validate.md verdict NITS — emit_default_config_yml helper good
```

These got into the branch via parallel worktree reuse during the
flow-monitor-graph-view implement loop. The user chose option 3
(acknowledge and merge together) at archive time; the merge commit
explicitly notes the riders.

The pre-archive grep above would have surfaced this earlier — at validate
time — giving the user a clearer choice between (1) folding into plan,
(2) reverting, or (3) accepting riders, rather than discovering it
mid-archive.

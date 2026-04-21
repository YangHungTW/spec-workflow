---
name: Pre-declare test filenames in 06-tasks.md (or 05-plan.md) to prevent same-wave collisions
description: When multiple tasks in the same wave author test files, pre-declare the exact filename per task in the Files: field; otherwise developers pick ambiguous or colliding names that fail merge.
type: pattern
created: 2026-04-20
updated: 2026-04-20
---

## Rule

When two or more tasks in the same wave author test files — even when the tests cover different functionality — the TPM MUST pre-declare the exact `test/tNN_<slug>.sh` filename in each task's `Files:` field. Do not leave the filename to developer choice. Cross-check across the wave for collisions before publishing.

## Why

Recurring pattern across 20260419-flow-monitor (W4+W5), 20260420-tier-model (W0a T4/T5, W1 T7/T8, W2 T11/T16, W3 T18–T25). Developers, left to pick a filename from the task slug, converge on similar names (`t74_*.sh`, `tN_*.sh`) and same-wave parallel branches create the same file with different contents. Merge-time the reviewer cannot tell which version is canonical; "take theirs" costs wave time and silently discards work from one branch.

Pre-declaring the filename makes the collision visible at plan review (TPM can grep the 06-tasks.md for duplicate `test/` paths before publishing) and removes developer ambiguity.

## How to apply

1. **Write explicit filenames in `Files:`**. Not `test/<new file>` or `test/tNN_*.sh` — the exact `test/t74_tier_schema_helpers.sh`, `test/t75_tier_rollout_migrate.sh`.
2. **Grep the wave for collisions before publish**: `grep -hE '^Files:' 06-tasks.md | grep test/ | sort | uniq -d` must be empty.
3. **Advance the `tNN` counter per wave** using the last-used number in `test/` + 1; never re-use a counter even if the earlier file was deleted.
4. **If a literal placeholder like `tN_` is in a task file, flag it as a planning bug** — the developer will interpret it literally (see `task-scope-fence-literal-placeholder-hazard.md`).
5. **In narrow cases where two tasks genuinely share a test file** (e.g. appending to `test/smoke.sh`), explicitly mark `Parallel-safe-with:` to serialise the tasks across sub-waves.

## Example

Bad (from 20260420-tier-model T4):

```
Files: test/<new tier rollout test>
```

Developer chose `test/t74_tier_rollout_migrate.sh` — which was also T5's designated filename. Merge collision resolved by `git checkout --theirs` on T5's branch; T4's tests were discarded.

Good:

```
# T4
Files: test/t74_tier_schema_helpers.sh

# T5
Files: test/t75_tier_rollout_migrate.sh
```

Collision impossible at wave publish time.

## When to use

Every wave with ≥2 test-authoring tasks. Cheap insurance; five minutes of TPM grep saves a wave-retry cycle.

## When NOT to use

Single-task waves, or waves where no task authors a new test file.

---
name: MERGE-NOTE consolidation claims must be their own explicit task, not plan prose
description: When a wave plan inserts MERGE-NOTE local copies of types/structs/utilities to keep tasks parallel-safe, the consolidation step must be a named task with a `Verify:` grep — not a prose aside. Plan-narrative consolidation claims silently evaporate.
type: feedback
created: 2026-04-26
updated: 2026-04-26
source: 20260426-flow-monitor-graph-view
---

## Rule

When a wave plan inserts MERGE-NOTE local copies of types/structs/utilities
to keep tasks parallel-safe, and the plan narrative says "consolidate in a
follow-up task", that consolidation must be a **named task** with a
concrete `Verify:` command — not a prose aside in the plan narrative or a
STATUS Notes line.

## Why

Plan-narrative consolidation claims silently evaporate: the developer
finishes the wave, the orchestrator merges, the next wave starts, and
nobody owns the cleanup. The MERGE-NOTE copies persist as dead-code
orphans, and worse, they may diverge from the canonical types over time —
leaving the codebase with two versions where the implementation uses one
and the canonical (defined-but-orphan) version diverges silently.

## How to apply

Any MERGE-NOTE pattern introduced by parallelisation **must** spawn an
explicit task in the same plan:

```
- [ ] T<n>: Consolidate MERGE-NOTE copies of <X> into canonical <Y>
    - Wave: W<n+1> (or later)
    - Files: <files where MERGE-NOTE local copies live>
    - Scope: delete MERGE-NOTE copies; have consumers `use crate::<canonical>`
    - Verify: `git grep -n 'MERGE-NOTE' -- '<paths>' | wc -l` returns 0
    - Depends on: T<m> (the task that merged the canonical type)
```

The `Verify:` step must be a grep that fails if any MERGE-NOTE marker
remains. The task must depend on (be sequenced after) the wave that lands
the canonical type. Never defer to "we'll clean up later" prose; never
assume the developer will remember.

## Example

Surfaced in `20260426-flow-monitor-graph-view` as F2/F3:

T1's instructions told the developer to add temporary local stubs of
`ArtifactKind`, `WatcherState`, `ArtifactChangedPayload`,
`WatcherStatusPayload` at the top of `fs_watcher.rs` with `// MERGE-NOTE:
replaced by lib.rs canonical types after T4 merges` comments. T4 added
the canonical types to `lib.rs`. The plan narrative said the MERGE-NOTE
copies would be cleaned up after T4 merged.

What actually happened:
- T4 merged. The canonical types in `lib.rs` were referenced ONLY by
  `cfg(test)` compile-gate tests.
- T1's MERGE-NOTE local copies in `fs_watcher.rs` remained the only
  versions used in production code.
- Field names diverged: lib.rs used `repo_path`/`kind` (mismatching
  D3 spec), fs_watcher.rs used `repo`/`artifact` (matching D3).
- Production wire format follows fs_watcher.rs; lib.rs is dead code with
  the "wrong" field names. If a future consolidator naively switches to
  `use crate::ArtifactChangedPayload`, the IPC wire format silently
  breaks.

Validate's analyst axis surfaced this as a `should`-level finding (F2 +
F3). Had the plan included an explicit consolidation task with a grep
`Verify:`, the gap would have been a closed task before validate ran.

```
# What the plan SHOULD have included as e.g. T19 in W3 or W4:
- [ ] T19: Consolidate fs_watcher.rs MERGE-NOTE local copies into lib.rs canonical types
    - Wave: W3
    - Files: flow-monitor/src-tauri/src/fs_watcher.rs, flow-monitor/src-tauri/src/lib.rs
    - Scope: delete the four local stub structs/enums in fs_watcher.rs (lines 11-48); add `use crate::{ArtifactKind, WatcherState, ArtifactChangedPayload, WatcherStatusPayload};` at the top of fs_watcher.rs; reconcile field-name divergence (repo vs repo_path, artifact vs kind) with the D3 spec.
    - Verify: `git grep -n 'MERGE-NOTE' -- 'flow-monitor/src-tauri/' | wc -l` returns 0; `cargo test` PASS.
    - Depends on: T4 (lib.rs canonical types must exist)
    - Parallel-safe-with: any T not touching fs_watcher.rs or lib.rs payload struct region
```

---
name: Setup-hook wiring commitment must be an explicit plan task
description: A tech D-id that promises a function will be called from the app lifecycle setup hook must be decomposed into a named task; implicit wiring produces dead-code orphans.
type: feedback
created: 2026-04-21
updated: 2026-04-21
---

## Rule

When 04-tech.md includes a decision body with text like "called from the setup hook on launch", "registered via the lifecycle callback", or "wired into `<lifecycle-fn>` during app init", the architect MUST flag that wiring as its own task-sized item when the plan is authored. The function-authoring task and the hook-wiring task are distinct deliverables; leaving the wiring implicit produces a dead-code orphan.

## Why

`20260420-flow-monitor-control-plane` 04-tech.md D1 committed: "temp files […] are removed on next app launch via a `purge_stale_temp_files()` setup hook". The function `pub fn purge_stale_temp_files()` was authored as part of T93 (invoke.rs) and lives at invoke.rs:381. No task in 05-plan.md scopes the lib.rs `.setup()` block to add the call. T108 (lib.rs polling wiring) was scoped to the `run_session_polling` async task, not the `.setup()` block. The function remained uncalled through archive — analyst finding E1: "purge_stale_temp_files() never called; D1 commitment unmet".

Low impact today (B2 is the first feature that creates such files, so "stale" files don't accumulate on first use) but the commitment is structurally unmet and the debt carries into the next feature silently. The root cause is a gap between the architect's commitment and the TPM's task decomposition: the architect assumed "and wire it" was implicit; the TPM plan scoped only the explicitly-named modules.

## How to apply

1. When writing a D-id body, if the body contains "called from" / "wired into" / "registered via" / "hooked from" any named lifecycle function, add a `**Wiring task**: <description>` line in the D-id body so the TPM must account for it in the plan.
2. At plan-review time, the TPM scans D-ids for the `Wiring task` marker and adds a dedicated task or an explicit acceptance clause on an existing task covering the hook wiring.
3. If the wiring is a one-line addition to an already-scoped file (e.g. lib.rs .setup() block), it is still a task-scope item — it MUST appear in the Acceptance clause of the task that owns that file, not inferred from the module's existence.
4. Archive retrospective discipline: for every D-id with a wiring commitment, grep the production code for the committed call site. Missing call = archive follow-up ticket (update-tech or next-feature task).

## Example

D1 in this feature committed `purge_stale_temp_files()` from the setup hook; no task scoped the lib.rs .setup() edit; the function shipped as dead code. If D1 had ended with `**Wiring task**: lib.rs .setup() block must call purge_stale_temp_files()` the TPM's T108 acceptance would have absorbed it (single-file single-task fit). The retrospective follow-up is now a next-feature cleanup ticket.

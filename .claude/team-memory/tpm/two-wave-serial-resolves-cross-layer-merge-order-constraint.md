## Rule

When a PRD decision imposes a cross-layer merge-order constraint (e.g. "backend change lands at or before the frontend consumer"), prefer a strict two-wave split (wave 1 = producer layer, wave 2 = consumer layer) over a single-wave schedule with per-task `Depends on:` chains.

## Why

A two-wave split enforces the ordering constraint at the merge-gate layer automatically — wave 2 cannot start until wave 1 is merged, by the orchestrator's definition. The alternative, encoding the constraint as inter-task dependencies in a single wave, is more fragile:

- A typo in a `Depends on:` field silently breaks the invariant (developers read task scopes, not dependency graphs).
- Inline review fires per-task, but the merge interleaving depends on developer completion timing, not on the declared order.
- If the constraint is subtle ("Rust scanner must read the new path before the TS IPC calls `path_exists`"), reviewers may not catch a violation of the reverse order until runtime.

A wave boundary is a bright line the orchestrator enforces.

Secondary benefits:

1. Wave 1 can be scoped to a specific axis (e.g. security-audited in `20260421-rename-flow-monitor` for the Tauri capability swap), giving the reviewer a focused diff with no cross-layer noise.
2. Wave 1 close-out gates (e.g. `cargo test` for Rust backend) run before the consumer layer's gates, surfacing backend regressions in isolation.

## How to apply

1. At plan time, read PRD §decisions for any D-id that phrases an ordering constraint ("must land before", "at or before", "prerequisite for").
2. If the ordering constraint maps cleanly to a layer boundary (backend vs frontend, library vs application, producer vs consumer), split the waves along that boundary. Wave 1 = producer; wave 2 = consumer.
3. Do NOT add explicit `Depends on:` entries for the cross-layer constraint in this case — the wave boundary carries it. Still declare intra-wave deps (T12 depends on T9 within the same wave) where they apply.
4. If the ordering constraint is local (same layer, same file), express it as `Depends on:` at task level instead; the wave split is overkill.
5. Reflect the rationale in the plan narrative's "Wave choice" paragraph so reviewers see why the wave boundary exists.

## Example

`20260421-rename-flow-monitor` PRD D6: "Rust backend scanner rename (R1) must land at or before `SettingsRepositories.tsx:33` frontend consumer (R6)." The TPM split the waves:

- **W1** = Rust backend (path literals, capability JSON, Rust tests, fixtures) — 8 tasks
- **W2** = React frontend + i18n + README + allow-list — 8 tasks

T11 (the `SettingsRepositories.tsx:33` edit) sat in W2. By the time W2 launched, the Rust scanner rename (T2 in W1) was already merged to the feature branch. No `Depends on:` field on T11 was needed — the wave order carried the constraint. Validate analyst audit confirmed merge order held with no drift.

The split also isolated the tier=audited security diff (T7 capabilities/default.json) inside W1 alongside backend-only context, letting the security reviewer audit the Tauri capability swap without React noise.

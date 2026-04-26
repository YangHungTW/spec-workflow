---
name: Named-risk + claimed-mitigation pairs require wiring verification, not symbol presence
description: When `04-tech.md` enumerates a risk and `05-plan.md` claims a task mitigates it, gap-check must verify the mitigation actually wires through the production call path — not just that the named symbol exists. A function can exist, a struct can be defined, a test can pass in isolation, while the production path bypasses all of them.
type: feedback
created: 2026-04-26
updated: 2026-04-26
source: 20260426-flow-monitor-graph-view
---

## Rule

For every "tech §6 risk N — mitigated by T<n>" pairing in the plan,
gap-check must:

1. Locate the production call site that should invoke the mitigation.
2. Assert (via grep + manual trace) that the carry-state / guard / cache
   prescribed by the tech doc is threaded into that path.

Symbol-presence is necessary but not sufficient. A mitigation function
can exist, its struct definitions can be in the right file, and its
isolated test can pass — yet production may instantiate a fresh empty
state on every call and never carry it across invocations.

## Why

Tests in isolation invoke the mitigation function directly, supplying a
correct prior-state argument. The production call path may invoke the
same function but with a freshly-constructed empty state, throwing away
the carry-state the mitigation depends on. The isolated test reports
green; production silently re-fires whatever the mitigation was supposed
to suppress.

## How to apply

Pattern for each named-risk / claimed-mitigation pairing:

1. Identify the production entry point (loop body, event handler, IPC
   command, etc.).
2. Trace the variable that *should* hold the carry-state (set, map,
   counter, timestamp, etc.) from the entry point through to the
   mitigation function.
3. If the carry-state is created fresh on every call into the entry
   point — finding. If it's threaded across iterations / events /
   requests — wiring is OK.
4. Cross-reference the tests: do they pass the carry-state across calls
   the way production does, or do they call the mitigation function
   directly with a controlled argument? If the latter, the test only
   covers the function-in-isolation, not the production path.

This is the **named-risk subcase** of `qa-analyst/partial-wiring-trace-every-entry-point.md`.

## Example

Surfaced in `20260426-flow-monitor-graph-view` validate as F6:

Tech §6 risk 7 was named: *"`prev_stalled_set` carry-state and the
`store::diff` notification gate must be preserved"*. Plan §1 claimed T11
sequencing *"preserves the `prev_stalled_set` carry-state."*
`notify_dedupe_test` passed.

Production reality: `emit_sessions_changed` always initialised
`prev_stalled_set: HashSet::new()` and `prev_map: HashMap::new()` at the
top of the function. The caller `spawn_watcher` invoked it on every
STATUS.md FSEvents change — never holding any state across calls.
Result: every STATUS.md write re-fired stalled notifications for sessions
already-stalled before that event.

`notify_dedupe_test` continued to pass because it tested `store::diff` in
isolation with a manually-threaded `prev_stalled_set` — not the
watcher-integrated path. The test demonstrated the gate worked when given
the right inputs; production didn't give it the right inputs.

Verification grep that would have caught it:

```sh
# Find the production caller of emit_sessions_changed
grep -rn 'emit_sessions_changed' flow-monitor/src-tauri/src/

# Confirm the caller threads prev_stalled_set across iterations
grep -B 2 -A 10 'prev_stalled_set' flow-monitor/src-tauri/src/fs_watcher.rs
# If prev_stalled_set only appears INSIDE emit_sessions_changed, it's
# being reset each call → mitigation unwired.
```

The test rectifying this would have to call `spawn_watcher` (or the
event-loop body that owns the carry-state) and assert the dedup behaviour
across multiple synthetic events, not a single function invocation.

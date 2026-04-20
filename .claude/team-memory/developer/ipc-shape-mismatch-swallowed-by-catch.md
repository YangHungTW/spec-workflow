---
name: ipc-shape-mismatch-swallowed-by-catch
description: TypeScript IPC types don't validate at runtime; a silent `.catch(() => undefined)` hides shape mismatches between frontend declared types and backend return types.
type: feedback
created: 2026-04-19
updated: 2026-04-19
---

## Rule

TypeScript IPC type declarations are compile-time only — they do NOT validate the actual runtime payload shape returned by the backend. A `.catch(() => undefined)` or `.catch(() => null)` on an `invoke` call silently hides shape mismatches, which typically present as a stuck loading state or an empty list with no error visible to the user.

## Why

Context from `20260419-flow-monitor`: `MainWindow.tsx` declared `ListSessionsResponse = { sessions: SessionRecord[], total: number, ... }`. The Rust backend returned a flat `Vec<SessionRecord>` because `list_sessions` had been refactored from a paginated response to a flat list without a corresponding frontend update. Frontend code ran `.sessions.map(...)` on what was actually an array, throwing `TypeError: Cannot read properties of undefined (reading 'map')`. The surrounding code:

```typescript
invoke<ListSessionsResponse>('list_sessions')
  .then(r => setSessions(r.sessions))
  .catch(() => undefined)  // silent
  .finally(() => setLoading(false));
```

swallowed the error. Result: `setSessions` never ran, `setLoading(false)` did run, the UI sat on an empty state with no error banner, forever.

## How to apply

1. **Single source of truth for IPC shapes.** Options in order of preference:
   - `ts-rs` — derive TypeScript types from Rust structs at build time.
   - `specta` — richer derivation including command signatures.
   - Hand-synced shared schema with a CI check that greps for drift.

2. **Loud catch in development.** Replace silent catch handlers with a verbose form that re-throws in dev:
   ```typescript
   .catch(e => {
     console.error('list_sessions failed:', e);
     if (import.meta.env.DEV) throw e;
     return undefined;
   })
   ```

3. **Surface errors visibly in UI during development.** Wire up an error boundary or a toast that displays the actual exception message. A silent empty state is the WORST failure mode because it looks like valid "no data".

4. **Runtime walkthrough coverage.** Per `shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds`, exercise every `invoke` call at least once during verify. A shape mismatch manifests immediately.

5. **Lint rule (optional).** A custom ESLint rule that flags `.catch(() => undefined)` / `.catch(() => null)` in the codebase surfaces the anti-pattern at review time.

## Example

The `20260419-flow-monitor` fix was a single-line change on the Rust side to re-wrap the response:

```rust
// before
pub fn list_sessions(...) -> Vec<SessionRecord> { ... }

// after
#[derive(Serialize)]
pub struct ListSessionsResponse {
    pub sessions: Vec<SessionRecord>,
    pub total: usize,
}
pub fn list_sessions(...) -> ListSessionsResponse { ... }
```

Had the frontend used a loud catch + dev error toast, the TypeError would have surfaced on the first session-list load rather than being deferred until post-archive runtime walkthrough.

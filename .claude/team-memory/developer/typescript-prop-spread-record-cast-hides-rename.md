## Rule

Never use `{...({ propName: value } as Record<string, unknown>)}` to pass an
optional prop through an intermediate component. The `Record<string, unknown>`
cast is an escape hatch that forfeits TypeScript's ability to flag prop-name
mismatches. Use explicit named props (even when optional); if the spread is
genuinely required (e.g. forwarding variable-key sets), pair it with a runtime
test that asserts the receiving component's callback actually fires.

## Why

In `20260422-monitor-ui-polish`, `MainWindow` passed an archived-row click
handler to `RepoSidebar` via:

```tsx
<RepoSidebar {...({ onArchivedFeatureClick: handler } as Record<string, unknown>)} />
```

while `RepoSidebar`'s prop was named `onArchivedRowClick`. Both sides compiled
cleanly, all 480 frontend tests passed, all three reviewer axes (security /
performance / style) returned PASS/NITS across the wave. The mismatch only
surfaced at validate stage (analyst axis) where a static grep of the prop
names across both files caught it. Clicking any archived row in the sidebar
did nothing — handler silently dead.

## How to apply

1. At review time, treat any `as Record<string, unknown>` or `as any` inside
   a JSX spread as a `must` finding. Request the named-prop rewrite.
2. If the spread is genuinely unavoidable (e.g. forwarding unknown
   parent-provided extras), require a co-located runtime test that renders
   the component, simulates the user interaction, and asserts the
   spread-forwarded callback fires.
3. At rename time, grep the old prop name across the repo before committing;
   TypeScript will not flag a spread-cast consumer.

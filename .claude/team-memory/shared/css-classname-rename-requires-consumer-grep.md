## Rule

Whenever a CSS class name is renamed — in the stylesheet OR in a component's
`className` attribute — grep the classname string across the whole repo before
merging the task. Neither side is compiler-checked against the other;
mismatches compile, tests pass, and visual behaviour silently disappears.

## Why

In `20260422-monitor-ui-polish` (AC17), the stylesheet carried an italic rule
on `.repo-sidebar__item-label` from an earlier iteration, while the shipped
component rendered archived slugs with `className="repo-sidebar__archived-slug"`.
Both sides passed their own unit tests (the CSS file had no missing-selector
check; the component test asserted on the `archived-slug` class string). The
italic never rendered at runtime. Every reviewer axis (including style)
missed it because each was scoped to its own diff and neither diff alone was
internally inconsistent.

This is the same failure mode as `developer/i18n-key-rename-requires-consumer-sweep.md`
(untyped-string drift between a JSON bundle and a `t()` consumer) — both are
cases where a string identifier spans two files that never reference each
other's type system.

## How to apply

1. When a task's scope mentions a CSS classname rename (either direction),
   run `grep -rn "<classname>" src/` before task close.
2. Add a wave-close grep assertion that the old classname returns zero hits
   across production source AND stylesheets.
3. Where possible, centralise classnames as TS constants
   (`const ARCHIVED_SLUG = "repo-sidebar__archived-slug"`) so a rename is
   compiler-checked.
4. Reviewer style axis: treat an orphan CSS rule (no component uses that
   classname) as a `should` finding — dead CSS is a common symptom of a
   half-complete rename.

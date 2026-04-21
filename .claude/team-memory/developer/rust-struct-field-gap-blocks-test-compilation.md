# Rust struct field gap blocks test compilation across unrelated modules

## Trigger

When running `cargo test --lib <module>::` for a new Rust module in a Tauri
project, the entire library must compile — including `#[cfg(test)]` blocks in
unrelated modules. A missing struct field in any other module's test fixture
(e.g. `SessionState { .. }` missing `has_ui:`) causes a compile error that
prevents the target module's tests from running.

## Lesson

Before authoring a new Rust module in a shared library crate (like
`flow-monitor`), check whether existing `#[cfg(test)]` blocks still compile
cleanly:

```bash
cargo test --lib 2>&1 | grep "^error"
```

If there are pre-existing struct initialiser errors (`E0063: missing field`),
fix them with `field_name: default_value` in the offending test fixture before
adding new code. These gaps accumulate silently when a struct gains a new field
but its test helpers are not updated.

## Fix pattern

Add the missing field with its zero/default value to the struct literal in the
test fixture. The field value should match what `Default::default()` or the
struct's `Default` impl would produce (usually `false`, `0`, `vec![]`,
`String::new()`, `PathBuf::new()`).

## Context

Encountered during T96 (`command_taxonomy.rs`) when `tray.rs::make_state()`
was missing `has_ui: false` after `status_parse::SessionState` gained the
`has_ui` field in a prior wave. The fix was a one-line addition to `tray.rs`.

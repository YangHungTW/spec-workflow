## Rule

When a feature renames the *directory* the repo lives in (e.g. `~/Tools/spec-workflow/` → `~/Tools/specaffold/`), run `cargo clean` before the first `cargo build` / `cargo test` — cargo's `target/` fingerprint stores absolute paths from the pre-rename location.

## Why

Cargo's incremental build state includes absolute paths in fingerprint and dep-info files under `target/`. After the repo directory is renamed, those paths point at a location that no longer exists. The next build fails with cryptic errors such as:

```
failed to read plugin permissions: failed to read file
'/Users/…/Tools/spec-workflow/flow-monitor/src-tauri/target/debug/build/tauri-*/out/permissions/…': No such file or directory
```

This is specific to **directory-rename** scenarios. Pure brand-renames (the source code changes, the repo directory does not) do not produce this symptom — the brand strings are in files, not in cargo's path fingerprints.

## How to apply

1. If the feature scope includes moving the repo to a new directory path (e.g. `~/Tools/old-name/` → `~/Tools/new-name/`), run `cargo clean --manifest-path <path/to/Cargo.toml>` once after the move, before any `cargo build` / `cargo test` / Tauri build command.
2. For features like `20260421-rename-flow-monitor` that only rename brand strings inside files — no directory move — skip this step; no cache invalidation is needed.
3. If the cargo-test gate produces "file not found" errors referencing the old repo directory path, the diagnosis is a stale target dir, not a source bug.

## Example

The `20260421-rename-flow-monitor` T8 cargo-test gate initially failed because a prior `rename-to-specaffold` feature had renamed the on-disk repo directory. `target/debug/build/tauri-*/out/permissions/…` still cached absolute paths under `~/Tools/spec-workflow/`. Running `cargo clean --manifest-path flow-monitor/src-tauri/Cargo.toml` cleared 5.9 GiB of stale artefacts; the next `cargo test --no-run` built cleanly and the full suite passed 153/153. Documented in STATUS 2026-04-21 W1 close.

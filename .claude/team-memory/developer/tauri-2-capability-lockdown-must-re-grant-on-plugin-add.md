---
name: tauri-2-capability-lockdown-must-re-grant-on-plugin-add
description: Tauri 2 strict capability model blocks plugin commands silently unless the matching `<plugin>:default` permission is added to capabilities/default.json in the same commit that adds the plugin crate.
type: feedback
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Whenever a `tauri-plugin-*` crate is added to `Cargo.toml`, the matching `<plugin>:default` permission (or a narrower `allow-*` set) MUST be added to `capabilities/default.json` in the SAME commit. Otherwise every `invoke(...)` call from that plugin silently fails at runtime with no error surfaced to the frontend.

## Why

Context from `20260419-flow-monitor`: T3 hardened the default capability set down to `core:default` as a security measure. Subsequent tasks T25 (fs plugin), T26 (dialog plugin), T27 (shell plugin), T28 (opener plugin), and T45 (store plugin) each added a plugin crate. Because none of them re-granted the corresponding `<plugin>:default` permission, every frontend call through those plugins returned undefined from a silently-rejected IPC request. Tauri's default logging emits nothing visible for capability denials. Tests that mock `@tauri-apps/api/core.invoke` cannot catch this class because the mock never exercises the capability layer. Runtime walkthrough was the only channel that surfaced it, and that only happened after archive.

## How to apply

1. When adding `tauri-plugin-<name>` to `src-tauri/Cargo.toml`, open `src-tauri/capabilities/default.json` in the same edit.
2. Add `"<name>:default"` to the `permissions` array (or narrower `allow-*` entries if least-privilege matters). Example: adding `tauri-plugin-dialog` means adding `"dialog:default"` or specific entries like `"dialog:allow-open"`.
3. Commit the Cargo.toml + capabilities/default.json changes together so `git log` shows the capability grant paired with the crate.
4. Add a wave-merge security-review check: `grep -l 'tauri-plugin-' src-tauri/Cargo.toml` paired with `jq '.permissions' src-tauri/capabilities/default.json` — every plugin crate must have a permission entry.
5. During runtime walkthrough (see shared memory `runtime-verify-must-exercise-end-to-end-not-just-build-succeeds`), exercise at least one call per plugin; a silent failure here is almost always a missing capability grant.

## Example

`20260419-flow-monitor` T25 added `tauri-plugin-fs = "2"` to Cargo.toml without touching capabilities/default.json. Every call to `readDir` / `readTextFile` from the frontend returned undefined. The same pattern repeated for T26 / T27 / T28 / T45. A single later commit added `"fs:default"`, `"dialog:default"`, `"shell:default"`, `"opener:default"`, `"store:default"` to the capabilities file and unblocked all five plugins at once. Had the capability grant been paired with each plugin-add commit, the runtime walkthrough would have found only the other seven defects, not eight.

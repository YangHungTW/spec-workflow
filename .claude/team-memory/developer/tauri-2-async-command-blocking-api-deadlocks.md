---
name: tauri-2-async-command-blocking-api-deadlocks
description: In Tauri 2 async commands, never call `*_blocking` methods from plugin APIs; the blocking call deadlocks the tokio worker driving the plugin's main-thread dispatch.
type: feedback
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Inside a `#[tauri::command] async fn`, never call any `*_blocking` method on a Tauri plugin API (e.g. `blocking_pick_folder`, `blocking_pick_file`, `blocking_message`). These methods block the tokio worker thread that is also responsible for driving the plugin's main-thread dispatch, producing a silent deadlock with no error surfaced.

## Why

Context from `20260419-flow-monitor`: `dialog_open_directory` was declared as an async command and invoked `app.dialog().file().blocking_pick_folder()` inside the body. Symptom: picker dialog never opened, no error in the console, no error returned to the frontend, user sees "button does nothing". Tauri runs async commands on the tokio runtime. `blocking_pick_folder` parks the current worker waiting for a main-thread callback, but the main-thread dispatcher that would deliver that callback is itself scheduled by the same tokio runtime pool. Result: a classic deadlock that presents as a hang, silently masked by the UI continuing to respond on other threads.

## How to apply

Pick one of the two fixes; both are equally valid, and the choice depends on whether the caller needs async semantics.

1. **Sync command (preferred for simple pickers)** — declare the command as sync: `#[tauri::command] pub fn dialog_open_directory(...) -> Result<Option<PathBuf>, String>`. Tauri runs sync commands on a worker thread, so `blocking_pick_folder` is safe there.

2. **Async command with callback bridge** — keep the command async and use the non-blocking callback form paired with a `tokio::sync::oneshot::channel`:
   ```rust
   #[tauri::command]
   pub async fn dialog_open_directory(app: AppHandle) -> Result<Option<PathBuf>, String> {
       let (tx, rx) = tokio::sync::oneshot::channel();
       app.dialog().file().pick_folder(move |path| {
           let _ = tx.send(path);
       });
       rx.await.map_err(|e| e.to_string())
   }
   ```

Additional guardrails:

- Grep the codebase for `blocking_` inside `#[tauri::command] async` blocks as a pre-merge check.
- During runtime walkthrough, exercise every dialog / picker at least once — a hang with no error message is almost always this bug.

## Example

`20260419-flow-monitor` T26 wired up the directory picker. Initial implementation used `blocking_pick_folder` inside an async command. Fix: converted the command to sync form. Alternative fix (rejected for simplicity): the callback + oneshot bridge. Both fixes were verified against the runtime walkthrough; sync form ships because the picker is a leaf operation with no surrounding async work.

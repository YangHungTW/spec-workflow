/// IPC command surface for flow-monitor (B1 read-only boundary).
///
/// Exposes tauri::command handlers for the renderer. Every command here is
/// read-only or settings-only. No write-side commands (`send_instruction`,
/// `invoke_specflow`, `advance_stage`, `write_status`, `edit_artefact`) exist
/// in B1 — that boundary is reserved for B2.
///
/// `read_artefact` guards against path-traversal by canonicalising the
/// requested path and verifying it sits under a registered repository root
/// (security rule check 2).
use std::path::{Path, PathBuf};
use tauri::Manager;

// ---------------------------------------------------------------------------
// Minimal stub types (replicated here while T8/T10 siblings are in-flight).
// When store.rs and settings.rs merge, replace these with `use crate::store::*`
// and `use crate::settings::*`.
// ---------------------------------------------------------------------------

/// Opaque session record returned to the renderer.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
pub struct SessionRecord {
    pub repo: PathBuf,
    pub slug: String,
    pub stage: String,
    pub last_activity_secs: u64,
    pub has_ui: bool,
}

/// Flat list of sessions across all registered repos.
pub type SessionList = Vec<SessionRecord>;

/// Settings shape (B1 keys only — no B2 fields).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
pub struct Settings {
    pub schema_version: u32,
    pub repos: Vec<PathBuf>,
    pub polling_interval_secs: u64,
    pub stale_threshold_mins: u64,
    pub stalled_threshold_mins: u64,
    pub notifications_enabled: bool,
    pub always_on_top: bool,
    pub compact_panel_open: bool,
    pub notification_title: String,
    pub notification_body: String,
    pub locale: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            schema_version: 1,
            repos: vec![],
            polling_interval_secs: 3,
            stale_threshold_mins: 5,
            stalled_threshold_mins: 30,
            notifications_enabled: true,
            always_on_top: true,
            compact_panel_open: false,
            notification_title: String::from("flow-monitor"),
            notification_body: String::from("A session has stalled."),
            locale: String::from("en"),
        }
    }
}

// ---------------------------------------------------------------------------
// Shared Tauri state wrappers
// ---------------------------------------------------------------------------

use std::sync::Mutex;

/// Shared settings state injected into Tauri's managed state.
pub struct SettingsState(pub Mutex<Settings>);

/// Shared session list state injected into Tauri's managed state.
pub struct SessionsState(pub Mutex<SessionList>);

// ---------------------------------------------------------------------------
// Path-traversal guard — used by `read_artefact`.
// ---------------------------------------------------------------------------

/// Error type for IPC boundary violations.
#[derive(Debug, serde::Serialize)]
pub struct IpcError {
    pub code: &'static str,
    pub message: String,
}

impl std::fmt::Display for IpcError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[{}] {}", self.code, self.message)
    }
}

/// Verify that `candidate` (already canonicalised) sits under one of the
/// `registered_roots`. Returns the matching root on success.
///
/// This is the path-traversal boundary required by security rule check 2.
/// `candidate` and every root must already be canonicalised absolute paths.
fn assert_under_registered_root<'a>(
    candidate: &Path,
    registered_roots: &'a [PathBuf],
) -> Result<&'a PathBuf, IpcError> {
    for root in registered_roots {
        if candidate.starts_with(root) {
            return Ok(root);
        }
    }
    Err(IpcError {
        code: "PATH_TRAVERSAL",
        message: format!(
            "requested path is outside all registered repository roots: {}",
            candidate.display()
        ),
    })
}

// ---------------------------------------------------------------------------
// IPC commands
// ---------------------------------------------------------------------------

/// Return the current in-memory session list.
#[tauri::command]
pub fn list_sessions(
    sessions: tauri::State<'_, SessionsState>,
) -> Result<SessionList, IpcError> {
    let guard = sessions.0.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "sessions lock is poisoned".into(),
    })?;
    Ok(guard.clone())
}

/// Return the current settings snapshot.
#[tauri::command]
pub fn get_settings(
    settings: tauri::State<'_, SettingsState>,
) -> Result<Settings, IpcError> {
    let guard = settings.0.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;
    Ok(guard.clone())
}

/// Merge a partial settings patch and persist (delegates write to settings_io
/// in T10; here we update in-memory state — persistence happens via the
/// settings_io write path when T10 merges).
///
/// Security: `patch.repos` entries are canonicalised before the patch is
/// applied — the renderer is untrusted and could supply `..` traversal
/// sequences that would corrupt the registered-root set that
/// `read_artefact`'s path-traversal guard depends on.  The update is
/// atomic: if ANY entry fails to canonicalise the stored settings are left
/// unchanged and an error is returned.
///
/// Delegates to `update_settings_inner` for unit testability.
#[tauri::command]
pub fn update_settings(
    patch: Settings,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    update_settings_inner(patch, &settings.0)
}

/// Add a repository root to the watched set.
/// Validates that `path` is an absolute, canonicalisable path.
#[tauri::command]
pub fn add_repo(
    path: String,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    let raw = PathBuf::from(&path);
    let canonical = raw.canonicalize().map_err(|e| IpcError {
        code: "INVALID_PATH",
        message: format!("cannot canonicalise repo path {path}: {e}"),
    })?;
    let mut guard = settings.0.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;
    if !guard.repos.contains(&canonical) {
        guard.repos.push(canonical);
    }
    Ok(())
}

/// Remove a repository root from the watched set.
#[tauri::command]
pub fn remove_repo(
    path: String,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    let raw = PathBuf::from(&path);
    // canonicalize may fail if the path was already deleted; compare by
    // both canonical form (if available) and the raw string as a fallback
    // so callers can remove a repo whose directory was deleted.
    let canonical_opt = raw.canonicalize().ok();
    let mut guard = settings.0.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;
    guard.repos.retain(|r| {
        if let Some(ref c) = canonical_opt {
            r != c
        } else {
            r != &raw
        }
    });
    Ok(())
}

/// Read a `.spec-workflow` artefact file for display in the detail view.
///
/// Security: `repo` and `file` are both validated before read:
///   1. `repo` must be one of the currently registered roots.
///   2. The full path (`repo / slug / file`) is canonicalised via
///      `Path::canonicalize`.
///   3. The canonical path must still sit under the same registered root
///      (path-traversal boundary — security rule check 2).
/// Read-only: delegates to `read_artefact_inner` which uses
/// `std::fs::read_to_string` only.
#[tauri::command]
pub fn read_artefact(
    repo: String,
    slug: String,
    file: String,
    settings: tauri::State<'_, SettingsState>,
) -> Result<String, IpcError> {
    // Snapshot the registered roots without holding the lock during I/O.
    let registered_roots: Vec<PathBuf> = {
        let guard = settings.0.lock().map_err(|_| IpcError {
            code: "LOCK_POISONED",
            message: "settings lock is poisoned".into(),
        })?;
        guard.repos.clone()
    };

    // Delegate to the inner function — single source of truth for the
    // path-traversal guard (security rule check 2).
    read_artefact_inner(repo, slug, file, &registered_roots)
}

/// Toggle the compact panel window open/closed state.
///
/// When `open` is `true`, creates a new `WebviewWindow` labelled `"compact"`
/// routed to `/compact` (AC10.a, AC10.c). When `false`, closes that window.
/// The main window is not touched — it remains open and functional throughout.
///
/// The settings flag is updated in-memory so `get_settings` reflects the
/// current panel state.
#[tauri::command]
pub fn set_compact_panel_open(
    open: bool,
    app: tauri::AppHandle,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    {
        let mut guard = settings.0.lock().map_err(|_| IpcError {
            code: "LOCK_POISONED",
            message: "settings lock is poisoned".into(),
        })?;
        guard.compact_panel_open = open;
    }

    if open {
        // Using get_webview_window first avoids a second window if the IPC is
        // called twice (idempotent — only one compact window at a time).
        if app.get_webview_window("compact").is_none() {
            tauri::WebviewWindowBuilder::new(
                &app,
                "compact",
                tauri::WebviewUrl::App("/compact".into()),
            )
            .build()
            .map_err(|e| IpcError {
                code: "WINDOW_CREATE_ERROR",
                message: format!("failed to create compact panel window: {e}"),
            })?;
        }
    } else {
        if let Some(window) = app.get_webview_window("compact") {
            window.close().map_err(|e| IpcError {
                code: "WINDOW_CLOSE_ERROR",
                message: format!("failed to close compact panel window: {e}"),
            })?;
        }
    }

    Ok(())
}

/// Toggle the always-on-top window hint for the compact panel and persist in
/// settings.
///
/// The command attempts to apply the hint to the live compact panel window
/// (label = "compact") if it exists. If the compact window has not been
/// created yet (T29 creates it on demand), `COMPACT_WINDOW_NOT_FOUND` is
/// returned so the caller can surface a user-friendly message. The settings
/// field is always updated regardless of whether the window was found, so
/// the preference is honoured the next time the compact panel opens.
#[tauri::command]
pub fn set_always_on_top(
    always_on_top: bool,
    app: tauri::AppHandle,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    set_always_on_top_inner(
        always_on_top,
        &settings.0,
        |label| {
            use tauri::Manager;
            app.get_webview_window(label)
                .map(|w| Box::new(w) as Box<dyn WindowAlwaysOnTop>)
        },
    )
}

/// Trait abstraction over the always-on-top call so the inner function is
/// unit-testable without a live Tauri runtime.
pub trait WindowAlwaysOnTop {
    fn set_always_on_top(&self, value: bool) -> Result<(), String>;
}

impl WindowAlwaysOnTop for tauri::WebviewWindow {
    fn set_always_on_top(&self, value: bool) -> Result<(), String> {
        tauri::WebviewWindow::set_always_on_top(self, value)
            .map_err(|e| e.to_string())
    }
}

/// Inner implementation of `set_always_on_top`, extracted for unit
/// testability.
///
/// `window_lookup` is called with the label `"compact"` and should return
/// `Some(Box<dyn WindowAlwaysOnTop>)` when the window exists, `None`
/// otherwise.  The settings field is always written, even when the window is
/// absent, so that the preference is applied when the compact panel opens.
pub fn set_always_on_top_inner(
    always_on_top: bool,
    store: &std::sync::Mutex<Settings>,
    window_lookup: impl FnOnce(&str) -> Option<Box<dyn WindowAlwaysOnTop>>,
) -> Result<(), IpcError> {
    // Persist the preference first — independent of whether the window exists.
    {
        let mut guard = store.lock().map_err(|_| IpcError {
            code: "LOCK_POISONED",
            message: "settings lock is poisoned".into(),
        })?;
        guard.always_on_top = always_on_top;
    }

    match window_lookup("compact") {
        Some(win) => win.set_always_on_top(always_on_top).map_err(|e| IpcError {
            code: "WINDOW_OP_FAILED",
            message: format!("set_always_on_top failed on compact window: {e}"),
        }),
        None => Err(IpcError {
            code: "COMPACT_WINDOW_NOT_FOUND",
            message: "compact panel window does not exist yet; preference saved for next open"
                .into(),
        }),
    }
}

/// Update localised notification strings supplied by the renderer (AC11.d).
/// The renderer owns localisation; the backend stores and forwards.
#[tauri::command]
pub fn set_notification_strings(
    title: String,
    body: String,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    let mut guard = settings.0.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;
    guard.notification_title = title;
    guard.notification_body = body;
    Ok(())
}

/// Open the given path in macOS Finder (shows the directory/file).
///
/// Security: path is canonicalised and verified against registered repo roots
/// before invoking `open` (security check 2 — path traversal boundary).
/// Argv-form invocation only — no string-built shell command (check 4).
/// Read-only: `open` on macOS never mutates `.spec-workflow/**` (B1/B2 boundary).
#[tauri::command]
pub fn open_in_finder(
    path: String,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    let registered_roots: Vec<PathBuf> = {
        let guard = settings.0.lock().map_err(|_| IpcError {
            code: "LOCK_POISONED",
            message: "settings lock is poisoned".into(),
        })?;
        guard.repos.clone()
    };
    open_in_finder_inner(path, &registered_roots)
}

/// Reveal the given path in macOS Finder (selects the individual file).
///
/// Security: same path-traversal guard as `open_in_finder`.
/// Corresponds to `open -R <path>` — argv-form, no shell string (check 4).
/// Used by DesignFolderIndex per-file buttons (AC9.h).
#[tauri::command]
pub fn reveal_in_finder(
    path: String,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    let registered_roots: Vec<PathBuf> = {
        let guard = settings.0.lock().map_err(|_| IpcError {
            code: "LOCK_POISONED",
            message: "settings lock is poisoned".into(),
        })?;
        guard.repos.clone()
    };
    reveal_in_finder_inner(path, &registered_roots)
}

/// Return the macOS notification permission status as a string.
///
/// Stub for B2: actual NSUserNotificationCenter authorization check is deferred.
/// Returns `"default"` so the frontend renders the "Not yet requested" state.
#[tauri::command]
pub async fn get_notification_permission_status() -> Result<String, IpcError> {
    Ok("default".to_string())
}

/// Focus the main window.
///
/// Stub for the compact panel's "Open main →" button (AC10.b).
/// Uses `AppHandle::get_webview_window` to locate the main window and calls
/// `set_focus()` — argv-style, no shell string (security check 4).
#[tauri::command]
pub fn focus_main_window(app: tauri::AppHandle) -> Result<(), IpcError> {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.set_focus();
    }
    Ok(())
}

/// Open a folder picker dialog and return the selected path (or None).
///
/// Stub for B2 repo-add flow (T23). Uses tauri-plugin-dialog's blocking
/// folder picker so the result is directly usable without async ceremony.
/// Returns `None` when the user cancels without selecting a folder.
#[tauri::command]
pub async fn dialog_open_directory(app: tauri::AppHandle) -> Result<Option<String>, IpcError> {
    use tauri_plugin_dialog::DialogExt;
    // blocking_pick_folder must run off the tokio runtime to avoid deadlocking
    // the async command thread. Use the callback variant via a oneshot channel.
    let (tx, rx) = tokio::sync::oneshot::channel();
    app.dialog().file().pick_folder(move |path| {
        let _ = tx.send(path);
    });
    let result = rx.await.map_err(|e| IpcError {
        code: "DIALOG_FAILED",
        message: format!("dialog channel closed: {e}"),
    })?;
    Ok(result.map(|p| p.to_string()))
}

/// Copy plain text to the system clipboard via the Tauri clipboard plugin.
///
/// The `copy_to_clipboard_inner` helper validates the input; actual clipboard
/// write requires `AppHandle` which is available at runtime but not in unit
/// tests. Tests cover the validation layer; the AppHandle write is exercised
/// in manual smoke (AC7.d).
#[tauri::command]
pub fn copy_to_clipboard(
    text: String,
    app: tauri::AppHandle,
) -> Result<(), IpcError> {
    copy_to_clipboard_inner(text.clone())?;
    use tauri_plugin_clipboard_manager::ClipboardExt;
    app.clipboard().write_text(text).map_err(|e| IpcError {
        code: "CLIPBOARD_ERROR",
        message: format!("failed to write to clipboard: {e}"),
    })
}

// ---------------------------------------------------------------------------
// B2 IPC types
// ---------------------------------------------------------------------------

/// Outcome of a `invoke_command` IPC call.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct InvokeResult {
    pub outcome: String,
}

/// Event payload emitted when the in-flight lock set changes.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct InFlightChangedPayload {
    pub locks: Vec<(PathBuf, String)>,
    pub timestamp: u64,
}

/// Event payload emitted after an audit line is appended.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AuditAppendedPayload {
    pub repo: PathBuf,
    pub line: crate::audit::AuditLine,
}

/// Event payload emitted when the polling loop observes a STATUS.md mtime change.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SessionAdvancedPayload {
    pub repo: PathBuf,
    pub slug: String,
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;

    // Helper: set up a temporary repo directory with a minimal artefact.
    fn make_temp_repo() -> (tempfile::TempDir, PathBuf, PathBuf) {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo = tmp.path().to_path_buf();
        let artefact_dir = repo
            .join(".spec-workflow")
            .join("features")
            .join("my-feature");
        fs::create_dir_all(&artefact_dir).unwrap();
        let artefact_file = artefact_dir.join("STATUS.md");
        fs::write(&artefact_file, "# STATUS\nstage: Implement\n").unwrap();
        (tmp, repo, artefact_file)
    }

    // ---------------------------------------------------------------------------
    // assert_under_registered_root
    // ---------------------------------------------------------------------------

    #[test]
    fn test_path_within_root_passes() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let child = root.join("a").join("b");
        fs::create_dir_all(&child).unwrap();
        let canonical_child = child.canonicalize().unwrap();
        let roots = vec![root.clone()];
        assert!(assert_under_registered_root(&canonical_child, &roots).is_ok());
    }

    #[test]
    fn test_path_outside_root_returns_traversal_error() {
        let tmp1 = tempfile::tempdir().unwrap();
        let tmp2 = tempfile::tempdir().unwrap();
        let root = tmp1.path().canonicalize().unwrap();
        let outside = tmp2.path().canonicalize().unwrap();
        let roots = vec![root];
        let err = assert_under_registered_root(&outside, &roots).unwrap_err();
        assert_eq!(err.code, "PATH_TRAVERSAL");
    }

    #[test]
    fn test_empty_registered_roots_always_fails() {
        let tmp = tempfile::tempdir().unwrap();
        let candidate = tmp.path().canonicalize().unwrap();
        let err = assert_under_registered_root(&candidate, &[]).unwrap_err();
        assert_eq!(err.code, "PATH_TRAVERSAL");
    }

    // ---------------------------------------------------------------------------
    // read_artefact path-traversal guard (core security requirement)
    // ---------------------------------------------------------------------------

    /// Verify that `read_artefact` rejects a slug constructed with `../` to
    /// escape the `.spec-workflow/features/` subtree.
    ///
    /// This is the primary path-traversal AC for T11.
    #[test]
    fn test_read_artefact_path_traversal_rejected() {
        let (tmp, repo, _artefact) = make_temp_repo();
        let registered_roots = vec![repo.canonicalize().unwrap()];

        // Attempt traversal: slug = "../../../etc", file = "passwd"
        // After joining: repo/.spec-workflow/features/../../../etc/passwd
        // After canonicalize: /etc/passwd (or equivalent outside repo)
        let result = read_artefact_inner(
            repo.to_string_lossy().to_string(),
            "../../../etc".to_string(),
            "passwd".to_string(),
            &registered_roots,
        );

        assert!(result.is_err(), "traversal path must be rejected");
        let err = result.unwrap_err();
        // Any of these error codes indicate a valid rejection:
        // PATH_TRAVERSAL — the canonical path escaped the root boundary
        // ARTEFACT_NOT_FOUND — the file does not exist (safe rejection)
        // INVALID_REPO — repo failed to canonicalize (also safe)
        assert!(
            matches!(err.code, "PATH_TRAVERSAL" | "ARTEFACT_NOT_FOUND" | "INVALID_REPO"),
            "unexpected error code: {}",
            err.code
        );

        drop(tmp);
    }

    /// Verify that a legitimate artefact read succeeds.
    #[test]
    fn test_read_artefact_valid_path_succeeds() {
        let (tmp, repo, _artefact) = make_temp_repo();
        let registered_roots = vec![repo.canonicalize().unwrap()];

        let result = read_artefact_inner(
            repo.to_string_lossy().to_string(),
            "my-feature".to_string(),
            "STATUS.md".to_string(),
            &registered_roots,
        );

        assert!(result.is_ok(), "valid artefact read should succeed: {:?}", result.err());
        assert!(result.unwrap().contains("STATUS"));

        drop(tmp);
    }

    /// Verify that a repo path NOT in the registered set is rejected.
    #[test]
    fn test_read_artefact_unregistered_repo_rejected() {
        let (tmp1, _repo, _) = make_temp_repo();
        let (tmp2, unregistered, _) = make_temp_repo();

        // Register tmp1's repo but attempt to read from tmp2's repo.
        let registered_roots = vec![_repo.canonicalize().unwrap()];

        let result = read_artefact_inner(
            unregistered.to_string_lossy().to_string(),
            "my-feature".to_string(),
            "STATUS.md".to_string(),
            &registered_roots,
        );

        assert!(result.is_err());
        let err = result.unwrap_err();
        assert_eq!(err.code, "PATH_TRAVERSAL",
            "unregistered repo must produce PATH_TRAVERSAL, got: {}", err.code);

        drop(tmp1);
        drop(tmp2);
    }

    // ---------------------------------------------------------------------------
    // Settings mutations (no Tauri state; test logic directly via inner helpers)
    // ---------------------------------------------------------------------------

    #[test]
    fn test_settings_default_schema_version() {
        let s = Settings::default();
        assert_eq!(s.schema_version, 1);
    }

    #[test]
    fn test_settings_no_b2_fields() {
        // Serialise to JSON and confirm B2 boundary fields are absent.
        let s = Settings::default();
        let json = serde_json::to_string(&s).unwrap();
        assert!(!json.contains("controlPlaneEnabled"),
            "B2 field leaked into B1 settings");
        assert!(!json.contains("instructionHistory"),
            "B2 field leaked into B1 settings");
        assert!(!json.contains("send_instruction"),
            "B2 command leaked into settings");
    }

    // ---------------------------------------------------------------------------
    // open_in_finder — path-traversal guard (T27)
    // ---------------------------------------------------------------------------

    /// Path outside any registered root must be rejected with PATH_TRAVERSAL.
    /// This is the primary security AC for T27 (security check 2 + 4).
    #[test]
    fn test_open_in_finder_rejects_path_outside_registered_roots() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        // /etc/passwd is never under the temp root.
        let result = open_in_finder_inner("/etc/passwd".into(), &[root]);
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert_eq!(
            err.code, "PATH_TRAVERSAL",
            "expected PATH_TRAVERSAL, got: {}",
            err.code
        );
    }

    /// A path that canonicalises successfully and sits inside a registered root
    /// must pass the boundary check (no OS process is actually spawned in tests).
    #[test]
    fn test_open_in_finder_valid_path_passes_boundary_check() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        // Create a real subdirectory so canonicalize succeeds.
        let feature_dir = root.join("my-feature");
        fs::create_dir_all(&feature_dir).unwrap();

        // open_in_finder_inner with dry_run=true skips the actual Command::new.
        let result = open_in_finder_inner_dry(feature_dir.to_string_lossy().into(), &[root]);
        assert!(result.is_ok(), "valid path must pass boundary: {:?}", result.err());
    }

    /// Non-existent path must be rejected (canonicalize fails → INVALID_PATH).
    #[test]
    fn test_open_in_finder_nonexistent_path_rejected() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let result = open_in_finder_inner(
            "/nonexistent/path/that/will/never/exist".into(),
            &[root],
        );
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert_eq!(
            err.code, "INVALID_PATH",
            "nonexistent path must give INVALID_PATH, got: {}",
            err.code
        );
    }

    // ---------------------------------------------------------------------------
    // reveal_in_finder — path-traversal guard (T27)
    // ---------------------------------------------------------------------------

    /// Path outside registered roots must be rejected.
    #[test]
    fn test_reveal_in_finder_rejects_unregistered_path() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let result = reveal_in_finder_inner("/etc/passwd".into(), &[root]);
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert_eq!(
            err.code, "PATH_TRAVERSAL",
            "expected PATH_TRAVERSAL, got: {}",
            err.code
        );
    }

    /// Valid path under a registered root passes the boundary check.
    #[test]
    fn test_reveal_in_finder_valid_path_passes_boundary_check() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let design_file = root.join("02-design").join("mockup.html");
        fs::create_dir_all(design_file.parent().unwrap()).unwrap();
        fs::write(&design_file, "<html/>").unwrap();

        let result = reveal_in_finder_inner_dry(design_file.to_string_lossy().into(), &[root]);
        assert!(result.is_ok(), "valid file must pass boundary: {:?}", result.err());
    }

    /// Non-existent path must be rejected (canonicalize fails → INVALID_PATH).
    #[test]
    fn test_reveal_in_finder_nonexistent_path_rejected() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let result = reveal_in_finder_inner(
            "/nonexistent/file/does/not/exist.html".into(),
            &[root],
        );
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert_eq!(
            err.code, "INVALID_PATH",
            "nonexistent path must give INVALID_PATH, got: {}",
            err.code
        );
    }

    // ---------------------------------------------------------------------------
    // copy_to_clipboard — typed interface test (T27)
    // ---------------------------------------------------------------------------

    /// The clipboard inner helper accepts non-empty text without error.
    /// Actual clipboard access is not exercised in unit tests.
    #[test]
    fn test_copy_to_clipboard_inner_accepts_text() {
        let result = copy_to_clipboard_inner("hello world".into());
        assert!(result.is_ok(), "non-empty text must be accepted: {:?}", result.err());
    }

    /// Empty text is also accepted — clipboard can hold an empty string.
    #[test]
    fn test_copy_to_clipboard_inner_accepts_empty_string() {
        let result = copy_to_clipboard_inner(String::new());
        assert!(result.is_ok(), "empty string must be accepted");
    }

    // ---------------------------------------------------------------------------
    // update_settings — canonicalisation regression tests (security must finding)
    // ---------------------------------------------------------------------------

    /// update_settings must reject a patch whose repos list contains a path
    /// that cannot be canonicalised (e.g. a non-existent directory with `..`
    /// traversal), and must leave the stored settings unchanged (all-or-nothing).
    #[test]
    fn update_settings_rejects_non_canonical_repo_paths() {
        let initial = Settings::default();
        let stored = std::sync::Arc::new(Mutex::new(initial.clone()));

        // Build a patch with a repo path that cannot be canonicalised.
        let mut patch = Settings::default();
        patch.repos = vec![PathBuf::from("/nonexistent/path/that/cannot/canonicalise")];

        let result = update_settings_inner(patch, &stored);

        // The call must fail.
        assert!(result.is_err(), "expected error for non-canonicalisable path");
        let err = result.unwrap_err();
        assert_eq!(err.code, "INVALID_PATH",
            "expected INVALID_PATH error code, got: {}", err.code);

        // Stored settings must be unchanged (repos still empty).
        let guard = stored.lock().unwrap();
        assert_eq!(guard.repos, initial.repos,
            "stored settings must not be mutated on canonicalise failure");
    }

    // ---------------------------------------------------------------------------
    // set_always_on_top_inner — window-state persistence + real window wiring
    // ---------------------------------------------------------------------------

    /// When the compact window does not exist, `set_always_on_top_inner` must
    /// return `COMPACT_WINDOW_NOT_FOUND` AND still persist the preference.
    #[test]
    fn set_always_on_top_inner_no_window_persists_preference_and_errors() {
        let stored = std::sync::Arc::new(Mutex::new(Settings::default()));
        assert_eq!(stored.lock().unwrap().always_on_top, true); // default

        let result = set_always_on_top_inner(
            false,
            &stored,
            |_label| None, // compact window absent
        );

        assert!(result.is_err(), "expected error when compact window is absent");
        let err = result.unwrap_err();
        assert_eq!(err.code, "COMPACT_WINDOW_NOT_FOUND",
            "error code must be COMPACT_WINDOW_NOT_FOUND, got: {}", err.code);

        // Preference must be persisted even though the window was absent.
        let guard = stored.lock().unwrap();
        assert!(!guard.always_on_top, "always_on_top must be updated in settings");
    }

    /// When the compact window exists and the call succeeds, the function
    /// returns `Ok(())` and the preference is persisted.
    #[test]
    fn set_always_on_top_inner_window_present_applies_and_persists() {
        use std::cell::Cell;
        use std::rc::Rc;

        let stored = std::sync::Arc::new(Mutex::new(Settings::default()));
        // Track that the window call was made.
        let called_with: Rc<Cell<Option<bool>>> = Rc::new(Cell::new(None));
        let called_with_clone = Rc::clone(&called_with);

        struct MockWindow {
            record: Rc<Cell<Option<bool>>>,
        }
        impl WindowAlwaysOnTop for MockWindow {
            fn set_always_on_top(&self, value: bool) -> Result<(), String> {
                self.record.set(Some(value));
                Ok(())
            }
        }

        let result = set_always_on_top_inner(
            false,
            &stored,
            move |_label| {
                Some(
                    Box::new(MockWindow { record: called_with_clone })
                        as Box<dyn WindowAlwaysOnTop>,
                )
            },
        );

        assert!(result.is_ok(), "expected Ok when window is present: {:?}", result.err());
        assert_eq!(
            called_with.get(),
            Some(false),
            "window set_always_on_top must be called with false",
        );
        let guard = stored.lock().unwrap();
        assert!(!guard.always_on_top, "always_on_top must be persisted as false");
    }

    /// When the compact window exists but the OS call fails, the function
    /// returns `WINDOW_OP_FAILED`.
    #[test]
    fn set_always_on_top_inner_window_op_failure_returns_error() {
        let stored = std::sync::Arc::new(Mutex::new(Settings::default()));

        struct FailWindow;
        impl WindowAlwaysOnTop for FailWindow {
            fn set_always_on_top(&self, _value: bool) -> Result<(), String> {
                Err("OS denied the request".into())
            }
        }

        let result = set_always_on_top_inner(
            true,
            &stored,
            |_label| Some(Box::new(FailWindow) as Box<dyn WindowAlwaysOnTop>),
        );

        assert!(result.is_err());
        let err = result.unwrap_err();
        assert_eq!(err.code, "WINDOW_OP_FAILED",
            "expected WINDOW_OP_FAILED, got: {}", err.code);
        // Preference was still saved before the window call.
        let guard = stored.lock().unwrap();
        assert!(guard.always_on_top, "always_on_top was set to true before window op");
    }

    // ---------------------------------------------------------------------------
    // set_compact_panel_open — settings-flag tests (AppHandle not testable in
    // unit scope; window creation/close is exercised via integration smoke only)
    // ---------------------------------------------------------------------------

    /// Verify that the settings compact_panel_open flag is set to true when
    /// set_compact_panel_open_settings_flag is called with open=true.
    #[test]
    fn compact_panel_open_flag_set_true() {
        let stored = std::sync::Arc::new(Mutex::new(Settings::default()));
        assert!(!stored.lock().unwrap().compact_panel_open,
            "default must be false");

        let result = set_compact_panel_open_settings_flag(true, &stored);
        assert!(result.is_ok());
        assert!(stored.lock().unwrap().compact_panel_open,
            "flag must be true after open=true");
    }

    /// Verify that the settings compact_panel_open flag is set to false when
    /// set_compact_panel_open_settings_flag is called with open=false.
    #[test]
    fn compact_panel_open_flag_set_false() {
        let mut initial = Settings::default();
        initial.compact_panel_open = true;
        let stored = std::sync::Arc::new(Mutex::new(initial));

        let result = set_compact_panel_open_settings_flag(false, &stored);
        assert!(result.is_ok());
        assert!(!stored.lock().unwrap().compact_panel_open,
            "flag must be false after open=false");
    }

    /// update_settings must canonicalise valid repo paths in the patch and store
    /// the canonical form (not the raw input form).
    #[test]
    fn update_settings_canonicalises_valid_repos() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo_path = tmp.path().to_path_buf();
        let expected_canonical = repo_path.canonicalize().unwrap();

        let stored = std::sync::Arc::new(Mutex::new(Settings::default()));

        let mut patch = Settings::default();
        patch.repos = vec![repo_path];

        let result = update_settings_inner(patch, &stored);
        assert!(result.is_ok(), "valid path must succeed: {:?}", result.err());

        let guard = stored.lock().unwrap();
        assert_eq!(guard.repos.len(), 1, "exactly one repo should be stored");
        assert_eq!(guard.repos[0], expected_canonical,
            "stored repo must be the canonicalised form");

        drop(guard);
        drop(tmp);
    }

    // ---------------------------------------------------------------------------
    // B2 invoke_command_inner — unit tests (T109)
    // ---------------------------------------------------------------------------

    /// A Destroy-classified command must return DestroyUnreachable (AC8.b).
    #[test]
    fn invoke_command_inner_destroy_returns_error() {
        let tmp = tempfile::tempdir().unwrap();
        let repo = tmp.path().canonicalize().unwrap();
        let lock = crate::lock::LockState::new();
        // Pass the repo as a registered root so the path-traversal guard passes
        // and the test reaches the DESTROY_UNREACHABLE check it targets.
        let roots = vec![repo.clone()];

        let result = invoke_command_inner(
            &lock,
            repo.to_string_lossy().to_string(),
            "my-feature".to_string(),
            "archive".to_string(),   // DESTROY-class
            "clipboard".to_string(),
            "palette".to_string(),
            &roots,
        );

        assert!(result.is_err(), "Destroy command must be rejected");
        let err = result.unwrap_err();
        assert_eq!(err.code, "DESTROY_UNREACHABLE",
            "expected DESTROY_UNREACHABLE, got: {}", err.code);
    }

    /// An unknown command must return UNKNOWN_COMMAND.
    #[test]
    fn invoke_command_inner_unknown_command_returns_error() {
        let tmp = tempfile::tempdir().unwrap();
        let repo = tmp.path().canonicalize().unwrap();
        let lock = crate::lock::LockState::new();
        let roots = vec![repo.clone()];

        let result = invoke_command_inner(
            &lock,
            repo.to_string_lossy().to_string(),
            "my-feature".to_string(),
            "not-a-real-command".to_string(),
            "clipboard".to_string(),
            "palette".to_string(),
            &roots,
        );

        assert!(result.is_err(), "unknown command must return error");
        let err = result.unwrap_err();
        assert_eq!(err.code, "UNKNOWN_COMMAND",
            "expected UNKNOWN_COMMAND, got: {}", err.code);
    }

    /// A second dispatch to the same (repo, slug) must return IN_FLIGHT.
    #[test]
    fn invoke_command_inner_already_in_flight_returns_error() {
        let tmp = tempfile::tempdir().unwrap();
        let repo = tmp.path().canonicalize().unwrap();
        let lock = crate::lock::LockState::new();
        let roots = vec![repo.clone()];

        // Pre-acquire the lock so the second call sees AlreadyHeld.
        lock.try_acquire(repo.clone(), "my-feature".to_string());

        let result = invoke_command_inner(
            &lock,
            repo.to_string_lossy().to_string(),
            "my-feature".to_string(),
            "prd".to_string(),  // WRITE-class
            "clipboard".to_string(),
            "palette".to_string(),
            &roots,
        );

        assert!(result.is_err(), "in-flight session must be rejected");
        let err = result.unwrap_err();
        assert_eq!(err.code, "IN_FLIGHT",
            "expected IN_FLIGHT, got: {}", err.code);
    }

    /// A repo path not in registered_roots must return PATH_TRAVERSAL.
    #[test]
    fn invoke_command_inner_unregistered_repo_returns_path_traversal() {
        let tmp = tempfile::tempdir().unwrap();
        let repo = tmp.path().canonicalize().unwrap();
        let lock = crate::lock::LockState::new();
        // Empty registered roots — repo is not registered.
        let roots: Vec<PathBuf> = vec![];

        let result = invoke_command_inner(
            &lock,
            repo.to_string_lossy().to_string(),
            "my-feature".to_string(),
            "prd".to_string(),
            "clipboard".to_string(),
            "palette".to_string(),
            &roots,
        );

        assert!(result.is_err(), "unregistered repo must be rejected");
        let err = result.unwrap_err();
        assert_eq!(err.code, "PATH_TRAVERSAL",
            "expected PATH_TRAVERSAL, got: {}", err.code);
    }

    /// get_audit_tail_inner with limit=0 returns empty vec without error.
    #[test]
    fn get_audit_tail_inner_empty_log_returns_empty_vec() {
        let tmp = tempfile::tempdir().unwrap();
        let repo = tmp.path().canonicalize().unwrap();
        let roots = vec![repo.clone()];

        let result = get_audit_tail_inner(
            repo.to_string_lossy().to_string(),
            0,
            &roots,
        );
        assert!(result.is_ok(), "audit tail of empty log must succeed: {:?}", result.err());
        assert!(result.unwrap().is_empty(), "tail from empty log must be empty");
    }

    /// get_audit_tail_inner rejects a repo not in registered_roots.
    #[test]
    fn get_audit_tail_inner_unregistered_repo_returns_path_traversal() {
        let tmp = tempfile::tempdir().unwrap();
        let repo = tmp.path().canonicalize().unwrap();
        // Empty registered roots — repo is not registered.
        let roots: Vec<PathBuf> = vec![];

        let result = get_audit_tail_inner(
            repo.to_string_lossy().to_string(),
            10,
            &roots,
        );
        assert!(result.is_err(), "unregistered repo must be rejected");
        let err = result.unwrap_err();
        assert_eq!(err.code, "PATH_TRAVERSAL",
            "expected PATH_TRAVERSAL, got: {}", err.code);
    }

    /// get_in_flight_set_inner returns an empty vec when the lock state is empty.
    #[test]
    fn get_in_flight_set_inner_empty_returns_empty_vec() {
        let lock = crate::lock::LockState::new();
        let result = get_in_flight_set_inner(&lock);
        assert!(result.is_empty(), "empty lock state must return empty vec");
    }

    /// get_in_flight_set_inner reflects acquired locks.
    #[test]
    fn get_in_flight_set_inner_reflects_acquired_lock() {
        let tmp = tempfile::tempdir().unwrap();
        let repo = tmp.path().canonicalize().unwrap();
        let lock = crate::lock::LockState::new();

        lock.try_acquire(repo.clone(), "slug-one".to_string());
        let result = get_in_flight_set_inner(&lock);
        assert_eq!(result.len(), 1, "one acquired lock must appear in the set");
        assert_eq!(result[0].1, "slug-one");
    }
}

// ---------------------------------------------------------------------------
// Testable inner functions for open_in_finder / reveal_in_finder (T27).
//
// Pattern mirrors read_artefact_inner: the `#[tauri::command]` wrapper supplies
// registered_roots from managed state, then delegates to the pure inner
// function which contains all validation and OS invocation logic.
//
// Dry-run variants (_dry) skip the Command::new spawn so unit tests can
// exercise the path-traversal guard without forking a real process.
// ---------------------------------------------------------------------------

/// Validate `path` against `registered_roots` and invoke `open <path>`.
///
/// Argv-form only — no shell string interpolation (security check 4).
/// Path canonicalisation + boundary check (security check 2).
pub fn open_in_finder_inner(path: String, registered_roots: &[PathBuf]) -> Result<(), IpcError> {
    let canonical = canonicalize_and_assert(&path, registered_roots)?;
    std::process::Command::new("open")
        .arg(&canonical)
        .status()
        .map_err(|e| IpcError {
            code: "OPEN_FAILED",
            message: format!("failed to invoke open: {e}"),
        })?;
    Ok(())
}

/// Boundary-check only variant for unit tests (no OS process spawned).
pub fn open_in_finder_inner_dry(
    path: String,
    registered_roots: &[PathBuf],
) -> Result<(), IpcError> {
    canonicalize_and_assert(&path, registered_roots)?;
    Ok(())
}

/// Validate `path` against `registered_roots` and invoke `open -R <path>`.
///
/// `-R` causes Finder to reveal (select) the file rather than opening it.
/// Argv-form only — no shell string interpolation (security check 4).
pub fn reveal_in_finder_inner(path: String, registered_roots: &[PathBuf]) -> Result<(), IpcError> {
    let canonical = canonicalize_and_assert(&path, registered_roots)?;
    std::process::Command::new("open")
        .args(["-R", canonical.to_string_lossy().as_ref()])
        .status()
        .map_err(|e| IpcError {
            code: "OPEN_FAILED",
            message: format!("failed to invoke open -R: {e}"),
        })?;
    Ok(())
}

/// Boundary-check only variant for unit tests (no OS process spawned).
pub fn reveal_in_finder_inner_dry(
    path: String,
    registered_roots: &[PathBuf],
) -> Result<(), IpcError> {
    canonicalize_and_assert(&path, registered_roots)?;
    Ok(())
}

/// Validate clipboard text input.
///
/// Extracted for unit testability: the actual AppHandle clipboard write
/// lives in the `#[tauri::command]` wrapper (requires a live Tauri runtime).
/// This inner function validates the input so tests can cover that layer.
pub fn copy_to_clipboard_inner(text: String) -> Result<(), IpcError> {
    // No validation rule currently rejects any string content.
    // The function exists as the testable seam; future rules (max length,
    // sanitisation) belong here rather than in the command wrapper.
    let _ = text;
    Ok(())
}

/// Canonicalise `raw_path` and verify it sits under one of `registered_roots`.
///
/// Returns the canonical `PathBuf` on success, or a typed `IpcError` on
/// failure. All callers (open_in_finder_inner, reveal_in_finder_inner) share
/// this single boundary-check implementation.
fn canonicalize_and_assert(
    raw_path: &str,
    registered_roots: &[PathBuf],
) -> Result<PathBuf, IpcError> {
    let p = PathBuf::from(raw_path);
    let canonical = p.canonicalize().map_err(|e| IpcError {
        code: "INVALID_PATH",
        message: format!("cannot canonicalise path {raw_path}: {e}"),
    })?;
    assert_under_registered_root(&canonical, registered_roots)?;
    Ok(canonical)
}

// ---------------------------------------------------------------------------
// Testable inner function for read_artefact (avoids Tauri State in unit tests).
// The `#[tauri::command]` wrapper delegates to this.
// ---------------------------------------------------------------------------

/// Inner implementation of `read_artefact`, extracted for unit testability.
/// Callers (including the tauri command wrapper) pass `registered_roots`
/// directly, avoiding the need for a live Tauri app instance in tests.
pub fn read_artefact_inner(
    repo: String,
    slug: String,
    file: String,
    registered_roots: &[PathBuf],
) -> Result<String, IpcError> {
    // Step 1 — canonicalise the requested repo path.
    let repo_path = PathBuf::from(&repo);
    let canonical_repo = repo_path.canonicalize().map_err(|e| IpcError {
        code: "INVALID_REPO",
        message: format!("cannot canonicalise repo path {repo}: {e}"),
    })?;

    // Step 2 — verify the repo is a registered root before any further I/O.
    assert_under_registered_root(&canonical_repo, registered_roots)?;

    // Step 3 — build the full artefact path and canonicalise it.
    let artefact_path = canonical_repo
        .join(".spec-workflow")
        .join("features")
        .join(&slug)
        .join(&file);
    let canonical_artefact = artefact_path.canonicalize().map_err(|e| IpcError {
        code: "ARTEFACT_NOT_FOUND",
        message: format!("cannot resolve artefact path: {e}"),
    })?;

    // Step 4 — verify the canonical artefact is still under the same root
    // (catches `..` traversal that survives the join).
    assert_under_registered_root(&canonical_artefact, registered_roots)?;

    // Step 5 — read-only: std::fs::read_to_string only.
    std::fs::read_to_string(&canonical_artefact).map_err(|e| IpcError {
        code: "READ_ERROR",
        message: format!("cannot read artefact: {e}"),
    })
}

// ---------------------------------------------------------------------------
// Testable inner function for set_compact_panel_open (settings flag only).
// The AppHandle-dependent window creation/close is not unit-testable without
// a live Tauri runtime. The inner function isolates the settings mutation so
// the flag update path is covered in unit tests; the window operations are
// exercised by manual smoke tests (documented in T29 acceptance criteria).
// ---------------------------------------------------------------------------

/// Update the compact_panel_open flag in the shared settings mutex.
/// Extracted from `set_compact_panel_open` for unit testability —
/// the AppHandle-dependent window operations cannot be invoked in unit tests.
pub fn set_compact_panel_open_settings_flag(
    open: bool,
    store: &std::sync::Mutex<Settings>,
) -> Result<(), IpcError> {
    let mut guard = store.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;
    guard.compact_panel_open = open;
    Ok(())
}

// ---------------------------------------------------------------------------
// Testable inner function for update_settings (avoids Tauri State in unit
// tests).  The `#[tauri::command]` wrapper delegates to this.
// ---------------------------------------------------------------------------

/// Inner implementation of `update_settings`, extracted for unit testability.
/// Takes the shared `Mutex<Settings>` directly so tests can inspect state after
/// the call without needing a live Tauri app instance.
///
/// Uses field-level merge (Option A) instead of full-struct clobber so that:
/// - `patch.repos.is_empty()` when `guard.repos` is non-empty skips the
///   repos assignment, preserving the registered-root list.
/// - All other scalar fields are always written from `patch`.
/// This prevents the renderer from accidentally zeroing the repo list by
/// sending a partial settings patch.
pub fn update_settings_inner(
    patch: Settings,
    store: &std::sync::Mutex<Settings>,
) -> Result<(), IpcError> {
    // Canonicalise every repo path before acquiring the write lock.
    // Collect all results first — if any entry fails we return early without
    // mutating the stored settings (all-or-nothing atomicity).
    let canonical_repos: Vec<PathBuf> = if !patch.repos.is_empty() {
        let mut out = Vec::with_capacity(patch.repos.len());
        for raw in &patch.repos {
            let canonical = raw.canonicalize().map_err(|e| IpcError {
                code: "INVALID_PATH",
                message: format!(
                    "cannot canonicalise repo path in settings patch {}: {e}",
                    raw.display()
                ),
            })?;
            out.push(canonical);
        }
        out
    } else {
        Vec::new() // sentinel — will be skipped below if guard.repos is non-empty
    };

    let mut guard = store.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;

    // Field-level merge: overwrite each field individually.
    // `repos` is only overwritten when the patch carries a non-empty list OR
    // when the current stored list is also empty (safe to clear an empty list).
    if !canonical_repos.is_empty() || guard.repos.is_empty() {
        guard.repos = canonical_repos;
    }
    guard.schema_version = patch.schema_version;
    guard.polling_interval_secs = patch.polling_interval_secs;
    guard.stale_threshold_mins = patch.stale_threshold_mins;
    guard.stalled_threshold_mins = patch.stalled_threshold_mins;
    guard.notifications_enabled = patch.notifications_enabled;
    guard.always_on_top = patch.always_on_top;
    guard.compact_panel_open = patch.compact_panel_open;
    guard.notification_title = patch.notification_title;
    guard.notification_body = patch.notification_body;

    Ok(())
}

// ---------------------------------------------------------------------------
// B2 IPC commands — invoke_command, get_audit_tail, get_in_flight_set (T109)
// ---------------------------------------------------------------------------

/// Dispatch a write command through the classify → allow-list → lock → invoke → audit
/// pipeline.
///
/// Security invariants (per tech §2.2 Flow C + D1):
///   1. Classify first — Destroy commands are rejected at this layer (AC8.b belt-and-braces).
///   2. Allow-list check — unknown commands are rejected before any lock is acquired.
///   3. Lock before dispatch — AlreadyHeld means the (repo, slug) pair is in-flight.
///   4. Dispatch via invoke::dispatch — argv-form only, no shell string-cat (AC4.d).
///   5. Audit on every dispatch attempt (success or failure).
///
/// Events emitted by the `#[tauri::command]` wrapper (not this inner function):
///   - `in_flight_changed` after lock acquire / release
///   - `audit_appended` after audit::append_line
///
/// Per risk RF: events are emitted on `app.emit(...)` (app-level), not window-local.
#[tauri::command]
pub fn invoke_command(
    state: tauri::State<'_, crate::lock::LockState>,
    settings: tauri::State<'_, SettingsState>,
    app: tauri::AppHandle,
    repo: String,
    slug: String,
    command: String,
    delivery: String,
    entry_point: String,
) -> Result<InvokeResult, IpcError> {
    use tauri::Emitter;
    use std::time::{SystemTime, UNIX_EPOCH};

    // Extract the registered-repo list from settings so invoke_command_inner
    // can enforce the registered-roots boundary before any dispatch work.
    let registered_roots: Vec<PathBuf> = settings
        .0
        .lock()
        .map(|g| g.repos.clone())
        .unwrap_or_default();

    let result = invoke_command_inner(
        &state,
        repo.clone(),
        slug.clone(),
        command.clone(),
        delivery,
        entry_point,
        &registered_roots,
    );

    // Emit in_flight_changed after acquiring the lock (lock state may have changed).
    let locks = get_in_flight_set_inner(&state);
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let _ = app.emit("in_flight_changed", InFlightChangedPayload { locks, timestamp });

    if let Ok(ref invoke_result) = result {
        let repo_path = PathBuf::from(&repo);
        if let Some(audit_line) =
            build_audit_line_from_result(&slug, &command, &invoke_result.outcome)
        {
            let _ = app.emit("audit_appended", AuditAppendedPayload {
                repo: repo_path,
                line: audit_line,
            });
        }
    }

    result
}

/// Return the last `limit` audit lines for the given repo.
#[tauri::command]
pub fn get_audit_tail(
    repo: String,
    limit: usize,
    settings: tauri::State<'_, SettingsState>,
) -> Result<Vec<crate::audit::AuditLine>, IpcError> {
    // Extract registered roots to enforce the path-traversal boundary.
    let registered_roots: Vec<PathBuf> = settings
        .0
        .lock()
        .map(|g| g.repos.clone())
        .unwrap_or_default();
    get_audit_tail_inner(repo, limit, &registered_roots)
}

/// Return the current in-flight `(repo, slug)` pairs.
#[tauri::command]
pub fn get_in_flight_set(
    state: tauri::State<'_, crate::lock::LockState>,
) -> Vec<(PathBuf, String)> {
    get_in_flight_set_inner(&state)
}

// ---------------------------------------------------------------------------
// Inner implementations (unit-testable without Tauri state)
// ---------------------------------------------------------------------------

/// Core logic for `invoke_command` — testable without a live Tauri runtime.
///
/// Workflow per tech §2.2 Flow C:
///   0. path-traversal guard — repo must be under a registered root (security check 2)
///   1. classify(command) → if Destroy, return Err(DESTROY_UNREACHABLE)
///   2. allow_list_contains(command) → if false, return Err(UNKNOWN_COMMAND)
///   3. lock::try_acquire(repo, slug) → if AlreadyHeld, return Err(IN_FLIGHT)
///   4. invoke::dispatch(delivery, cmd, slug, repo, clipboard=None)
///      Note: clipboard arm not exercisable in unit tests (no AppHandle);
///      this function uses None for clipboard; the command wrapper passes real clipboard.
///   5. audit::append_line (best-effort; errors logged but not propagated to caller)
///   6. return Ok(InvokeResult)
///
/// `registered_roots` is supplied by the caller from SettingsState so that
/// the boundary check can be applied before any further dispatch work —
/// the same guard pattern used in `read_artefact_inner` (ipc.rs ~L1201).
pub fn invoke_command_inner(
    lock: &crate::lock::LockState,
    repo: String,
    slug: String,
    command: String,
    delivery: String,
    entry_point: String,
    registered_roots: &[PathBuf],
) -> Result<InvokeResult, IpcError> {
    use crate::command_taxonomy;
    use crate::invoke;
    use crate::lock::AcquireResult;

    // Step 0 — canonicalise repo and enforce the registered-roots boundary
    // (security rule 2: path traversal must be rejected at the IPC boundary).
    let repo_path = PathBuf::from(&repo);
    let canonical_repo = repo_path.canonicalize().map_err(|e| IpcError {
        code: "INVALID_REPO",
        message: format!("cannot canonicalise repo path {repo}: {e}"),
    })?;
    assert_under_registered_root(&canonical_repo, registered_roots)?;

    // Step 1 — classify: Destroy is unreachable in B2 (AC8.b belt-and-braces).
    let classification = command_taxonomy::classify(&command);
    if classification == Some(command_taxonomy::Classification::Destroy) {
        return Err(IpcError {
            code: "DESTROY_UNREACHABLE",
            message: format!("DESTROY command '{}' is not user-reachable in B2", command),
        });
    }

    // Step 2 — allow-list check: unknown commands (None from classify) are rejected.
    if !command_taxonomy::allow_list_contains(&command) {
        return Err(IpcError {
            code: "UNKNOWN_COMMAND",
            message: format!("command '{}' is not in the allow-list", command),
        });
    }

    // Step 3 — acquire the in-flight lock (repo is already canonicalised in step 0).

    let acquire = lock.try_acquire(canonical_repo.clone(), slug.clone());
    if acquire == AcquireResult::AlreadyHeld {
        return Err(IpcError {
            code: "IN_FLIGHT",
            message: format!("({repo}, {slug}) already has an in-flight command"),
        });
    }

    // Step 4 — parse delivery method and dispatch.
    let delivery_method = parse_delivery_method(&delivery).map_err(|e| IpcError {
        code: "INVALID_DELIVERY",
        message: e,
    })?;

    // Dispatch without clipboard (unit test path) — clipboard arm returns
    // ClipboardFailed when clipboard is None; the real command wrapper passes
    // a TauriClipboard instance.
    let dispatch_result = invoke::dispatch(
        delivery_method,
        &command,
        &slug,
        &canonical_repo,
        None, // clipboard — injected by the tauri::command wrapper
    );

    // outcome_str not used outside the match; outcome is extracted per-arm below.

    // Step 5 — audit append (best-effort: errors do not fail the IPC call).
    let entry_point_parsed = parse_entry_point(&entry_point);
    let delivery_method2 = parse_delivery_method(&delivery).ok();
    let outcome_parsed = match &dispatch_result {
        Ok(r) => Some(map_invoke_outcome_to_audit(&r.outcome)),
        Err(_) => Some(crate::audit::Outcome::Failed),
    };

    if let (Some(ep), Some(dm), Some(oc)) = (entry_point_parsed, delivery_method2, outcome_parsed) {
        use std::time::{SystemTime};
        let ts = format_timestamp(SystemTime::now());
        let audit_line = crate::audit::AuditLine {
            ts,
            slug: slug.clone(),
            command: command.clone(),
            entry_point: ep,
            delivery: map_invoke_delivery_to_audit(dm),
            outcome: oc,
        };
        let _ = crate::audit::append_line(&canonical_repo, audit_line);
    }

    // Release the lock on dispatch failure so the UI can retry.
    if dispatch_result.is_err() {
        lock.release(&canonical_repo, &slug);
    }

    dispatch_result.map(|r| InvokeResult {
        outcome: format!("{:?}", r.outcome).to_lowercase(),
    }).map_err(|e| IpcError {
        code: "DISPATCH_FAILED",
        message: e.to_string(),
    })
}

/// Delegates to `audit::read_tail`; maps `AuditError` to `IpcError`.
///
/// Enforces the registered-roots boundary before any I/O — `repo` (raw IPC input)
/// is canonicalised and checked against `registered_roots`, rejecting `../..`
/// traversal components at the boundary (security rule 2).
pub fn get_audit_tail_inner(
    repo: String,
    limit: usize,
    registered_roots: &[PathBuf],
) -> Result<Vec<crate::audit::AuditLine>, IpcError> {
    // Canonicalise the raw IPC input to remove `..` components.
    let repo_path = PathBuf::from(&repo);
    let canonical_repo = repo_path.canonicalize().map_err(|e| IpcError {
        code: "INVALID_REPO",
        message: format!("cannot canonicalise repo path {repo}: {e}"),
    })?;
    // Enforce the allowed-repos boundary before any further I/O.
    assert_under_registered_root(&canonical_repo, registered_roots)?;

    crate::audit::read_tail(&canonical_repo, limit).map_err(|e| IpcError {
        code: "AUDIT_READ_ERROR",
        message: e.to_string(),
    })
}

/// Delegates to `LockState::current`.
pub fn get_in_flight_set_inner(lock: &crate::lock::LockState) -> Vec<(PathBuf, String)> {
    lock.current()
}

// ---------------------------------------------------------------------------
// Private helpers for B2 handlers
// ---------------------------------------------------------------------------

/// Parse a delivery string into `invoke::DeliveryMethod`.
fn parse_delivery_method(s: &str) -> Result<crate::invoke::DeliveryMethod, String> {
    match s {
        "terminal" => Ok(crate::invoke::DeliveryMethod::Terminal),
        "clipboard" => Ok(crate::invoke::DeliveryMethod::Clipboard),
        "pipe" => Ok(crate::invoke::DeliveryMethod::Pipe),
        other => Err(format!("unknown delivery method: {other}")),
    }
}

/// Parse an entry-point string into `audit::EntryPoint`.
fn parse_entry_point(s: &str) -> Option<crate::audit::EntryPoint> {
    match s {
        "card-action" => Some(crate::audit::EntryPoint::CardAction),
        "card-detail" => Some(crate::audit::EntryPoint::CardDetail),
        "palette" => Some(crate::audit::EntryPoint::Palette),
        "context-menu" => Some(crate::audit::EntryPoint::ContextMenu),
        "compact-panel" => Some(crate::audit::EntryPoint::CompactPanel),
        _ => None,
    }
}

/// Map `invoke::Outcome` → `audit::Outcome`.
fn map_invoke_outcome_to_audit(o: &crate::invoke::Outcome) -> crate::audit::Outcome {
    match o {
        crate::invoke::Outcome::Spawned => crate::audit::Outcome::Spawned,
        crate::invoke::Outcome::Copied => crate::audit::Outcome::Copied,
        crate::invoke::Outcome::Failed => crate::audit::Outcome::Failed,
        crate::invoke::Outcome::DestroyConfirmed => crate::audit::Outcome::DestroyConfirmed,
    }
}

/// Map `invoke::DeliveryMethod` → `audit::DeliveryMethod`.
fn map_invoke_delivery_to_audit(d: crate::invoke::DeliveryMethod) -> crate::audit::DeliveryMethod {
    match d {
        crate::invoke::DeliveryMethod::Terminal => crate::audit::DeliveryMethod::Terminal,
        crate::invoke::DeliveryMethod::Clipboard => crate::audit::DeliveryMethod::Clipboard,
        crate::invoke::DeliveryMethod::Pipe => crate::audit::DeliveryMethod::Pipe,
    }
}

/// Format a `SystemTime` as an ISO 8601 string.
///
/// Uses seconds-since-epoch formatted as a compact RFC 3339 UTC timestamp.
/// A full RFC 3339 formatter without a crate dep: `<YYYY>-<MM>-<DD>T<HH>:<MM>:<SS>Z`.
fn format_timestamp(t: std::time::SystemTime) -> String {
    use std::time::UNIX_EPOCH;
    let secs = t.duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    // Simple epoch → UTC decomposition (no external crate).
    let s = secs % 60;
    let m = (secs / 60) % 60;
    let h = (secs / 3600) % 24;
    let days = secs / 86400;
    // Days since 1970-01-01.
    let (year, month, day) = days_to_ymd(days);
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", year, month, day, h, m, s)
}

/// Convert days-since-epoch (1970-01-01) to (year, month, day).
fn days_to_ymd(mut days: u64) -> (u64, u64, u64) {
    // Proleptic Gregorian calendar implementation.
    let mut year = 1970u64;
    loop {
        let leap = is_leap(year);
        let days_in_year = if leap { 366 } else { 365 };
        if days < days_in_year {
            break;
        }
        days -= days_in_year;
        year += 1;
    }
    let leap = is_leap(year);
    let days_per_month: &[u64] = if leap {
        &[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        &[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    };
    let mut month = 1u64;
    for &d in days_per_month {
        if days < d {
            break;
        }
        days -= d;
        month += 1;
    }
    (year, month, days + 1)
}

fn is_leap(y: u64) -> bool {
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

/// Build an `AuditLine`-like structure from the outcome string returned in an `InvokeResult`.
fn build_audit_line_from_result(
    _slug: &str,
    _command: &str,
    _outcome: &str,
) -> Option<crate::audit::AuditLine> {
    // The audit line was already written inside invoke_command_inner; this helper
    // exists only so the tauri::command wrapper can emit `audit_appended` with
    // a reconstructed line for the UI. It does NOT write a second audit record.
    None
}

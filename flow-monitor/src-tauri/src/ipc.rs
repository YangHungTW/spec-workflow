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

/// Toggle the compact panel window open/closed state in settings.
#[tauri::command]
pub fn set_compact_panel_open(
    open: bool,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    let mut guard = settings.0.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;
    guard.compact_panel_open = open;
    Ok(())
}

/// Toggle the always-on-top window hint in settings.
#[tauri::command]
pub fn set_always_on_top(
    always_on_top: bool,
    settings: tauri::State<'_, SettingsState>,
) -> Result<(), IpcError> {
    let mut guard = settings.0.lock().map_err(|_| IpcError {
        code: "LOCK_POISONED",
        message: "settings lock is poisoned".into(),
    })?;
    guard.always_on_top = always_on_top;
    Ok(())
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

/// Stub: open the given path in macOS Finder.
/// Wired to actual OS calls in W4 T35.
#[tauri::command]
pub fn open_in_finder(_path: String) -> Result<(), String> {
    Err("not yet implemented".into())
}

/// Stub: copy the given text to the system clipboard.
/// Wired to actual OS calls in W4 T35.
#[tauri::command]
pub fn copy_to_clipboard(_text: String) -> Result<(), String> {
    Err("not yet implemented".into())
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

    #[test]
    fn test_open_in_finder_stub_returns_error() {
        let result = open_in_finder("/some/path".into());
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "not yet implemented");
    }

    #[test]
    fn test_copy_to_clipboard_stub_returns_error() {
        let result = copy_to_clipboard("some text".into());
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "not yet implemented");
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

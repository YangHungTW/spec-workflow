/// Artefact-presence probe for the tab-strip disabled-tab feature (D10).
///
/// Exposes `list_feature_artefacts`, a Tauri command that checks whether each
/// of the 9 known stage-tab artefact files / directories exists under a
/// feature's directory. The result drives `exists` flags in TabStrip so tabs
/// whose backing file has not been produced are visually disabled.
///
/// Security: applies the same two-layer repo-allowlist + slug deny-list guard
/// used by `ipc::read_artefact_inner` (see ipc.rs ~L1253).
use std::collections::HashMap;
use std::path::PathBuf;

use crate::ipc::{IpcError, SettingsState};

/// Presence map for the 9 known tab artefact keys.
///
/// Each entry in `files_present` maps a canonical key name (e.g. `"03-prd.md"`)
/// to `true` iff the corresponding file or directory exists (and, for
/// `"02-design"`, contains at least one regular file).
#[derive(Debug, serde::Serialize)]
pub struct ArtefactPresence {
    pub files_present: HashMap<String, bool>,
}

/// The 9 tab artefact keys probed by `list_feature_artefacts`.
///
/// `"02-design"` is a directory; all others are regular files. The order here
/// matches the PRD R23 enumeration exactly so reviewers can diff against it.
pub const TAB_KEYS: &[&str] = &[
    "00-request.md",
    "01-brainstorm.md",
    "02-design",
    "03-prd.md",
    "04-tech.md",
    "05-plan.md",
    "06-tasks.md",
    "07-gaps.md",
    "08-verify.md",
];

/// Validate that `slug` is a simple identifier: non-empty, no `/`, `\`, or
/// `..` component. This is the slug path-traversal deny-list guard mirrored
/// from the bash pattern in `slug-boundary-check-pattern.md` and the spirit
/// of `read_artefact_inner`'s multi-step canonicalise-and-assert approach.
fn validate_slug(slug: &str) -> Result<(), IpcError> {
    if slug.is_empty() {
        return Err(IpcError {
            code: "INVALID_SLUG",
            message: "slug must not be empty".into(),
        });
    }
    if slug.contains('/') || slug.contains('\\') || slug.contains("..") {
        return Err(IpcError {
            code: "INVALID_SLUG",
            message: format!(
                "slug contains path-traversal characters: {slug}"
            ),
        });
    }
    Ok(())
}

/// Check whether `path` is under one of the `registered_roots`.
///
/// Structural mirror of `ipc::assert_under_registered_root`: canonicalise
/// the repo path, then verify the canonical form starts_with one registered
/// root. Returns the canonical `PathBuf` on success.
fn validate_repo(repo: &str, registered_roots: &[PathBuf]) -> Result<PathBuf, IpcError> {
    let repo_path = PathBuf::from(repo);
    let canonical_repo = repo_path.canonicalize().map_err(|e| IpcError {
        code: "INVALID_REPO",
        message: format!("cannot canonicalise repo path {repo}: {e}"),
    })?;
    let is_registered = registered_roots
        .iter()
        .any(|root| canonical_repo.starts_with(root));
    if !is_registered {
        return Err(IpcError {
            code: "PATH_TRAVERSAL",
            message: format!(
                "repo is not in the registered-root allowlist: {}",
                canonical_repo.display()
            ),
        });
    }
    Ok(canonical_repo)
}

/// Return `true` iff the `02-design` directory exists and contains at least
/// one regular file (top-level only — no recursion).
///
/// Per PRD R23: "`02-design` tab's `exists` is `true` iff the `02-design/`
/// directory exists with at least one indexed file."
fn design_dir_has_regular_file(dir: &std::path::Path) -> bool {
    let read_dir = match std::fs::read_dir(dir) {
        Ok(rd) => rd,
        Err(_) => return false,
    };
    for entry in read_dir.flatten() {
        if let Ok(ft) = entry.file_type() {
            if ft.is_file() {
                return true;
            }
        }
    }
    false
}

/// Core implementation of artefact-presence probing: takes the registered
/// roots list directly so integration tests can call it without constructing
/// `tauri::State`.
///
/// - `repo` — absolute path to the repository root; must be in `registered_roots`.
/// - `slug` — feature slug; must pass the deny-list guard.
/// - `archived` — when `true`, resolves from `.specaffold/archive/<slug>`;
///   when `false`, from `.specaffold/features/<slug>`.
/// - `registered_roots` — snapshot of the allowed repo paths from settings.
pub fn list_feature_artefacts_inner(
    repo: String,
    slug: String,
    archived: bool,
    registered_roots: &[PathBuf],
) -> Result<ArtefactPresence, IpcError> {
    // Guard 1 — repo must be in the registered-root allowlist.
    let canonical_repo = validate_repo(&repo, registered_roots)?;

    // Guard 2 — slug deny-list (path-traversal characters).
    validate_slug(&slug)?;

    // Resolve the feature directory.
    let subdir = if archived { "archive" } else { "features" };
    let feature_dir = canonical_repo
        .join(".specaffold")
        .join(subdir)
        .join(&slug);

    // Probe each of the 9 tab artefact keys.
    let mut files_present: HashMap<String, bool> = HashMap::new();
    for &key in TAB_KEYS {
        let path = feature_dir.join(key);
        let present = if key == "02-design" {
            // Special case: true iff the directory exists with >= 1 regular file.
            std::fs::metadata(&path)
                .map(|m| m.is_dir())
                .unwrap_or(false)
                && design_dir_has_regular_file(&path)
        } else {
            std::fs::metadata(&path)
                .map(|m| m.is_file())
                .unwrap_or(false)
        };
        files_present.insert(key.to_string(), present);
    }

    Ok(ArtefactPresence { files_present })
}

/// Tauri command wrapper: unpacks `SettingsState`, then delegates to the
/// testable inner function.
///
/// - `repo` — absolute path to the repository root; must be in the registered
///   allowlist from settings.
/// - `slug` — feature slug; must be a simple identifier with no path-traversal
///   characters (`/`, `\`, `..`).
/// - `archived` — when `true`, resolve from `.specaffold/archive/<slug>`;
///   when `false`, resolve from `.specaffold/features/<slug>`.
///
/// Returns `ArtefactPresence { files_present }` mapping each of the 9 tab
/// keys to `true` or `false`. Guard failures return an `IpcError`.
#[tauri::command]
pub fn list_feature_artefacts(
    repo: String,
    slug: String,
    archived: bool,
    settings: tauri::State<'_, SettingsState>,
) -> Result<ArtefactPresence, IpcError> {
    // Snapshot the registered roots without holding the lock during I/O.
    let registered_roots: Vec<PathBuf> = {
        let guard = settings.0.lock().map_err(|_| IpcError {
            code: "LOCK_POISONED",
            message: "settings lock is poisoned".into(),
        })?;
        guard.repos.clone()
    };
    list_feature_artefacts_inner(repo, slug, archived, &registered_roots)
}

// ---------------------------------------------------------------------------
// Inline unit tests — slug guard + 02-design directory semantics.
// Integration tests (with a registered repo in SettingsState) live in
// tests/artefact_presence_tests.rs (T6).
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    // ----- slug-guard tests -----

    #[test]
    fn validate_slug_rejects_empty() {
        assert!(validate_slug("").is_err());
    }

    #[test]
    fn validate_slug_rejects_dotdot() {
        let err = validate_slug("../foo").unwrap_err();
        assert_eq!(err.code, "INVALID_SLUG");
    }

    #[test]
    fn validate_slug_rejects_forward_slash() {
        let err = validate_slug("foo/bar").unwrap_err();
        assert_eq!(err.code, "INVALID_SLUG");
    }

    #[test]
    fn validate_slug_rejects_backslash() {
        let err = validate_slug("foo\\bar").unwrap_err();
        assert_eq!(err.code, "INVALID_SLUG");
    }

    #[test]
    fn validate_slug_accepts_normal_slug() {
        assert!(validate_slug("20260422-my-feature").is_ok());
    }

    #[test]
    fn validate_slug_accepts_slug_with_dots_but_not_dotdot() {
        // A slug like "v1.0.0" has dots but not "..".
        assert!(validate_slug("v1.0.0").is_ok());
    }

    // ----- 02-design directory semantics -----

    #[test]
    fn design_dir_false_when_path_does_not_exist() {
        let tmp = tempfile::tempdir().unwrap();
        let missing = tmp.path().join("02-design");
        assert!(!design_dir_has_regular_file(&missing));
    }

    #[test]
    fn design_dir_false_when_directory_is_empty() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path().join("02-design");
        fs::create_dir(&dir).unwrap();
        assert!(!design_dir_has_regular_file(&dir));
    }

    #[test]
    fn design_dir_false_when_directory_contains_only_subdirs() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path().join("02-design");
        fs::create_dir(&dir).unwrap();
        fs::create_dir(dir.join("subdir")).unwrap();
        assert!(!design_dir_has_regular_file(&dir));
    }

    #[test]
    fn design_dir_true_when_directory_has_one_regular_file() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path().join("02-design");
        fs::create_dir(&dir).unwrap();
        fs::write(dir.join("notes.md"), "content").unwrap();
        assert!(design_dir_has_regular_file(&dir));
    }

    #[test]
    fn design_dir_true_when_directory_has_file_and_subdir() {
        let tmp = tempfile::tempdir().unwrap();
        let dir = tmp.path().join("02-design");
        fs::create_dir(&dir).unwrap();
        fs::create_dir(dir.join("sub")).unwrap();
        fs::write(dir.join("palette.md"), "hex").unwrap();
        assert!(design_dir_has_regular_file(&dir));
    }

    // ----- validate_repo guard -----

    #[test]
    fn validate_repo_rejects_unregistered_root() {
        let tmp = tempfile::tempdir().unwrap();
        let canonical = tmp.path().canonicalize().unwrap();
        // Pass a different (empty) registered_roots list.
        let other_tmp = tempfile::tempdir().unwrap();
        let other_root = other_tmp.path().canonicalize().unwrap();
        let roots = vec![other_root];
        let result = validate_repo(canonical.to_str().unwrap(), &roots);
        assert!(result.is_err());
        assert_eq!(result.unwrap_err().code, "PATH_TRAVERSAL");
    }

    #[test]
    fn validate_repo_accepts_registered_root() {
        let tmp = tempfile::tempdir().unwrap();
        let canonical = tmp.path().canonicalize().unwrap();
        let roots = vec![canonical.clone()];
        let result = validate_repo(canonical.to_str().unwrap(), &roots);
        assert!(result.is_ok());
    }
}

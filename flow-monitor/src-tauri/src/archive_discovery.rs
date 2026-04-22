use std::fs;
use std::path::PathBuf;

use crate::ipc::{IpcError, SettingsState};

// ---------------------------------------------------------------------------
// Closed-enum classifier (classify-before-mutate rule)
// ---------------------------------------------------------------------------

/// Closed enum representing the classification of a single directory entry
/// under `.specaffold/archive/`. Every possible outcome is named explicitly;
/// callers dispatch via match with one arm per variant — no fall-through panic.
#[derive(Debug, PartialEq)]
pub enum ArchivedKind {
    /// A valid archived feature directory; carries the slug (directory name).
    Feature(String),
    /// A hidden entry (name starts with `.`); excluded from discovery results.
    Hidden,
    /// The entry is not a directory (regular file, symlink, etc.).
    NotADir,
}

/// Pure classifier: maps a single `DirEntry` under `.specaffold/archive/`
/// to an `ArchivedKind`. No file opens beyond what `DirEntry` already provides.
/// No side effects — pure mapping from entry metadata to variant.
pub fn classify_archive_entry(entry: &fs::DirEntry) -> ArchivedKind {
    let name = entry.file_name();
    let name_str = name.to_string_lossy();

    // Hidden entries (names starting with `.`) are skipped.
    if name_str.starts_with('.') {
        return ArchivedKind::Hidden;
    }

    let file_type = match entry.file_type() {
        Ok(ft) => ft,
        // If we cannot stat the entry, treat it as NotADir to skip it safely.
        Err(_) => return ArchivedKind::NotADir,
    };

    if !file_type.is_dir() {
        return ArchivedKind::NotADir;
    }

    ArchivedKind::Feature(name_str.to_string())
}

// ---------------------------------------------------------------------------
// Record type returned to the renderer
// ---------------------------------------------------------------------------

/// An archived feature entry returned by `list_archived_features`.
///
/// Field names and Serde derives match the `SessionRecord` style in `ipc.rs`
/// so the renderer can treat both record types uniformly.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, PartialEq)]
pub struct ArchivedFeatureRecord {
    /// Absolute path of the repository root this entry belongs to.
    pub repo: PathBuf,
    /// The directory name under `.specaffold/archive/` — used as the feature slug.
    pub slug: String,
    /// Absolute path of the archive entry directory itself.
    pub dir: PathBuf,
}

// ---------------------------------------------------------------------------
// IPC command — inner fn + thin wrapper (Pattern A)
// ---------------------------------------------------------------------------

/// Core implementation of archive discovery: takes the registered repo list
/// directly so integration tests can call it without constructing `tauri::State`.
///
/// For each repo, reads `.specaffold/archive/` once via a single `read_dir`
/// call. Non-existent archive directories are silently skipped. O(N) entries
/// per repo, no recursion, no per-entry file opens.
pub fn list_archived_features_inner(
    repos: &[PathBuf],
) -> Result<Vec<ArchivedFeatureRecord>, IpcError> {
    let mut records: Vec<ArchivedFeatureRecord> = Vec::new();

    for repo in repos {
        let archive_dir = repo.join(".specaffold").join("archive");

        // Missing archive directory is not an error — skip gracefully.
        let read_dir_iter = match fs::read_dir(&archive_dir) {
            Ok(iter) => iter,
            Err(_) => continue,
        };

        for entry_result in read_dir_iter {
            let entry = match entry_result {
                Ok(e) => e,
                // Skip unreadable entries rather than aborting the whole scan.
                Err(_) => continue,
            };

            match classify_archive_entry(&entry) {
                ArchivedKind::Feature(slug) => {
                    records.push(ArchivedFeatureRecord {
                        repo: repo.clone(),
                        slug,
                        dir: entry.path(),
                    });
                }
                // Dispatch table: Hidden and NotADir entries are not collected.
                ArchivedKind::Hidden | ArchivedKind::NotADir => {}
            }
        }
    }

    Ok(records)
}

/// Tauri command wrapper: unpacks `SettingsState`, then delegates to the
/// testable inner function.
#[tauri::command]
pub fn list_archived_features(
    settings: tauri::State<'_, SettingsState>,
) -> Result<Vec<ArchivedFeatureRecord>, IpcError> {
    // Snapshot the registered repos without holding the lock during I/O.
    let repos: Vec<PathBuf> = {
        let guard = settings.0.lock().map_err(|_| IpcError {
            code: "LOCK_POISONED",
            message: "settings lock is poisoned".into(),
        })?;
        guard.repos.clone()
    };
    list_archived_features_inner(&repos)
}

// ---------------------------------------------------------------------------
// Inline unit tests — pure classifier cases
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    /// Helper: create a temporary directory structure and return a DirEntry
    /// for the named child. The child is created as a directory if `is_dir`
    /// is true, or as a regular file otherwise.
    fn make_entry(parent: &std::path::Path, name: &str, is_dir: bool) -> fs::DirEntry {
        let child = parent.join(name);
        if is_dir {
            fs::create_dir_all(&child).unwrap();
        } else {
            fs::write(&child, b"").unwrap();
        }
        // read_dir the parent and find the entry for `name`.
        fs::read_dir(parent)
            .unwrap()
            .filter_map(|e| e.ok())
            .find(|e| e.file_name().to_string_lossy() == name)
            .expect("entry not found after creation")
    }

    /// A non-hidden subdirectory is classified as Feature(slug).
    #[test]
    fn classify_plain_dir_is_feature() {
        let tmp = tempfile::tempdir().unwrap();
        let entry = make_entry(tmp.path(), "my-feature", true);
        assert_eq!(classify_archive_entry(&entry), ArchivedKind::Feature("my-feature".to_string()));
    }

    /// A hidden directory (starts with `.`) is classified as Hidden.
    #[test]
    fn classify_hidden_dir_is_hidden() {
        let tmp = tempfile::tempdir().unwrap();
        let entry = make_entry(tmp.path(), ".hidden-dir", true);
        assert_eq!(classify_archive_entry(&entry), ArchivedKind::Hidden);
    }

    /// A hidden file (starts with `.`) is classified as Hidden — name check
    /// takes priority over the directory check.
    #[test]
    fn classify_hidden_file_is_hidden() {
        let tmp = tempfile::tempdir().unwrap();
        let entry = make_entry(tmp.path(), ".gitkeep", false);
        assert_eq!(classify_archive_entry(&entry), ArchivedKind::Hidden);
    }

    /// A regular file (not a directory) is classified as NotADir.
    #[test]
    fn classify_regular_file_is_not_a_dir() {
        let tmp = tempfile::tempdir().unwrap();
        let entry = make_entry(tmp.path(), "README.md", false);
        assert_eq!(classify_archive_entry(&entry), ArchivedKind::NotADir);
    }
}

use std::fs;
use std::path::{Path, PathBuf};

/// Closed enum representing the classification of a single directory entry
/// under `.spec-workflow/features/`. Every possible outcome is named explicitly;
/// callers dispatch via match with one arm per variant — no fall-through panic.
#[derive(Debug, PartialEq)]
pub enum SessionKind {
    /// A valid session directory: a non-template, non-archived dir that contains STATUS.md.
    Session(String),
    /// The reserved `_template/` directory; excluded from discovery results.
    Template,
    /// Any entry that is not a session for a named reason.
    NotASession(String),
}

/// Metadata returned by `discover_sessions` for every `Session(_)` match.
#[derive(Debug, PartialEq)]
pub struct SessionInfo {
    pub slug: String,
    pub dir: PathBuf,
    pub status_path: PathBuf,
}

/// Pure classifier: maps a single `DirEntry` under `.spec-workflow/features/`
/// to a `SessionKind`. Does NOT read STATUS.md content — that is `status_parse`'s job.
/// Does NOT recurse into sub-directories.
pub fn classify_entry(entry: &fs::DirEntry) -> SessionKind {
    let file_type = match entry.file_type() {
        Ok(ft) => ft,
        Err(e) => return SessionKind::NotASession(format!("file_type error: {e}")),
    };

    if !file_type.is_dir() {
        return SessionKind::NotASession("not a directory".to_string());
    }

    let name = entry.file_name();
    let name_str = name.to_string_lossy();

    // The _template/ directory is always excluded by name.
    if name_str == "_template" {
        return SessionKind::Template;
    }

    // Hidden directories (e.g. .git artefacts landing here) are not sessions.
    if name_str.starts_with('.') {
        return SessionKind::NotASession("hidden directory".to_string());
    }

    // A valid session must contain a STATUS.md sentinel file.
    let status_path = entry.path().join("STATUS.md");
    if !status_path.exists() {
        return SessionKind::NotASession("no STATUS.md".to_string());
    }

    SessionKind::Session(name_str.to_string())
}

/// Performs exactly ONE `read_dir` of `<repo_root>/.spec-workflow/features/`,
/// classifies each entry with `classify_entry`, and returns `Vec<SessionInfo>`
/// for `Session(_)` matches only.
///
/// Exclusions applied inside this single pass:
/// - `_template/` (caught by `classify_entry` returning `Template`)
/// - Anything under `.spec-workflow/archive/` is never in the features/ read_dir,
///   so no extra check is needed; the archive dir sits alongside features/, not inside it.
/// - Directories without `STATUS.md` (caught by `classify_entry` returning `NotASession`)
///
/// Per AC13.a: this function does NOT recurse into sub-directories.
pub fn discover_sessions(repo_root: &Path) -> Vec<SessionInfo> {
    let features_dir = repo_root.join(".spec-workflow").join("features");

    let read_dir_iter = match fs::read_dir(&features_dir) {
        Ok(iter) => iter,
        Err(_) => return Vec::new(),
    };

    let mut sessions = Vec::new();

    for entry_result in read_dir_iter {
        let entry = match entry_result {
            Ok(e) => e,
            Err(_) => continue,
        };

        match classify_entry(&entry) {
            SessionKind::Session(slug) => {
                let dir = entry.path();
                let status_path = dir.join("STATUS.md");
                sessions.push(SessionInfo {
                    slug,
                    dir,
                    status_path,
                });
            }
            SessionKind::Template | SessionKind::NotASession(_) => {
                // Dispatch is the caller's job; no mutation here.
            }
        }
    }

    sessions
}

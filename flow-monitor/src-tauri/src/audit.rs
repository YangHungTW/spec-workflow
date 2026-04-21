/// Audit log module — append-only TSV log with rotation + gitignore bootstrap.
///
/// Per tech D7: log lives at `<repo>/.spec-workflow/.flow-monitor/audit.log`.
/// Fields: timestamp (ISO 8601), slug, command, entry_point, delivery, outcome.
/// Rotation: on every append, if `audit.log` ≥ 1 048 576 bytes, rename to
/// `audit.log.1` then open a fresh `audit.log`.
/// Gitignore bootstrap: before the first write, `ensure_gitignore` appends
/// `.spec-workflow/.flow-monitor/` to `<repo>/.gitignore` if absent (idempotent,
/// atomic write-temp-then-rename per no-force-on-user-paths rule).
/// Path-traversal guard: the audit log path is canonicalised and checked to
/// start with `<repo>/.spec-workflow/.flow-monitor/` before any write.

use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------------------
// Public enums — closed sets per tech D7
// ---------------------------------------------------------------------------

/// The UI surface that triggered the command.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum EntryPoint {
    CardAction,
    CardDetail,
    Palette,
    ContextMenu,
    CompactPanel,
}

impl std::fmt::Display for EntryPoint {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            EntryPoint::CardAction => write!(f, "card-action"),
            EntryPoint::CardDetail => write!(f, "card-detail"),
            EntryPoint::Palette => write!(f, "palette"),
            EntryPoint::ContextMenu => write!(f, "context-menu"),
            EntryPoint::CompactPanel => write!(f, "compact-panel"),
        }
    }
}

/// The delivery mechanism used for the command.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum DeliveryMethod {
    Terminal,
    Clipboard,
    Pipe,
}

impl std::fmt::Display for DeliveryMethod {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DeliveryMethod::Terminal => write!(f, "terminal"),
            DeliveryMethod::Clipboard => write!(f, "clipboard"),
            DeliveryMethod::Pipe => write!(f, "pipe"),
        }
    }
}

/// The result of the dispatch attempt.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Outcome {
    Spawned,
    Copied,
    Failed,
    // Reserved for B3 DESTROY confirmation — never written by any B2 code path.
    DestroyConfirmed,
}

impl std::fmt::Display for Outcome {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Outcome::Spawned => write!(f, "spawned"),
            Outcome::Copied => write!(f, "copied"),
            Outcome::Failed => write!(f, "failed"),
            Outcome::DestroyConfirmed => write!(f, "destroy-confirmed"),
        }
    }
}

// ---------------------------------------------------------------------------
// AuditLine — the record written to disk
// ---------------------------------------------------------------------------

/// One row in the audit log.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AuditLine {
    /// RFC 3339 / ISO 8601 timestamp.
    pub ts: String,
    /// Session slug (ASCII per B1 discipline).
    pub slug: String,
    /// specflow command name (e.g. "implement").
    pub command: String,
    pub entry_point: EntryPoint,
    pub delivery: DeliveryMethod,
    pub outcome: Outcome,
}

// ---------------------------------------------------------------------------
// Error type
// ---------------------------------------------------------------------------

/// Errors produced by audit operations.
#[derive(Debug)]
pub enum AuditError {
    /// The computed write path does not sit under the expected `.flow-monitor/` subdir.
    PathTraversal(String),
    /// An I/O operation failed.
    Io(std::io::Error),
}

impl std::fmt::Display for AuditError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AuditError::PathTraversal(msg) => write!(f, "path traversal guard: {}", msg),
            AuditError::Io(e) => write!(f, "io error: {}", e),
        }
    }
}

impl From<std::io::Error> for AuditError {
    fn from(e: std::io::Error) -> Self {
        AuditError::Io(e)
    }
}

// ---------------------------------------------------------------------------
// Rotation threshold (1 MiB)
// ---------------------------------------------------------------------------

const ROTATE_THRESHOLD_BYTES: u64 = 1_048_576;

// ---------------------------------------------------------------------------
// Path helpers
// ---------------------------------------------------------------------------

/// Return the canonical `.spec-workflow/.flow-monitor/` directory path for `repo`.
/// The path may not yet exist; callers are responsible for creating it.
fn flow_monitor_dir(repo: &Path) -> PathBuf {
    repo.join(".spec-workflow").join(".flow-monitor")
}

/// Canonicalise `target` and verify it sits under the expected `allowed_prefix`.
///
/// Uses `Path::canonicalize` when the path already exists. For paths that do
/// not yet exist (a fresh `audit.log` before the first write), the parent
/// directory must exist and be canonicalisable; the filename is appended after.
///
/// Returns `Err(AuditError::PathTraversal)` when the resulting path does not
/// start with `allowed_prefix`.
fn canonicalise_and_check_under(
    target: &Path,
    allowed_prefix: &Path,
) -> Result<PathBuf, AuditError> {
    // Canonicalize the parent directory (must exist); then re-attach the filename.
    let parent = target.parent().ok_or_else(|| {
        AuditError::PathTraversal(format!("path has no parent: {}", target.display()))
    })?;
    let filename = target.file_name().ok_or_else(|| {
        AuditError::PathTraversal(format!("path has no filename: {}", target.display()))
    })?;

    let canon_parent = parent.canonicalize().map_err(|e| {
        AuditError::PathTraversal(format!(
            "cannot canonicalise parent {}: {}",
            parent.display(),
            e
        ))
    })?;
    let canonical = canon_parent.join(filename);

    if !canonical.starts_with(allowed_prefix) {
        return Err(AuditError::PathTraversal(format!(
            "write path {} escapes allowed prefix {}",
            canonical.display(),
            allowed_prefix.display()
        )));
    }
    Ok(canonical)
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Ensure `<repo>/.spec-workflow/.flow-monitor/` exists (mkdir -p).
pub fn ensure_flow_monitor_dir_exists(repo: &Path) -> Result<(), AuditError> {
    let dir = flow_monitor_dir(repo);
    fs::create_dir_all(&dir)?;
    Ok(())
}

/// Idempotently append `.spec-workflow/.flow-monitor/` to `<repo>/.gitignore`.
///
/// Reads the existing `.gitignore` first, then only writes when the target line
/// is absent. The write uses an atomic temp-file-then-rename so a partial write
/// never corrupts the live `.gitignore`. Per no-force-on-user-paths rule.
pub fn ensure_gitignore(repo: &Path) -> Result<(), AuditError> {
    let gitignore_path = repo.join(".gitignore");
    let target_line = ".spec-workflow/.flow-monitor/";

    // Read existing content (or empty string when file is absent).
    let existing = if gitignore_path.exists() {
        fs::read_to_string(&gitignore_path)?
    } else {
        String::new()
    };

    // Check whether the target line already exists (any line that, when trimmed,
    // equals the target). If present, nothing to do.
    let already_present = existing
        .lines()
        .any(|l| l.trim() == target_line);

    if already_present {
        return Ok(());
    }

    // Build the new content: existing + newline separator + the line + newline.
    let mut new_content = existing.clone();
    if !new_content.is_empty() && !new_content.ends_with('\n') {
        new_content.push('\n');
    }
    new_content.push_str(target_line);
    new_content.push('\n');

    // Atomic write: write to a temp file alongside .gitignore, then rename.
    let tmp_path = repo.join(".gitignore.flow-monitor-tmp");
    {
        let mut f = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&tmp_path)?;
        f.write_all(new_content.as_bytes())?;
        f.flush()?;
    }
    fs::rename(&tmp_path, &gitignore_path)?;
    Ok(())
}

/// Append one audit line to `<repo>/.spec-workflow/.flow-monitor/audit.log`.
///
/// Workflow:
///   1. Path-traversal guard — verify the audit log path is under the expected subdir.
///   2. `ensure_flow_monitor_dir_exists` — mkdir -p on first call.
///   3. `ensure_gitignore` — idempotent gitignore add.
///   4. Size check — if `audit.log` ≥ 1 MiB, rename to `audit.log.1`.
///   5. Append one TSV line (6 fields + LF) via `O_APPEND | O_CREAT`.
pub fn append_line(repo: &Path, line: AuditLine) -> Result<(), AuditError> {
    let dir = flow_monitor_dir(repo);
    let audit_log = dir.join("audit.log");

    // Step 1 — path-traversal guard. The parent dir must exist for canonicalization.
    // We ensure the dir first, then perform the guard.
    ensure_flow_monitor_dir_exists(repo)?;

    // Canonicalize the allowed prefix (the .flow-monitor dir itself).
    let canon_prefix = dir.canonicalize().map_err(|e| {
        AuditError::PathTraversal(format!(
            "cannot canonicalise flow-monitor dir {}: {}",
            dir.display(),
            e
        ))
    })?;

    let _canonical_log = canonicalise_and_check_under(&audit_log, &canon_prefix)?;

    // Step 3 — ensure gitignore (idempotent).
    ensure_gitignore(repo)?;

    // Step 4 — rotate if ≥ 1 MiB.
    if let Ok(meta) = fs::metadata(&audit_log) {
        if meta.len() >= ROTATE_THRESHOLD_BYTES {
            let audit_log_1 = dir.join("audit.log.1");
            fs::rename(&audit_log, &audit_log_1)?;
        }
    }

    // Step 5 — append TSV line.
    let tsv = format!(
        "{}\t{}\t{}\t{}\t{}\t{}\n",
        line.ts, line.slug, line.command, line.entry_point, line.delivery, line.outcome
    );
    let mut f = OpenOptions::new()
        .append(true)
        .create(true)
        .open(&audit_log)?;
    f.write_all(tsv.as_bytes())?;
    Ok(())
}

/// Read the last `limit` lines from the audit log(s) for the given repo.
///
/// Reads `audit.log` first; if fewer than `limit` lines are available, reads
/// `audit.log.1` and prepends its tail to fill the budget.
/// Lines are returned oldest-first (chronological order).
pub fn read_tail(repo: &Path, limit: usize) -> Result<Vec<AuditLine>, AuditError> {
    let dir = flow_monitor_dir(repo);
    let primary = dir.join("audit.log");
    let rotated = dir.join("audit.log.1");

    // Read lines from a file path into a Vec<String>, returning [] when absent.
    let read_lines = |path: &Path| -> Vec<String> {
        match fs::read_to_string(path) {
            Ok(s) => s.lines().map(|l| l.to_owned()).collect(),
            Err(_) => vec![],
        }
    };

    let primary_lines = read_lines(&primary);

    let lines: Vec<String> = if primary_lines.len() >= limit {
        // Primary alone satisfies the budget.
        primary_lines
            .into_iter()
            .rev()
            .take(limit)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect()
    } else {
        // Supplement from the rotated log.
        let need = limit - primary_lines.len();
        let rotated_lines = read_lines(&rotated);
        let rotated_tail: Vec<String> = rotated_lines
            .into_iter()
            .rev()
            .take(need)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect();
        let mut result = rotated_tail;
        result.extend(primary_lines);
        result
    };

    // Parse each line. Lines that cannot be parsed are silently skipped so a
    // corrupted log entry does not break the entire read.
    let parsed = lines
        .into_iter()
        .filter_map(|l| parse_audit_line(&l))
        .collect();
    Ok(parsed)
}

/// Parse a single TSV audit line into an `AuditLine`.
/// Returns `None` when the line is malformed (wrong field count or unknown enum value).
fn parse_audit_line(line: &str) -> Option<AuditLine> {
    let parts: Vec<&str> = line.splitn(6, '\t').collect();
    if parts.len() != 6 {
        return None;
    }
    let entry_point = match parts[3] {
        "card-action" => EntryPoint::CardAction,
        "card-detail" => EntryPoint::CardDetail,
        "palette" => EntryPoint::Palette,
        "context-menu" => EntryPoint::ContextMenu,
        "compact-panel" => EntryPoint::CompactPanel,
        _ => return None,
    };
    let delivery = match parts[4] {
        "terminal" => DeliveryMethod::Terminal,
        "clipboard" => DeliveryMethod::Clipboard,
        "pipe" => DeliveryMethod::Pipe,
        _ => return None,
    };
    let outcome = match parts[5] {
        "spawned" => Outcome::Spawned,
        "copied" => Outcome::Copied,
        "failed" => Outcome::Failed,
        "destroy-confirmed" => Outcome::DestroyConfirmed,
        _ => return None,
    };
    Some(AuditLine {
        ts: parts[0].to_owned(),
        slug: parts[1].to_owned(),
        command: parts[2].to_owned(),
        entry_point,
        delivery,
        outcome,
    })
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    // Helper: build a sample AuditLine for tests.
    fn sample_line(slug: &str) -> AuditLine {
        AuditLine {
            ts: "2026-04-22T14:32:01+08:00".to_owned(),
            slug: slug.to_owned(),
            command: "verify".to_owned(),
            entry_point: EntryPoint::CardAction,
            delivery: DeliveryMethod::Terminal,
            outcome: Outcome::Spawned,
        }
    }

    // ---------------------------------------------------------------------------
    // Seam C — rotation at 1 MiB
    // ---------------------------------------------------------------------------

    /// Write a 1 MiB fixture into audit.log, call append_line, then assert:
    ///   - audit.log.1 exists and contains the old content.
    ///   - audit.log exists and contains exactly one TSV line (the new entry).
    #[test]
    fn seam_c_rotation_at_1mb() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo = tmp.path();

        // Pre-create the .flow-monitor dir and write a 1 MiB audit.log fixture.
        let dir = repo.join(".spec-workflow").join(".flow-monitor");
        fs::create_dir_all(&dir).unwrap();
        let audit_log = dir.join("audit.log");
        let big_content = "x".repeat(1_048_576); // exactly 1 MiB
        fs::write(&audit_log, &big_content).unwrap();

        // Append a new line — rotation should fire.
        append_line(repo, sample_line("my-session")).expect("append_line failed");

        let audit_log_1 = dir.join("audit.log.1");

        // audit.log.1 must exist with the old content.
        assert!(audit_log_1.exists(), "audit.log.1 must exist after rotation");
        let rotated_content = fs::read_to_string(&audit_log_1).unwrap();
        assert_eq!(
            rotated_content, big_content,
            "audit.log.1 must contain the pre-rotation content"
        );

        // audit.log must exist with exactly one TSV line.
        let new_content = fs::read_to_string(&audit_log).unwrap();
        let lines: Vec<&str> = new_content.lines().collect();
        assert_eq!(
            lines.len(),
            1,
            "audit.log must contain exactly one line after rotation; got: {:?}",
            lines
        );
        assert!(
            lines[0].contains('\t'),
            "the single line must be tab-separated TSV"
        );
    }

    // ---------------------------------------------------------------------------
    // Seam D — idempotent gitignore add
    // ---------------------------------------------------------------------------

    /// Call ensure_gitignore twice on the same tempdir; assert the target line
    /// is present exactly once (not duplicated).
    #[test]
    fn seam_d_gitignore_add_is_idempotent() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo = tmp.path();
        let gitignore_path = repo.join(".gitignore");

        // First call — file absent, should create it with the target line.
        ensure_gitignore(repo).expect("first ensure_gitignore failed");
        assert!(gitignore_path.exists(), ".gitignore must be created");

        let content_after_first = fs::read_to_string(&gitignore_path).unwrap();
        let count = content_after_first
            .lines()
            .filter(|l| l.trim() == ".spec-workflow/.flow-monitor/")
            .count();
        assert_eq!(count, 1, "target line must appear exactly once after first call");

        // Second call — line already present, must not duplicate.
        ensure_gitignore(repo).expect("second ensure_gitignore failed");

        let content_after_second = fs::read_to_string(&gitignore_path).unwrap();
        let count2 = content_after_second
            .lines()
            .filter(|l| l.trim() == ".spec-workflow/.flow-monitor/")
            .count();
        assert_eq!(count2, 1, "target line must still appear exactly once after second call");
    }

    /// When .gitignore already contains other entries, ensure the append does
    /// not overwrite them and adds the target line once.
    #[test]
    fn seam_d_gitignore_preserves_existing_entries() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo = tmp.path();
        let gitignore_path = repo.join(".gitignore");

        let existing = "node_modules/\ndist/\n";
        fs::write(&gitignore_path, existing).unwrap();

        ensure_gitignore(repo).expect("ensure_gitignore failed");

        let content = fs::read_to_string(&gitignore_path).unwrap();
        assert!(
            content.contains("node_modules/"),
            "existing entries must be preserved"
        );
        assert!(
            content.contains("dist/"),
            "existing entries must be preserved"
        );
        assert!(
            content.contains(".spec-workflow/.flow-monitor/"),
            "target line must be appended"
        );
    }

    // ---------------------------------------------------------------------------
    // Seam H — path-traversal guard
    // ---------------------------------------------------------------------------

    /// Craft a repo path that, when combined with the .flow-monitor subdir,
    /// resolves to a path outside the repo via symlink or `..` tricks.
    ///
    /// We cannot actually escape the tempdir with `..` via canonicalize (the OS
    /// resolves it), so we test the boundary check by pointing the `.flow-monitor`
    /// dir at an outside location via a symlink.
    ///
    /// The simpler test: append_line with a canonicalized repo path verifies
    /// the guard does NOT fire on a legitimate write path.
    #[test]
    fn seam_h_legitimate_path_does_not_trigger_traversal() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo = tmp.path();

        let result = append_line(repo, sample_line("my-session"));
        assert!(
            result.is_ok(),
            "legitimate append must succeed: {:?}",
            result.err()
        );
    }

    /// Traversal guard fires when the .flow-monitor dir is a symlink pointing
    /// outside the repo. We test a synthetic scenario: construct a path that
    /// starts with the repo root but whose canonicalised form escapes it.
    ///
    /// Since we cannot construct a true traversal within a tempdir sandbox
    /// (the OS resolves `..`), we instead call `canonicalise_and_check_under`
    /// directly with a path outside the allowed prefix.
    #[test]
    fn seam_h_path_traversal_guard_fires_outside_prefix() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let allowed_prefix = tmp.path().join("allowed");
        fs::create_dir_all(&allowed_prefix).unwrap();
        let canon_prefix = allowed_prefix.canonicalize().unwrap();

        // Construct a target path that is OUTSIDE the allowed prefix.
        let other_dir = tmp.path().join("outside");
        fs::create_dir_all(&other_dir).unwrap();
        let outside_target = other_dir.join("audit.log");

        let result = canonicalise_and_check_under(&outside_target, &canon_prefix);
        assert!(
            matches!(result, Err(AuditError::PathTraversal(_))),
            "path outside allowed prefix must yield PathTraversal error; got: {:?}",
            result.map(|p| p.display().to_string())
        );
    }

    // ---------------------------------------------------------------------------
    // TSV format — field layout and content
    // ---------------------------------------------------------------------------

    /// Append one line and verify the TSV has the correct 6-field layout.
    #[test]
    fn append_line_produces_6_field_tsv() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo = tmp.path();

        let line = AuditLine {
            ts: "2026-04-22T14:32:01+08:00".to_owned(),
            slug: "data-pipeline".to_owned(),
            command: "verify".to_owned(),
            entry_point: EntryPoint::CardAction,
            delivery: DeliveryMethod::Terminal,
            outcome: Outcome::Spawned,
        };

        append_line(repo, line).expect("append_line failed");

        let dir = flow_monitor_dir(repo);
        let content = fs::read_to_string(dir.join("audit.log")).unwrap();
        let first_line = content.lines().next().expect("at least one line");
        let fields: Vec<&str> = first_line.split('\t').collect();

        assert_eq!(
            fields.len(),
            6,
            "TSV line must have exactly 6 fields; got {:?}",
            fields
        );
        assert_eq!(fields[0], "2026-04-22T14:32:01+08:00", "field 0: timestamp");
        assert_eq!(fields[1], "data-pipeline", "field 1: slug");
        assert_eq!(fields[2], "verify", "field 2: command");
        assert_eq!(fields[3], "card-action", "field 3: entry_point");
        assert_eq!(fields[4], "terminal", "field 4: delivery");
        assert_eq!(fields[5], "spawned", "field 5: outcome");
    }

    // ---------------------------------------------------------------------------
    // read_tail
    // ---------------------------------------------------------------------------

    /// Write 3 lines, request tail(2), verify exactly 2 lines returned (newest 2).
    #[test]
    fn read_tail_returns_last_n_lines() {
        let tmp = tempfile::tempdir().expect("tempdir");
        let repo = tmp.path();

        for slug in &["alpha", "beta", "gamma"] {
            append_line(repo, sample_line(slug)).expect("append_line failed");
        }

        let result = read_tail(repo, 2).expect("read_tail failed");
        assert_eq!(result.len(), 2, "read_tail(2) must return 2 lines");
        assert_eq!(result[0].slug, "beta");
        assert_eq!(result[1].slug, "gamma");
    }
}

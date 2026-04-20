use flow_monitor_lib::repo_discovery::{classify_entry, discover_sessions, SessionKind};
use std::fs;
use std::path::PathBuf;

/// Build a minimal fixture repository layout under a tempdir:
///
/// ```
/// <root>/
///   .spec-workflow/
///     features/
///       _template/          <- Template; excluded
///       session-alpha/      <- valid session (has STATUS.md)
///         STATUS.md
///       session-beta/       <- valid session (has STATUS.md)
///         STATUS.md
///       no-status-dir/      <- NotASession: no STATUS.md
///     archive/
///       old-session/        <- in archive/, not under features/; never visited
///         STATUS.md
/// ```
fn build_fixture() -> tempfile::TempDir {
    let tmp = tempfile::tempdir().expect("tempdir");
    let root = tmp.path();

    let features = root.join(".spec-workflow").join("features");
    fs::create_dir_all(&features).unwrap();

    // _template/ — no STATUS.md required; classified by name
    fs::create_dir_all(features.join("_template")).unwrap();

    // valid session: session-alpha
    let alpha = features.join("session-alpha");
    fs::create_dir_all(&alpha).unwrap();
    fs::write(alpha.join("STATUS.md"), "# session-alpha\n").unwrap();

    // valid session: session-beta
    let beta = features.join("session-beta");
    fs::create_dir_all(&beta).unwrap();
    fs::write(beta.join("STATUS.md"), "# session-beta\n").unwrap();

    // directory without STATUS.md — must be excluded
    fs::create_dir_all(features.join("no-status-dir")).unwrap();

    // archive dir sits alongside features/, NOT inside it; discover_sessions never touches it
    let archive_old = root.join(".spec-workflow").join("archive").join("old-session");
    fs::create_dir_all(&archive_old).unwrap();
    fs::write(archive_old.join("STATUS.md"), "# archived\n").unwrap();

    tmp
}

// --- classify_entry tests ---

#[test]
fn classify_template_dir_returns_template() {
    let tmp = build_fixture();
    let features = tmp.path().join(".spec-workflow").join("features");

    for entry in fs::read_dir(&features).unwrap() {
        let entry = entry.unwrap();
        if entry.file_name() == "_template" {
            assert_eq!(classify_entry(&entry), SessionKind::Template);
            return;
        }
    }
    panic!("_template entry not found in fixture");
}

#[test]
fn classify_valid_session_returns_session_with_slug() {
    let tmp = build_fixture();
    let features = tmp.path().join(".spec-workflow").join("features");

    for entry in fs::read_dir(&features).unwrap() {
        let entry = entry.unwrap();
        if entry.file_name() == "session-alpha" {
            match classify_entry(&entry) {
                SessionKind::Session(slug) => assert_eq!(slug, "session-alpha"),
                other => panic!("expected Session, got {:?}", other),
            }
            return;
        }
    }
    panic!("session-alpha entry not found in fixture");
}

#[test]
fn classify_dir_without_status_md_returns_not_a_session() {
    let tmp = build_fixture();
    let features = tmp.path().join(".spec-workflow").join("features");

    for entry in fs::read_dir(&features).unwrap() {
        let entry = entry.unwrap();
        if entry.file_name() == "no-status-dir" {
            match classify_entry(&entry) {
                SessionKind::NotASession(reason) => {
                    assert!(reason.contains("STATUS.md"), "reason was: {reason}")
                }
                other => panic!("expected NotASession, got {:?}", other),
            }
            return;
        }
    }
    panic!("no-status-dir entry not found in fixture");
}

// --- discover_sessions tests ---

#[test]
fn discover_excludes_template() {
    let tmp = build_fixture();
    let sessions = discover_sessions(tmp.path());
    let slugs: Vec<&str> = sessions.iter().map(|s| s.slug.as_str()).collect();
    assert!(
        !slugs.contains(&"_template"),
        "_template must not appear in results; got: {slugs:?}"
    );
}

#[test]
fn discover_excludes_dir_without_status_md() {
    let tmp = build_fixture();
    let sessions = discover_sessions(tmp.path());
    let slugs: Vec<&str> = sessions.iter().map(|s| s.slug.as_str()).collect();
    assert!(
        !slugs.contains(&"no-status-dir"),
        "no-status-dir must not appear in results; got: {slugs:?}"
    );
}

#[test]
fn discover_excludes_archive_dir() {
    // archive/ sits alongside features/, not inside it — discover_sessions does one
    // read_dir of features/ and never visits archive/ at all.
    let tmp = build_fixture();
    let sessions = discover_sessions(tmp.path());
    let slugs: Vec<&str> = sessions.iter().map(|s| s.slug.as_str()).collect();
    assert!(
        !slugs.contains(&"old-session"),
        "old-session from archive must not appear; got: {slugs:?}"
    );
}

#[test]
fn discover_includes_valid_sessions() {
    let tmp = build_fixture();
    let mut sessions = discover_sessions(tmp.path());
    sessions.sort_by(|a, b| a.slug.cmp(&b.slug));

    assert_eq!(sessions.len(), 2, "expected exactly 2 sessions; got: {:?}", sessions);
    assert_eq!(sessions[0].slug, "session-alpha");
    assert_eq!(sessions[1].slug, "session-beta");
}

#[test]
fn discover_status_path_points_to_status_md() {
    let tmp = build_fixture();
    let sessions = discover_sessions(tmp.path());

    for session in &sessions {
        let expected_status = session.dir.join("STATUS.md");
        assert_eq!(
            session.status_path, expected_status,
            "status_path for {} must be <dir>/STATUS.md",
            session.slug
        );
        assert!(
            session.status_path.exists(),
            "STATUS.md must exist at {:?}",
            session.status_path
        );
    }
}

#[test]
fn discover_returns_empty_when_features_dir_missing() {
    let tmp = tempfile::tempdir().unwrap();
    // No .spec-workflow/features/ created — read_dir will fail gracefully
    let sessions = discover_sessions(tmp.path());
    assert!(sessions.is_empty(), "must return empty vec when features dir is absent");
}

#[test]
fn session_dir_field_matches_entry_path() {
    let tmp = build_fixture();
    let features = tmp.path().join(".spec-workflow").join("features");
    let sessions = discover_sessions(tmp.path());

    for session in &sessions {
        let expected_dir: PathBuf = features.join(&session.slug);
        assert_eq!(
            session.dir, expected_dir,
            "dir field must equal features/<slug>"
        );
    }
}

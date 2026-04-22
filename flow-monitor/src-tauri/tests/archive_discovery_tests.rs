/// Integration tests for `archive_discovery::list_archived_features_inner`.
///
/// These tests exercise the full discovery path through a real tempdir
/// filesystem — not just the classifier in isolation.  Pattern A: call the
/// public inner function directly with `&[PathBuf]` instead of constructing
/// a `tauri::State`.
use flow_monitor_lib::archive_discovery::{
    classify_archive_entry, list_archived_features_inner, ArchivedKind,
};
use std::fs;
use std::path::PathBuf;

// ---------------------------------------------------------------------------
// Case 1 — empty `.specaffold/archive/` yields an empty result
// ---------------------------------------------------------------------------

#[test]
fn empty_archive_dir_returns_empty_result() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().to_path_buf();

    // Create the archive directory but leave it empty.
    let archive_dir = repo.join(".specaffold").join("archive");
    fs::create_dir_all(&archive_dir).unwrap();

    let result = list_archived_features_inner(&[repo]).unwrap();
    assert!(
        result.is_empty(),
        "expected empty result for empty archive dir; got: {result:?}"
    );
}

// ---------------------------------------------------------------------------
// Case 2 — N slug directories (N=3) yields N records
// ---------------------------------------------------------------------------

#[test]
fn three_slug_dirs_yield_three_records() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().to_path_buf();
    let archive_dir = repo.join(".specaffold").join("archive");
    fs::create_dir_all(&archive_dir).unwrap();

    let slugs = ["20260401-alpha", "20260402-beta", "20260403-gamma"];
    for slug in &slugs {
        fs::create_dir_all(archive_dir.join(slug)).unwrap();
    }

    let mut result = list_archived_features_inner(&[repo.clone()]).unwrap();
    result.sort_by(|a, b| a.slug.cmp(&b.slug));

    assert_eq!(
        result.len(),
        3,
        "expected 3 records for 3 slug dirs; got: {result:?}"
    );

    let result_slugs: Vec<&str> = result.iter().map(|r| r.slug.as_str()).collect();
    assert_eq!(result_slugs, slugs, "slugs must match the created directories");

    // Each record's repo field must equal the repo root.
    for record in &result {
        assert_eq!(record.repo, repo, "repo field must match the registered repo root");
        // dir must be archive_dir/<slug>
        assert_eq!(
            record.dir,
            archive_dir.join(&record.slug),
            "dir field must be archive_dir/<slug>"
        );
    }
}

// ---------------------------------------------------------------------------
// Case 3 — hidden directories (`.foo`) and regular files are skipped
// ---------------------------------------------------------------------------

#[test]
fn hidden_dirs_and_files_are_skipped() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().to_path_buf();
    let archive_dir = repo.join(".specaffold").join("archive");
    fs::create_dir_all(&archive_dir).unwrap();

    // One legitimate slug.
    fs::create_dir_all(archive_dir.join("real-feature")).unwrap();

    // Hidden directory — must be skipped.
    fs::create_dir_all(archive_dir.join(".hidden-dir")).unwrap();

    // Hidden file — must be skipped.
    fs::write(archive_dir.join(".gitkeep"), b"").unwrap();

    // Regular (visible) file — must be skipped because it is not a directory.
    fs::write(archive_dir.join("README.md"), b"").unwrap();

    let result = list_archived_features_inner(&[repo]).unwrap();

    assert_eq!(
        result.len(),
        1,
        "expected exactly 1 record (hidden entries and files skipped); got: {result:?}"
    );
    assert_eq!(result[0].slug, "real-feature");
}

// ---------------------------------------------------------------------------
// Case 4 — unregistered repo yields an error without touching the filesystem
// ---------------------------------------------------------------------------
//
// `list_archived_features_inner` does NOT validate repo membership — it
// simply iterates the slice it is given. The "unregistered repo" guard lives
// one layer up in the Tauri command (which checks `SettingsState.repos`).
//
// Here we verify the semantically equivalent invariant: if the repo path is
// not in the `repos` slice passed to the inner function, no records for that
// repo appear in the result.  We also verify that a completely absent (i.e.
// non-existent) repo path is handled gracefully without a panic — the inner
// function treats a missing archive dir as "nothing to enumerate".
//
// The full PATH_TRAVERSAL error path for an unregistered repo is exercised in
// artefact_presence_tests.rs (via `list_feature_artefacts_inner`), which
// applies the allowlist guard before any filesystem access.

#[test]
fn repo_not_in_slice_produces_no_records() {
    let registered_tmp = tempfile::tempdir().unwrap();
    let registered_repo = registered_tmp.path().to_path_buf();
    let archive_dir = registered_repo.join(".specaffold").join("archive");
    fs::create_dir_all(&archive_dir).unwrap();
    fs::create_dir_all(archive_dir.join("my-feature")).unwrap();

    // Unregistered repo (a different temp dir, not in the repos slice).
    let unregistered_tmp = tempfile::tempdir().unwrap();
    let unregistered_repo = unregistered_tmp.path().to_path_buf();

    // Only pass the registered repo; ignore the unregistered one.
    let result = list_archived_features_inner(&[registered_repo]).unwrap();
    let repos_in_result: Vec<&PathBuf> = result.iter().map(|r| &r.repo).collect();

    assert!(
        !repos_in_result.contains(&&unregistered_repo),
        "unregistered repo must not appear in result; got: {result:?}"
    );
    assert_eq!(result.len(), 1, "only the registered repo's feature is expected");
}

#[test]
fn absent_repo_path_is_skipped_gracefully() {
    // A repo path that does not exist at all — the inner function must not panic.
    let absent = PathBuf::from("/nonexistent/path/that/does/not/exist");
    let result = list_archived_features_inner(&[absent]).unwrap();
    assert!(
        result.is_empty(),
        "absent repo path must yield empty result; got: {result:?}"
    );
}

// ---------------------------------------------------------------------------
// Classifier smoke-checks (confirm public re-export from integration harness)
// ---------------------------------------------------------------------------

#[test]
fn classifier_feature_variant_carries_slug() {
    let tmp = tempfile::tempdir().unwrap();
    let child = tmp.path().join("slug-name");
    fs::create_dir_all(&child).unwrap();

    let entry = fs::read_dir(tmp.path())
        .unwrap()
        .filter_map(|e| e.ok())
        .find(|e| e.file_name().to_string_lossy() == "slug-name")
        .expect("entry not found");

    assert_eq!(
        classify_archive_entry(&entry),
        ArchivedKind::Feature("slug-name".to_string())
    );
}

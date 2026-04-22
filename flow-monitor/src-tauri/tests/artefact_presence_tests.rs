/// Integration tests for `artefact_presence::list_feature_artefacts_inner`.
///
/// Pattern A: call the public inner function with `&[PathBuf]` directly so
/// these tests never need to construct a `tauri::State`.
use flow_monitor_lib::artefact_presence::{list_feature_artefacts_inner, TAB_KEYS};
use std::fs;
use std::path::PathBuf;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal repo tree with a single feature under `features/<slug>`.
/// Returns `(tmp, repo_path, feature_dir)`.
fn make_feature_repo(slug: &str) -> (tempfile::TempDir, PathBuf, PathBuf) {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().canonicalize().unwrap();
    let feature_dir = repo.join(".specaffold").join("features").join(slug);
    fs::create_dir_all(&feature_dir).unwrap();
    (tmp, repo, feature_dir)
}

/// Build a minimal repo tree with a single feature under `archive/<slug>`.
/// Returns `(tmp, repo_path, archive_feature_dir)`.
fn make_archived_feature_repo(slug: &str) -> (tempfile::TempDir, PathBuf, PathBuf) {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().canonicalize().unwrap();
    let feature_dir = repo.join(".specaffold").join("archive").join(slug);
    fs::create_dir_all(&feature_dir).unwrap();
    (tmp, repo, feature_dir)
}

// ---------------------------------------------------------------------------
// Case 1 — only `00-request.md` + `03-prd.md` present → those two true, rest false
// ---------------------------------------------------------------------------

#[test]
fn only_request_and_prd_present_rest_are_false() {
    let slug = "test-feature";
    let (_tmp, repo, feature_dir) = make_feature_repo(slug);

    // Create only the two artefacts.
    fs::write(feature_dir.join("00-request.md"), b"request").unwrap();
    fs::write(feature_dir.join("03-prd.md"), b"prd").unwrap();

    let presence =
        list_feature_artefacts_inner(repo.to_str().unwrap().to_string(), slug.to_string(), false, &[repo.clone()])
            .unwrap();

    assert_eq!(
        presence.files_present["00-request.md"], true,
        "00-request.md must be true"
    );
    assert_eq!(
        presence.files_present["03-prd.md"], true,
        "03-prd.md must be true"
    );

    // The remaining 7 keys must all be false.
    let absent_keys = TAB_KEYS
        .iter()
        .filter(|&&k| k != "00-request.md" && k != "03-prd.md");
    for key in absent_keys {
        assert_eq!(
            presence.files_present[*key], false,
            "key {key} must be false when not created"
        );
    }

    // Sanity: all 9 keys are present in the map.
    assert_eq!(
        presence.files_present.len(),
        TAB_KEYS.len(),
        "result must have exactly {} keys",
        TAB_KEYS.len()
    );
}

// ---------------------------------------------------------------------------
// Case 2 — `archived=true` reads from `<repo>/.specaffold/archive/<slug>/`
// ---------------------------------------------------------------------------

#[test]
fn archived_true_reads_from_archive_path() {
    let slug = "20260401-archived";
    let (_tmp, repo, archive_feature_dir) = make_archived_feature_repo(slug);

    // Create `03-prd.md` under the archive path only.
    fs::write(archive_feature_dir.join("03-prd.md"), b"archived prd").unwrap();

    // Also create a features dir WITHOUT the file to confirm the right branch is read.
    let features_dir = repo.join(".specaffold").join("features").join(slug);
    fs::create_dir_all(&features_dir).unwrap();
    // Do NOT write 03-prd.md in features/ — it must be absent there.

    let presence =
        list_feature_artefacts_inner(repo.to_str().unwrap().to_string(), slug.to_string(), true, &[repo.clone()])
            .unwrap();

    assert_eq!(
        presence.files_present["03-prd.md"], true,
        "03-prd.md must be true when read from archive path"
    );

    // All other keys absent in the archive feature dir must be false.
    let others: Vec<&str> = TAB_KEYS
        .iter()
        .copied()
        .filter(|&k| k != "03-prd.md")
        .collect();
    for key in others {
        assert_eq!(
            presence.files_present[key], false,
            "key {key} must be false in archived branch"
        );
    }
}

#[test]
fn archived_false_does_not_read_from_archive_path() {
    // Mirror of the previous test: with archived=false we must read from
    // features/ even if the archive dir also exists.
    let slug = "overlap-slug";
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().canonicalize().unwrap();

    let features_dir = repo.join(".specaffold").join("features").join(slug);
    fs::create_dir_all(&features_dir).unwrap();
    fs::write(features_dir.join("00-request.md"), b"request").unwrap();

    let archive_dir = repo.join(".specaffold").join("archive").join(slug);
    fs::create_dir_all(&archive_dir).unwrap();
    fs::write(archive_dir.join("03-prd.md"), b"archive-only prd").unwrap();

    let presence =
        list_feature_artefacts_inner(repo.to_str().unwrap().to_string(), slug.to_string(), false, &[repo.clone()])
            .unwrap();

    assert_eq!(
        presence.files_present["00-request.md"], true,
        "00-request.md is in features/ and must be true"
    );
    assert_eq!(
        presence.files_present["03-prd.md"], false,
        "03-prd.md is only in archive/, must be false when archived=false"
    );
}

// ---------------------------------------------------------------------------
// Case 3 — path-traversal: `slug="../foo"` is rejected
// ---------------------------------------------------------------------------

#[test]
fn slug_with_dotdot_is_rejected() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().canonicalize().unwrap();

    let result = list_feature_artefacts_inner(
        repo.to_str().unwrap().to_string(),
        "../foo".to_string(),
        false,
        &[repo],
    );
    assert!(result.is_err(), "slug='../foo' must return an error");
    let err = result.unwrap_err();
    assert_eq!(err.code, "INVALID_SLUG", "error code must be INVALID_SLUG");
}

#[test]
fn slug_with_forward_slash_is_rejected() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().canonicalize().unwrap();

    let result = list_feature_artefacts_inner(
        repo.to_str().unwrap().to_string(),
        "foo/bar".to_string(),
        false,
        &[repo],
    );
    assert!(result.is_err(), "slug='foo/bar' must return an error");
    let err = result.unwrap_err();
    assert_eq!(err.code, "INVALID_SLUG");
}

#[test]
fn unregistered_repo_is_rejected() {
    let registered_tmp = tempfile::tempdir().unwrap();
    let registered_repo = registered_tmp.path().canonicalize().unwrap();

    let unregistered_tmp = tempfile::tempdir().unwrap();
    let unregistered_repo = unregistered_tmp.path().canonicalize().unwrap();

    // Pass only the registered repo in the allowlist.
    let result = list_feature_artefacts_inner(
        unregistered_repo.to_str().unwrap().to_string(),
        "some-slug".to_string(),
        false,
        &[registered_repo],
    );
    assert!(result.is_err(), "unregistered repo must return an error");
    let err = result.unwrap_err();
    assert_eq!(
        err.code, "PATH_TRAVERSAL",
        "error code must be PATH_TRAVERSAL for unregistered repo"
    );
}

// ---------------------------------------------------------------------------
// Case 4 — `02-design` directory semantics
// ---------------------------------------------------------------------------

#[test]
fn design_dir_exists_and_empty_yields_false() {
    let slug = "design-empty";
    let (_tmp, repo, feature_dir) = make_feature_repo(slug);

    // Create `02-design` as an empty directory.
    fs::create_dir_all(feature_dir.join("02-design")).unwrap();

    let presence =
        list_feature_artefacts_inner(repo.to_str().unwrap().to_string(), slug.to_string(), false, &[repo.clone()])
            .unwrap();

    assert_eq!(
        presence.files_present["02-design"], false,
        "02-design exists but empty — must be false per PRD R23"
    );
}

#[test]
fn design_dir_with_one_regular_file_yields_true() {
    let slug = "design-has-file";
    let (_tmp, repo, feature_dir) = make_feature_repo(slug);

    // Create `02-design` with one regular file inside.
    let design = feature_dir.join("02-design");
    fs::create_dir_all(&design).unwrap();
    fs::write(design.join("notes.md"), b"content").unwrap();

    let presence =
        list_feature_artefacts_inner(repo.to_str().unwrap().to_string(), slug.to_string(), false, &[repo.clone()])
            .unwrap();

    assert_eq!(
        presence.files_present["02-design"], true,
        "02-design with one regular file — must be true per PRD R23"
    );
}

#[test]
fn design_dir_with_subdirs_only_yields_false() {
    let slug = "design-subdir-only";
    let (_tmp, repo, feature_dir) = make_feature_repo(slug);

    // Create `02-design` with a subdirectory but no regular file.
    let design = feature_dir.join("02-design");
    fs::create_dir_all(&design).unwrap();
    fs::create_dir_all(design.join("nested")).unwrap();

    let presence =
        list_feature_artefacts_inner(repo.to_str().unwrap().to_string(), slug.to_string(), false, &[repo.clone()])
            .unwrap();

    assert_eq!(
        presence.files_present["02-design"], false,
        "02-design with only subdirs (no regular file) — must be false"
    );
}

#[test]
fn design_dir_absent_yields_false() {
    let slug = "design-absent";
    let (_tmp, repo, _feature_dir) = make_feature_repo(slug);
    // Do NOT create 02-design at all.

    let presence =
        list_feature_artefacts_inner(repo.to_str().unwrap().to_string(), slug.to_string(), false, &[repo.clone()])
            .unwrap();

    assert_eq!(
        presence.files_present["02-design"], false,
        "02-design absent — must be false"
    );
}

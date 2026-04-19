/// Seam 5 integration tests for `settings_io`.
///
/// Each test exercises the public API through the crate boundary so that
/// the atomic-rename, .bak, and forward-compatibility invariants are
/// verified at the integration level (not just unit level).
use flow_monitor_lib::settings::{self, Language, Settings, Theme};
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

// ---------------------------------------------------------------------------
// T1 — round-trip byte-equality after canonicalisation
// ---------------------------------------------------------------------------

#[test]
fn seam5_round_trip_byte_equality() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");

    let mut s = Settings::default();
    s.repos = vec![PathBuf::from("/tmp/repo-x")];
    s.polling_interval_secs = 7;
    s.stale_threshold_mins = 12;
    s.stalled_threshold_mins = 45;
    s.notifications_enabled = false;
    s.always_on_top = false;
    s.language = Language::ZhTw;
    s.theme = Theme::Dark;
    s.repo_section_collapse
        .insert(PathBuf::from("/tmp/repo-x"), true);

    // Write → read → compare.
    settings::write(&p, &s).unwrap();
    let s2 = settings::read(&p);
    assert_eq!(s, s2, "round-trip must produce an identical Settings value");

    // Write a second time (rewrite through read value) → read again → equal.
    settings::write(&p, &s2).unwrap();
    let s3 = settings::read(&p);
    assert_eq!(s, s3, "second rewrite must still be byte-equal");
}

// ---------------------------------------------------------------------------
// T2 — .bak file exists after a second write (prior file was present)
// ---------------------------------------------------------------------------

#[test]
fn seam5_bak_exists_after_second_write() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");
    let bak = {
        let mut b = p.as_os_str().to_os_string();
        b.push(".bak");
        PathBuf::from(b)
    };

    // First write — no prior file, so no .bak expected.
    settings::write(&p, &Settings::default()).unwrap();
    assert!(p.exists(), "live file must exist after first write");
    assert!(!bak.exists(), ".bak must NOT exist after first write");

    // Second write — live file exists, so .bak must be created.
    settings::write(&p, &Settings::default()).unwrap();
    assert!(bak.exists(), ".bak must exist after second write");
}

// ---------------------------------------------------------------------------
// T3 — atomic-rename: .tmp must not linger after write() returns
// ---------------------------------------------------------------------------

#[test]
fn seam5_atomic_rename_no_tmp_after_write() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");
    let tmp = {
        let mut t = p.as_os_str().to_os_string();
        t.push(".tmp");
        PathBuf::from(t)
    };

    assert!(!tmp.exists(), ".tmp must not exist before write");
    settings::write(&p, &Settings::default()).unwrap();
    assert!(!tmp.exists(), ".tmp must be renamed away; must not linger");
    assert!(p.exists(), "live path must exist");
}

// ---------------------------------------------------------------------------
// T4 — unknown top-level key (b2_field) is preserved after rewrite
// ---------------------------------------------------------------------------

#[test]
fn seam5_unknown_key_preserved_after_rewrite() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");

    // Seed file with a B2 field this version does not know.
    let seed = r#"{
  "schema_version": 1,
  "b2_field": "preserved",
  "repos": [],
  "polling_interval_secs": 3,
  "stale_threshold_mins": 5,
  "stalled_threshold_mins": 30,
  "notifications_enabled": true,
  "always_on_top": true,
  "language": "en",
  "theme": "light",
  "repo_section_collapse": {}
}"#;
    fs::write(&p, seed).unwrap();

    // Read through our API — schema_version must be correct.
    let s = settings::read(&p);
    assert_eq!(s.schema_version, 1);

    // Rewrite through our write() — unknown key must survive.
    settings::write(&p, &s).unwrap();

    let on_disk = fs::read_to_string(&p).unwrap();
    let parsed: Value = serde_json::from_str(&on_disk).unwrap();
    assert_eq!(
        parsed.get("b2_field").and_then(Value::as_str),
        Some("preserved"),
        "b2_field must be preserved after round-trip rewrite (forward-compat)"
    );
}

// ---------------------------------------------------------------------------
// T5 — schema_version is always 1 in B1 writes
// ---------------------------------------------------------------------------

#[test]
fn seam5_schema_version_is_1() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");

    settings::write(&p, &Settings::default()).unwrap();

    let on_disk = fs::read_to_string(&p).unwrap();
    let parsed: Value = serde_json::from_str(&on_disk).unwrap();
    assert_eq!(
        parsed.get("schema_version").and_then(Value::as_u64),
        Some(1),
        "schema_version must be 1 for B1 writes"
    );
}

// ---------------------------------------------------------------------------
// T6 — no B2 leakage fields in Settings struct
// ---------------------------------------------------------------------------

#[test]
fn seam5_no_b2_fields_in_settings_struct() {
    // Serialise default Settings and assert prohibited B2 keys are absent.
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");
    settings::write(&p, &Settings::default()).unwrap();

    let on_disk = fs::read_to_string(&p).unwrap();
    let parsed: Value = serde_json::from_str(&on_disk).unwrap();
    let obj = parsed.as_object().unwrap();

    assert!(
        !obj.contains_key("controlPlaneEnabled"),
        "controlPlaneEnabled must NOT be written by B1 settings"
    );
    assert!(
        !obj.contains_key("instructionHistory"),
        "instructionHistory must NOT be written by B1 settings"
    );
}

// ---------------------------------------------------------------------------
// T7 — read returns defaults when file is absent (no panic)
// ---------------------------------------------------------------------------

#[test]
fn seam5_read_absent_file_returns_defaults() {
    let p = PathBuf::from("/tmp/seam5_definitely_absent_settings_file.json");
    let _ = fs::remove_file(&p); // ensure it's gone
    let s = settings::read(&p);
    assert_eq!(s, Settings::default());
}

// ---------------------------------------------------------------------------
// T8 — corrupt JSON file is renamed away and defaults returned
// ---------------------------------------------------------------------------

#[test]
fn seam5_corrupt_json_renamed_and_defaults_returned() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");
    fs::write(&p, b"{ definitely not json !! }").unwrap();

    let s = settings::read(&p);
    assert_eq!(s, Settings::default(), "corrupt file must yield defaults");
    assert!(
        !p.exists(),
        "corrupt file must have been renamed away from original path"
    );

    // A .corrupt-<epoch> sibling should now exist.
    let siblings: Vec<_> = fs::read_dir(dir.path())
        .unwrap()
        .filter_map(|e| e.ok())
        .collect();
    let has_corrupt = siblings
        .iter()
        .any(|e| e.file_name().to_string_lossy().contains(".corrupt-"));
    assert!(has_corrupt, ".corrupt-<epoch> file must exist after rename");
}

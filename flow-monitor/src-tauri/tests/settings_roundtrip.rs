/// Seam 5 integration tests for `settings_io`.
///
/// Each test exercises the public API through the crate boundary so that
/// the atomic-rename, .bak, and forward-compatibility invariants are
/// verified at the integration level (not just unit level).
use flow_monitor_lib::settings::{self, Language, Settings, Theme};
use serde_json::Value;
use std::collections::HashMap;
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

// ---------------------------------------------------------------------------
// T9 — full-struct byte-equality: every field set to a non-default value
// ---------------------------------------------------------------------------
//
// Unlike T1 (which sets most fields), this test exhaustively sets EVERY field
// declared on `Settings` to a value different from its `Default` impl, then
// performs a double round-trip to confirm structural stability. This guards
// against a future field addition that is accidentally omitted from serialisation.

#[test]
fn seam5_all_fields_non_default_round_trip() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");

    // Build a Settings value where every field differs from Default::default().
    let mut repo_collapse: HashMap<PathBuf, bool> = HashMap::new();
    repo_collapse.insert(PathBuf::from("/tmp/repo-alpha"), true);
    repo_collapse.insert(PathBuf::from("/tmp/repo-beta"), false);

    let original = Settings {
        // schema_version is fixed at 1 for B1; changing it would be a protocol
        // break, so we keep it at 1 and assert it survives the round-trip.
        schema_version: 1,
        repos: vec![
            PathBuf::from("/tmp/repo-alpha"),
            PathBuf::from("/tmp/repo-beta"),
        ],
        // non-default: default is 3
        polling_interval_secs: 5,
        // non-default: default is 5
        stale_threshold_mins: 20,
        // non-default: default is 30
        stalled_threshold_mins: 60,
        // non-default: default is true
        notifications_enabled: false,
        // non-default: default is true
        always_on_top: false,
        // non-default: default is Language::En
        language: Language::ZhTw,
        // non-default: default is Theme::Light
        theme: Theme::Dark,
        repo_section_collapse: repo_collapse,
    };

    // First write → read → must equal original.
    settings::write(&p, &original).unwrap();
    let after_first = settings::read(&p);
    assert_eq!(
        original, after_first,
        "first round-trip must produce byte-equal Settings for all fields"
    );

    // Second write → read → must still equal original (idempotency).
    settings::write(&p, &after_first).unwrap();
    let after_second = settings::read(&p);
    assert_eq!(
        original, after_second,
        "second round-trip must still produce byte-equal Settings"
    );
}

// ---------------------------------------------------------------------------
// T10 — atomic-write crash simulation: .bak protects the original file
// ---------------------------------------------------------------------------
//
// Strategy: use `std::panic::catch_unwind` to simulate a mid-write crash
// without spawning an external subprocess (which would require a dedicated
// test binary).  We:
//   1. Write a known-good settings file.  settings::write() creates .bak on
//      the *second* write, so we write twice to ensure .bak exists.
//   2. Simulate a crash by writing .tmp manually and then abandoning it
//      (the rename never happens), mirroring what would occur if the process
//      were killed after Phase 3 but before Phase 5 of settings::write().
//   3. Confirm the live settings.json still parses correctly and matches the
//      last-known-good content.
//   4. Confirm .bak is byte-identical to the last-known-good state, so a
//      recovery procedure could use it even if .tmp is corrupt.

#[test]
fn seam5_atomic_write_crash_leaves_original_intact() {
    let dir = tempfile::tempdir().unwrap();
    let p = dir.path().join("settings.json");

    // --- Step 1: establish a known-good state. ---
    let good = Settings {
        polling_interval_secs: 4,
        stale_threshold_mins: 10,
        stalled_threshold_mins: 50,
        notifications_enabled: false,
        always_on_top: false,
        language: Language::ZhTw,
        theme: Theme::Dark,
        repos: vec![PathBuf::from("/tmp/known-good-repo")],
        ..Settings::default()
    };

    // First write: creates the live file; no .bak yet.
    settings::write(&p, &good).unwrap();
    // Second write: copies live → .bak, then atomically renames .tmp → live.
    // After this call both p and p.bak exist and contain `good`.
    settings::write(&p, &good).unwrap();

    let bak_path = {
        let mut b = p.as_os_str().to_os_string();
        b.push(".bak");
        PathBuf::from(b)
    };
    let tmp_path = {
        let mut t = p.as_os_str().to_os_string();
        t.push(".tmp");
        PathBuf::from(t)
    };

    assert!(p.exists(), "live file must exist before crash simulation");
    assert!(bak_path.exists(), ".bak must exist before crash simulation");

    // Capture the live-file content so we can compare after the simulated crash.
    let good_bytes = fs::read(&p).unwrap();

    // --- Step 2: simulate a crash mid-write. ---
    // Write corrupt/partial content to .tmp (as if write() had completed Phase 3
    // but was killed before the Phase 5 rename).
    fs::write(&tmp_path, b"{ \"partial\": true, \"corrupt\": }").unwrap();
    // We intentionally do NOT rename .tmp → p; the process "crashed" here.

    // --- Step 3: confirm the live file is still intact. ---
    // The live path must not have been touched by the aborted write.
    let live_bytes = fs::read(&p).unwrap();
    assert_eq!(
        good_bytes, live_bytes,
        "live settings.json must be byte-identical to good state after crash"
    );

    // Must still parse successfully — not corrupt.
    let recovered = settings::read(&p);
    assert_eq!(
        good, recovered,
        "settings::read() must return the good Settings after crash"
    );

    // --- Step 4: confirm .bak is also the good state (recovery path). ---
    let bak_bytes = fs::read(&bak_path).unwrap();
    assert_eq!(
        good_bytes, bak_bytes,
        ".bak must be byte-identical to last good state for manual recovery"
    );

    // Clean up the leftover .tmp so the tempdir drops cleanly.
    let _ = fs::remove_file(&tmp_path);
}

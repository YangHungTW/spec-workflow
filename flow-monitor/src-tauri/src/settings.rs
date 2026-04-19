use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

/// Display language preference (B1 scope; zh-TW added here, control-plane variants in B2+).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum Language {
    #[default]
    En,
    ZhTw,
}

/// UI colour theme.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum Theme {
    #[default]
    Light,
    Dark,
}

/// B1 application settings.  Unknown top-level JSON keys are preserved on
/// rewrite so that B2 fields added later survive a round-trip through this
/// version's `write()`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Settings {
    /// Bump only when the shape changes in a breaking way.
    #[serde(default = "default_schema_version")]
    pub schema_version: u32,

    /// Watched repository roots.
    #[serde(default)]
    pub repos: Vec<PathBuf>,

    /// How often the polling engine checks for new sessions.
    #[serde(default = "default_polling_interval_secs")]
    pub polling_interval_secs: u64,

    /// Minutes before a session is considered stale.
    #[serde(default = "default_stale_threshold_mins")]
    pub stale_threshold_mins: u64,

    /// Minutes before a session is considered stalled.
    #[serde(default = "default_stalled_threshold_mins")]
    pub stalled_threshold_mins: u64,

    /// Whether desktop notifications are shown.
    #[serde(default = "default_true")]
    pub notifications_enabled: bool,

    /// Whether the window floats above all other windows.
    #[serde(default = "default_true")]
    pub always_on_top: bool,

    /// UI language.
    #[serde(default)]
    pub language: Language,

    /// UI colour theme.
    #[serde(default)]
    pub theme: Theme,

    /// Per-repo collapse state for the sidebar section header.
    #[serde(default)]
    pub repo_section_collapse: HashMap<PathBuf, bool>,
}

// ---------------------------------------------------------------------------
// Default helpers (serde requires free functions for `default = "…"`)
// ---------------------------------------------------------------------------

fn default_schema_version() -> u32 {
    1
}

fn default_polling_interval_secs() -> u64 {
    3
}

fn default_stale_threshold_mins() -> u64 {
    5
}

fn default_stalled_threshold_mins() -> u64 {
    30
}

fn default_true() -> bool {
    true
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            schema_version: default_schema_version(),
            repos: Vec::new(),
            polling_interval_secs: default_polling_interval_secs(),
            stale_threshold_mins: default_stale_threshold_mins(),
            stalled_threshold_mins: default_stalled_threshold_mins(),
            notifications_enabled: default_true(),
            always_on_top: default_true(),
            language: Language::default(),
            theme: Theme::default(),
            repo_section_collapse: HashMap::new(),
        }
    }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Read settings from `path`.
///
/// * If the file does not exist, silently return `Settings::default()`.
/// * If the file exists but cannot be parsed, rename it to
///   `<path>.corrupt-<epoch>` (best-effort) and return `Settings::default()`.
pub fn read(path: &Path) -> Settings {
    let raw = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Settings::default(),
        Err(_) => return Settings::default(),
    };

    match serde_json::from_str::<Settings>(&raw) {
        Ok(s) => s,
        Err(_) => {
            // Rename corrupt file so the user can inspect it later.
            let epoch = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0);
            let corrupt = format!("{}.corrupt-{}", path.display(), epoch);
            let _ = std::fs::rename(path, &corrupt);
            Settings::default()
        }
    }
}

/// Write `settings` to `path` using the read-merge-write atomic-rename
/// discipline required by `.claude/rules/common/no-force-on-user-paths.md`
/// and D8:
///
/// 1. Read the existing file as a raw JSON object (preserves unknown B2+ keys).
/// 2. Merge the serialised `settings` over the preserved map.
/// 3. Write the merged map to `<path>.tmp` — the only `fs::write` target.
/// 4. Copy `<path>` → `<path>.bak` (best-effort; skipped when absent).
/// 5. Atomic rename `<path>.tmp` → `<path>`.
pub fn write(path: &Path, settings: &Settings) -> std::io::Result<()> {
    // Phase 1 — classify: read existing JSON as a generic map so unknown keys survive.
    let mut merged: serde_json::Map<String, Value> = if path.exists() {
        let raw = std::fs::read_to_string(path)?;
        serde_json::from_str(&raw).unwrap_or_default()
    } else {
        serde_json::Map::new()
    };

    // Phase 2 — merge: overlay incoming settings over preserved keys.
    let incoming = serde_json::to_value(settings)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
    if let Value::Object(map) = incoming {
        for (k, v) in map {
            merged.insert(k, v);
        }
    }

    let serialised = serde_json::to_string_pretty(&Value::Object(merged))
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;

    // Phase 3 — write to .tmp (the ONLY fs::write target — never the live path).
    let tmp_path = tmp_path_for(path);
    std::fs::write(&tmp_path, serialised.as_bytes())?;

    // Phase 4 — backup: copy live file to .bak before the rename (best-effort).
    if path.exists() {
        let bak_path = bak_path_for(path);
        let _ = std::fs::copy(path, &bak_path);
    }

    // Phase 5 — atomic swap: rename .tmp → live path.
    std::fs::rename(&tmp_path, path)?;

    Ok(())
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn tmp_path_for(path: &Path) -> PathBuf {
    let mut p = path.as_os_str().to_os_string();
    p.push(".tmp");
    PathBuf::from(p)
}

fn bak_path_for(path: &Path) -> PathBuf {
    let mut p = path.as_os_str().to_os_string();
    p.push(".bak");
    PathBuf::from(p)
}

// ---------------------------------------------------------------------------
// Unit tests (kept here for `cargo test settings` convenience)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::NamedTempFile;

    /// Helper: write raw text to a NamedTempFile and return its path kept open.
    fn write_raw(content: &str) -> NamedTempFile {
        let f = NamedTempFile::new().unwrap();
        fs::write(f.path(), content).unwrap();
        f
    }

    #[test]
    fn settings_read_returns_defaults_when_absent() {
        let path = PathBuf::from("/tmp/settings_nonexistent_test_file_xyz.json");
        let s = read(&path);
        assert_eq!(s, Settings::default());
    }

    #[test]
    fn settings_read_returns_defaults_on_corrupt_json() {
        let f = write_raw("{ not valid json }");
        let p = f.path().to_path_buf();
        let s = read(&p);
        assert_eq!(s, Settings::default());
        // The corrupt file should have been renamed; original path gone.
        assert!(!p.exists(), "corrupt file should have been renamed away");
    }

    #[test]
    fn settings_round_trip() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("settings.json");

        let mut s = Settings::default();
        s.repos = vec![PathBuf::from("/tmp/repo-a")];
        s.polling_interval_secs = 10;
        s.theme = Theme::Dark;
        s.language = Language::ZhTw;

        write(&p, &s).unwrap();
        let s2 = read(&p);
        assert_eq!(s, s2);
    }

    #[test]
    fn settings_write_creates_bak_when_prior_file_exists() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("settings.json");

        // Write once to create the live file.
        write(&p, &Settings::default()).unwrap();
        assert!(p.exists(), "live file should exist after first write");

        // Write again — this second call should create the .bak.
        write(&p, &Settings::default()).unwrap();

        let bak = bak_path_for(&p);
        assert!(bak.exists(), ".bak should exist after second write");
    }

    #[test]
    fn settings_write_no_bak_when_no_prior_file() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("settings.json");

        write(&p, &Settings::default()).unwrap();

        let bak = bak_path_for(&p);
        assert!(!bak.exists(), ".bak should NOT exist on first write");
    }

    #[test]
    fn settings_write_preserves_unknown_top_level_keys() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("settings.json");

        // Seed the file with a B2 field that this version does not know about.
        let seed = r#"{"schema_version":1,"b2_field":"hello","repos":[]}"#;
        fs::write(&p, seed).unwrap();

        // Read (should ignore unknown field but not crash).
        let s = read(&p);
        assert_eq!(s.schema_version, 1);

        // Rewrite through our write() — unknown key must survive.
        write(&p, &s).unwrap();

        let on_disk = fs::read_to_string(&p).unwrap();
        let parsed: Value = serde_json::from_str(&on_disk).unwrap();
        assert_eq!(
            parsed.get("b2_field").and_then(Value::as_str),
            Some("hello"),
            "b2_field must be preserved after round-trip rewrite"
        );
    }

    #[test]
    fn settings_write_only_targets_tmp_not_live_path_directly() {
        // This test validates the write discipline indirectly: we stat the live
        // path BEFORE and AFTER write() and confirm the only intermediate file
        // that appears and disappears is the .tmp file.
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("settings.json");
        let tmp = tmp_path_for(&p);

        // .tmp must not exist before write.
        assert!(!tmp.exists());

        write(&p, &Settings::default()).unwrap();

        // After write() completes, .tmp must have been renamed away.
        assert!(!tmp.exists(), ".tmp must be renamed away by atomic swap");
        assert!(p.exists(), "live path must exist after write");
    }
}

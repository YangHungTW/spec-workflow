pub mod archive_discovery;
pub mod fs_watcher;
pub mod audit;
pub mod artefact_presence;
pub mod command_taxonomy;
pub mod invoke;
pub mod ipc;
pub mod lock;
pub mod notify;
pub mod repo_discovery;
pub mod settings;
pub mod status_parse;
pub mod store;
pub mod tray;

use tauri::Manager;

/// Serialisable payload emitted on the `sessions_changed` event.
///
/// Extends the B1 unit-payload (`()`) with the stalled-transitions list from
/// `store::diff` so the renderer can correlate notification firings without a
/// second IPC round-trip (D5, AC1.a).
#[derive(Debug, Clone, serde::Serialize)]
pub struct SessionsChangedPayload {
    /// Session keys that newly crossed the stalled threshold on this tick.
    /// Each entry is `(repo_path, slug)` — matches `store::SessionKey`.
    pub stalled_transitions: Vec<(std::path::PathBuf, String)>,
}

/// Identifies which artefact kind triggered an `artifact_changed` event (D3).
#[derive(Clone, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ArtifactKind {
    Request,
    Design,
    Prd,
    Tech,
    Plan,
    Tasks,
    Status,
    Other,
}

/// Two-state watcher health indicator for `watcher_status` events (D3, R16).
#[derive(Clone, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum WatcherState {
    Running,
    Errored,
}

/// Serialisable payload emitted on the `artifact_changed` event (D3).
#[derive(Clone, serde::Serialize)]
pub struct ArtifactChangedPayload {
    /// Absolute path to the repository root.
    pub repo_path: String,
    /// Feature slug (e.g. "20260426-flow-monitor-graph-view").
    pub slug: String,
    /// Which artefact kind changed.
    pub kind: ArtifactKind,
    /// Absolute path to the changed artefact file.
    pub path: String,
    /// Unix epoch milliseconds of the file's mtime.
    pub mtime_ms: u64,
}

/// Serialisable payload emitted on the `watcher_status` event (D3, R16).
#[derive(Clone, serde::Serialize)]
pub struct WatcherStatusPayload {
    /// Current watcher health state.
    pub state: WatcherState,
    /// Human-readable error kind when state is Errored; None when Running.
    pub error_kind: Option<String>,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_dialog::init())
        // See D1 / T93 — fs plugin needed for audit-log appends + temp invoke-*.command writes
        .plugin(tauri_plugin_fs::init())
        // See D1 / T93 — shell plugin needed for argv-form /usr/bin/open Terminal.app spawn
        .plugin(tauri_plugin_shell::init())
        // Restores position + size for every named window (main, compact) before
        // first paint. Applied unconditionally — the RISK GATE in 05-plan.md R-2
        // requires dropping this plugin if it causes flash, drift, or focus
        // issues; document the cut in STATUS Notes if that occurs.
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .plugin(tauri_plugin_opener::init())
        .manage(ipc::SettingsState(std::sync::Mutex::new(
            ipc::Settings::default(),
        )))
        .manage(ipc::SessionsState(std::sync::Mutex::new(
            ipc::SessionList::new(),
        )))
        .setup(|app| {
            let repos = {
                let settings_state = app.state::<ipc::SettingsState>();
                let guard = settings_state.0.lock().expect("settings lock poisoned");
                guard.repos.clone()
            };
            fs_watcher::spawn_watcher(repos, app.handle().clone()).expect("watcher init");
            Ok(())
        })
        .manage(crate::lock::LockState::new())
        .invoke_handler(tauri::generate_handler![
            ipc::list_sessions,
            ipc::get_settings,
            ipc::update_settings,
            ipc::add_repo,
            ipc::remove_repo,
            ipc::read_artefact,
            ipc::set_compact_panel_open,
            ipc::set_always_on_top,
            ipc::set_notification_strings,
            ipc::open_in_finder,
            ipc::reveal_in_finder,
            ipc::copy_to_clipboard,
            ipc::get_notification_permission_status,
            ipc::focus_main_window,
            ipc::dialog_open_directory,
            // B2 control-plane commands (T109) — invoke_handler region only;
            // T108 edits the polling-loop region 30+ lines below; regions are disjoint.
            ipc::invoke_command,
            ipc::get_audit_tail,
            ipc::get_in_flight_set,
            // T7: new commands wired so the renderer can invoke them (D11).
            archive_discovery::list_archived_features,
            artefact_presence::list_feature_artefacts,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

// ---------------------------------------------------------------------------
// Inline tests — Seam A: prev_stalled_set carry across ticks (AC1.c / AC1.d)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use std::collections::{HashMap, HashSet};
    use std::path::PathBuf;
    use std::time::{Duration, SystemTime, UNIX_EPOCH};

    use crate::status_parse::{SessionState, Stage};
    use crate::store::{diff, SessionKey, SessionMap};

    /// Build a minimal `SessionState` with last_activity set to `ago` seconds
    /// before now so that it is treated as stalled when the threshold is shorter
    /// than `ago`.
    fn stalled_state(slug: &str, ago_secs: u64) -> SessionState {
        let last_activity = SystemTime::now()
            .checked_sub(Duration::from_secs(ago_secs))
            .unwrap_or(UNIX_EPOCH);
        SessionState {
            slug: slug.to_string(),
            stage: Stage::Implement,
            last_activity,
            stage_checklist: vec![],
            notes: vec![],
            has_ui: false,
            raw_status_path: PathBuf::new(),
        }
    }

    fn key(repo: &str, slug: &str) -> SessionKey {
        (PathBuf::from(repo), slug.to_string())
    }

    /// AC1.c — Seam A: a session already in `prev_stalled_set` on tick N must
    /// NOT appear in `stalled_transitions` on tick N+1 while still stalled.
    ///
    /// This verifies that `run_session_polling` correctly carries
    /// `prev_stalled_set = diff_event.next_stalled_set` across ticks so that
    /// re-notification is suppressed for sessions that remain stalled.
    #[test]
    fn seam_a_stalled_session_does_not_re_notify_on_subsequent_tick() {
        // Use a 5-minute threshold; session has been idle for 10 minutes → stalled.
        let threshold = Duration::from_secs(5 * 60);
        let slug = "my-feature";
        let repo = "/repo/test";

        let k = key(repo, slug);
        let state = stalled_state(slug, 10 * 60); // 10 min idle

        let mut map: SessionMap = HashMap::new();
        map.insert(k.clone(), state.clone());

        // Tick N: empty prev_map, empty prev_stalled_set.
        let prev_map: SessionMap = HashMap::new();
        let prev_stalled_set: HashSet<SessionKey> = HashSet::new();

        let event_n = diff(&prev_map, &map, threshold, &prev_stalled_set);

        // Session is new + stalled → must appear in stalled_transitions on tick N.
        assert!(
            event_n.stalled_transitions.contains(&k),
            "tick N: newly stalled session must appear in stalled_transitions; got {:?}",
            event_n.stalled_transitions,
        );

        // Carry state forward — this is the wiring T108 adds to lib.rs.
        let prev_stalled_set_n1 = event_n.next_stalled_set.clone();

        // Tick N+1: same map, session still stalled, prev_stalled_set is now populated.
        let event_n1 = diff(&map, &map, threshold, &prev_stalled_set_n1);

        // Session remains stalled but was already in prev_stalled_set →
        // must NOT appear in stalled_transitions (AC1.c).
        assert!(
            event_n1.stalled_transitions.is_empty(),
            "tick N+1: session still stalled but prev_stalled_set populated — \
             stalled_transitions must be empty; got {:?}",
            event_n1.stalled_transitions,
        );
    }

    /// AC1.d — structural half: a session that leaves stalled and re-crosses
    /// the threshold fires the stalled transition again.
    ///
    /// Verifies that when a session is removed from `prev_stalled_set` (because
    /// STATUS.md advanced and it dropped below the threshold) and later becomes
    /// stalled again, the transition fires once more.
    #[test]
    fn seam_a_session_re_enters_stalled_fires_transition_again() {
        let threshold = Duration::from_secs(5 * 60);
        let slug = "re-enter-feature";
        let repo = "/repo/test";

        let k = key(repo, slug);
        let stalled = stalled_state(slug, 10 * 60);

        // Active state: last_activity was 1 second ago (not stalled).
        let active = SessionState {
            last_activity: SystemTime::now()
                .checked_sub(Duration::from_secs(1))
                .unwrap_or(UNIX_EPOCH),
            ..stalled.clone()
        };

        let mut stalled_map: SessionMap = HashMap::new();
        stalled_map.insert(k.clone(), stalled.clone());

        let mut active_map: SessionMap = HashMap::new();
        active_map.insert(k.clone(), active);

        // Tick 1: session becomes stalled (prev empty).
        let empty_map: SessionMap = HashMap::new();
        let empty_set: HashSet<SessionKey> = HashSet::new();
        let e1 = diff(&empty_map, &stalled_map, threshold, &empty_set);
        assert!(e1.stalled_transitions.contains(&k), "tick 1: should fire");

        // Tick 2: session becomes active — not stalled, removed from stalled set.
        let e2 = diff(&stalled_map, &active_map, threshold, &e1.next_stalled_set);
        assert!(
            !e2.next_stalled_set.contains(&k),
            "tick 2: active session must not be in next_stalled_set"
        );

        // Tick 3: session stalls again — prev_stalled_set does NOT contain it.
        let e3 = diff(&active_map, &stalled_map, threshold, &e2.next_stalled_set);
        assert!(
            e3.stalled_transitions.contains(&k),
            "tick 3: re-stalled session must fire again; got {:?}",
            e3.stalled_transitions,
        );
    }
}

// ---------------------------------------------------------------------------
// T4 struct / enum tests — compile-gate that the types exist with correct fields
// ---------------------------------------------------------------------------

#[cfg(test)]
mod t4_type_tests {
    use super::{ArtifactChangedPayload, ArtifactKind, WatcherState, WatcherStatusPayload};

    /// Verifies ArtifactKind variants compile and Serialize/Clone derives work.
    #[test]
    fn artifact_kind_variants_compile() {
        let kinds = [
            ArtifactKind::Request,
            ArtifactKind::Design,
            ArtifactKind::Prd,
            ArtifactKind::Tech,
            ArtifactKind::Plan,
            ArtifactKind::Tasks,
            ArtifactKind::Status,
            ArtifactKind::Other,
        ];
        let _ = kinds.clone();
        let json = serde_json::to_string(&ArtifactKind::Plan).unwrap();
        assert_eq!(json, "\"plan\"");
    }

    /// Verifies WatcherState variants compile and serialize to snake_case.
    #[test]
    fn watcher_state_variants_compile() {
        let _ = WatcherState::Running.clone();
        let _ = WatcherState::Errored.clone();
        let json = serde_json::to_string(&WatcherState::Errored).unwrap();
        assert_eq!(json, "\"errored\"");
    }

    /// Verifies ArtifactChangedPayload can be constructed and serialized.
    #[test]
    fn artifact_changed_payload_fields_and_serialize() {
        let p = ArtifactChangedPayload {
            repo_path: "/repo/test".to_string(),
            slug: "my-feature".to_string(),
            kind: ArtifactKind::Status,
            path: "/repo/test/.specaffold/features/my-feature/STATUS.md".to_string(),
            mtime_ms: 1_700_000_000_000,
        };
        let _ = p.clone();
        let json = serde_json::to_string(&p).unwrap();
        assert!(json.contains("\"repo_path\""));
        assert!(json.contains("\"slug\""));
        assert!(json.contains("\"kind\""));
        assert!(json.contains("\"path\""));
        assert!(json.contains("\"mtime_ms\""));
    }

    /// Verifies WatcherStatusPayload can be constructed with None and Some error_kind.
    #[test]
    fn watcher_status_payload_fields_and_serialize() {
        let running = WatcherStatusPayload {
            state: WatcherState::Running,
            error_kind: None,
        };
        let _ = running.clone();
        let errored = WatcherStatusPayload {
            state: WatcherState::Errored,
            error_kind: Some("init_failed".to_string()),
        };
        let _ = errored.clone();
        let json = serde_json::to_string(&errored).unwrap();
        assert!(json.contains("\"state\""));
        assert!(json.contains("\"error_kind\""));
        assert!(json.contains("init_failed"));
    }
}


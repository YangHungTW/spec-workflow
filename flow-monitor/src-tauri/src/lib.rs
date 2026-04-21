pub mod audit;
pub mod ipc;
pub mod invoke;
pub mod notify;
pub mod poller;
pub mod repo_discovery;
pub mod settings;
pub mod status_parse;
pub mod store;
pub mod tray;

use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tauri::Manager;

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
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                run_session_polling(app_handle).await;
            });
            Ok(())
        })
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
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

/// Background polling task: every interval_secs, scans every registered repo,
/// discovers sessions, parses STATUS.md, updates SessionsState, emits event.
/// Reads SettingsState.repos LIVE so add_repo / remove_repo are observed.
async fn run_session_polling(app: tauri::AppHandle) {
    use tauri::Emitter;
    loop {
        // Snapshot settings + sleep duration without holding lock during scan
        let (repos, interval_secs) = {
            let settings_state = app.state::<ipc::SettingsState>();
            let guard = settings_state.0.lock().expect("settings lock poisoned");
            (guard.repos.clone(), guard.polling_interval_secs.max(1))
        };

        let mut new_list: Vec<ipc::SessionRecord> = Vec::new();
        for repo in &repos {
            let sessions = repo_discovery::discover_sessions(repo);
            for session_info in sessions {
                let content = match std::fs::read_to_string(&session_info.status_path) {
                    Ok(c) => c,
                    Err(_) => continue,
                };
                let mtime = std::fs::metadata(&session_info.status_path)
                    .and_then(|m| m.modified())
                    .unwrap_or(SystemTime::UNIX_EPOCH);
                let state = status_parse::parse(&content, mtime);
                if matches!(state.stage, status_parse::Stage::Archive) {
                    continue;
                }
                let last_activity_secs = state
                    .last_activity
                    .duration_since(UNIX_EPOCH)
                    .map(|d| d.as_secs())
                    .unwrap_or(0);
                new_list.push(ipc::SessionRecord {
                    repo: repo.clone(),
                    slug: session_info.slug,
                    stage: format!("{:?}", state.stage).to_lowercase(),
                    last_activity_secs,
                    has_ui: state.has_ui,
                });
            }
        }

        // Update shared state + emit event
        {
            let sessions_state = app.state::<ipc::SessionsState>();
            let mut guard = sessions_state.0.lock().expect("sessions lock poisoned");
            *guard = new_list;
        }
        let _ = app.emit("sessions_changed", ());

        tokio::time::sleep(Duration::from_secs(interval_secs)).await;
    }
}

pub mod ipc;
pub mod notify;
pub mod poller;
pub mod repo_discovery;
pub mod settings;
pub mod status_parse;
pub mod store;
pub mod tray;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_dialog::init())
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

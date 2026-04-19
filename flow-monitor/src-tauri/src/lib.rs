pub mod ipc;
pub mod poller;
pub mod repo_discovery;
pub mod settings;
pub mod store;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
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
            ipc::copy_to_clipboard,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

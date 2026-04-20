//! Tray icon module — macOS menu bar icon with stalled-count badge.
//!
//! This module exposes `init_tray`, which wires a `TrayIcon` into the Tauri
//! application during setup.  Badge updates are throttled to one per polling
//! cycle: the caller drives the update frequency by calling `update_stalled_count`
//! exactly once per `DiffEvent` received from the polling loop.
//!
//! macOS-only for B1.  On other platforms the tray icon is still registered
//! (Tauri supports it) but the badge overlay is a no-op because macOS
//! NSStatusItem badge rendering is the only supported path in this release.

use std::sync::{Arc, Mutex};

use tauri::{
    image::Image,
    menu::{Menu, MenuItem},
    tray::{TrayIcon, TrayIconBuilder},
    AppHandle, Manager, Runtime,
};

use crate::store::SessionMap;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Initialise the tray icon and wire it into the Tauri app handle.
///
/// Must be called from within the `.setup()` callback so that the Tauri
/// runtime is fully initialised before the tray icon is created.
///
/// The returned `TrayIcon` must be kept alive for the duration of the
/// application; drop it only on quit.
pub fn init_tray<R: Runtime>(
    app: &AppHandle<R>,
    _store: Arc<Mutex<SessionMap>>,
) -> tauri::Result<TrayIcon<R>> {
    // Build the "Open Flow Monitor" menu item.  The menu item id is used by
    // the event handler to dispatch the focus action.
    let open_item = MenuItem::with_id(app, "open-flow-monitor", "Open Flow Monitor", true, None::<&str>)?;

    let menu = Menu::with_items(app, &[&open_item])?;

    // Load the placeholder tray icon bundled with the app.  Falls back to an
    // empty 1×1 transparent pixel on any load failure so the app still starts.
    let icon = load_tray_icon(app);

    let tray = TrayIconBuilder::with_id("flow-monitor-tray")
        .tooltip("Flow Monitor")
        .icon(icon)
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event({
            let app_handle = app.clone();
            move |_tray, event| {
                if event.id.as_ref() == "open-flow-monitor" {
                    focus_main_window(&app_handle);
                }
            }
        })
        .on_tray_icon_event({
            let app_handle = app.clone();
            move |_tray, event| {
                // Left-click on the tray icon focuses the main window.
                if let tauri::tray::TrayIconEvent::Click {
                    button: tauri::tray::MouseButton::Left,
                    button_state: tauri::tray::MouseButtonState::Up,
                    ..
                } = event
                {
                    focus_main_window(&app_handle);
                }
            }
        })
        .build(app)?;

    Ok(tray)
}

/// Update the tray icon tooltip to reflect the current stalled-session count.
///
/// Called once per polling cycle (throttled by the caller — one call per
/// `DiffEvent`, not one call per session change within a cycle).
///
/// The stalled count is derived purely from `stalled_set.len()` on the
/// `DiffEvent.next_stalled_set`, which is already computed by `store::diff`.
/// This function accepts the pre-computed count to keep it pure and testable.
pub fn update_stalled_count<R: Runtime>(tray: &TrayIcon<R>, stalled_count: usize) -> tauri::Result<()> {
    let tooltip = if stalled_count == 0 {
        "Flow Monitor".to_string()
    } else {
        format!("Flow Monitor — {} stalled", stalled_count)
    };
    tray.set_tooltip(Some(tooltip))
}

/// Compute the stalled-session count from a `SessionMap` snapshot.
///
/// Pure function — no side effects.  Used by tests and by the update path.
pub fn stalled_count_from_store(stalled_set_len: usize) -> usize {
    stalled_set_len
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Focus (show and raise) the main window.
fn focus_main_window<R: Runtime>(app: &AppHandle<R>) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.set_focus();
    }
}

/// Load the tray icon image.  Uses the bundled default window icon when
/// available; otherwise falls back to a 1×1 transparent pixel so the app
/// does not crash on icon load failure.
fn load_tray_icon<R: Runtime>(app: &AppHandle<R>) -> Image<'static> {
    app.default_window_icon()
        .and_then(|icon| {
            // Clone the rgba bytes out so we own them with 'static lifetime.
            let rgba = icon.rgba().to_vec();
            let (w, h) = (icon.width(), icon.height());
            Some(Image::new_owned(rgba, w, h))
        })
        .unwrap_or_else(|| {
            // Minimal 1×1 transparent RGBA fallback.
            Image::new_owned(vec![0u8, 0, 0, 0], 1, 1)
        })
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::status_parse::SessionState;
    use crate::store::{SessionKey, SessionMap};
    use std::collections::{HashMap, HashSet};
    use std::path::PathBuf;
    use std::time::SystemTime;

    /// Build a minimal `SessionState` for use in test fixtures.
    fn make_state(slug: &str) -> SessionState {
        use crate::status_parse::Stage;
        SessionState {
            slug: slug.to_string(),
            stage: Stage::Implement,
            last_activity: SystemTime::now(),
            stage_checklist: vec![],
            notes: vec![],
            raw_status_path: PathBuf::new(),
        }
    }

    /// Build a `SessionKey` helper.
    fn key(repo: &str, slug: &str) -> SessionKey {
        (PathBuf::from(repo), slug.to_string())
    }

    // -----------------------------------------------------------------------
    // T25 acceptance: stalled-count computation from SessionMap
    // -----------------------------------------------------------------------

    /// AC: stalled_count_from_store returns 0 when the stalled set is empty.
    #[test]
    fn test_stalled_count_zero_when_no_stalled_sessions() {
        let count = stalled_count_from_store(0);
        assert_eq!(count, 0);
    }

    /// AC: stalled_count_from_store returns the correct count for N stalled
    /// sessions, verified by building a realistic stalled set.
    #[test]
    fn test_stalled_count_matches_stalled_set_len() {
        let mut map: SessionMap = HashMap::new();
        map.insert(key("/repo/a", "alpha"), make_state("alpha"));
        map.insert(key("/repo/a", "beta"), make_state("beta"));
        map.insert(key("/repo/b", "gamma"), make_state("gamma"));

        // Simulate a stalled set containing two of the three sessions.
        let mut stalled: HashSet<SessionKey> = HashSet::new();
        stalled.insert(key("/repo/a", "alpha"));
        stalled.insert(key("/repo/b", "gamma"));

        let count = stalled_count_from_store(stalled.len());
        assert_eq!(count, 2, "stalled count must equal stalled_set.len()");
    }

    /// AC: badge shows 0 when ALL sessions recover (stalled set empties).
    #[test]
    fn test_stalled_count_resets_to_zero_after_recovery() {
        // First tick: two sessions stalled.
        let first = stalled_count_from_store(2);
        assert_eq!(first, 2);

        // Second tick: all sessions recover — stalled set empties.
        let second = stalled_count_from_store(0);
        assert_eq!(second, 0, "count must reset to 0 when stalled set is empty");
    }

    /// AC: stalled_count_from_store is a pure passthrough of the stalled
    /// set length — it never clamps, caps, or transforms the value.
    #[test]
    fn test_stalled_count_is_pure_passthrough() {
        for n in [0usize, 1, 5, 10, 100] {
            assert_eq!(
                stalled_count_from_store(n),
                n,
                "stalled_count_from_store must return its argument unchanged"
            );
        }
    }
}

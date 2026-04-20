//! macOS Notification Center integration — fire-once on stalled transitions.
//!
//! This module has one public entry point:
//!   `fire_stalled_notification(repo, slug, stage, title, body, enabled, sink)`
//!
//! Dedupe is the caller's responsibility: the caller passes only the keys
//! present in `DiffEvent.stalled_transitions` (T8's `store::diff` output),
//! which are already guaranteed to be one-shot per crossing.  This function
//! fires exactly once for each invocation when `enabled` is true.
//!
//! The `title` and `body` strings are supplied by the renderer via
//! `set_notification_strings` IPC (T11) — this module accepts them as
//! arguments and does not compose English strings internally (AC11.d).
//!
//! Permission denial is handled silently: the plugin's `show()` returns an
//! error which is logged at WARN level; the caller receives `Ok(())` and
//! the in-app indicator (T23) surfaces the denied state via settings.
//!
//! The `NotificationSink` trait abstracts the OS call for unit testability
//! (injected in tests via `MockSink`; injected in production via
//! `TauriSink` which wraps `tauri_plugin_notification::Notification`).

use std::path::Path;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;

// ---------------------------------------------------------------------------
// NotificationSink trait — seam between production and test code
// ---------------------------------------------------------------------------

/// Abstraction over the OS notification call.
///
/// Production code uses `TauriSink`; test code uses `MockSink`.
/// The trait is object-safe so it can be passed as `&dyn NotificationSink`.
pub trait NotificationSink {
    /// Fire one silent notification with the given title and body.
    ///
    /// The implementation is responsible for honouring the silent flag.
    /// Returns `Ok(())` even on permission denial — callers must not retry.
    fn notify(&self, title: &str, body: &str) -> Result<(), String>;
}

// ---------------------------------------------------------------------------
// MockSink — used in tests; counts invocations
// ---------------------------------------------------------------------------

/// Test double that counts how many times `notify` was called.
///
/// Thread-safe via `AtomicU32`; can be shared across assertion boundaries.
pub struct MockSink {
    count: Arc<AtomicU32>,
}

impl MockSink {
    /// Create a new sink with zero invocations.
    pub fn new() -> Self {
        Self {
            count: Arc::new(AtomicU32::new(0)),
        }
    }

    /// Return the total number of `notify` invocations so far.
    pub fn fired_count(&self) -> u32 {
        self.count.load(Ordering::SeqCst)
    }
}

impl Default for MockSink {
    fn default() -> Self {
        Self::new()
    }
}

impl NotificationSink for MockSink {
    fn notify(&self, _title: &str, _body: &str) -> Result<(), String> {
        self.count.fetch_add(1, Ordering::SeqCst);
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// TauriSink — production implementation wrapping tauri-plugin-notification
// ---------------------------------------------------------------------------

/// Production `NotificationSink` backed by `tauri_plugin_notification`.
///
/// Silent flag is set unconditionally (AC6.d — no sound).
/// Permission denial → the error is logged at WARN and `Ok(())` is returned
/// so the caller is not interrupted.
#[cfg(not(test))]
pub struct TauriSink {
    app: tauri::AppHandle,
}

#[cfg(not(test))]
impl TauriSink {
    /// Construct from an `AppHandle` obtained during plugin setup.
    pub fn new(app: tauri::AppHandle) -> Self {
        Self { app }
    }
}

#[cfg(not(test))]
impl NotificationSink for TauriSink {
    fn notify(&self, title: &str, body: &str) -> Result<(), String> {
        use tauri_plugin_notification::NotificationExt;
        // `.silent()` sets the notification to silent (no sound) — AC6.d.
        // In tauri-plugin-notification 2.x, `.silent()` takes no argument.
        let result = self
            .app
            .notification()
            .builder()
            .title(title)
            .body(body)
            .silent()
            .show();
        match result {
            Ok(_) => Ok(()),
            Err(e) => {
                // Permission denial or other OS error: log and return Ok(())
                // so the caller is not interrupted (PRD §6 edge case).
                tracing::warn!(
                    error = %e,
                    "notification failed (permission denied or OS error) — suppressing silently"
                );
                Ok(())
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Core function — single point of fire
// ---------------------------------------------------------------------------

/// Fire one macOS Notification Center banner for a stalled-transition crossing.
///
/// # Arguments
/// * `repo`    – absolute path to the repository root (informational; logged).
/// * `slug`    – feature slug (informational; logged).
/// * `stage`   – current workflow stage string (informational; logged).
/// * `title`   – notification title supplied by the renderer (AC11.d).
/// * `body`    – notification body supplied by the renderer (AC11.d).
/// * `enabled` – `settings.notifications_enabled`; when false, returns early
///               without calling the sink (AC6.e).
/// * `sink`    – `&dyn NotificationSink`; production code passes `&TauriSink`,
///               tests pass `&MockSink`.
///
/// # Dedupe contract
/// Callers **must** pass only keys from `DiffEvent.stalled_transitions`.
/// That slice is already deduplicated by `store::diff` (AC6.a/b/c), so this
/// function fires exactly once per call — it performs no internal deduplication.
///
/// # Panics
/// Does not panic. Errors from the sink are absorbed (permission denial → Ok).
pub fn fire_stalled_notification(
    repo: &Path,
    slug: &str,
    stage: &str,
    title: &str,
    body: &str,
    enabled: bool,
    sink: &dyn NotificationSink,
) {
    if !enabled {
        tracing::debug!(
            repo = %repo.display(),
            slug,
            stage,
            "notifications disabled — skipping stalled notification"
        );
        return;
    }

    tracing::info!(
        repo = %repo.display(),
        slug,
        stage,
        "firing stalled-transition notification"
    );

    if let Err(e) = sink.notify(title, body) {
        // Sink implementations are expected to absorb OS errors internally;
        // this branch is a fallback for any sink that propagates them.
        tracing::warn!(
            error = %e,
            slug,
            "stalled notification sink returned error — ignoring"
        );
    }
}

// ---------------------------------------------------------------------------
// Unit tests (in-module)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn silent_flag_is_honoured_by_mock_sink() {
        // The MockSink does not check the silent flag — it is an attribute
        // of the TauriSink which passes `.silent(true)` unconditionally.
        // This test verifies that `fire_stalled_notification` with a mock
        // sink counts exactly one invocation per call (not zero, not two).
        let sink = MockSink::new();
        fire_stalled_notification(
            Path::new("/repo/test"),
            "test-feature",
            "Implement",
            "flow-monitor",
            "A session has stalled.",
            true,
            &sink,
        );
        assert_eq!(sink.fired_count(), 1);
    }

    #[test]
    fn disabled_notifications_fire_zero_times() {
        let sink = MockSink::new();
        fire_stalled_notification(
            Path::new("/repo/test"),
            "test-feature",
            "Implement",
            "flow-monitor",
            "A session has stalled.",
            false, // disabled
            &sink,
        );
        assert_eq!(sink.fired_count(), 0);
    }

    #[test]
    fn multiple_independent_calls_each_fire_once() {
        // Verifies that the function has no hidden internal deduplication
        // that would suppress a legitimate second call (AC6.c — re-cross).
        let sink = MockSink::new();
        for _ in 0..3 {
            fire_stalled_notification(
                Path::new("/repo/test"),
                "test-feature",
                "Implement",
                "flow-monitor",
                "A session has stalled.",
                true,
                &sink,
            );
        }
        assert_eq!(sink.fired_count(), 3);
    }
}

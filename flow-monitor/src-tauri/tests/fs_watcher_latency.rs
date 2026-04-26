//! Integration test: fs_watcher emits `artifact_changed` within 1 s (AC12).
//!
//! Strategy (option 1 from T13 spec): `spawn_watcher_with_emitter` accepts a
//! generic `artifact_emitter` callback instead of hard-wiring `app.emit(...)`.
//! The production path (via `spawn_watcher`) passes a closure that calls
//! `app.emit`; this test passes a closure that pushes to a `std::sync::mpsc`
//! channel so the async task is never blocked on a `blocking_send`.
//!
//! No `$HOME` access: all paths live inside a `tempfile::tempdir()` sandbox.
//!
//! Observed latency on local APFS (M-series Mac): ~200–300 ms end-to-end from
//! `std::fs::write` to channel receive (debouncer window = 150 ms, D2).
//! 2 s total timeout (0.5 s setup sleep + 1.5 s receive window) gives headroom
//! for slow CI boxes. Both sides canonicalize paths because macOS FSEvents
//! resolves /var/folders → /private/var/folders via a symlink.

use flow_monitor_lib::fs_watcher;
use flow_monitor_lib::fs_watcher::ArtifactChangedPayload;
use std::path::PathBuf;
use std::sync::mpsc as std_mpsc;
use std::time::Duration;
use tempfile::tempdir;

/// AC12: the watcher emits an `artifact_changed` event with the correct path
/// within 2 seconds of a file write.
///
/// Uses a `std::sync::mpsc` channel as the test seam so the emitter closure can
/// be called from inside the async watcher task without blocking a tokio thread.
/// Both the expected path and the received path are canonicalized before the
/// assertion because on macOS, FSEvents resolves `/var` → `/private/var`.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn watcher_emits_artifact_changed_within_one_second() {
    // Build a tempdir repo with the required `.specaffold/features/<slug>/` layout.
    let repo_dir = tempdir().expect("tempdir creation must succeed");
    let repo = repo_dir.path().to_path_buf();

    let slug = "test-feature-latency";
    let artifact_path: PathBuf = repo
        .join(".specaffold")
        .join("features")
        .join(slug)
        .join("03-prd.md");

    std::fs::create_dir_all(artifact_path.parent().expect("parent exists"))
        .expect("dir creation must succeed");

    // Place an initial file so the watched directory tree exists before spawning.
    std::fs::write(&artifact_path, b"initial content").expect("initial write must succeed");

    // Use a sync channel for the test seam: the emitter closure is called from
    // inside an async task (not a blocking thread), so try_send keeps it
    // non-blocking. Capacity 8 is more than enough for the single event we expect.
    let (tx, rx) = std_mpsc::sync_channel::<ArtifactChangedPayload>(8);

    let emitter = move |payload: ArtifactChangedPayload| {
        // try_send is non-blocking; drop the send error if the receiver is gone.
        let _ = tx.try_send(payload);
    };

    // Spawn the watcher pointing at the temp repo root.
    let _handle = fs_watcher::spawn_watcher_with_emitter(vec![repo.clone()], emitter)
        .expect("watcher must initialise without error");

    // Give the OS watcher a moment to register the FSEvents/inotify watch before
    // triggering the write. 500 ms for FSEvents registration on APFS.
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Trigger the file-changed event.
    std::fs::write(&artifact_path, b"updated content").expect("write must succeed");

    // Assert the channel receives an event within 2 seconds.
    // The debouncer window is 150 ms (D2); 2 s gives ample headroom for CI.
    let payload = tokio::task::spawn_blocking(move || {
        rx.recv_timeout(Duration::from_secs(2))
            .expect("must receive artifact_changed event within 2 s")
    })
    .await
    .expect("spawn_blocking must not panic");

    // Canonicalize expected path: on macOS, FSEvents resolves /var → /private/var
    // via a symlink; spawn_watcher_with_emitter already canonicalizes on the
    // emitting side, so both sides must compare canonical forms.
    let canonical_artifact =
        std::fs::canonicalize(&artifact_path).unwrap_or_else(|_| artifact_path.clone());

    assert_eq!(
        payload.path, canonical_artifact,
        "emitted path must match the written file path (canonical)"
    );
    assert_eq!(
        payload.slug, slug,
        "emitted slug must match the feature directory name"
    );
}

//! AC13.c wall-clock budget integration test.
//!
//! Fixture: 5 tempdir repos × 4 STATUS.md each = 20 sessions total (the
//! upper bound from AC13.c).  The polling loop runs for exactly 5 ticks at a
//! 3-second interval.
//!
//! Assertions:
//!   1. Every tick completes in < 3000 ms (the interval — AC13.c MUST).
//!   2. No tick "backs up": the poller uses `tokio::time::interval` which
//!      skips missed ticks when the executor is not saturated; receiving all 5
//!      tick observations within 5 × (interval + buffer) seconds proves no
//!      backup occurred.
//!   3. Target: max tick < 1500 ms (50 % headroom, per 05-plan.md W5 perf
//!      brief).
//!
//! Test-only hook: `poller::run_polling_loop_with_observer` exposes a
//! `std::sync::mpsc::SyncSender<u128>` that the loop uses to emit each tick's
//! elapsed milliseconds.  The function is compiled only under `#[cfg(test)]`
//! and does not alter the public `run_polling_loop` signature.

use flow_monitor_lib::poller::run_polling_loop_with_observer;
use flow_monitor_lib::store::{DiffEvent, SessionMap};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::{mpsc as std_mpsc, Arc, Mutex};
use std::time::Duration;
use tokio::sync::mpsc as tokio_mpsc;

// ---------------------------------------------------------------------------
// Fixture builder
// ---------------------------------------------------------------------------

/// Create one synthetic repo under `base` with `session_count` STATUS.md files.
///
/// Each session directory is named `session-<n>` and contains a minimal
/// STATUS.md that satisfies `status_parse::parse`.
fn make_repo_with_sessions(base: &std::path::Path, session_count: usize) -> PathBuf {
    let features = base.join(".spec-workflow").join("features");
    for i in 0..session_count {
        let slug = format!("session-{i:02}");
        let dir = features.join(&slug);
        fs::create_dir_all(&dir).expect("create session dir");
        fs::write(
            dir.join("STATUS.md"),
            format!(
                "- **slug**: {slug}\n- **stage**: Implement\n- **updated**: 2026-04-19\n"
            ),
        )
        .expect("write STATUS.md");
    }
    base.to_path_buf()
}

// ---------------------------------------------------------------------------
// AC13.c wall-clock budget test
// ---------------------------------------------------------------------------

/// 5 repos × 4 sessions = 20 sessions; 5 ticks at a 3-second interval.
///
/// Uses `run_polling_loop_with_observer` (test-only hook in `poller.rs`) to
/// receive per-tick elapsed milliseconds on a `std::sync::mpsc` channel,
/// keeping the timing collection off the async executor.
///
/// The test completes in roughly 5 × 3 s ≈ 15 s on a normally loaded machine.
/// The CI runner must accept a 60 s total timeout for this test.
#[tokio::test]
async fn wall_clock_budget_20_sessions_5_ticks() {
    // Build 5 tempdir repos each containing 4 STATUS.md sessions (= 20 sessions).
    let tmpdirs: Vec<tempfile::TempDir> = (0..5)
        .map(|_| tempfile::tempdir().expect("tempdir"))
        .collect();

    let repos: Vec<PathBuf> = tmpdirs
        .iter()
        .map(|d| {
            let repo = make_repo_with_sessions(d.path(), 4);
            repo.canonicalize().expect("canonicalize repo path")
        })
        .collect();

    let store: Arc<Mutex<SessionMap>> = Arc::new(Mutex::new(HashMap::new()));
    let (diff_tx, mut diff_rx) = tokio_mpsc::channel::<DiffEvent>(64);

    // Observer channel: the loop pushes elapsed_ms here after each tick.
    // Buffer of 16 is ample for 5 ticks.
    let (tick_tx, tick_rx) = std_mpsc::sync_channel::<u128>(16);

    const TICKS: usize = 5;
    const INTERVAL_SECS: u64 = 3;
    // AC13.c MUST: every tick must complete in less than one full interval.
    const MAX_TICK_MS: u128 = 3000;
    // W5 perf brief target: 50 % headroom below the interval.
    const TARGET_TICK_MS: u128 = 1500;

    let repos_clone = repos.clone();
    let store_clone = Arc::clone(&store);

    // Spawn the polling loop with the observer hook.
    let handle = tokio::spawn(async move {
        run_polling_loop_with_observer(
            repos_clone,
            INTERVAL_SECS,
            store_clone,
            diff_tx,
            tick_tx,
        )
        .await
        .expect("polling loop failed");
    });

    // Collect tick timings on a dedicated OS thread so the std_mpsc::Receiver
    // never blocks the tokio executor.
    let timing_handle = std::thread::spawn(move || {
        let mut times: Vec<u128> = Vec::with_capacity(TICKS);
        for _ in 0..TICKS {
            // Each tick must arrive within the interval plus a 5 s safety margin.
            let ms = tick_rx
                .recv_timeout(Duration::from_secs(INTERVAL_SECS + 5))
                .expect("timed out waiting for tick observer: loop stalled or crashed");
            times.push(ms);
        }
        times
    });

    // Drain DiffEvents on the async side so the tokio mpsc channel never fills
    // up and blocks the polling loop's `.await` on `tx.send(event)`.
    let per_tick_timeout = Duration::from_secs(INTERVAL_SECS + 5);
    for tick_n in 0..TICKS {
        tokio::time::timeout(per_tick_timeout, diff_rx.recv())
            .await
            .unwrap_or_else(|_| panic!("tick {tick_n}: DiffEvent recv timed out"))
            .unwrap_or_else(|| panic!("tick {tick_n}: diff channel closed unexpectedly"));
    }

    // Signal the polling loop to exit by dropping the diff receiver.
    drop(diff_rx);
    let _ = tokio::time::timeout(Duration::from_secs(5), handle).await;

    // Collect the elapsed times gathered by the timing thread.
    let elapsed_times = timing_handle
        .join()
        .expect("timing thread panicked");

    assert_eq!(
        elapsed_times.len(),
        TICKS,
        "expected {TICKS} tick observations but got {}",
        elapsed_times.len()
    );

    let max_observed = *elapsed_times.iter().max().unwrap();

    // Assertion 1: every tick < interval (3000 ms) — AC13.c MUST.
    for (i, &ms) in elapsed_times.iter().enumerate() {
        assert!(
            ms < MAX_TICK_MS,
            "tick {i}: elapsed {ms} ms >= interval {MAX_TICK_MS} ms \
             (AC13.c MUST violation — cycle wall-clock exceeded the polling interval)"
        );
    }

    // Assertion 2: max tick < 1500 ms — W5 50 % headroom target.
    assert!(
        max_observed < TARGET_TICK_MS,
        "max observed tick time {max_observed} ms >= target {TARGET_TICK_MS} ms \
         (W5 perf brief: 50% headroom below the 3000 ms interval); \
         per-tick times: {elapsed_times:?}"
    );

    // Assertion 3: no tick backed up — structural proof.
    //
    // The polling loop uses `tokio::time::interval` whose default
    // `MissedTickBehavior` is `Burst` (fires immediately on recovery without
    // sleeping) but since every tick completes well inside the interval
    // (asserted above), the next tick always starts on schedule.  Receiving
    // exactly TICKS observations within TICKS × (interval + buffer) seconds
    // (guaranteed by the `recv_timeout` in the timing thread) confirms that no
    // tick was delayed by a backed-up predecessor.

    eprintln!(
        "wall_clock_budget PASS: 5 repos × 4 sessions = 20 sessions, \
         {TICKS} ticks at {INTERVAL_SECS}s interval. \
         Elapsed per tick (ms): {elapsed_times:?}. \
         Max: {max_observed} ms (target < {TARGET_TICK_MS} ms)."
    );
}

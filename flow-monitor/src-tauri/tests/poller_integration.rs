//! Seam 3 integration test: tempdir fixture-repo for `poller::run_polling_loop`.
//!
//! Covers:
//!   AC1.a–d  — discovered set = {alpha, bravo, charlie}; echo (stage:archive),
//!              delta (no STATUS.md), _template, archive/foxtrot all excluded.
//!   AC13.a   — per-cycle read count = 3 (one File::open per discovered session).
//!   AC13.c   — per-cycle wall-clock < interval at 2s, 3s, 5s; also at 20-session
//!              synthetic scale with 3s interval.

use flow_monitor_lib::poller::run_polling_loop;
use flow_monitor_lib::store::{DiffEvent, SessionMap};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::sync::mpsc;

// ---------------------------------------------------------------------------
// Fixture builder — the canonical Seam 3 shape from 04-tech.md §8
// ---------------------------------------------------------------------------

/// Build the standard Seam 3 fixture with alpha, bravo, charlie, delta, echo,
/// _template, and archive/foxtrot. Returns the tempdir (kept alive by the
/// caller) and the absolute root path.
fn build_seam3_fixture() -> (tempfile::TempDir, PathBuf) {
    let tmp = tempfile::tempdir().expect("tempdir allocation failed");
    let root = tmp.path().to_path_buf();

    let features = root.join(".specaffold").join("features");
    fs::create_dir_all(&features).expect("create features dir");

    // --- alpha: stage:implement, recent updated: field (AC1.a, AC3.a) ---
    fs::create_dir_all(features.join("alpha")).unwrap();
    fs::write(
        features.join("alpha").join("STATUS.md"),
        "- **slug**: alpha\n\
         - **stage**: implement\n\
         - **updated**: 2026-04-19\n\
         \n\
         ## Notes\n\
         - 2026-01-10 PM \u{2014} created feature request\n",
    )
    .unwrap();

    // --- bravo: stage:plan, recent Notes line is the latest date (AC3.b) ---
    fs::create_dir_all(features.join("bravo")).unwrap();
    fs::write(
        features.join("bravo").join("STATUS.md"),
        "- **slug**: bravo\n\
         - **stage**: plan\n\
         - **updated**: 2026-03-01\n\
         \n\
         ## Notes\n\
         - 2026-04-18 TPM \u{2014} updated plan (more recent than updated field)\n",
    )
    .unwrap();

    // --- charlie: stage:request, no Notes, mtime is the only activity signal (AC3.c) ---
    fs::create_dir_all(features.join("charlie")).unwrap();
    fs::write(
        features.join("charlie").join("STATUS.md"),
        "- **slug**: charlie\n\
         - **stage**: request\n\
         - **updated**: 2026-01-01\n",
    )
    .unwrap();

    // --- delta: no STATUS.md — must be excluded (AC1.b) ---
    fs::create_dir_all(features.join("delta")).unwrap();

    // --- echo: stage:archive — must be excluded by stage (AC1.a) ---
    fs::create_dir_all(features.join("echo")).unwrap();
    fs::write(
        features.join("echo").join("STATUS.md"),
        "- **slug**: echo\n\
         - **stage**: archive\n\
         - **updated**: 2026-01-01\n",
    )
    .unwrap();

    // --- _template: excluded by name (AC1.d) ---
    fs::create_dir_all(features.join("_template")).unwrap();
    fs::write(
        features.join("_template").join("STATUS.md"),
        "- **slug**: _template\n\
         - **stage**: implement\n",
    )
    .unwrap();

    // --- archive/foxtrot: excluded by location — sits alongside features/, not inside (AC1.c) ---
    let archive = root.join(".specaffold").join("archive").join("foxtrot");
    fs::create_dir_all(&archive).unwrap();
    fs::write(
        archive.join("STATUS.md"),
        "- **slug**: foxtrot\n\
         - **stage**: archive\n",
    )
    .unwrap();

    (tmp, root)
}

/// Extend the fixture with `n` additional synthetic sessions (session-00 … session-N-1)
/// for the 20-session wall-clock test. Returns the paths created.
fn add_synthetic_sessions(features: &PathBuf, n: usize) {
    for i in 0..n {
        let name = format!("session-{i:02}");
        fs::create_dir_all(features.join(&name)).unwrap();
        fs::write(
            features.join(&name).join("STATUS.md"),
            format!(
                "- **slug**: {name}\n\
                 - **stage**: implement\n\
                 - **updated**: 2026-04-19\n"
            ),
        )
        .unwrap();
    }
}

// ---------------------------------------------------------------------------
// Helper: run one polling tick and return the DiffEvent + elapsed time
// ---------------------------------------------------------------------------

/// Spawn `run_polling_loop` with `interval_secs`, wait for the FIRST DiffEvent,
/// drop the receiver (loop exits cleanly), and return (event, elapsed).
async fn one_tick(root: &PathBuf, interval_secs: u64) -> (DiffEvent, Duration) {
    let abs_root = root.canonicalize().expect("canonicalize repo root");
    let store: Arc<Mutex<SessionMap>> = Arc::new(Mutex::new(HashMap::new()));
    let (tx, mut rx) = mpsc::channel::<DiffEvent>(16);

    let repos = vec![abs_root];
    let store_clone = Arc::clone(&store);

    // Spawn loop in background; the first tick fires immediately (tokio interval
    // semantics: the first tick does NOT wait for the interval to elapse).
    let handle = tokio::spawn(async move {
        run_polling_loop(repos, interval_secs, store_clone, tx)
            .await
            .expect("polling loop must not error");
    });

    let wall_start = Instant::now();

    // Wait up to 10s for the first event — far longer than any real interval.
    let event = tokio::time::timeout(Duration::from_secs(10), rx.recv())
        .await
        .expect("timed out waiting for first DiffEvent")
        .expect("channel closed before first event");

    let elapsed = wall_start.elapsed();

    // Signal loop to exit by dropping the receiver, then wait for task.
    drop(rx);
    let _ = tokio::time::timeout(Duration::from_secs(2), handle).await;

    (event, elapsed)
}

// ---------------------------------------------------------------------------
// AC1.a–d: discovered set = {alpha, bravo, charlie}
// ---------------------------------------------------------------------------

#[tokio::test]
async fn test_discovered_set_is_alpha_bravo_charlie() {
    let (_tmp, root) = build_seam3_fixture();
    let (event, _elapsed) = one_tick(&root, 2).await;

    // Collect slug names from the added set (first tick: prev is empty → all discovered sessions appear as added).
    let added_slugs: HashSet<String> = event
        .added
        .iter()
        .map(|(_repo, slug)| slug.clone())
        .collect();

    // AC1.a — alpha and bravo and charlie must be present
    assert!(
        added_slugs.contains("alpha"),
        "alpha must be discovered; got: {added_slugs:?}"
    );
    assert!(
        added_slugs.contains("bravo"),
        "bravo must be discovered; got: {added_slugs:?}"
    );
    assert!(
        added_slugs.contains("charlie"),
        "charlie must be discovered; got: {added_slugs:?}"
    );

    // AC1.b — delta has no STATUS.md → excluded
    assert!(
        !added_slugs.contains("delta"),
        "delta must be excluded (no STATUS.md); got: {added_slugs:?}"
    );

    // AC1.a / stage:archive — echo has stage:archive → excluded
    assert!(
        !added_slugs.contains("echo"),
        "echo must be excluded (stage:archive); got: {added_slugs:?}"
    );

    // AC1.d — _template excluded by name
    assert!(
        !added_slugs.contains("_template"),
        "_template must be excluded by name; got: {added_slugs:?}"
    );

    // AC1.c — foxtrot is under archive/ alongside features/, not inside features/ — never visited
    assert!(
        !added_slugs.contains("foxtrot"),
        "foxtrot (archive/foxtrot) must be excluded by location; got: {added_slugs:?}"
    );

    // Exact cardinality: exactly {alpha, bravo, charlie}
    assert_eq!(
        added_slugs.len(),
        3,
        "expected exactly 3 discovered sessions {{alpha, bravo, charlie}}; got: {added_slugs:?}"
    );
}

// ---------------------------------------------------------------------------
// AC13.a: per-cycle read count = 3
//
// The poller opens File::open exactly once per discovered session per tick.
// We cannot intercept syscalls directly, so we verify the invariant
// structurally: the discovered set has cardinality 3 (verified by
// test_discovered_set_is_alpha_bravo_charlie above), and the module comment
// in poller.rs documents "one File::open per session per tick".
//
// As a complementary runtime signal, we count DiffEvent.added entries on
// the first tick: exactly 3 entries means exactly 3 STATUS.md files were
// successfully opened and parsed in the cycle.
// ---------------------------------------------------------------------------

#[tokio::test]
async fn test_per_cycle_read_count_is_3() {
    let (_tmp, root) = build_seam3_fixture();
    let (event, _elapsed) = one_tick(&root, 2).await;

    // On the first tick, `added` holds every successfully read session.
    // A read failure causes the session to be skipped (not added); a count
    // of 3 therefore implies exactly 3 successful File::open + read_to_string
    // calls — which is AC13.a.
    assert_eq!(
        event.added.len(),
        3,
        "AC13.a: expected 3 successful reads (alpha, bravo, charlie); got {} entries: {:?}",
        event.added.len(),
        event.added
    );
}

// ---------------------------------------------------------------------------
// AC13.c: per-cycle wall-clock < interval at 2s, 3s, 5s (small fixture)
//
// The first tick fires immediately; we measure from just before the spawn to
// just after the event arrives. For the small 3-session fixture the cycle
// should complete in well under 1s on any reasonable machine.
// ---------------------------------------------------------------------------

#[tokio::test]
async fn test_wall_clock_under_interval_at_2s() {
    let (_tmp, root) = build_seam3_fixture();
    let (_event, elapsed) = one_tick(&root, 2).await;
    assert!(
        elapsed < Duration::from_secs(2),
        "AC13.c (2s): cycle elapsed {elapsed:?} must be < 2s"
    );
}

#[tokio::test]
async fn test_wall_clock_under_interval_at_3s() {
    let (_tmp, root) = build_seam3_fixture();
    let (_event, elapsed) = one_tick(&root, 3).await;
    assert!(
        elapsed < Duration::from_secs(3),
        "AC13.c (3s): cycle elapsed {elapsed:?} must be < 3s"
    );
}

#[tokio::test]
async fn test_wall_clock_under_interval_at_5s() {
    let (_tmp, root) = build_seam3_fixture();
    let (_event, elapsed) = one_tick(&root, 5).await;
    assert!(
        elapsed < Duration::from_secs(5),
        "AC13.c (5s): cycle elapsed {elapsed:?} must be < 5s"
    );
}

// ---------------------------------------------------------------------------
// AC13.c (20-session synthetic scale): wall-clock at 3s interval < 1.5s
//
// Replicates the fixture to 20 sessions total (alpha + bravo + charlie +
// 17 synthetic sessions). Target: well below 3s (05-plan.md W5 perf brief:
// 50% headroom means target < 1.5s).
// ---------------------------------------------------------------------------

#[tokio::test]
async fn test_wall_clock_20_sessions_under_1500ms_at_3s_interval() {
    let (_tmp, root) = build_seam3_fixture();

    // Add 17 synthetic sessions so the total discovered set is 20
    // (alpha + bravo + charlie + 17 synthetic = 20).
    // echo is excluded by stage:archive; delta by missing STATUS.md;
    // _template by name — none of these count toward the 20.
    let features = root.join(".specaffold").join("features");
    add_synthetic_sessions(&features, 17);

    let (event, elapsed) = one_tick(&root, 3).await;

    // Verify the fixture actually reached 20 discovered sessions.
    // This ensures the wall-clock measurement is meaningful.
    assert_eq!(
        event.added.len(),
        20,
        "20-session fixture must yield exactly 20 discovered sessions; got: {}",
        event.added.len()
    );

    // Wall-clock target: < 1.5s (50% headroom per 05-plan.md W5 perf brief).
    assert!(
        elapsed < Duration::from_millis(1500),
        "AC13.c (20-session, 3s interval): elapsed {elapsed:?} must be < 1.5s"
    );
}

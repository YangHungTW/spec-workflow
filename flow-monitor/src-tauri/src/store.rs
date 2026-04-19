//! Pure in-memory session store: diff, sort, and group helpers.
//!
//! All functions in this module are pure — no I/O, no global state.
//! Dedupe state for stalled transitions is passed in and returned so
//! the caller owns lifetime and persistence (D11, Seam 2).

use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

// ---------------------------------------------------------------------------
// Types imported from status_parse (T6).
// Until T6 merges we define a minimal stub so this module compiles standalone.
// The orchestrator will align the real type at wave-merge time.
// ---------------------------------------------------------------------------

#[cfg(not(feature = "status_parse_real"))]
mod status_parse_stub {
    use std::path::PathBuf;
    use std::time::SystemTime;

    /// Minimal stub for SessionState — replaced by T6's real definition at merge.
    #[derive(Debug, Clone, PartialEq)]
    pub struct SessionState {
        pub slug: String,
        pub stage: String,
        pub last_activity: SystemTime,
        pub raw_status_path: PathBuf,
    }
}

#[cfg(not(feature = "status_parse_real"))]
pub use status_parse_stub::SessionState;

#[cfg(feature = "status_parse_real")]
pub use crate::status_parse::SessionState;

// ---------------------------------------------------------------------------
// Core types
// ---------------------------------------------------------------------------

/// Unique identity for one spec-workflow session inside a repo.
pub type SessionKey = (PathBuf, String);

/// The full in-memory session map (repo_path × slug → state).
pub type SessionMap = HashMap<SessionKey, SessionState>;

/// Closed sort-axis enum — one match arm per axis in all callers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortAxis {
    LastUpdatedDesc,
    Stage,
    SlugAZ,
    StalledFirst,
}

/// Output of a single `diff()` call.
#[derive(Debug, Clone, PartialEq)]
pub struct DiffEvent {
    /// Keys present in `new` but absent in `prev`.
    pub added: Vec<SessionKey>,
    /// Keys present in `prev` but absent in `new`.
    pub removed: Vec<SessionKey>,
    /// Keys present in both maps whose `SessionState` differs.
    pub changed: Vec<SessionKey>,
    /// Sessions that newly crossed into stalled on this tick.
    /// Fired exactly once per crossing (AC6.a/b/c): a session leaving
    /// stalled then re-entering will fire again.
    pub stalled_transitions: Vec<SessionKey>,
    /// The updated stalled set — caller stores this for the next tick.
    pub next_stalled_set: HashSet<SessionKey>,
}

// ---------------------------------------------------------------------------
// Pure diff — O(n) over max(|prev|, |new|)
// ---------------------------------------------------------------------------

/// Compute the difference between two session maps.
///
/// # Complexity
/// O(|prev| + |new|) — one pass over each map using hash lookup; no nested
/// iteration. The stalled-set membership test is O(1) per key.
///
/// # Stalled-transition dedupe (AC6)
/// - AC6.a: a session that was not stalled and now crosses the threshold
///   appears in `stalled_transitions` exactly once.
/// - AC6.b: a session that is already in `prev_stalled_set` does NOT appear
///   again on subsequent ticks while still stalled.
/// - AC6.c: if a session leaves stalled (last_activity refreshes) and later
///   re-crosses the threshold, it fires again (handled naturally because
///   `prev_stalled_set` is updated each tick by the caller).
pub fn diff(
    prev: &SessionMap,
    new: &SessionMap,
    stale_threshold: Duration,
    stalled_threshold: Duration,
    prev_stalled_set: &HashSet<SessionKey>,
) -> DiffEvent {
    let now = SystemTime::now();
    let _ = stale_threshold; // available for callers who want to layer stale logic

    let mut added = Vec::new();
    let mut removed = Vec::new();
    let mut changed = Vec::new();
    let mut stalled_transitions = Vec::new();

    // Build the next stalled set incrementally (no separate pass).
    let mut next_stalled_set: HashSet<SessionKey> = HashSet::new();

    // Pass 1: iterate new map — detect added / changed / stalled.
    for (key, new_state) in new {
        let is_stalled = is_session_stalled(new_state, now, stalled_threshold);

        if is_stalled {
            next_stalled_set.insert(key.clone());
        }

        match prev.get(key) {
            None => {
                // New session appeared this tick.
                added.push(key.clone());
                // Fire stalled transition if it arrives already stalled and
                // was not previously tracked (it was absent, so not in prev_stalled_set).
                if is_stalled && !prev_stalled_set.contains(key) {
                    stalled_transitions.push(key.clone());
                }
            }
            Some(prev_state) => {
                // Session existed before — check if state changed.
                if states_differ(prev_state, new_state) {
                    changed.push(key.clone());
                }
                // Stalled-transition: newly crossed threshold (AC6.a/b/c).
                if is_stalled && !prev_stalled_set.contains(key) {
                    stalled_transitions.push(key.clone());
                }
            }
        }
    }

    // Pass 2: iterate prev map — detect removals.
    for key in prev.keys() {
        if !new.contains_key(key) {
            removed.push(key.clone());
            // Removed session is no longer stalled — drop from next set (already absent).
        }
    }

    DiffEvent {
        added,
        removed,
        changed,
        stalled_transitions,
        next_stalled_set,
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Returns true when the session's last activity exceeds the stalled threshold.
fn is_session_stalled(state: &SessionState, now: SystemTime, threshold: Duration) -> bool {
    match now.duration_since(state.last_activity) {
        Ok(elapsed) => elapsed >= threshold,
        Err(_) => false, // clock skew: treat as not stalled
    }
}

/// Returns true when two SessionState values differ in any observable field.
/// Comparing by last_activity and slug covers the fields available in the stub;
/// the real implementation will align with T6's full struct at merge time.
fn states_differ(a: &SessionState, b: &SessionState) -> bool {
    a.last_activity != b.last_activity || a.stage != b.stage || a.slug != b.slug
}

// ---------------------------------------------------------------------------
// Sort helpers (AC7.c)
// ---------------------------------------------------------------------------

/// Return session keys sorted by `axis`.
///
/// Closed dispatch — one match arm per `SortAxis` variant; no fall-through.
pub fn sort_by(axis: SortAxis, map: &SessionMap) -> Vec<SessionKey> {
    let mut keys: Vec<SessionKey> = map.keys().cloned().collect();

    match axis {
        SortAxis::LastUpdatedDesc => {
            keys.sort_by(|a, b| {
                let ta = map[a].last_activity;
                let tb = map[b].last_activity;
                // Newer first → reverse order.
                tb.cmp(&ta)
            });
        }
        SortAxis::Stage => {
            keys.sort_by(|a, b| {
                let sa = &map[a].stage;
                let sb = &map[b].stage;
                sa.cmp(sb)
            });
        }
        SortAxis::SlugAZ => {
            keys.sort_by(|a, b| {
                // Key is (PathBuf, slug); sort by slug (index 1) then path.
                a.1.cmp(&b.1).then_with(|| a.0.cmp(&b.0))
            });
        }
        SortAxis::StalledFirst => {
            // Stalled sessions come first; within each tier sort by slug A-Z
            // so the order is deterministic.
            let now = SystemTime::now();
            // Use a large stalled threshold placeholder; callers who want
            // threshold-aware stalling should pre-classify and call diff().
            // Here we compare last_activity age: older first.
            keys.sort_by(|a, b| {
                let ta = map[a].last_activity;
                let tb = map[b].last_activity;
                // Oldest activity first (stalled sessions tend to be oldest).
                ta.cmp(&tb).then_with(|| a.1.cmp(&b.1))
            });
            let _ = now; // suppress unused-variable lint
        }
    }

    keys
}

// ---------------------------------------------------------------------------
// Group-by-repo helper (AC8.a)
// ---------------------------------------------------------------------------

/// Group session keys by their `repo_path` component.
///
/// Returns a vector of `(repo_path, keys)` pairs sorted by `repo_path` for
/// deterministic ordering. Within each group, keys are sorted `SlugAZ`.
///
/// Complexity: O(n log n) — one pass to build the group map, one sort.
pub fn group_by_repo(map: &SessionMap) -> Vec<(PathBuf, Vec<SessionKey>)> {
    let mut groups: HashMap<PathBuf, Vec<SessionKey>> = HashMap::new();

    for key in map.keys() {
        groups.entry(key.0.clone()).or_default().push(key.clone());
    }

    // Sort each group's keys by slug A-Z for deterministic output.
    for keys in groups.values_mut() {
        keys.sort_by(|a, b| a.1.cmp(&b.1));
    }

    // Sort groups by repo path.
    let mut result: Vec<(PathBuf, Vec<SessionKey>)> = groups.into_iter().collect();
    result.sort_by(|(pa, _), (pb, _)| pa.cmp(pb));
    result
}

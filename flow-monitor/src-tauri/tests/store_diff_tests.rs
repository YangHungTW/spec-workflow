//! Integration tests for `store::diff`, sort helpers, and group_by_repo.
//!
//! Covers: AC6.a (one-shot stalled transition), AC6.b (no-recurrence while
//! still stalled), AC6.c (re-cross fires again), AC7.c (each SortAxis),
//! AC8.a (group_by_repo).

use flow_monitor_lib::store::{
    diff, group_by_repo, sort_by, SessionMap, SessionKey, SortAxis,
};
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal SessionState stub used in these tests.
/// At T6 merge the real struct replaces this; the test API stays the same.
use flow_monitor_lib::store::SessionState;

fn make_state(slug: &str, stage: &str, ago_secs: u64) -> SessionState {
    let last_activity = SystemTime::now()
        .checked_sub(Duration::from_secs(ago_secs))
        .expect("time subtraction should not underflow for test durations");
    SessionState {
        slug: slug.to_string(),
        stage: stage.to_string(),
        last_activity,
        raw_status_path: PathBuf::from(format!("/fake/{}/STATUS.md", slug)),
    }
}

fn repo(s: &str) -> PathBuf {
    PathBuf::from(s)
}

fn key(repo_path: &str, slug: &str) -> SessionKey {
    (repo(repo_path), slug.to_string())
}

const STALE_THRESH: Duration = Duration::from_secs(5 * 60);
const STALLED_THRESH: Duration = Duration::from_secs(30 * 60);

fn empty_stalled() -> HashSet<SessionKey> {
    HashSet::new()
}

// ---------------------------------------------------------------------------
// AC6.a — stalled transition fires exactly once on first crossing
// ---------------------------------------------------------------------------

#[test]
fn ac6a_stalled_transition_fires_on_first_crossing() {
    // Session that has been inactive for > stalled threshold.
    let k = key("/repo/a", "feature-x");
    let old_state = make_state("feature-x", "Implement", 10); // 10 s ago — NOT stalled
    let new_state = make_state("feature-x", "Implement", 31 * 60); // 31 min ago — stalled

    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), old_state);

    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), new_state);

    let event = diff(&prev, &new, STALE_THRESH, STALLED_THRESH, &empty_stalled());

    assert!(
        event.stalled_transitions.contains(&k),
        "AC6.a: newly stalled session must appear in stalled_transitions"
    );
    assert_eq!(event.stalled_transitions.len(), 1);
    assert!(event.next_stalled_set.contains(&k));
}

// ---------------------------------------------------------------------------
// AC6.b — no recurrence: already in stalled set → does NOT fire again
// ---------------------------------------------------------------------------

#[test]
fn ac6b_no_recurrence_while_still_stalled() {
    let k = key("/repo/a", "feature-x");
    let stalled_state = make_state("feature-x", "Implement", 31 * 60);

    // Session is stalled in both prev and new.
    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), stalled_state.clone());

    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), stalled_state.clone());

    // Simulate that we already fired the transition: key is in prev_stalled_set.
    let mut prev_stalled = HashSet::new();
    prev_stalled.insert(k.clone());

    let event = diff(&prev, &new, STALE_THRESH, STALLED_THRESH, &prev_stalled);

    assert!(
        event.stalled_transitions.is_empty(),
        "AC6.b: session already in stalled set must NOT fire stalled_transitions again"
    );
    // Still stalled → must remain in next set.
    assert!(event.next_stalled_set.contains(&k));
}

// ---------------------------------------------------------------------------
// AC6.c — re-cross: session recovers then stalls again → fires again
// ---------------------------------------------------------------------------

#[test]
fn ac6c_recross_fires_again_after_recovery() {
    let k = key("/repo/a", "feature-x");

    // Tick 1: stalled.
    let stalled_state = make_state("feature-x", "Implement", 31 * 60);
    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), stalled_state.clone());
    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), stalled_state.clone());

    let event1 = diff(&prev, &new, STALE_THRESH, STALLED_THRESH, &empty_stalled());
    assert!(event1.stalled_transitions.contains(&k), "tick-1 must fire");
    let after_tick1 = event1.next_stalled_set.clone();

    // Tick 2: session recovers (recent activity — no longer stalled).
    let active_state = make_state("feature-x", "Implement", 10); // 10 s ago
    let prev2 = new.clone();
    let mut new2: SessionMap = HashMap::new();
    new2.insert(k.clone(), active_state);

    let event2 = diff(&prev2, &new2, STALE_THRESH, STALLED_THRESH, &after_tick1);
    assert!(
        event2.stalled_transitions.is_empty(),
        "tick-2: recovered session must not fire"
    );
    // Must be removed from stalled set after recovery.
    assert!(!event2.next_stalled_set.contains(&k));
    let after_tick2 = event2.next_stalled_set.clone();

    // Tick 3: session goes stalled again — must fire once more (AC6.c).
    let stalled_again = make_state("feature-x", "Implement", 32 * 60);
    let prev3 = new2.clone();
    let mut new3: SessionMap = HashMap::new();
    new3.insert(k.clone(), stalled_again);

    let event3 = diff(&prev3, &new3, STALE_THRESH, STALLED_THRESH, &after_tick2);
    assert!(
        event3.stalled_transitions.contains(&k),
        "AC6.c: re-crossed threshold must fire stalled_transitions again"
    );
}

// ---------------------------------------------------------------------------
// Added / removed / changed basic correctness
// ---------------------------------------------------------------------------

#[test]
fn added_session_appears_in_added() {
    let k = key("/repo/b", "new-feature");
    let prev: SessionMap = HashMap::new();
    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), make_state("new-feature", "Prd", 60));

    let event = diff(&prev, &new, STALE_THRESH, STALLED_THRESH, &empty_stalled());
    assert!(event.added.contains(&k));
    assert!(event.removed.is_empty());
    assert!(event.changed.is_empty());
}

#[test]
fn removed_session_appears_in_removed() {
    let k = key("/repo/b", "old-feature");
    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), make_state("old-feature", "Archive", 60));
    let new: SessionMap = HashMap::new();

    let event = diff(&prev, &new, STALE_THRESH, STALLED_THRESH, &empty_stalled());
    assert!(event.removed.contains(&k));
    assert!(event.added.is_empty());
    assert!(event.changed.is_empty());
}

#[test]
fn changed_session_detected_when_stage_changes() {
    let k = key("/repo/c", "stage-change");
    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), make_state("stage-change", "Design", 120));
    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), make_state("stage-change", "Prd", 60));

    let event = diff(&prev, &new, STALE_THRESH, STALLED_THRESH, &empty_stalled());
    assert!(event.changed.contains(&k));
}

// ---------------------------------------------------------------------------
// AC7.c — each SortAxis produces a deterministic ordering
// ---------------------------------------------------------------------------

fn build_sort_map() -> SessionMap {
    let mut map: SessionMap = HashMap::new();
    // Three sessions: alpha (recent, Design), beta (old, Archive), gamma (mid, Prd)
    map.insert(
        key("/repo/x", "alpha"),
        make_state("alpha", "Design", 60),
    );
    map.insert(
        key("/repo/x", "beta"),
        make_state("beta", "Archive", 2 * 60 * 60),
    );
    map.insert(
        key("/repo/x", "gamma"),
        make_state("gamma", "Prd", 30 * 60),
    );
    map
}

#[test]
fn ac7c_sort_last_updated_desc() {
    let map = build_sort_map();
    let sorted = sort_by(SortAxis::LastUpdatedDesc, &map);
    // alpha (60s ago) → gamma (30min ago) → beta (2h ago)
    assert_eq!(sorted[0].1, "alpha");
    assert_eq!(sorted[1].1, "gamma");
    assert_eq!(sorted[2].1, "beta");
}

#[test]
fn ac7c_sort_stage() {
    let map = build_sort_map();
    let sorted = sort_by(SortAxis::Stage, &map);
    // Lexicographic: Archive < Design < Prd
    assert_eq!(sorted[0].1, "beta");   // Archive
    assert_eq!(sorted[1].1, "alpha");  // Design
    assert_eq!(sorted[2].1, "gamma");  // Prd
}

#[test]
fn ac7c_sort_slug_az() {
    let map = build_sort_map();
    let sorted = sort_by(SortAxis::SlugAZ, &map);
    // alpha < beta < gamma
    assert_eq!(sorted[0].1, "alpha");
    assert_eq!(sorted[1].1, "beta");
    assert_eq!(sorted[2].1, "gamma");
}

#[test]
fn ac7c_sort_stalled_first() {
    let map = build_sort_map();
    let sorted = sort_by(SortAxis::StalledFirst, &map);
    // Oldest activity first: beta (2h) → gamma (30min) → alpha (1min)
    assert_eq!(sorted[0].1, "beta");
    assert_eq!(sorted[1].1, "gamma");
    assert_eq!(sorted[2].1, "alpha");
}

// ---------------------------------------------------------------------------
// AC8.a — group_by_repo groups sessions under their repo_path
// ---------------------------------------------------------------------------

#[test]
fn ac8a_group_by_repo_groups_correctly() {
    let mut map: SessionMap = HashMap::new();
    map.insert(key("/repo/a", "feat-1"), make_state("feat-1", "Design", 60));
    map.insert(key("/repo/a", "feat-2"), make_state("feat-2", "Prd", 120));
    map.insert(key("/repo/b", "feat-3"), make_state("feat-3", "Tasks", 30));

    let groups = group_by_repo(&map);

    assert_eq!(groups.len(), 2, "should produce 2 repo groups");

    let repo_a = groups.iter().find(|(p, _)| p == &repo("/repo/a"));
    let repo_b = groups.iter().find(|(p, _)| p == &repo("/repo/b"));

    assert!(repo_a.is_some(), "/repo/a group must exist");
    assert!(repo_b.is_some(), "/repo/b group must exist");

    let (_, keys_a) = repo_a.unwrap();
    assert_eq!(keys_a.len(), 2);
    // Within group, keys are sorted slug A-Z.
    assert_eq!(keys_a[0].1, "feat-1");
    assert_eq!(keys_a[1].1, "feat-2");

    let (_, keys_b) = repo_b.unwrap();
    assert_eq!(keys_b.len(), 1);
    assert_eq!(keys_b[0].1, "feat-3");
}

#[test]
fn ac8a_group_by_repo_empty_map() {
    let map: SessionMap = HashMap::new();
    let groups = group_by_repo(&map);
    assert!(groups.is_empty());
}

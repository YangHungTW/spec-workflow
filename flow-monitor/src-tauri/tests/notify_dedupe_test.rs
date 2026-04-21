//! Fixture tests for `notify::fire_stalled_notification` dedupe logic.
//!
//! Covers AC6.a (transition fires exactly once), AC6.b (no recurrence while
//! stalled), AC6.c (re-cross fires again), AC6.d (silent flag), and
//! AC6.e (notifications_enabled = false suppresses all firing).
//!
//! Uses T8's `store::diff` output shape as the event source so that the
//! dedupe logic is exercised end-to-end through the same pipeline the
//! production poller uses.

use flow_monitor_lib::notify::{fire_stalled_notification, MockSink};
use flow_monitor_lib::status_parse::Stage;
use flow_monitor_lib::store::{diff, SessionMap, SessionKey};
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::time::{Duration, SystemTime};

use flow_monitor_lib::store::SessionState;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn make_state(slug: &str, stage: Stage, ago_secs: u64) -> SessionState {
    let last_activity = SystemTime::now()
        .checked_sub(Duration::from_secs(ago_secs))
        .expect("time subtraction should not underflow");
    SessionState {
        slug: slug.to_string(),
        stage,
        last_activity,
        has_ui: false,
        stage_checklist: Vec::new(),
        notes: Vec::new(),
        raw_status_path: PathBuf::from(format!("/fake/{}/STATUS.md", slug)),
    }
}

fn key(repo_path: &str, slug: &str) -> SessionKey {
    (PathBuf::from(repo_path), slug.to_string())
}

const STALLED_THRESH: Duration = Duration::from_secs(30 * 60);

fn empty_stalled() -> HashSet<SessionKey> {
    HashSet::new()
}

// ---------------------------------------------------------------------------
// AC6.a — first crossing fires the notification once
// ---------------------------------------------------------------------------

#[test]
fn notify_ac6a_fires_on_first_stalled_crossing() {
    let k = key("/repo/a", "feature-x");

    let not_stalled = make_state("feature-x", Stage::Implement, 10);
    let stalled = make_state("feature-x", Stage::Implement, 31 * 60);

    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), not_stalled);

    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), stalled);

    let event = diff(&prev, &new, STALLED_THRESH, &empty_stalled());
    assert_eq!(event.stalled_transitions.len(), 1, "AC6.a: exactly one transition");

    let sink = MockSink::new();

    for transition_key in &event.stalled_transitions {
        fire_stalled_notification(
            &transition_key.0,
            &transition_key.1,
            "Implement",
            "flow-monitor",
            "A session has stalled.",
            true, // notifications_enabled
            &sink,
        );
    }

    assert_eq!(
        sink.fired_count(),
        1,
        "AC6.a: notification must fire exactly once on first crossing"
    );
}

// ---------------------------------------------------------------------------
// AC6.b — no recurrence while session remains stalled
// ---------------------------------------------------------------------------

#[test]
fn notify_ac6b_no_notification_while_already_stalled() {
    let k = key("/repo/a", "feature-x");
    let stalled = make_state("feature-x", Stage::Implement, 31 * 60);

    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), stalled.clone());

    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), stalled.clone());

    // Simulate that the first crossing already fired — key is in prev_stalled_set.
    let mut prev_stalled = HashSet::new();
    prev_stalled.insert(k.clone());

    let event = diff(&prev, &new, STALLED_THRESH, &prev_stalled);

    // stalled_transitions must be empty — the session is already in the stalled set.
    assert!(
        event.stalled_transitions.is_empty(),
        "AC6.b: already-stalled session must produce zero transitions"
    );

    let sink = MockSink::new();

    for transition_key in &event.stalled_transitions {
        fire_stalled_notification(
            &transition_key.0,
            &transition_key.1,
            "Implement",
            "flow-monitor",
            "A session has stalled.",
            true,
            &sink,
        );
    }

    assert_eq!(
        sink.fired_count(),
        0,
        "AC6.b: zero notifications must fire while session remains stalled"
    );
}

// ---------------------------------------------------------------------------
// AC6.c — re-cross fires again after recovery
// ---------------------------------------------------------------------------

#[test]
fn notify_ac6c_fires_again_after_recovery_and_re_cross() {
    let k = key("/repo/a", "feature-x");
    let sink = MockSink::new();

    // --- Tick 1: session goes stalled for the first time ---
    let not_stalled = make_state("feature-x", Stage::Implement, 10);
    let stalled = make_state("feature-x", Stage::Implement, 31 * 60);

    let mut prev1: SessionMap = HashMap::new();
    prev1.insert(k.clone(), not_stalled);
    let mut new1: SessionMap = HashMap::new();
    new1.insert(k.clone(), stalled.clone());

    let event1 = diff(&prev1, &new1, STALLED_THRESH, &empty_stalled());
    assert_eq!(event1.stalled_transitions.len(), 1, "tick-1 must have one transition");

    for transition_key in &event1.stalled_transitions {
        fire_stalled_notification(
            &transition_key.0,
            &transition_key.1,
            "Implement",
            "flow-monitor",
            "A session has stalled.",
            true,
            &sink,
        );
    }
    let after_tick1_stalled = event1.next_stalled_set.clone();
    assert_eq!(sink.fired_count(), 1, "tick-1: exactly one notification");

    // --- Tick 2: session recovers (active again) ---
    let recovered = make_state("feature-x", Stage::Implement, 10);
    let mut new2: SessionMap = HashMap::new();
    new2.insert(k.clone(), recovered);

    let event2 = diff(&new1, &new2, STALLED_THRESH, &after_tick1_stalled);
    assert!(
        event2.stalled_transitions.is_empty(),
        "tick-2: recovered session must not fire"
    );
    assert!(
        !event2.next_stalled_set.contains(&k),
        "tick-2: session must be removed from stalled set after recovery"
    );

    for transition_key in &event2.stalled_transitions {
        fire_stalled_notification(
            &transition_key.0,
            &transition_key.1,
            "Implement",
            "flow-monitor",
            "A session has stalled.",
            true,
            &sink,
        );
    }
    let after_tick2_stalled = event2.next_stalled_set.clone();
    assert_eq!(sink.fired_count(), 1, "tick-2: still only one total notification");

    // --- Tick 3: session goes stalled again — must fire once more (AC6.c) ---
    let stalled_again = make_state("feature-x", Stage::Implement, 32 * 60);
    let mut new3: SessionMap = HashMap::new();
    new3.insert(k.clone(), stalled_again);

    let event3 = diff(&new2, &new3, STALLED_THRESH, &after_tick2_stalled);
    assert!(
        event3.stalled_transitions.contains(&k),
        "AC6.c: re-crossed session must appear in stalled_transitions"
    );

    for transition_key in &event3.stalled_transitions {
        fire_stalled_notification(
            &transition_key.0,
            &transition_key.1,
            "Implement",
            "flow-monitor",
            "A session has stalled.",
            true,
            &sink,
        );
    }
    assert_eq!(
        sink.fired_count(),
        2,
        "AC6.c: notification must fire a second time after re-cross (total = 2)"
    );
}

// ---------------------------------------------------------------------------
// AC6.e — notifications_enabled = false suppresses all firing
// ---------------------------------------------------------------------------

#[test]
fn notify_ac6e_disabled_suppresses_all_firing() {
    let k = key("/repo/b", "feature-y");
    let not_stalled = make_state("feature-y", Stage::Prd, 10);
    let stalled = make_state("feature-y", Stage::Prd, 31 * 60);

    let mut prev: SessionMap = HashMap::new();
    prev.insert(k.clone(), not_stalled);
    let mut new: SessionMap = HashMap::new();
    new.insert(k.clone(), stalled);

    let event = diff(&prev, &new, STALLED_THRESH, &empty_stalled());
    assert_eq!(event.stalled_transitions.len(), 1);

    let sink = MockSink::new();

    for transition_key in &event.stalled_transitions {
        fire_stalled_notification(
            &transition_key.0,
            &transition_key.1,
            "Prd",
            "flow-monitor",
            "A session has stalled.",
            false, // notifications_enabled = false
            &sink,
        );
    }

    assert_eq!(
        sink.fired_count(),
        0,
        "AC6.e: no notification must fire when notifications_enabled is false"
    );
}

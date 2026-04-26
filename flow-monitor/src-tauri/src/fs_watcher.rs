use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use notify::RecursiveMode;
use notify_debouncer_full::{new_debouncer, DebounceEventResult, Debouncer, FileIdMap};
use tauri::{AppHandle, Emitter, Manager};
use tokio::task::JoinHandle;

// MERGE-NOTE: replaced by lib.rs canonical types after T4 merges
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ArtifactKind {
    Request,
    Design,
    Prd,
    Tech,
    Plan,
    Tasks,
    Status,
    Other,
}

// MERGE-NOTE: replaced by lib.rs canonical types after T4 merges
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum WatcherState {
    Running,
    Errored,
}

// MERGE-NOTE: replaced by lib.rs canonical types after T4 merges
#[derive(Debug, Clone, serde::Serialize)]
pub struct ArtifactChangedPayload {
    pub repo: PathBuf,
    pub slug: String,
    pub artifact: ArtifactKind,
    pub path: PathBuf,
    pub mtime_ms: u64,
}

// MERGE-NOTE: replaced by lib.rs canonical types after T4 merges
#[derive(Debug, Clone, serde::Serialize)]
pub struct WatcherStatusPayload {
    pub state: WatcherState,
    pub error_kind: Option<String>,
    pub repo: Option<PathBuf>,
}

/// Pure classifier: given an absolute path, return the ArtifactKind it represents.
///
/// The classifier is a pure function (no I/O, no side effects) per the
/// classify-before-mutate rule. The dispatch on the returned kind lives in the
/// watcher loop, not here.
///
/// Classification rules (D3):
///   - filename is "STATUS.md"         → Status
///   - filename is "00-request.md"     → Request
///   - any ancestor component is "02-design" → Design
///   - filename is "03-prd.md"         → Prd
///   - filename is "04-tech.md"        → Tech
///   - filename is "05-plan.md"        → Plan
///   - filename is "tasks.md"          → Tasks
///   - anything else                   → Other
pub fn classify_artifact(path: &Path) -> ArtifactKind {
    let filename = path
        .file_name()
        .map(|n| n.to_string_lossy())
        .unwrap_or_default();

    match filename.as_ref() {
        "STATUS.md" => return ArtifactKind::Status,
        "00-request.md" => return ArtifactKind::Request,
        "03-prd.md" => return ArtifactKind::Prd,
        "04-tech.md" => return ArtifactKind::Tech,
        "05-plan.md" => return ArtifactKind::Plan,
        "tasks.md" => return ArtifactKind::Tasks,
        _ => {}
    }

    // Any path component named "02-design" (directory or file inside it).
    if path.components().any(|c| c.as_os_str() == "02-design") {
        return ArtifactKind::Design;
    }

    ArtifactKind::Other
}

/// Derive the slug from an artifact path rooted at `<repo>/.specaffold/features/<slug>/...`.
///
/// Returns `None` when the path does not contain the expected structure; the caller
/// skips the event silently in that case (unknown repo layout).
fn slug_from_path<'a>(repo: &Path, path: &'a Path) -> Option<String> {
    let features = repo.join(".specaffold").join("features");
    let rel = path.strip_prefix(&features).ok()?;
    let slug = rel.components().next()?.as_os_str().to_string_lossy().into_owned();
    if slug.is_empty() {
        return None;
    }
    Some(slug)
}

/// Return the file's mtime as Unix epoch milliseconds, or 0 on any I/O error.
fn mtime_ms(path: &Path) -> u64 {
    std::fs::metadata(path)
        .and_then(|m| m.modified())
        .map(|t| {
            t.duration_since(UNIX_EPOCH)
                .map(|d| d.as_millis() as u64)
                .unwrap_or(0)
        })
        .unwrap_or(0)
}

/// Scan all sessions in `repo` and emit a `sessions_changed` event on `app`.
///
/// Mirrors the discover → parse → emit pipeline from `run_session_polling`,
/// but is triggered by a STATUS.md FSEvents change rather than a timer tick.
/// The `prev_stalled_set` carry-state is not maintained here; that responsibility
/// stays with the caller that holds the watcher state across events.
fn emit_sessions_changed(repo: &Path, app: &AppHandle) {
    use crate::ipc::{SessionRecord, SessionsState, SettingsState};
    use crate::repo_discovery;
    use crate::status_parse;
    use crate::store;
    use std::collections::{HashMap, HashSet};

    let (stalled_threshold, notif_enabled, notif_title, notif_body) = {
        let settings_state = app.state::<SettingsState>();
        let guard = settings_state.0.lock().expect("settings lock poisoned");
        (
            Duration::from_secs(guard.stalled_threshold_mins * 60),
            guard.notifications_enabled,
            guard.notification_title.clone(),
            guard.notification_body.clone(),
        )
    };

    let sessions = repo_discovery::discover_sessions(repo);

    let mut new_list: Vec<SessionRecord> = Vec::new();
    let mut new_map: store::SessionMap = HashMap::new();

    for session_info in sessions {
        let content = match std::fs::read_to_string(&session_info.status_path) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let mtime = std::fs::metadata(&session_info.status_path)
            .and_then(|m| m.modified())
            .unwrap_or(SystemTime::UNIX_EPOCH);
        let state = status_parse::parse(&content, mtime);
        if matches!(state.stage, status_parse::Stage::Archive) {
            continue;
        }
        let last_activity_secs = state
            .last_activity
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let stage_str = format!("{:?}", state.stage).to_lowercase();
        let slug = session_info.slug.clone();
        new_list.push(SessionRecord {
            repo: repo.to_path_buf(),
            slug: slug.clone(),
            stage: stage_str,
            last_activity_secs,
            has_ui: state.has_ui,
        });
        let key: store::SessionKey = (repo.to_path_buf(), slug);
        new_map.insert(key, state);
    }

    let prev_map: store::SessionMap = HashMap::new();
    let prev_stalled_set: HashSet<store::SessionKey> = HashSet::new();
    let diff_event = store::diff(&prev_map, &new_map, stalled_threshold, &prev_stalled_set);

    #[cfg(not(test))]
    {
        let sink = crate::notify::TauriSink::new(app.clone());
        for (repo_path, slug) in &diff_event.stalled_transitions {
            crate::notify::fire_stalled_notification(
                repo_path.as_path(),
                slug,
                "",
                &notif_title,
                &notif_body,
                notif_enabled,
                &sink,
            );
        }
    }
    #[cfg(test)]
    let _ = (notif_enabled, notif_title, notif_body);

    {
        let sessions_state = app.state::<SessionsState>();
        let mut guard = sessions_state.0.lock().expect("sessions lock poisoned");
        *guard = new_list;
    }

    let payload = crate::SessionsChangedPayload {
        stalled_transitions: diff_event.stalled_transitions,
    };
    let _ = app.emit("sessions_changed", payload);
}

/// Spawn the filesystem watcher with a caller-supplied `artifact_emitter` callback.
///
/// This is the testable seam (T13 / AC12): the production caller [`spawn_watcher`]
/// passes a closure that calls `app.emit("artifact_changed", ...)`, while test
/// callers pass a closure that pushes to a `tokio::sync::mpsc` channel.
///
/// Only `artifact_changed` events are routed through the emitter; `watcher_status`
/// and `sessions_changed` events require an `AppHandle` and are not emitted here.
/// The test harness does not need those events to verify latency.
///
/// The debouncer uses a 150 ms window (D2) to coalesce burst writes.
pub fn spawn_watcher_with_emitter<F>(
    repos: Vec<PathBuf>,
    artifact_emitter: F,
) -> Result<tokio::task::JoinHandle<()>, String>
where
    F: Fn(ArtifactChangedPayload) + Send + 'static,
{
    // Use tokio::sync::mpsc with try_send from the debouncer callback.
    // try_send is safe to call from a non-tokio thread (unlike blocking_send,
    // which panics inside an async context). The async task uses recv().await.
    let (tx, mut rx) = tokio::sync::mpsc::channel::<DebounceEventResult>(64);

    let mut debouncer: Debouncer<notify::RecommendedWatcher, FileIdMap> =
        new_debouncer(Duration::from_millis(150), None, move |result| {
            // try_send does not require a tokio runtime context and returns
            // immediately if the channel is full (capacity 64 prevents drops
            // under normal operation).
            let _ = tx.try_send(result);
        })
        .map_err(|e| format!("watcher init failed: {e}"))?;

    // Canonicalise repo paths so that symlink-resolved event paths (e.g.
    // macOS /var → /private/var) still match via starts_with.
    let canonical_repos: Vec<PathBuf> = repos
        .iter()
        .map(|r| std::fs::canonicalize(r).unwrap_or_else(|_| r.clone()))
        .collect();

    for repo in &repos {
        let watch_root = repo.join(".specaffold");
        if let Err(e) = debouncer.watch(&watch_root, RecursiveMode::Recursive) {
            tracing::warn!(
                repo = %watch_root.display(),
                err = ?e,
                "fs_watcher: init failed for repo"
            );
        }
    }

    let repos_arc = Arc::new(canonical_repos);

    let handle = tokio::task::spawn(async move {
        let _debouncer = debouncer;

        while let Some(result) = rx.recv().await {
            match result {
                Ok(events) => {
                    for event in events {
                        let path = match event.paths.first() {
                            Some(p) => p.clone(),
                            None => continue,
                        };

                        let repo =
                            repos_arc.iter().find(|r| path.starts_with(r.as_path()));
                        let repo = match repo {
                            Some(r) => r,
                            None => continue,
                        };

                        let kind = classify_artifact(&path);

                        match &kind {
                            ArtifactKind::Request
                            | ArtifactKind::Design
                            | ArtifactKind::Prd
                            | ArtifactKind::Tech
                            | ArtifactKind::Plan
                            | ArtifactKind::Tasks => {
                                let slug = match slug_from_path(repo, &path) {
                                    Some(s) => s,
                                    None => continue,
                                };
                                artifact_emitter(ArtifactChangedPayload {
                                    repo: repo.clone(),
                                    slug,
                                    artifact: kind,
                                    path: path.clone(),
                                    mtime_ms: mtime_ms(&path),
                                });
                            }
                            ArtifactKind::Status | ArtifactKind::Other => {}
                        }
                    }
                }
                Err(errors) => {
                    for err in errors {
                        tracing::warn!(err = ?err, "fs_watcher: debouncer error");
                    }
                }
            }
        }
    });

    Ok(handle)
}

/// Spawn the filesystem watcher for all registered repos.
///
/// The returned `JoinHandle` runs a tokio task that owns the debouncer and
/// processes events until the handle is dropped. The debouncer uses a 150 ms
/// window (D2) to coalesce burst writes (editor save → tmp rename sequence).
///
/// T5 is responsible for calling this function from `lib.rs run() .setup()`.
pub fn spawn_watcher(
    repos: Vec<PathBuf>,
    app: AppHandle,
) -> Result<JoinHandle<()>, String> {
    // Per D2: notify-debouncer-full with 150 ms window, RecommendedWatcher backend.
    // The tick_rate is None (uses default) so the debouncer thread manages its own sleep.
    let (tx, mut rx) = tokio::sync::mpsc::channel::<DebounceEventResult>(64);

    let mut debouncer: Debouncer<notify::RecommendedWatcher, FileIdMap> =
        new_debouncer(Duration::from_millis(150), None, move |result| {
            let _ = tx.blocking_send(result);
        })
        .map_err(|e| format!("watcher init failed: {e}"))?;

    // Register each repo's .specaffold/ tree. If any registration fails we
    // still start up — watcher_status.errored will fire for that repo so the
    // renderer can surface a grey pip per R16.
    let mut init_errors: Vec<(PathBuf, String)> = Vec::new();
    for repo in &repos {
        let watch_root = repo.join(".specaffold");
        if let Err(e) = debouncer.watch(&watch_root, RecursiveMode::Recursive) {
            init_errors.push((repo.clone(), format!("{e}")));
        }
    }

    // Emit running status for successfully-watched repos; error for failures.
    for repo in &repos {
        let watch_root = repo.join(".specaffold");
        let had_error = init_errors.iter().any(|(r, _)| r == repo);
        if had_error {
            let err_str = init_errors
                .iter()
                .find(|(r, _)| r == repo)
                .map(|(_, e)| e.clone());
            let _ = app.emit(
                "watcher_status",
                WatcherStatusPayload {
                    state: WatcherState::Errored,
                    error_kind: Some("init_failed".to_string()),
                    repo: Some(repo.clone()),
                },
            );
            tracing::warn!(
                repo = %watch_root.display(),
                err = ?err_str,
                "fs_watcher: init failed for repo"
            );
        } else {
            let _ = app.emit(
                "watcher_status",
                WatcherStatusPayload {
                    state: WatcherState::Running,
                    error_kind: None,
                    repo: Some(repo.clone()),
                },
            );
        }
    }

    // Move ownership of repos list and the debouncer into the async task.
    // The debouncer must stay alive for the lifetime of the watcher; dropping
    // it unregisters all watches.
    let repos_arc = Arc::new(repos);
    let app_handle = app.clone();

    let handle = tokio::task::spawn(async move {
        // Keep debouncer alive for the duration of this task.
        let _debouncer = debouncer;

        while let Some(result) = rx.recv().await {
            match result {
                Ok(events) => {
                    for event in events {
                        let path = match event.paths.first() {
                            Some(p) => p.clone(),
                            None => continue,
                        };

                        // Identify which repo this path belongs to.
                        let repo = repos_arc.iter().find(|r| path.starts_with(r.as_path()));
                        let repo = match repo {
                            Some(r) => r,
                            None => continue,
                        };

                        let kind = classify_artifact(&path);

                        // Dispatch per classify-before-mutate rule: the classifier
                        // above is pure; all side effects happen in this match.
                        match &kind {
                            ArtifactKind::Status => {
                                emit_sessions_changed(repo, &app_handle);
                            }
                            ArtifactKind::Request
                            | ArtifactKind::Design
                            | ArtifactKind::Prd
                            | ArtifactKind::Tech
                            | ArtifactKind::Plan
                            | ArtifactKind::Tasks => {
                                let slug = match slug_from_path(repo, &path) {
                                    Some(s) => s,
                                    None => continue,
                                };
                                let _ = app_handle.emit(
                                    "artifact_changed",
                                    ArtifactChangedPayload {
                                        repo: repo.clone(),
                                        slug,
                                        artifact: kind,
                                        path: path.clone(),
                                        mtime_ms: mtime_ms(&path),
                                    },
                                );
                            }
                            ArtifactKind::Other => {}
                        }
                    }
                }
                Err(errors) => {
                    for err in errors {
                        tracing::warn!(err = ?err, "fs_watcher: debouncer error");
                        let _ = app_handle.emit(
                            "watcher_status",
                            WatcherStatusPayload {
                                state: WatcherState::Errored,
                                error_kind: Some("dropped".to_string()),
                                repo: None,
                            },
                        );
                    }
                }
            }
        }
    });

    Ok(handle)
}

// ---------------------------------------------------------------------------
// Unit tests — classifier contract (pure function, no I/O)
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn p(s: &str) -> PathBuf {
        PathBuf::from(s)
    }

    #[test]
    fn classify_status_md() {
        assert_eq!(
            classify_artifact(&p("/repo/.specaffold/features/my-feat/STATUS.md")),
            ArtifactKind::Status,
        );
    }

    #[test]
    fn classify_request_md() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/00-request.md"
            )),
            ArtifactKind::Request,
        );
    }

    #[test]
    fn classify_design_dir_file() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/02-design/notes.md"
            )),
            ArtifactKind::Design,
        );
    }

    #[test]
    fn classify_prd_md() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/03-prd.md"
            )),
            ArtifactKind::Prd,
        );
    }

    #[test]
    fn classify_tech_md() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/04-tech.md"
            )),
            ArtifactKind::Tech,
        );
    }

    #[test]
    fn classify_plan_md() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/05-plan.md"
            )),
            ArtifactKind::Plan,
        );
    }

    #[test]
    fn classify_tasks_md() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/tasks.md"
            )),
            ArtifactKind::Tasks,
        );
    }

    #[test]
    fn classify_other() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/some-unknown-file.txt"
            )),
            ArtifactKind::Other,
        );
    }

    #[test]
    fn classify_design_nested_file() {
        assert_eq!(
            classify_artifact(&p(
                "/repo/.specaffold/features/my-feat/02-design/mockup.html"
            )),
            ArtifactKind::Design,
        );
    }

    #[test]
    fn slug_from_path_happy() {
        let repo = p("/repo");
        let path = p("/repo/.specaffold/features/my-feat/STATUS.md");
        assert_eq!(slug_from_path(&repo, &path), Some("my-feat".to_string()));
    }

    #[test]
    fn slug_from_path_no_match() {
        let repo = p("/repo");
        let path = p("/other/.specaffold/features/my-feat/STATUS.md");
        assert_eq!(slug_from_path(&repo, &path), None);
    }

    #[test]
    fn slug_from_path_nested_artifact() {
        let repo = p("/repo");
        let path = p("/repo/.specaffold/features/my-feat/02-design/notes.md");
        assert_eq!(slug_from_path(&repo, &path), Some("my-feat".to_string()));
    }
}

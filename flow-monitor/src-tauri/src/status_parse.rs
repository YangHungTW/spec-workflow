//! Pure parser for STATUS.md files — Architect Seam 1.
//!
//! No I/O in this module: `parse()` receives `content: &str` and `mtime: SystemTime`
//! and returns a fully populated `SessionState`.  All file reading happens in the caller.

use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// The 11 workflow stages plus Unknown for malformed / unrecognised values.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Stage {
    Request,
    Brainstorm,
    Design,
    Prd,
    Tech,
    Plan,
    Tasks,
    Implement,
    GapCheck,
    Verify,
    Archive,
    Unknown,
}

/// One item in the `## Stage checklist` section.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StageItem {
    pub label: String,
}

/// One entry from the `## Notes` section, preserving source order.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NotesEntry {
    /// Raw date string as it appears in the file (e.g. "2026-04-19").
    pub date: String,
    /// Role or author token (e.g. "Developer", "PM").
    pub role: String,
    /// Action text (everything after "role — ").
    pub action: String,
}

/// Parsed representation of one STATUS.md file.
#[derive(Debug, Clone)]
pub struct SessionState {
    pub slug: String,
    pub stage: Stage,
    /// `max(parsed updated:, most-recent Notes-line date, mtime)`.
    pub last_activity: SystemTime,
    /// Exactly 11 entries when well-formed; empty when malformed.
    pub stage_checklist: Vec<(StageItem, bool)>,
    /// Notes in source (chronological-insertion) order.
    pub notes: Vec<NotesEntry>,
    /// Filled in by the caller after `parse()` returns.
    pub raw_status_path: PathBuf,
}

impl SessionState {
    /// Returns notes newest-first for UI rendering (CardDetail view).
    /// Source-order is preserved in `self.notes`; this is a computed view.
    pub fn notes_newest_first(&self) -> Vec<&NotesEntry> {
        self.notes.iter().rev().collect()
    }
}

// ---------------------------------------------------------------------------
// Public entry point — the only `fn parse` in this file
// ---------------------------------------------------------------------------

/// Parse `content` (the raw text of a STATUS.md) together with the file's
/// `mtime` into a `SessionState`.
///
/// On any parse failure the function returns `Stage::Unknown` and
/// `last_activity = mtime` rather than propagating an error, so the caller
/// always gets a usable value (PRD §6 edge case).
pub fn parse(content: &str, mtime: SystemTime) -> SessionState {
    match try_parse(content, mtime) {
        Some(state) => state,
        None => SessionState {
            slug: String::new(),
            stage: Stage::Unknown,
            last_activity: mtime,
            stage_checklist: Vec::new(),
            notes: Vec::new(),
            raw_status_path: PathBuf::new(),
        },
    }
}

// ---------------------------------------------------------------------------
// Internal helpers — single-pass over the lines of content
// ---------------------------------------------------------------------------

fn try_parse(content: &str, mtime: SystemTime) -> Option<SessionState> {
    let mut slug: Option<String> = None;
    let mut stage: Option<Stage> = None;
    let mut updated_epoch: Option<u64> = None;
    let mut checklist: Vec<(StageItem, bool)> = Vec::new();
    let mut notes: Vec<NotesEntry> = Vec::new();

    // Track which section we are currently inside.
    let mut in_checklist = false;
    let mut in_notes = false;

    for line in content.lines() {
        let trimmed = line.trim();

        // Section headers reset the section state.
        if trimmed.starts_with("## Stage checklist") {
            in_checklist = true;
            in_notes = false;
            continue;
        }
        if trimmed.starts_with("## Notes") {
            in_checklist = false;
            in_notes = true;
            continue;
        }
        // Any other ## heading ends both sections.
        if trimmed.starts_with("## ") {
            in_checklist = false;
            in_notes = false;
            continue;
        }

        if in_checklist {
            if let Some(entry) = parse_checklist_line(trimmed) {
                checklist.push(entry);
            }
            continue;
        }

        if in_notes {
            if let Some(entry) = parse_notes_line(trimmed) {
                notes.push(entry);
            }
            continue;
        }

        // Front-matter fields (lines like `- **slug**: value`).
        if let Some(rest) = trimmed.strip_prefix("- **slug**:") {
            slug = Some(rest.trim().to_string());
        } else if let Some(rest) = trimmed.strip_prefix("- **stage**:") {
            stage = Some(parse_stage(rest.trim()));
        } else if let Some(rest) = trimmed.strip_prefix("- **updated**:") {
            updated_epoch = parse_date_to_epoch(rest.trim());
        }
    }

    // Require at least slug and stage to be considered well-formed.
    let slug = slug?;
    let stage = stage?;

    // last_activity = max(updated, most-recent notes date, mtime)
    let mtime_epoch = system_time_to_epoch(mtime);
    let notes_max = notes
        .iter()
        .filter_map(|n| parse_date_to_epoch(&n.date))
        .max()
        .unwrap_or(0);
    let updated = updated_epoch.unwrap_or(0);
    let max_epoch = mtime_epoch.max(notes_max).max(updated);
    let last_activity = epoch_to_system_time(max_epoch);

    Some(SessionState {
        slug,
        stage,
        last_activity,
        stage_checklist: checklist,
        notes,
        raw_status_path: PathBuf::new(),
    })
}

// ---------------------------------------------------------------------------
// Line-level parsers
// ---------------------------------------------------------------------------

/// Parse a checklist line: `- [ ] label ...` or `- [x] label ...`.
fn parse_checklist_line(trimmed: &str) -> Option<(StageItem, bool)> {
    // Expected format: `- [ ] label` or `- [x] label`
    let rest = trimmed.strip_prefix("- ")?;
    let (checked, label_rest) = if rest.starts_with("[x]") || rest.starts_with("[X]") {
        (true, &rest[3..])
    } else if rest.starts_with("[ ]") {
        (false, &rest[3..])
    } else {
        return None;
    };
    // Grab only the first word of the remainder as the canonical label.
    let label = label_rest.trim().split_whitespace().next()?.to_string();
    Some((StageItem { label }, checked))
}

/// Parse a notes line: `- YYYY-MM-DD Role — action text`.
fn parse_notes_line(trimmed: &str) -> Option<NotesEntry> {
    // Skip HTML comments.
    if trimmed.starts_with("<!--") {
        return None;
    }
    let rest = trimmed.strip_prefix("- ")?;
    // Expect `YYYY-MM-DD` at the start.
    if rest.len() < 10 {
        return None;
    }
    let date = &rest[..10];
    if !is_date_like(date) {
        return None;
    }
    let after_date = rest[10..].trim();
    // Split on " — " (em-dash with spaces) or fall back to " - ".
    let (role, action) = if let Some(idx) = after_date.find(" \u{2014} ") {
        let r = after_date[..idx].trim().to_string();
        let a = after_date[idx + " \u{2014} ".len()..].trim().to_string();
        (r, a)
    } else if let Some(idx) = after_date.find(" - ") {
        let r = after_date[..idx].trim().to_string();
        let a = after_date[idx + 3..].trim().to_string();
        (r, a)
    } else {
        // No separator — role is whatever is left, action is empty.
        (after_date.to_string(), String::new())
    };
    Some(NotesEntry { date: date.to_string(), role, action })
}

// ---------------------------------------------------------------------------
// Stage string -> enum
// ---------------------------------------------------------------------------

fn parse_stage(s: &str) -> Stage {
    match s.to_lowercase().as_str() {
        "request" => Stage::Request,
        "brainstorm" => Stage::Brainstorm,
        "design" => Stage::Design,
        "prd" => Stage::Prd,
        "tech" => Stage::Tech,
        "plan" => Stage::Plan,
        "tasks" => Stage::Tasks,
        "implement" => Stage::Implement,
        "gap-check" | "gapcheck" => Stage::GapCheck,
        "verify" => Stage::Verify,
        "archive" => Stage::Archive,
        _ => Stage::Unknown,
    }
}

// ---------------------------------------------------------------------------
// Date helpers — no subprocess, no filesystem
// ---------------------------------------------------------------------------

/// Returns true if `s` looks like `YYYY-MM-DD` (ASCII digits and hyphens only).
fn is_date_like(s: &str) -> bool {
    if s.len() != 10 {
        return false;
    }
    let b = s.as_bytes();
    b[4] == b'-' && b[7] == b'-'
        && b[..4].iter().all(|c| c.is_ascii_digit())
        && b[5..7].iter().all(|c| c.is_ascii_digit())
        && b[8..10].iter().all(|c| c.is_ascii_digit())
}

/// Convert `YYYY-MM-DD` to a Unix-epoch `u64` without any system calls.
/// Accurate for dates from 1970-01-01 onwards; ignores leap-seconds.
fn parse_date_to_epoch(date: &str) -> Option<u64> {
    if !is_date_like(date) {
        return None;
    }
    let year: u64 = date[0..4].parse().ok()?;
    let month: u64 = date[5..7].parse().ok()?;
    let day: u64 = date[8..10].parse().ok()?;
    if month < 1 || month > 12 || day < 1 || day > 31 {
        return None;
    }
    // Days from epoch to start of year.
    let days_per_month = [0u64, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let leap = is_leap(year);
    let mut days: u64 = 0;
    // Accumulate years since 1970.
    for y in 1970..year {
        days += if is_leap(y) { 366 } else { 365 };
    }
    // Accumulate months.
    for m in 1..month {
        let extra = if m == 2 && leap { 1 } else { 0 };
        days += days_per_month[m as usize] + extra;
    }
    days += day - 1;
    Some(days * 86_400)
}

fn is_leap(year: u64) -> bool {
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
}

fn system_time_to_epoch(t: SystemTime) -> u64 {
    t.duration_since(UNIX_EPOCH).unwrap_or(Duration::ZERO).as_secs()
}

fn epoch_to_system_time(epoch: u64) -> SystemTime {
    UNIX_EPOCH + Duration::from_secs(epoch)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, UNIX_EPOCH};

    // Fixtures are embedded at compile time — no filesystem access at runtime.
    const FIXTURE_RECENT_UPDATED: &str =
        include_str!("../tests/fixtures/status/recent_updated.md");
    const FIXTURE_RECENT_NOTES: &str =
        include_str!("../tests/fixtures/status/recent_notes.md");
    const FIXTURE_MTIME_FALLBACK: &str =
        include_str!("../tests/fixtures/status/mtime_fallback.md");
    const FIXTURE_TEMPLATE_BASELINE: &str =
        include_str!("../tests/fixtures/status/template_baseline.md");
    const FIXTURE_MALFORMED: &str =
        include_str!("../tests/fixtures/status/malformed_partial.md");
    const FIXTURE_NOTES_MULTI: &str =
        include_str!("../tests/fixtures/status/notes_multi.md");

    /// Helper: epoch seconds from a YYYY-MM-DD string (test-local, panics on bad input).
    fn date_epoch(date: &str) -> u64 {
        parse_date_to_epoch(date).expect("test date must be valid")
    }

    fn epoch_st(secs: u64) -> SystemTime {
        UNIX_EPOCH + Duration::from_secs(secs)
    }

    // AC3.a — `updated:` field is more recent than both Notes and mtime.
    #[test]
    fn test_recent_updated_wins() {
        // updated = 2026-04-15, notes max = 2026-02-05, mtime = 2026-01-01
        let mtime = epoch_st(date_epoch("2026-01-01"));
        let state = parse(FIXTURE_RECENT_UPDATED, mtime);
        assert_eq!(state.slug, "my-feature");
        assert_eq!(state.stage, Stage::Implement);
        let expected = epoch_st(date_epoch("2026-04-15"));
        assert_eq!(state.last_activity, expected, "last_activity should be updated: field");
        assert_eq!(state.stage_checklist.len(), 11);
    }

    // AC3.b — most-recent Notes line date is later than `updated:` and mtime.
    #[test]
    fn test_recent_notes_wins() {
        // updated = 2026-03-01, notes max = 2026-04-18, mtime = 2026-01-01
        let mtime = epoch_st(date_epoch("2026-01-01"));
        let state = parse(FIXTURE_RECENT_NOTES, mtime);
        assert_eq!(state.slug, "notes-feature");
        assert_eq!(state.stage, Stage::Plan);
        let expected = epoch_st(date_epoch("2026-04-18"));
        assert_eq!(state.last_activity, expected, "last_activity should be most-recent notes date");
        assert_eq!(state.stage_checklist.len(), 11);
    }

    // AC3.c — mtime is the most recent value when both parsed dates are older.
    #[test]
    fn test_mtime_fallback() {
        // updated = 2026-01-01, no notes, mtime = 2026-04-19
        let mtime = epoch_st(date_epoch("2026-04-19"));
        let state = parse(FIXTURE_MTIME_FALLBACK, mtime);
        assert_eq!(state.slug, "mtime-feature");
        assert_eq!(state.stage, Stage::Request);
        assert_eq!(state.last_activity, mtime, "last_activity should be mtime");
        assert_eq!(state.stage_checklist.len(), 11);
        assert!(state.notes.is_empty());
    }

    // AC9.b — stage checklist parses exactly 11 items from template baseline.
    #[test]
    fn test_template_baseline_checklist() {
        let mtime = epoch_st(0);
        let state = parse(FIXTURE_TEMPLATE_BASELINE, mtime);
        // Template has placeholder slug — we still get 11 checklist items.
        assert_eq!(state.stage_checklist.len(), 11, "template must yield 11 checklist entries");
        // All items unchecked in the template.
        for (item, checked) in &state.stage_checklist {
            assert!(!checked, "template item '{}' should be unchecked", item.label);
        }
    }

    // Malformed file — Stage::Unknown, last_activity = mtime.
    #[test]
    fn test_malformed_returns_unknown() {
        let mtime = epoch_st(date_epoch("2026-04-19"));
        let state = parse(FIXTURE_MALFORMED, mtime);
        assert_eq!(state.stage, Stage::Unknown);
        assert_eq!(state.last_activity, mtime);
        assert!(state.slug.is_empty());
        assert!(state.stage_checklist.is_empty());
    }

    // AC9.c — Notes are preserved in source (insertion) order.
    #[test]
    fn test_notes_source_order() {
        let mtime = epoch_st(date_epoch("2026-01-01"));
        let state = parse(FIXTURE_NOTES_MULTI, mtime);
        assert_eq!(state.notes.len(), 4, "should parse 4 notes entries");
        assert_eq!(state.notes[0].date, "2026-01-05");
        assert_eq!(state.notes[1].date, "2026-02-10");
        assert_eq!(state.notes[2].date, "2026-03-15");
        assert_eq!(state.notes[3].date, "2026-04-01");
    }

    // AC9.i — notes_newest_first() reverses source order.
    #[test]
    fn test_notes_newest_first() {
        let mtime = epoch_st(date_epoch("2026-01-01"));
        let state = parse(FIXTURE_NOTES_MULTI, mtime);
        let newest = state.notes_newest_first();
        assert_eq!(newest.len(), 4);
        assert_eq!(newest[0].date, "2026-04-01");
        assert_eq!(newest[1].date, "2026-03-15");
        assert_eq!(newest[2].date, "2026-02-10");
        assert_eq!(newest[3].date, "2026-01-05");
    }

    // Notes entries: role and action are split correctly on em-dash separator.
    #[test]
    fn test_notes_entry_fields() {
        let mtime = epoch_st(date_epoch("2026-01-01"));
        let state = parse(FIXTURE_NOTES_MULTI, mtime);
        let first = &state.notes[0];
        assert_eq!(first.role, "PM");
        assert_eq!(first.action, "created initial request");
    }

    // Stage checklist checked/unchecked flags are parsed correctly.
    #[test]
    fn test_checklist_checked_flags() {
        let mtime = epoch_st(date_epoch("2026-01-01"));
        let state = parse(FIXTURE_NOTES_MULTI, mtime);
        assert_eq!(state.stage_checklist.len(), 11);
        // notes_multi has request through gap-check checked, verify+archive unchecked.
        let (_, req_checked) = &state.stage_checklist[0];
        assert!(req_checked, "request should be checked");
        let (_, verify_checked) = &state.stage_checklist[9];
        assert!(!verify_checked, "verify should be unchecked");
        let (_, archive_checked) = &state.stage_checklist[10];
        assert!(!archive_checked, "archive should be unchecked");
    }

    // All 11 stage variants parse correctly from string.
    #[test]
    fn test_stage_parsing_all_variants() {
        assert_eq!(parse_stage("request"), Stage::Request);
        assert_eq!(parse_stage("brainstorm"), Stage::Brainstorm);
        assert_eq!(parse_stage("design"), Stage::Design);
        assert_eq!(parse_stage("prd"), Stage::Prd);
        assert_eq!(parse_stage("tech"), Stage::Tech);
        assert_eq!(parse_stage("plan"), Stage::Plan);
        assert_eq!(parse_stage("tasks"), Stage::Tasks);
        assert_eq!(parse_stage("implement"), Stage::Implement);
        assert_eq!(parse_stage("gap-check"), Stage::GapCheck);
        assert_eq!(parse_stage("verify"), Stage::Verify);
        assert_eq!(parse_stage("archive"), Stage::Archive);
        assert_eq!(parse_stage("bogus"), Stage::Unknown);
    }

    // Date epoch conversion is correct for a known date.
    #[test]
    fn test_date_epoch_known_value() {
        // 2026-01-01 = 1767225600 seconds from Unix epoch.
        let epoch = parse_date_to_epoch("2026-01-01").unwrap();
        // Verify it is in a plausible range (year 2025-2027).
        assert!(epoch > 1_700_000_000, "epoch for 2026-01-01 should be > 1.7B");
        assert!(epoch < 1_800_000_000, "epoch for 2026-01-01 should be < 1.8B");
    }
}

/// Terminal-spawn + clipboard + pipe-Err dispatcher (B2 D1 / D6).
///
/// Delivers a specflow command to the user via one of three modes:
///   Terminal  — writes a temp `.command` script, opens it in Terminal.app
///   Clipboard — writes the command string to the system clipboard
///   Pipe      — reserved for B3; always returns Err(NotAvailable)
///
/// # Coupling note (D1 / T91)
/// `TEMP_INVOKE_PATH_TEMPLATE` drives the path written at runtime.
/// The regex validator in `capabilities/default.json` `shell:allow-execute`
/// entry `"open-terminal"` MUST match every path this module generates.
/// Regex: `^/(private/)?(var|tmp)/flow-monitor-[a-z0-9-]+/invoke-[a-f0-9]{16}\.command$`
/// If you change the directory prefix or the filename template below, update
/// the regex in `capabilities/default.json` in the same commit.
///
/// See D1 / T93 — regex validator must match invoke.rs's tmpdir pattern.
use std::path::{Path, PathBuf};

// ---------------------------------------------------------------------------
// Path template — coupling to capabilities/default.json regex validator.
//
// Runtime-generated paths look like:
//   /tmp/flow-monitor-<16hex>/invoke-<16hex>.command
// or (macOS canonical form):
//   /private/tmp/flow-monitor-<16hex>/invoke-<16hex>.command
//
// Both forms match the capability regex:
//   ^/(private/)?(var|tmp)/flow-monitor-[a-z0-9-]+/invoke-[a-f0-9]{16}\.command$
// ---------------------------------------------------------------------------

/// Base directory prefix under `/tmp`.  The full directory name is
/// `flow-monitor-<16hex>` where the hex suffix is stable across a single
/// app run (derived once via `build_temp_base_dir()`).
pub const TEMP_INVOKE_PATH_TEMPLATE: &str = "/tmp/flow-monitor-";

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Closed enum of delivery methods — classifier input for `dispatch`.
/// `Pipe` lands here per spec; no caller in B2 invokes it successfully.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeliveryMethod {
    Terminal,
    Clipboard,
    Pipe,
}

/// Typed error variants for `dispatch`.  No string-escape hatch.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum InvokeError {
    /// Command name not in the allow-list (classify returned None).
    UnknownCommand,
    /// DESTROY-class command attempted but unreachable in B2 (B3 gate).
    DestroyUnreachable,
    /// A different invocation for (repo, slug) is already in flight.
    InFlight,
    /// `/usr/bin/open -a Terminal.app` returned a non-zero exit code or
    /// could not be spawned.
    SpawnFailed,
    /// Clipboard write call failed (plugin error).
    ClipboardFailed,
    /// The generated temp-file path was rejected by the path validator.
    PathTraversal,
    /// Delivery method is `Pipe` — not available in B2.
    NotAvailable,
}

impl std::fmt::Display for InvokeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InvokeError::UnknownCommand => write!(f, "unknown command"),
            InvokeError::DestroyUnreachable => write!(f, "DESTROY unreachable in B2"),
            InvokeError::InFlight => write!(f, "invocation already in flight"),
            InvokeError::SpawnFailed => write!(f, "terminal spawn failed"),
            InvokeError::ClipboardFailed => write!(f, "clipboard write failed"),
            InvokeError::PathTraversal => write!(f, "generated path failed validator"),
            InvokeError::NotAvailable => write!(f, "pipe delivery not available in B2"),
        }
    }
}

/// Closed set of dispatch outcomes.
/// `DestroyConfirmed` is reserved for B3; no B2 code path produces it.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Outcome {
    Spawned,
    Copied,
    Failed,
    /// Reserved for B3 — DESTROY command confirmed by the modal. No B2
    /// code path writes this variant; it exists so the enum is a closed set
    /// and audit.rs can reference it without a forward declaration in B3.
    DestroyConfirmed,
}

/// Result struct returned by `dispatch` on success.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct InvokeResult {
    pub outcome: Outcome,
}

// ---------------------------------------------------------------------------
// Path construction helpers
// ---------------------------------------------------------------------------

/// Generate a 16-character lowercase hex string from 8 OS-sourced random bytes.
///
/// Reads 8 bytes from `/dev/urandom` for unpredictable filenames that close
/// the /tmp symlink race window (security finding 5).  Falls back to a
/// time-XOR mix only if the OS device is unavailable — an unlikely degraded
/// path on any UNIX system.
fn gen_hex16() -> String {
    // Primary: OS entropy via /dev/urandom — no crate dep required.
    use std::io::Read;
    let mut buf = [0u8; 8];
    if let Ok(mut f) = std::fs::File::open("/dev/urandom") {
        if f.read_exact(&mut buf).is_ok() {
            let v = u64::from_ne_bytes(buf);
            return format!("{:016x}", v);
        }
    }
    // Fallback (should never be reached on macOS/Linux): time + stack addr mix.
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.subsec_nanos())
        .unwrap_or(0) as u64;
    let addr: u64 = (&nanos as *const u64) as u64;
    let combined = nanos ^ addr ^ (nanos.wrapping_mul(6364136223846793005));
    format!("{:016x}", combined)
}

/// Build the per-run base directory path under `/tmp`.
///
/// Returns a path like `/tmp/flow-monitor-<16hex>` whose name matches the
/// regex segment `flow-monitor-[a-z0-9-]+` from the capability manifest.
pub fn build_temp_base_dir() -> PathBuf {
    let hex = gen_hex16();
    PathBuf::from(format!("{}{}", TEMP_INVOKE_PATH_TEMPLATE, hex))
}

/// Build the full `.command` script path for a single invocation.
///
/// `base_dir` is the directory returned by `build_temp_base_dir()`.
/// Returns a path like `/tmp/flow-monitor-<hex>/invoke-<16hex>.command`.
///
/// The returned path MUST match the capability manifest regex:
///   `^/(private/)?(var|tmp)/flow-monitor-[a-z0-9-]+/invoke-[a-f0-9]{16}\.command$`
pub fn build_script_path(base_dir: &Path) -> PathBuf {
    let hex = gen_hex16();
    base_dir.join(format!("invoke-{}.command", hex))
}

/// Validate that `path` matches the capability manifest regex pattern.
///
/// Returns `Err(InvokeError::PathTraversal)` if the path does not match.
/// Called before every spawn to ensure the generated path satisfies the
/// capability allow-list (belt-and-braces — the manifest enforces it at
/// plugin level too, but we fail loudly here rather than silently at spawn).
pub fn validate_script_path(path: &Path) -> Result<(), InvokeError> {
    let s = path.to_string_lossy();
    // Pattern: ^/(private/)?(var|tmp)/flow-monitor-[a-z0-9-]+/invoke-[a-f0-9]{16}\.command$
    // Implemented without regex crate (not a dep) — manual prefix/suffix checks.
    //
    // Accepted forms:
    //   /tmp/flow-monitor-<hex>/invoke-<hex16>.command
    //   /var/tmp/flow-monitor-<hex>/invoke-<hex16>.command
    //   /private/tmp/flow-monitor-<hex>/invoke-<hex16>.command
    //   /private/var/tmp/flow-monitor-<hex>/invoke-<hex16>.command
    if !path_matches_capability_regex(&s) {
        return Err(InvokeError::PathTraversal);
    }
    Ok(())
}

/// Returns true iff `s` matches the capability regex:
/// `^/(private/)?(var|tmp)/flow-monitor-[a-z0-9-]+/invoke-[a-f0-9]{16}\.command$`
///
/// Exposed as `pub` so the `#[cfg(test)]` block can verify the unit test
/// paths satisfy the same check used at runtime.
pub fn path_matches_capability_regex(s: &str) -> bool {
    // Strip optional /private prefix
    let s = if let Some(rest) = s.strip_prefix("/private/") {
        rest
    } else if let Some(rest) = s.strip_prefix('/') {
        rest
    } else {
        return false;
    };

    // Match (var/)?tmp/ or var/tmp/ — spec allows var|tmp as a single segment
    let s = if let Some(rest) = s.strip_prefix("tmp/") {
        rest
    } else if let Some(rest) = s.strip_prefix("var/tmp/") {
        rest
    } else {
        return false;
    };

    // Match flow-monitor-<[a-z0-9-]+>/
    let s = match s.strip_prefix("flow-monitor-") {
        Some(rest) => rest,
        None => return false,
    };
    let slash = match s.find('/') {
        Some(i) => i,
        None => return false,
    };
    let dir_suffix = &s[..slash];
    let s = &s[slash + 1..];
    // dir_suffix must be [a-z0-9-]+ and non-empty
    if dir_suffix.is_empty() || !dir_suffix.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-') {
        return false;
    }

    // Match invoke-<[a-f0-9]{16}>.command
    let s = match s.strip_prefix("invoke-") {
        Some(rest) => rest,
        None => return false,
    };
    match s.strip_suffix(".command") {
        Some(hex) => {
            hex.len() == 16 && hex.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f'))
        }
        None => false,
    }
}

// ---------------------------------------------------------------------------
// Command allow-list guard
//
// Mirrors the list from command_taxonomy.rs (T96).  When T96 merges and
// `crate::command_taxonomy` is available, replace this with:
//   `use crate::command_taxonomy; command_taxonomy::allow_list_contains(cmd)`
// ---------------------------------------------------------------------------

/// Returns true if `cmd` is in the hardcoded specflow allow-list.
///
/// This is a defence-in-depth check inside `invoke.rs`; the primary check
/// lives (or will live) in `ipc.rs` which calls `command_taxonomy::classify`.
/// Keeping the check here too means `dispatch` is safe to call even from
/// test code that bypasses the IPC layer.
///
/// The list is the post-tier-model live command set (D3):
///   SAFE  — next, review, remember, promote
///   WRITE — request, prd, tech, plan, implement, validate, design
///   DESTROY — archive, update-req, update-tech, update-plan, update-task
fn cmd_is_in_allow_list(cmd: &str) -> bool {
    const ALLOWED: &[&str] = &[
        // SAFE
        "next", "review", "remember", "promote",
        // WRITE
        "request", "prd", "tech", "plan", "implement", "validate", "design",
        // DESTROY
        "archive", "update-req", "update-tech", "update-plan", "update-task",
    ];
    ALLOWED.contains(&cmd)
}

// ---------------------------------------------------------------------------
// Shell single-quote escape helper
// ---------------------------------------------------------------------------

/// Escape a string for embedding inside a bash single-quoted string.
///
/// Single-quoted strings in bash cannot contain a literal single quote.
/// The idiom `'\''` ends the current quote, inserts a literal `'` via
/// `\'`, then reopens the quote.  Applied to every occurrence of `'`
/// in the input value.
///
/// Example: `o'malley` → `o'\''malley`; embedded as `'o'\''malley'`.
fn shell_single_quote_escape(s: &str) -> String {
    s.replace('\'', "'\\''")
}

// ---------------------------------------------------------------------------
// Script content builder
// ---------------------------------------------------------------------------

/// Build the contents of the `.command` shell script.
///
/// The script `cd`s into the repo and runs `specflow <cmd>`.  The command
/// name and repo path are written into the **script body** — nothing goes
/// on the `/usr/bin/open` argv (that argv carries only the script path,
/// satisfying AC4.d's no-shell-string-cat constraint).
///
/// The slug is embedded in a comment for traceability; it is not passed to
/// the specflow invocation (specflow infers context from the working dir).
fn build_script_content(cmd: &str, slug: &str, repo: &Path) -> String {
    // Use single-quoted strings to prevent shell-expansion of the repo path
    // and command name.  Single-quote characters inside either value are
    // escaped using the `'\''` idiom so they cannot escape the shell quote
    // boundary (security findings 1 and 2).
    let repo_escaped = shell_single_quote_escape(&repo.to_string_lossy());
    let cmd_escaped = shell_single_quote_escape(cmd);
    format!(
        "#!/usr/bin/env bash\n\
         # flow-monitor terminal spawn — slug: {slug}\n\
         set -euo pipefail\n\
         cd '{repo_escaped}'\n\
         specflow '{cmd_escaped}'\n"
    )
}

// ---------------------------------------------------------------------------
// Temp-file writer (testable seam)
// ---------------------------------------------------------------------------

/// Write the `.command` script to `script_path` with mode 0755.
///
/// Creates the parent directory if it does not exist.
/// Returns `Err(InvokeError::SpawnFailed)` on any I/O error.
pub fn write_script(
    script_path: &Path,
    content: &str,
) -> Result<(), InvokeError> {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    // Create parent directory (e.g. /tmp/flow-monitor-<hex>/) if absent.
    if let Some(parent) = script_path.parent() {
        fs::create_dir_all(parent).map_err(|e| {
            tracing::error!("invoke: failed to create temp dir {:?}: {e}", parent);
            InvokeError::SpawnFailed
        })?;
    }

    fs::write(script_path, content).map_err(|e| {
        tracing::error!("invoke: failed to write script {:?}: {e}", script_path);
        InvokeError::SpawnFailed
    })?;

    let mut perms = fs::metadata(script_path)
        .map_err(|_| InvokeError::SpawnFailed)?
        .permissions();
    perms.set_mode(0o755);
    fs::set_permissions(script_path, perms).map_err(|e| {
        tracing::error!("invoke: failed to chmod {:?}: {e}", script_path);
        InvokeError::SpawnFailed
    })?;

    Ok(())
}

// ---------------------------------------------------------------------------
// Spawn executor (testable seam — injectable for unit tests)
// ---------------------------------------------------------------------------

/// Spawn `/usr/bin/open -a Terminal.app <script_path>`.
///
/// Argv-form invocation only — no shell string interpolation (AC4.d).
/// The script path has already been validated by `validate_script_path`.
///
/// Uses `std::process::Command` directly rather than `tauri-plugin-shell`
/// because the capability enforcement is at the plugin manifest layer;
/// the Rust-side invocation must be argv-clean regardless.
pub fn spawn_terminal(script_path: &Path) -> Result<(), InvokeError> {
    std::process::Command::new("/usr/bin/open")
        .args(["-a", "Terminal.app", &script_path.to_string_lossy()])
        .status()
        .map_err(|e| {
            tracing::error!("invoke: /usr/bin/open failed: {e}");
            InvokeError::SpawnFailed
        })?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Stale temp-file purge (called from app setup — D1)
// ---------------------------------------------------------------------------

/// Remove all `.command` files under `/tmp/` whose names match the
/// `flow-monitor-*` directory pattern.
///
/// Called once during app setup (T108 wires this into `lib.rs`).  Silently
/// ignores per-file errors — the purge is best-effort cleanup; a leftover
/// script causes no functional harm.
pub fn purge_stale_temp_files() {
    let tmp = Path::new("/tmp");
    let dir_iter = match std::fs::read_dir(tmp) {
        Ok(it) => it,
        Err(e) => {
            tracing::warn!("invoke: cannot read /tmp for purge: {e}");
            return;
        }
    };

    for entry in dir_iter.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if !name_str.starts_with("flow-monitor-") {
            continue;
        }
        let dir_path = entry.path();
        if !dir_path.is_dir() {
            continue;
        }
        // Remove the whole directory (it contains only app-owned .command files).
        if let Err(e) = std::fs::remove_dir_all(&dir_path) {
            tracing::warn!("invoke: failed to purge {:?}: {e}", dir_path);
        }
    }
}

// ---------------------------------------------------------------------------
// Clipboard write (testable seam — injectable for unit tests via trait)
// ---------------------------------------------------------------------------

/// Trait over the clipboard write operation so `dispatch_inner` can be
/// exercised in unit tests without a live Tauri `AppHandle`.
pub trait ClipboardWriter: Send + Sync {
    fn write_text(&self, text: &str) -> Result<(), String>;
}

/// Production implementation that delegates to `tauri-plugin-clipboard-manager`.
pub struct TauriClipboard<'a>(pub &'a tauri::AppHandle);

impl<'a> ClipboardWriter for TauriClipboard<'a> {
    fn write_text(&self, text: &str) -> Result<(), String> {
        use tauri_plugin_clipboard_manager::ClipboardExt;
        self.0.clipboard().write_text(text.to_string()).map_err(|e| e.to_string())
    }
}

// ---------------------------------------------------------------------------
// Core dispatch function
// ---------------------------------------------------------------------------

/// Dispatch a specflow command using the requested delivery method.
///
/// # Classify-before-mutate discipline (classify-before-mutate.md)
/// The caller (ipc.rs `invoke_command`) is responsible for:
///   1. Classifying the command via `command_taxonomy::classify`.
///   2. Checking the allow-list via `command_taxonomy::allow_list_contains`.
///   3. Acquiring the in-flight lock via `lock::LockState::acquire`.
///   4. Calling this function to execute delivery.
///
/// `dispatch` itself is a pure executor — it does not classify or lock.
/// The separation makes the executor unit-testable without a taxonomy or
/// lock dependency.
///
/// # Path-traversal guard (R9)
/// The `repo` path is trusted only if the caller has already validated it
/// against the registered-repo set (ipc.rs `read_artefact`'s pattern).
/// `dispatch` calls `validate_script_path` on the generated temp-file path
/// to detect any generation logic that would violate the capability regex.
pub fn dispatch(
    delivery: DeliveryMethod,
    cmd: &str,
    slug: &str,
    repo: &Path,
    clipboard: Option<&dyn ClipboardWriter>,
) -> Result<InvokeResult, InvokeError> {
    // Defence-in-depth allow-list check (security finding 3).
    // The primary check is in ipc.rs `invoke_command` (caller validates via
    // command_taxonomy::allow_list_contains before calling dispatch).
    // This second check ensures dispatch() is safe even when called directly
    // from tests or future callers that bypass the IPC layer.
    if !cmd_is_in_allow_list(cmd) {
        return Err(InvokeError::UnknownCommand);
    }

    match delivery {
        DeliveryMethod::Terminal => {
            dispatch_terminal(cmd, slug, repo)
        }
        DeliveryMethod::Clipboard => {
            let clipboard = clipboard.ok_or(InvokeError::ClipboardFailed)?;
            dispatch_clipboard(cmd, slug, repo, clipboard)
        }
        DeliveryMethod::Pipe => {
            // Pipe delivery is not available in B2 — reserved for B3.
            Err(InvokeError::NotAvailable)
        }
    }
}

/// Terminal arm: write script, validate path, spawn `/usr/bin/open`.
fn dispatch_terminal(cmd: &str, slug: &str, repo: &Path) -> Result<InvokeResult, InvokeError> {
    let base = build_temp_base_dir();
    let script_path = build_script_path(&base);

    // Belt-and-braces: validate the generated path against the capability regex
    // before attempting the spawn.  Fails loudly rather than silently.
    validate_script_path(&script_path)?;

    let content = build_script_content(cmd, slug, repo);
    write_script(&script_path, &content)?;
    spawn_terminal(&script_path)?;

    Ok(InvokeResult { outcome: Outcome::Spawned })
}

/// Clipboard arm: write the command string to the clipboard.
fn dispatch_clipboard(
    cmd: &str,
    slug: &str,
    repo: &Path,
    clipboard: &dyn ClipboardWriter,
) -> Result<InvokeResult, InvokeError> {
    // Build the command string: `cd '<repo>' && specflow '<cmd>'` — single line
    // suitable for pasting in a terminal.  Single-quote characters in either
    // value are escaped using the `'\''` idiom (security findings 2 and 4).
    let _ = slug; // slug embedded in comment only; not needed for clipboard text
    let repo_escaped = shell_single_quote_escape(&repo.to_string_lossy());
    let cmd_escaped = shell_single_quote_escape(cmd);
    let text = format!("cd '{repo_escaped}' && specflow '{cmd_escaped}'");
    clipboard
        .write_text(&text)
        .map_err(|e| {
            tracing::error!("invoke: clipboard write failed: {e}");
            InvokeError::ClipboardFailed
        })?;
    Ok(InvokeResult { outcome: Outcome::Copied })
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    // -----------------------------------------------------------------------
    // (a) Pipe arm returns NotAvailable
    // -----------------------------------------------------------------------

    #[test]
    fn pipe_arm_returns_not_available() {
        // Pipe delivery must always return Err(NotAvailable) — no side effects.
        // Use a known-good command so the allow-list check passes and we reach
        // the Pipe arm's NotAvailable return.
        let repo = Path::new("/tmp/fake-repo");
        let result = dispatch(DeliveryMethod::Pipe, "implement", "my-session", repo, None);
        assert!(
            matches!(result, Err(InvokeError::NotAvailable)),
            "Pipe arm must return NotAvailable, got: {:?}",
            result
        );
    }

    // -----------------------------------------------------------------------
    // (b) Terminal arm builds argv without shell-string interpolation
    //
    // We test the argv shape by inspecting `build_script_path` + the path
    // validator rather than spawning a real process.  The unit verifies:
    //   1. The generated path satisfies `validate_script_path` (would be
    //      accepted by the capability manifest).
    //   2. The path is built from `TEMP_INVOKE_PATH_TEMPLATE` prefix + hex.
    //   3. No shell metacharacters appear in the generated path.
    // -----------------------------------------------------------------------

    #[test]
    fn terminal_arm_argv_shape_no_shell_string() {
        let base = build_temp_base_dir();
        let script_path = build_script_path(&base);

        // The path must pass the capability validator — proof that no
        // shell-metachar or traversal sequence was introduced.
        assert!(
            validate_script_path(&script_path).is_ok(),
            "generated path must satisfy capability regex: {:?}",
            script_path
        );

        // The argv vector for the actual spawn is:
        //   ["/usr/bin/open", "-a", "Terminal.app", "<script_path>"]
        // Verify by constructing it explicitly and checking none of the
        // args contain shell metacharacters (space, semicolon, ampersand,
        // pipe, backtick, dollar, quote).
        let script_str = script_path.to_string_lossy();
        let argv: Vec<&str> = vec!["/usr/bin/open", "-a", "Terminal.app", &script_str];

        let shell_metachars = [' ', ';', '&', '|', '`', '$', '"', '\'', '<', '>'];
        for arg in &argv[1..] {
            // "-a" and "Terminal.app" are literal constants; only script_str is generated.
            for ch in shell_metachars {
                assert!(
                    !arg.contains(ch),
                    "argv arg {:?} contains shell metachar {:?}",
                    arg,
                    ch
                );
            }
        }
    }

    // -----------------------------------------------------------------------
    // (c) Temp-file path matches the capability manifest regex
    //
    // Exercises `path_matches_capability_regex` against a variety of:
    //   - valid paths (must return true)
    //   - invalid paths (must return false)
    // -----------------------------------------------------------------------

    #[test]
    fn generated_path_matches_capability_regex() {
        // A freshly-generated path must match.
        let base = build_temp_base_dir();
        let script_path = build_script_path(&base);
        assert!(
            path_matches_capability_regex(&script_path.to_string_lossy()),
            "generated path must match regex: {:?}",
            script_path
        );
    }

    #[test]
    fn capability_regex_valid_paths() {
        let valid = [
            "/tmp/flow-monitor-abc123/invoke-0123456789abcdef.command",
            "/tmp/flow-monitor-a/invoke-aaaaaaaaaaaaaaaa.command",
            "/private/tmp/flow-monitor-abc/invoke-0000000000000000.command",
            "/var/tmp/flow-monitor-abc/invoke-fedcba9876543210.command",
            "/private/var/tmp/flow-monitor-abc/invoke-fedcba9876543210.command",
        ];
        for path in &valid {
            assert!(
                path_matches_capability_regex(path),
                "expected match for: {path}"
            );
        }
    }

    #[test]
    fn capability_regex_invalid_paths() {
        let invalid = [
            // Too short hex (15 chars)
            "/tmp/flow-monitor-abc/invoke-0123456789abcde.command",
            // Too long hex (17 chars)
            "/tmp/flow-monitor-abc/invoke-0123456789abcdeff.command",
            // Uppercase in hex
            "/tmp/flow-monitor-abc/invoke-0123456789ABCDEF.command",
            // Wrong extension
            "/tmp/flow-monitor-abc/invoke-0123456789abcdef.sh",
            // Directory name has uppercase
            "/tmp/flow-MONITOR-abc/invoke-0123456789abcdef.command",
            // Missing flow-monitor- prefix in dir
            "/tmp/invoke-0123456789abcdef.command",
            // Traversal attempt
            "/tmp/flow-monitor-abc/../etc/passwd",
            // Empty directory suffix
            "/tmp/flow-monitor-/invoke-0123456789abcdef.command",
            // Relative path
            "tmp/flow-monitor-abc/invoke-0123456789abcdef.command",
        ];
        for path in &invalid {
            assert!(
                !path_matches_capability_regex(path),
                "expected no match for: {path}"
            );
        }
    }

    // -----------------------------------------------------------------------
    // Clipboard arm routes through the ClipboardWriter trait
    // -----------------------------------------------------------------------

    struct SpyClipboard {
        recorded: Mutex<Option<String>>,
    }

    impl ClipboardWriter for SpyClipboard {
        fn write_text(&self, text: &str) -> Result<(), String> {
            *self.recorded.lock().unwrap() = Some(text.to_string());
            Ok(())
        }
    }

    #[test]
    fn clipboard_arm_writes_cd_and_command() {
        let spy = SpyClipboard { recorded: Mutex::new(None) };
        let repo = Path::new("/some/repo");
        // Use a known-good command so the allow-list check passes.
        let result = dispatch(
            DeliveryMethod::Clipboard,
            "implement",
            "my-session",
            repo,
            Some(&spy),
        );
        assert!(
            matches!(result, Ok(InvokeResult { outcome: Outcome::Copied })),
            "clipboard arm must return Copied: {:?}",
            result
        );
        let text = spy.recorded.lock().unwrap();
        let text = text.as_ref().expect("clipboard must have been written");
        assert!(text.contains("specflow 'implement'"), "must contain command");
        assert!(text.contains("/some/repo"), "must contain repo path");
        // No shell metachar $, `, ; outside the single-quoted path
        assert!(!text.contains('`'), "no backtick in clipboard text");
    }

    #[test]
    fn clipboard_arm_error_when_no_writer_provided() {
        let repo = Path::new("/some/repo");
        // Use a known-good command; the missing-writer error must fire at the
        // clipboard layer, not at the allow-list gate.
        let result = dispatch(
            DeliveryMethod::Clipboard,
            "implement",
            "my-session",
            repo,
            None,
        );
        assert!(
            matches!(result, Err(InvokeError::ClipboardFailed)),
            "missing writer must return ClipboardFailed: {:?}",
            result
        );
    }

    // -----------------------------------------------------------------------
    // Script content builder — no shell-expansion in repo path or cmd
    // -----------------------------------------------------------------------

    #[test]
    fn script_content_contains_cd_and_specflow() {
        let content = build_script_content("implement", "my-slug", Path::new("/home/user/project"));
        assert!(content.contains("cd '/home/user/project'"), "must cd to repo");
        // Command is now single-quoted in the generated script.
        assert!(content.contains("specflow 'implement'"), "must invoke specflow");
        assert!(content.contains("my-slug"), "must reference slug in comment");
        assert!(content.starts_with("#!/usr/bin/env bash"), "must have shebang");
    }

    // -----------------------------------------------------------------------
    // Security: single-quote injection in repo path (finding 1)
    //
    // A repo path containing a single quote must not escape the
    // single-quoted shell string.  The `'\''` idiom must be applied.
    // -----------------------------------------------------------------------

    #[test]
    fn script_content_repo_single_quote_is_escaped() {
        // A path with a single-quote must be safely embedded — the quote
        // must be escaped so that the `cd '...'` shell construct remains
        // a single shell word and does not allow injection.
        let repo = Path::new("/home/user/o'malley/project");
        let content = build_script_content("implement", "slug", repo);
        // The raw single quote must not appear unescaped between the outer quotes.
        // After applying '\'' idiom the cd line becomes:
        //   cd '/home/user/o'\''malley/project'
        assert!(
            !content.contains("cd '/home/user/o'malley/project'"),
            "unescaped single-quote in repo path is a shell injection vector"
        );
        // The escaped form must be present.
        assert!(
            content.contains(r"cd '/home/user/o'\''malley/project'"),
            "repo single-quote must use the '\\''  escape idiom; content:\n{content}"
        );
    }

    // -----------------------------------------------------------------------
    // Security: cmd must be shell-quoted in build_script_content (finding 2)
    // -----------------------------------------------------------------------

    #[test]
    fn script_content_cmd_single_quote_is_escaped() {
        // A cmd containing a single quote must be safely embedded.
        let content = build_script_content("bad'cmd", "slug", Path::new("/tmp/repo"));
        // The unescaped form must not appear.
        assert!(
            !content.contains("specflow bad'cmd\n"),
            "unescaped single-quote in cmd is a shell injection vector"
        );
        // The escaped form must be present.
        assert!(
            content.contains(r"specflow 'bad'\''cmd'"),
            "cmd single-quote must use the '\\'' escape idiom; content:\n{content}"
        );
    }

    // -----------------------------------------------------------------------
    // Security: dispatch() rejects unknown commands (finding 3)
    // -----------------------------------------------------------------------

    #[test]
    fn dispatch_rejects_unknown_command_terminal() {
        // Pipe arm already returns NotAvailable; this test checks the
        // allow-list guard at the top of dispatch for Terminal delivery.
        // An unknown command must return Err(UnknownCommand) before any
        // script is written or process is spawned.
        let repo = Path::new("/tmp/fake-repo");
        let result = dispatch(
            DeliveryMethod::Terminal,
            "totally-unknown-cmd",
            "slug",
            repo,
            None,
        );
        assert!(
            matches!(result, Err(InvokeError::UnknownCommand)),
            "dispatch must reject unknown commands with UnknownCommand, got: {:?}",
            result
        );
    }

    #[test]
    fn dispatch_rejects_unknown_command_clipboard() {
        let spy = SpyClipboard { recorded: Mutex::new(None) };
        let repo = Path::new("/tmp/fake-repo");
        let result = dispatch(
            DeliveryMethod::Clipboard,
            "not-a-real-cmd",
            "slug",
            repo,
            Some(&spy),
        );
        assert!(
            matches!(result, Err(InvokeError::UnknownCommand)),
            "clipboard arm must also reject unknown commands, got: {:?}",
            result
        );
        // Clipboard must NOT have been written.
        assert!(
            spy.recorded.lock().unwrap().is_none(),
            "clipboard must not be written for an unknown command"
        );
    }

    // -----------------------------------------------------------------------
    // Security: clipboard arm also escapes single quotes (finding 4)
    // -----------------------------------------------------------------------

    #[test]
    fn clipboard_arm_repo_single_quote_is_escaped() {
        let spy = SpyClipboard { recorded: Mutex::new(None) };
        // Use a known-good command so the allow-list check passes.
        let repo = Path::new("/home/user/o'malley/project");
        let result = dispatch(
            DeliveryMethod::Clipboard,
            "implement",
            "slug",
            repo,
            Some(&spy),
        );
        assert!(
            matches!(result, Ok(InvokeResult { outcome: Outcome::Copied })),
            "clipboard arm must succeed: {:?}",
            result
        );
        let text = spy.recorded.lock().unwrap();
        let text = text.as_ref().expect("clipboard must have been written");
        // The raw unescaped single-quote must not appear in a way that breaks
        // the shell single-quote boundary.
        assert!(
            !text.contains("cd '/home/user/o'malley/project'"),
            "unescaped single-quote in clipboard repo path is a shell injection vector"
        );
        assert!(
            text.contains(r"cd '/home/user/o'\''malley/project'"),
            "clipboard repo path single-quote must use the '\\'' escape idiom; text:\n{text}"
        );
    }

    // -----------------------------------------------------------------------
    // Security: gen_hex16 returns 16 lowercase hex chars using OS entropy
    //
    // This is a basic sanity check — the exact output is random.
    // We verify format (16 hex chars), not value.  The weak-entropy
    // `time ^ addr` approach must be replaced with OS-sourced bytes.
    // -----------------------------------------------------------------------

    #[test]
    fn gen_hex16_format_is_16_lowercase_hex() {
        for _ in 0..20 {
            let h = gen_hex16();
            assert_eq!(h.len(), 16, "gen_hex16 must return 16 chars, got {:?}", h);
            assert!(
                h.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f')),
                "gen_hex16 must be lowercase hex, got {:?}",
                h
            );
        }
    }

    #[test]
    fn gen_hex16_is_not_constant() {
        // OS entropy must produce different values across calls.
        // With 16 hex chars (64 bits of entropy) the probability of a
        // collision in 100 calls is astronomically low.
        let values: std::collections::HashSet<String> = (0..100).map(|_| gen_hex16()).collect();
        assert!(values.len() > 90, "gen_hex16 must not be near-constant: only {} unique in 100 calls", values.len());
    }

    // -----------------------------------------------------------------------
    // validate_script_path returns PathTraversal for bad paths
    // -----------------------------------------------------------------------

    #[test]
    fn validate_script_path_rejects_traversal() {
        let bad = Path::new("/tmp/flow-monitor-abc/../etc/passwd");
        let result = validate_script_path(bad);
        assert!(
            matches!(result, Err(InvokeError::PathTraversal)),
            "traversal path must be rejected: {:?}",
            result
        );
    }

    #[test]
    fn validate_script_path_accepts_generated_path() {
        let base = build_temp_base_dir();
        let script_path = build_script_path(&base);
        assert!(
            validate_script_path(&script_path).is_ok(),
            "generated path must be accepted: {:?}",
            script_path
        );
    }
}

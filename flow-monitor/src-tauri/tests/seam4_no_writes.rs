/// Seam 4 — read-only invariant static check.
///
/// Walks every `.rs` file under `src-tauri/src/` and asserts that no
/// write-call pattern (`OpenOptions::write`, `OpenOptions::create`,
/// `fs::write(`, `fs::create(`, `File::create(`) appears on the same
/// line as the string `spec-workflow`.
///
/// The single legitimate write site is `settings.rs` — it writes to
/// `app_data_dir` via a `.tmp` atomic rename, not to any
/// `.spec-workflow/**` path.  All test-fixture writes (under
/// `#[cfg(test)]` blocks in `ipc.rs` and `poller.rs`) reference
/// `spec-workflow` path *variables* that are declared on separate lines,
/// so the same-line regex catches only true production-path violations.
///
/// AC3.d: no write across any `.spec-workflow/**` path in production code.
use std::fs;
use std::path::PathBuf;
use walkdir::WalkDir;

/// Patterns that indicate a write-call expression.
const WRITE_PATTERNS: &[&str] = &[
    "OpenOptions::write",
    "OpenOptions::create",
    "fs::write(",
    "fs::create(",
    "File::create(",
];

/// The dangerous combination: a write call whose line also names the
/// spec-workflow directory.  Any hit here is a Seam-4 violation.
const SPEC_WORKFLOW_MARKER: &str = "spec-workflow";

#[test]
fn seam4_no_write_call_references_spec_workflow_path() {
    // Resolve the `src` directory relative to this integration-test binary.
    // At test time `CARGO_MANIFEST_DIR` is the crate root
    // (`flow-monitor/src-tauri`), so `src` sits right below it.
    let manifest_dir = env!("CARGO_MANIFEST_DIR");
    let src_dir = PathBuf::from(manifest_dir).join("src");

    assert!(
        src_dir.is_dir(),
        "src directory must exist at {:?}",
        src_dir
    );

    let mut violations: Vec<String> = Vec::new();

    for entry in WalkDir::new(&src_dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| {
            e.file_type().is_file()
                && e.path().extension().map_or(false, |ext| ext == "rs")
        })
    {
        let path = entry.path();
        let content = fs::read_to_string(path)
            .unwrap_or_else(|e| panic!("cannot read {:?}: {}", path, e));

        for (line_no, line) in content.lines().enumerate() {
            // Check whether this line contains any write-call pattern.
            let has_write_call = WRITE_PATTERNS.iter().any(|pat| line.contains(pat));
            if !has_write_call {
                continue;
            }

            // If the write-call line also references `spec-workflow`, that is
            // a Seam-4 violation: production code is writing to a
            // `.spec-workflow/**` path.
            if line.contains(SPEC_WORKFLOW_MARKER) {
                violations.push(format!(
                    "{}:{}: write call references spec-workflow — {:?}",
                    path.display(),
                    line_no + 1,
                    line.trim()
                ));
            }
        }
    }

    assert!(
        violations.is_empty(),
        "Seam 4 FAIL — write call(s) reference spec-workflow paths \
         (AC3.d: app must never write to .spec-workflow/**):\n{}",
        violations.join("\n")
    );
}

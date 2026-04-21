use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    tauri_build::build();
    generate_command_taxonomy_ts();
}

/// Parse `src/command_taxonomy.rs` for the three `const` arrays and emit
/// `src/generated/command_taxonomy.ts` with matching `export const` arrays.
///
/// Fail-loud: if any array cannot be parsed, the build fails with a descriptive
/// error message so a developer knows exactly what to fix.
///
/// Pattern matched (per T109 spec):
///   `const (SAFE|WRITE|DESTROY): &[&str] = &["a", "b", ...];`
fn generate_command_taxonomy_ts() {
    // Tell Cargo to re-run this build script when the taxonomy source changes.
    println!("cargo:rerun-if-changed=src/command_taxonomy.rs");

    let manifest_dir = PathBuf::from(
        std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR must be set by Cargo"),
    );
    let taxonomy_src = manifest_dir.join("src").join("command_taxonomy.rs");
    let out_dir = manifest_dir.parent().unwrap_or(Path::new(".")).join("src").join("generated");

    let source = fs::read_to_string(&taxonomy_src).unwrap_or_else(|e| {
        panic!(
            "build.rs: cannot read command_taxonomy.rs at {}: {}",
            taxonomy_src.display(),
            e
        )
    });

    let safe = parse_const_array(&source, "SAFE").unwrap_or_else(|| {
        panic!(
            "build.rs: could not parse `const SAFE` array in {}",
            taxonomy_src.display()
        )
    });
    let write = parse_const_array(&source, "WRITE").unwrap_or_else(|| {
        panic!(
            "build.rs: could not parse `const WRITE` array in {}",
            taxonomy_src.display()
        )
    });
    let destroy = parse_const_array(&source, "DESTROY").unwrap_or_else(|| {
        panic!(
            "build.rs: could not parse `const DESTROY` array in {}",
            taxonomy_src.display()
        )
    });

    let ts = render_ts(&safe, &write, &destroy);

    fs::create_dir_all(&out_dir).unwrap_or_else(|e| {
        panic!(
            "build.rs: cannot create output directory {}: {}",
            out_dir.display(),
            e
        )
    });

    let out_file = out_dir.join("command_taxonomy.ts");
    // Write to a temp file then rename so a disk-full or signal interrupt
    // mid-write cannot leave a corrupt partial file at the final path.
    let tmp_file = out_dir.join("command_taxonomy.ts.tmp");
    fs::write(&tmp_file, &ts).unwrap_or_else(|e| {
        panic!(
            "build.rs: cannot write TS projection to {}: {}",
            tmp_file.display(),
            e
        )
    });
    fs::rename(&tmp_file, &out_file).unwrap_or_else(|e| {
        panic!(
            "build.rs: cannot rename {} → {}: {}",
            tmp_file.display(),
            out_file.display(),
            e
        )
    });

    // Cargo picks up this warning in verbose builds; used to confirm which
    // taxonomy version was active without grepping the full build log.
    println!("cargo:warning=Generated {}", out_file.display());
}

/// Parse a `pub const <NAME>: &[&str] = &["a", "b", ...];` declaration.
///
/// Returns the list of string values, or `None` if the pattern is not found
/// or parsing fails.
///
/// The implementation is a simple linear scan: locate the `const <NAME>` token,
/// find the opening `&[`, then collect `"..."` string literals until the closing `]`.
/// No regex crate is used — build dependencies are kept minimal.
fn parse_const_array(source: &str, name: &str) -> Option<Vec<String>> {
    // Find `const <NAME>:` — matches inside `pub const SAFE:` etc.
    let marker = format!("const {name}:");
    let start = source.find(&marker)?;

    // The declaration looks like: `const NAME: &[&str] = &["a", "b"];`
    // We need to skip past the `= ` to find the value array, not the type `&[&str]`.
    // Find the `=` that separates the type annotation from the value.
    let eq_pos = source[start..].find('=')? + start;

    // Find the `&[` that opens the value array (after the `=`).
    let after_eq = &source[eq_pos + 1..];
    let value_array_offset = after_eq.find("&[")?;
    let array_start = eq_pos + 1 + value_array_offset;

    // Find the `]` that closes the array literal (first `]` after `&[`).
    let array_end = source[array_start..].find(']')? + array_start;

    // +2 skips the `&[` opener; the `]` closer is excluded by using array_end as the end bound.
    let array_body = &source[array_start + 2..array_end];

    let mut values = Vec::new();
    let mut remaining = array_body;
    while let Some(quote_open) = remaining.find('"') {
        let after_open = &remaining[quote_open + 1..];
        let quote_close = after_open.find('"')?;
        let value = &after_open[..quote_close];
        // Validate: command names are ASCII lowercase + hyphen only (no escape sequences needed).
        if value.bytes().all(|b| b.is_ascii_lowercase() || b == b'-') {
            values.push(value.to_string());
        } else {
            // Non-ASCII or escape sequence — fail-loud so unexpected values surface.
            return None;
        }
        remaining = &after_open[quote_close + 1..];
    }

    if values.is_empty() {
        None
    } else {
        Some(values)
    }
}

/// Render the three arrays as a TypeScript file.
///
/// Each array gets a corresponding `Set<string>` constant built at module-load
/// time.  `classify()` uses `.has()` (O(1)) instead of `Array.includes()` (O(n))
/// so three sequential linear scans are avoided on every dispatch call.
///
/// NOTE: this output couples with `flow-monitor/src/generated/command_taxonomy.ts`
/// (the placeholder committed by T110).  Any change to the exported shape here
/// must be reflected in the consumers of that file (e.g. invokeStore.ts).
fn render_ts(safe: &[String], write: &[String], destroy: &[String]) -> String {
    let safe_ts = ts_array(safe);
    let write_ts = ts_array(write);
    let destroy_ts = ts_array(destroy);

    format!(
        "// Auto-generated by src-tauri/build.rs — DO NOT EDIT.\n\
         // Source of truth: src-tauri/src/command_taxonomy.rs\n\
         // Regenerated on every `cargo build`.\n\
         \n\
         export const SAFE = {safe_ts} as const;\n\
         \n\
         export const WRITE = {write_ts} as const;\n\
         \n\
         export const DESTROY = {destroy_ts} as const;\n\
         \n\
         export type SafeCommand = (typeof SAFE)[number];\n\
         export type WriteCommand = (typeof WRITE)[number];\n\
         export type DestroyCommand = (typeof DESTROY)[number];\n\
         export type KnownCommand = SafeCommand | WriteCommand | DestroyCommand;\n\
         \n\
         export type Classification = 'safe' | 'write' | 'destroy';\n\
         \n\
         // Pre-built Sets allow O(1) membership tests in classify() below.\n\
         // Constructed once at module load; do not mutate at runtime.\n\
         export const SAFE_SET: Set<string> = new Set(SAFE);\n\
         export const WRITE_SET: Set<string> = new Set(WRITE);\n\
         export const DESTROY_SET: Set<string> = new Set(DESTROY);\n\
         \n\
         export function classify(cmd: string): Classification | null {{\n\
         \x20 if (SAFE_SET.has(cmd)) return 'safe';\n\
         \x20 if (WRITE_SET.has(cmd)) return 'write';\n\
         \x20 if (DESTROY_SET.has(cmd)) return 'destroy';\n\
         \x20 return null;\n\
         }}\n"
    )
}

/// Format a slice of strings as a TypeScript string-literal array, e.g. `["a", "b"]`.
fn ts_array(items: &[String]) -> String {
    let inner: Vec<String> = items.iter().map(|s| format!("\"{s}\"")).collect();
    format!("[{}]", inner.join(", "))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_safe_array_from_taxonomy_source() {
        let source = r#"
pub const SAFE: &[&str] = &["next", "review", "remember", "promote"];
pub const WRITE: &[&str] = &["request", "prd"];
pub const DESTROY: &[&str] = &["archive"];
"#;
        let safe = parse_const_array(source, "SAFE");
        assert!(safe.is_some(), "SAFE array must parse");
        let safe = safe.unwrap();
        assert_eq!(safe, vec!["next", "review", "remember", "promote"]);
    }

    #[test]
    fn parse_write_array_from_taxonomy_source() {
        let source = r#"
pub const SAFE: &[&str] = &["next"];
pub const WRITE: &[&str] = &["request", "prd", "tech"];
pub const DESTROY: &[&str] = &["archive"];
"#;
        let write = parse_const_array(source, "WRITE");
        assert!(write.is_some(), "WRITE array must parse");
        let write = write.unwrap();
        assert_eq!(write, vec!["request", "prd", "tech"]);
    }

    #[test]
    fn parse_destroy_array_with_hyphen_names() {
        let source = r#"
pub const SAFE: &[&str] = &["next"];
pub const WRITE: &[&str] = &["prd"];
pub const DESTROY: &[&str] = &["archive", "update-req", "update-tech"];
"#;
        let destroy = parse_const_array(source, "DESTROY");
        assert!(destroy.is_some(), "DESTROY array must parse");
        let destroy = destroy.unwrap();
        assert_eq!(destroy, vec!["archive", "update-req", "update-tech"]);
    }

    #[test]
    fn parse_missing_const_returns_none() {
        let source = "pub const SAFE: &[&str] = &[\"next\"];";
        assert!(parse_const_array(source, "WRITE").is_none());
    }

    #[test]
    fn render_ts_output_contains_export_const() {
        let ts = render_ts(&["a".into()], &["b".into()], &["c".into()]);
        assert!(ts.contains("export const SAFE = [\"a\"] as const;"));
        assert!(ts.contains("export const WRITE = [\"b\"] as const;"));
        assert!(ts.contains("export const DESTROY = [\"c\"] as const;"));
    }

    /// classify() in the generated TS must use Set.has() (O(1)) not Array.includes() (O(n)).
    #[test]
    fn render_ts_classify_uses_set_has_not_array_includes() {
        let ts = render_ts(&["a".into()], &["b".into()], &["c".into()]);
        // Set constants must be exported.
        assert!(ts.contains("export const SAFE_SET: Set<string> = new Set(SAFE);"),
            "SAFE_SET not found in generated TS");
        assert!(ts.contains("export const WRITE_SET: Set<string> = new Set(WRITE);"),
            "WRITE_SET not found in generated TS");
        assert!(ts.contains("export const DESTROY_SET: Set<string> = new Set(DESTROY);"),
            "DESTROY_SET not found in generated TS");
        // classify() must use .has() not .includes().
        assert!(ts.contains("SAFE_SET.has(cmd)"), "classify must use SAFE_SET.has");
        assert!(ts.contains("WRITE_SET.has(cmd)"), "classify must use WRITE_SET.has");
        assert!(ts.contains("DESTROY_SET.has(cmd)"), "classify must use DESTROY_SET.has");
        // No Array.includes() usage left in classify.
        assert!(!ts.contains(".includes(cmd)"),
            "classify must not use Array.includes() — O(n) per call");
    }

    #[test]
    fn ts_array_formats_correctly() {
        let items = vec!["foo".to_string(), "bar".to_string()];
        assert_eq!(ts_array(&items), r#"["foo", "bar"]"#);
    }
}

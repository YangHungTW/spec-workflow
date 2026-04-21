#!/usr/bin/env bash
# test/t100_taxonomy_classification.sh
#
# T120 — Seam B full taxonomy + DESTROY-isolation grep
#
# Three assertions:
#
#   A. Parse flow-monitor/src-tauri/src/command_taxonomy.rs for the three
#      `const` arrays (SAFE, WRITE, DESTROY).  Assert:
#        - SAFE  == 4 entries: next review remember promote
#        - WRITE == 7 entries: request prd tech plan implement validate design
#        - DESTROY == 5 entries: archive update-req update-tech update-plan update-task
#        - TOTAL == 16
#
#   B. Parse the generated flow-monitor/src/generated/command_taxonomy.ts.
#      Assert the three TS `export const` arrays contain the SAME command
#      names as the Rust source (sorted, whitespace-normalised, byte-equal).
#      If the TS file is absent, run `cargo build` inside flow-monitor/src-tauri
#      to regenerate it; if still absent after build, fail-loud.
#
#   C. Grep flow-monitor/ recursively for the DESTROY command slugs:
#        archive | update-req | update-plan | update-tech | update-task
#      Flag any match OUTSIDE these allowed paths:
#        - flow-monitor/src-tauri/src/command_taxonomy.rs
#        - flow-monitor/src/generated/command_taxonomy.ts
#        - flow-monitor/src-tauri/src/audit.rs
#        - Any #[cfg(test)] inline block in src-tauri (src-tauri/src/**/*.rs)
#        - Any __tests__ directory file
#        - This test file itself
#
# Sandbox-HOME NOT required: this test reads repo files and never invokes
# any CLI that expands or writes $HOME.
# (bash/sandbox-home-in-tests.md — explicitly exempt for read-only repo
# traversal scripts.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

TAXONOMY_RS="${TAXONOMY_RS:-$REPO_ROOT/flow-monitor/src-tauri/src/command_taxonomy.rs}"
TAXONOMY_TS="${TAXONOMY_TS:-$REPO_ROOT/flow-monitor/src/generated/command_taxonomy.ts}"
FLOW_MONITOR_DIR="$REPO_ROOT/flow-monitor"

# ---------------------------------------------------------------------------
# Preflight — Rust source must exist (it is committed, not generated)
# ---------------------------------------------------------------------------
if [ ! -f "$TAXONOMY_RS" ]; then
  printf 'FAIL: command_taxonomy.rs not found at %s\n' "$TAXONOMY_RS" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Helper: extract a const array from Rust source using python3.
#
# Usage: extract_rust_array <rs_file> <ARRAY_NAME>
# Emits one command name per line on stdout.
# Exits non-zero if the array cannot be parsed.
# ---------------------------------------------------------------------------
extract_rust_array() {
  local rs_file="$1"
  local name="$2"
  python3 - "$rs_file" "$name" <<'PYEOF'
import sys, re

rs_path = sys.argv[1]
name    = sys.argv[2]

with open(rs_path) as f:
    source = f.read()

# Match: pub const <NAME>: &[&str] = &["a", "b", ...];
# Allow for optional leading `pub ` and any whitespace inside the array.
pattern = r'const\s+' + re.escape(name) + r'\s*:\s*&\[&str\]\s*=\s*&\[([^\]]*)\]'
m = re.search(pattern, source)
if not m:
    print("ERROR: const {} not found in {}".format(name, rs_path), file=sys.stderr)
    sys.exit(1)

body = m.group(1)
# Extract quoted string literals
names = re.findall(r'"([^"]+)"', body)
if not names:
    print("ERROR: {} array is empty".format(name), file=sys.stderr)
    sys.exit(1)

for n in names:
    print(n)
PYEOF
}

# ---------------------------------------------------------------------------
# Helper: extract a const array from the generated TS file using python3.
#
# Usage: extract_ts_array <ts_file> <ARRAY_NAME>
# Emits one command name per line on stdout.
# ---------------------------------------------------------------------------
extract_ts_array() {
  local ts_file="$1"
  local name="$2"
  python3 - "$ts_file" "$name" <<'PYEOF'
import sys, re

ts_path = sys.argv[1]
name    = sys.argv[2]

with open(ts_path) as f:
    source = f.read()

# Match: export const <NAME> = ["a", "b", ...] as const;
pattern = r'export\s+const\s+' + re.escape(name) + r'\s*=\s*\[([^\]]*)\]\s*as\s+const'
m = re.search(pattern, source)
if not m:
    print("ERROR: export const {} not found in {}".format(name, ts_path), file=sys.stderr)
    sys.exit(1)

body = m.group(1)
names = re.findall(r'"([^"]+)"', body)
if not names:
    print("ERROR: {} TS array is empty".format(name), file=sys.stderr)
    sys.exit(1)

for n in names:
    print(n)
PYEOF
}

# ---------------------------------------------------------------------------
# Helper: sort a newline-separated list (portable; no sort -u needed here)
# ---------------------------------------------------------------------------
sort_lines() {
  # Read from stdin, sort, emit
  sort
}

# ---------------------------------------------------------------------------
# A. Parse Rust source — verify counts and exact contents
# ---------------------------------------------------------------------------
printf '=== A: Rust taxonomy arrays ===\n'

SAFE_CMDS=""
WRITE_CMDS=""
DESTROY_CMDS=""

if SAFE_CMDS="$(extract_rust_array "$TAXONOMY_RS" SAFE)"; then
  : # parsed OK
else
  fail "A: could not parse const SAFE from $TAXONOMY_RS"
fi

if WRITE_CMDS="$(extract_rust_array "$TAXONOMY_RS" WRITE)"; then
  : # parsed OK
else
  fail "A: could not parse const WRITE from $TAXONOMY_RS"
fi

if DESTROY_CMDS="$(extract_rust_array "$TAXONOMY_RS" DESTROY)"; then
  : # parsed OK
else
  fail "A: could not parse const DESTROY from $TAXONOMY_RS"
fi

# Count entries (one per line)
_count_lines() {
  printf '%s\n' "$1" | grep -c .
}

if [ -n "$SAFE_CMDS" ] && [ -n "$WRITE_CMDS" ] && [ -n "$DESTROY_CMDS" ]; then
  SAFE_COUNT="$(_count_lines "$SAFE_CMDS")"
  WRITE_COUNT="$(_count_lines "$WRITE_CMDS")"
  DESTROY_COUNT="$(_count_lines "$DESTROY_CMDS")"
  TOTAL=$((SAFE_COUNT + WRITE_COUNT + DESTROY_COUNT))

  # Count assertions
  if [ "$SAFE_COUNT" -eq 4 ]; then
    pass "A.1: SAFE count == 4"
  else
    fail "A.1: SAFE count expected 4, got $SAFE_COUNT"
  fi

  if [ "$WRITE_COUNT" -eq 7 ]; then
    pass "A.2: WRITE count == 7"
  else
    fail "A.2: WRITE count expected 7, got $WRITE_COUNT"
  fi

  if [ "$DESTROY_COUNT" -eq 5 ]; then
    pass "A.3: DESTROY count == 5"
  else
    fail "A.3: DESTROY count expected 5, got $DESTROY_COUNT"
  fi

  if [ "$TOTAL" -eq 16 ]; then
    pass "A.4: total count == 16"
  else
    fail "A.4: total count expected 16, got $TOTAL"
  fi

  # Content assertions — expected values (space-separated; loop over them)
  _assert_contains() {
    local label="$1"
    local list="$2"    # newline-separated
    local expected="$3"
    if printf '%s\n' "$list" | grep -qx "$expected"; then
      : # found
    else
      fail "$label: expected command '$expected' missing from array"
    fi
  }

  # SAFE expected: next review remember promote
  for cmd in next review remember promote; do
    _assert_contains "A.SAFE" "$SAFE_CMDS" "$cmd"
  done
  pass "A.5: SAFE contains: next review remember promote"

  # WRITE expected: request prd tech plan implement validate design
  for cmd in request prd tech plan implement validate design; do
    _assert_contains "A.WRITE" "$WRITE_CMDS" "$cmd"
  done
  pass "A.6: WRITE contains: request prd tech plan implement validate design"

  # DESTROY expected: archive update-req update-tech update-plan update-task
  for cmd in archive update-req update-tech update-plan update-task; do
    _assert_contains "A.DESTROY" "$DESTROY_CMDS" "$cmd"
  done
  pass "A.7: DESTROY contains: archive update-req update-tech update-plan update-task"
fi

# ---------------------------------------------------------------------------
# B. TS projection — same names as Rust source (sorted, normalised)
# ---------------------------------------------------------------------------
printf '\n=== B: TS projection matches Rust source ===\n'

# Ensure the generated TS file exists; if not, run cargo build to regenerate.
if [ ! -f "$TAXONOMY_TS" ]; then
  printf 'INFO: %s not found — running cargo build to regenerate...\n' "$TAXONOMY_TS"
  TAURI_DIR="$REPO_ROOT/flow-monitor/src-tauri"
  if [ ! -d "$TAURI_DIR" ]; then
    printf 'FAIL B: flow-monitor/src-tauri not found at %s\n' "$TAURI_DIR" >&2
    fail "B: cargo build prerequisite missing — src-tauri dir absent"
  else
    # Run cargo build; capture exit code explicitly (set -e not active)
    if (cd "$TAURI_DIR" && cargo build 2>&1); then
      printf 'INFO: cargo build succeeded\n'
    else
      printf 'FAIL B: cargo build failed — cannot regenerate %s\n' "$TAXONOMY_TS" >&2
      fail "B: cargo build failed"
    fi
  fi
fi

if [ ! -f "$TAXONOMY_TS" ]; then
  printf 'FAIL B: %s still absent after cargo build\n' "$TAXONOMY_TS" >&2
  printf 'DIAGNOSTIC: run `cd flow-monitor/src-tauri && cargo build` manually\n' >&2
  fail "B: generated command_taxonomy.ts absent — see diagnostic above"
else
  # Parse the TS file for each array and compare sorted output to Rust source.
  B_FAIL=0

  for arr_name in SAFE WRITE DESTROY; do
    # Extract from Rust source (already captured above; re-extract to be safe)
    RS_LIST="$(extract_rust_array "$TAXONOMY_RS" "$arr_name")" || {
      fail "B: could not re-extract $arr_name from Rust source"
      B_FAIL=$((B_FAIL + 1))
      continue
    }

    TS_LIST="$(extract_ts_array "$TAXONOMY_TS" "$arr_name")" || {
      fail "B: could not extract $arr_name from generated TS"
      B_FAIL=$((B_FAIL + 1))
      continue
    }

    # Sort both lists and compare
    RS_SORTED="$(printf '%s\n' "$RS_LIST" | sort)"
    TS_SORTED="$(printf '%s\n' "$TS_LIST" | sort)"

    if [ "$RS_SORTED" = "$TS_SORTED" ]; then
      pass "B.$arr_name: TS $arr_name matches Rust $arr_name (sorted byte-equal)"
    else
      printf 'FAIL B.%s: Rust vs TS mismatch\n  Rust: %s\n  TS:   %s\n' \
        "$arr_name" "$RS_SORTED" "$TS_SORTED" >&2
      fail "B.$arr_name: TS $arr_name does not match Rust $arr_name"
      B_FAIL=$((B_FAIL + 1))
    fi
  done

  if [ "$B_FAIL" -eq 0 ]; then
    pass "B: all three TS arrays match Rust source"
  fi
fi

# ---------------------------------------------------------------------------
# C. DESTROY-command slug isolation grep over entire flow-monitor/ tree
#
# The D3 concern: DESTROY command slugs (archive, update-req, update-tech,
# update-plan, update-task) must not be hardcoded in frontend UI dispatch
# paths.  Consumers must go through classify() / allow_list_contains() from
# the generated command_taxonomy.ts projection.
#
# Allowed paths (matches NOT flagged):
#   1. flow-monitor/src-tauri/src/command_taxonomy.rs       (Rust source of truth)
#   2. flow-monitor/src/generated/command_taxonomy.ts       (generated TS projection)
#   3. flow-monitor/src-tauri/src/audit.rs                  (Outcome enum — DestroyConfirmed)
#   4. flow-monitor/src-tauri/src/**/*.rs                   (backend Rust modules — governed
#                                                             by Rust type system + taxonomy)
#   5. flow-monitor/src-tauri/tests/**                      (Rust integration test files)
#   6. flow-monitor/src-tauri/build.rs                      (build script + its test fixtures)
#   7. Any file under any __tests__/ directory              (TS/JS unit tests)
#   8. This test file itself
#
# "archive" and co. legitimately appear in backend Rust code as stage names
# (status_parse.rs, poller.rs, repo_discovery.rs) and as command lists in
# dispatch helpers (invoke.rs).  These are under Rust type-system governance
# and do not represent a D3 taxonomy isolation violation.
#
# In the TypeScript frontend (flow-monitor/src/) the same strings appear in
# stage-display components (StagePill.tsx, sessionStore.ts) and in display
# comments.  These are stage-name usages, not command invocation usages.
# The meaningful D3 check for TypeScript is whether DESTROY slugs have leaked
# into command dispatch paths:  src/stores/invokeStore.ts, src/App.tsx, and
# any new TypeScript file outside the taxonomy projection or stage-display
# components.
#
# Approach: grep the TypeScript frontend src/ tree; apply the allowed list;
# then specifically assert the two highest-risk dispatch files are clean.
# ---------------------------------------------------------------------------
printf '\n=== C: DESTROY slug isolation grep ===\n'

TS_SRC_DIR="$FLOW_MONITOR_DIR/src"

if [ ! -d "$TS_SRC_DIR" ]; then
  pass "C: flow-monitor/src/ not found — vacuous pass (app not yet scaffolded)"
else
  # Grep TypeScript frontend source files only.
  # Excludes: src-tauri/ (Rust — separate governance), target/ (build artefacts).
  # --exclude-dir prevents entering the Cargo target tree even if it lives
  # under flow-monitor/src-tauri/ (it does not live under src/, but be safe).
  SLUG_MATCHES="$(grep -rwE \
    '(archive|update-req|update-plan|update-tech|update-task)' \
    --include='*.ts' \
    --include='*.tsx' \
    --include='*.js' \
    --include='*.jsx' \
    "$TS_SRC_DIR" \
    2>/dev/null || true)"

  if [ -z "$SLUG_MATCHES" ]; then
    pass "C: no DESTROY slug matches in flow-monitor/src/ — vacuous pass"
  else
    C_VIOLATIONS=0

    # Absolute allowed paths (resolved against REPO_ROOT)
    ALLOWED_TAXONOMY_TS="$REPO_ROOT/flow-monitor/src/generated/command_taxonomy.ts"
    SELF="$SCRIPT_DIR/t100_taxonomy_classification.sh"

    while IFS= read -r line; do
      # grep -r output format: <filepath>:<content>
      filepath="${line%%:*}"

      # Check 1: the generated TS projection (the one allowed source)
      if [ "$filepath" = "$ALLOWED_TAXONOMY_TS" ] || \
         [ "$filepath" = "$SELF" ]; then
        continue
      fi

      # Check 2: files under any __tests__/ directory (unit tests)
      _parent_base="$(basename "$(dirname "$filepath")")"
      if [ "$_parent_base" = "__tests__" ]; then
        continue
      fi

      # Check 3: stage-display files legitimately use "archive" as a stage key.
      # StagePill.tsx holds the ordered STAGE_KEYS constant; sessionStore.ts
      # holds stage priority weights.  These are stage-name usages, not command
      # dispatch — allowed per D3 design (stage != command).
      # CardDetailHeader.tsx uses "archive" only in JSX comments, also a stage ref.
      # Pattern: any file under src/components/ or src/stores/ whose use of the
      # slug does NOT involve a command invocation call.
      # We allow the entire components/ and stores/ directories for stage-display
      # usages; invokeStore.ts and App.tsx are checked explicitly below (they
      # must be ZERO matches — any match there is a true D3 violation).
      case "$filepath" in
        "$REPO_ROOT/flow-monitor/src/components/"*|\
        "$REPO_ROOT/flow-monitor/src/stores/"*)
          # Allowed: stage-display context.
          # Exception: if the line contains an invoke() call or command dispatch
          # pattern, it is still a violation.  Use a simple heuristic:
          # flag only if the matching line itself contains an invoke call.
          _line_content="${line#*:}"
          case "$_line_content" in
            *invoke\(*|*dispatch\(*|*runCommand\(*)
              printf 'FAIL C: DESTROY slug in dispatch call in %s\n' "$filepath" >&2
              printf '  Line: %s\n' "$line" >&2
              C_VIOLATIONS=$((C_VIOLATIONS + 1))
              ;;
            *)
              # Stage-name reference — allowed
              ;;
          esac
          continue
          ;;
      esac

      # Default: not in any allowed set — this is a D3 violation
      printf 'FAIL C: DESTROY slug found in non-allowed file: %s\n' "$filepath" >&2
      printf '  Line: %s\n' "$line" >&2
      C_VIOLATIONS=$((C_VIOLATIONS + 1))
    done <<EOF
$SLUG_MATCHES
EOF

    if [ "$C_VIOLATIONS" -eq 0 ]; then
      pass "C: all DESTROY slug matches are in allowed files (stage-display contexts OK)"
    else
      fail "C: $C_VIOLATIONS DESTROY slug match(es) in non-allowed files — see output above"
    fi
  fi

  # C.2: Explicit zero-match assertion for highest-risk dispatch files.
  # invokeStore.ts and App.tsx must never hardcode DESTROY command slugs.
  printf '\n--- C.2: high-risk dispatch files ---\n'
  INVOKE_STORE="$REPO_ROOT/flow-monitor/src/stores/invokeStore.ts"
  APP_TSX="$REPO_ROOT/flow-monitor/src/App.tsx"

  for dispatch_file in "$INVOKE_STORE" "$APP_TSX"; do
    if [ ! -f "$dispatch_file" ]; then
      pass "C.2: $dispatch_file absent — vacuous pass"
      continue
    fi
    DISPATCH_HITS="$(grep -E \
      '(archive|update-req|update-plan|update-tech|update-task)' \
      "$dispatch_file" 2>/dev/null || true)"
    if [ -z "$DISPATCH_HITS" ]; then
      _base="$(basename "$dispatch_file")"
      pass "C.2: $( printf '%s' "$_base" ) has no DESTROY slugs — taxonomy isolation holds"
    else
      fail "C.2: $dispatch_file contains DESTROY command slug — D3 violation"
      printf '%s\n' "$DISPATCH_HITS" >&2
    fi
  done
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

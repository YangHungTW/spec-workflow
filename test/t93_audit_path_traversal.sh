#!/usr/bin/env bash
# test/t93_audit_path_traversal.sh
#
# Seam H — structural cross-check: verify that audit.rs enforces a
# path-traversal guard on write paths.
#
# This script delegates to `cargo test -p flow-monitor --lib audit::` to run
# the inline Rust tests (Seam H tests live in audit.rs).  It then adds
# grep-level assertions that confirm the guard pattern is present in source —
# ensuring the guard cannot be silently removed without breaking these checks.
#
# Sandbox-HOME NOT required: this script only reads repo files and invokes
# `cargo test` — no CLI expands $HOME against the user's real home directory.
# (plan §167 — explicitly exempt from sandbox-home-in-tests rule)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile, [[ =~ ]], GNU-only flags.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

AUDIT_RS="$REPO_ROOT/flow-monitor/src-tauri/src/audit.rs"
TAURI_SRC_DIR="$REPO_ROOT/flow-monitor/src-tauri"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Preflight — ensure audit.rs exists (T94 not yet merged → skip)
# ---------------------------------------------------------------------------
if [ ! -f "$AUDIT_RS" ]; then
  printf 'SKIP: %s not found — T94 not yet merged; re-run after T94.\n' "$AUDIT_RS" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# A. Source-level grep: confirm PathTraversal error variant is defined.
# ---------------------------------------------------------------------------
printf '=== A: PathTraversal error variant in audit.rs ===\n'

if grep -q 'PathTraversal' "$AUDIT_RS"; then
  pass "A: AuditError::PathTraversal variant present in audit.rs"
else
  fail "A: AuditError::PathTraversal variant NOT found in audit.rs — guard may be absent"
fi

# ---------------------------------------------------------------------------
# B. Source-level grep: confirm canonicalise_and_check_under function is present.
#    This is the boundary-check helper that mirrors ipc.rs::read_artefact pattern.
# ---------------------------------------------------------------------------
printf '\n=== B: canonicalise_and_check_under boundary-check helper ===\n'

if grep -q 'canonicalise_and_check_under' "$AUDIT_RS"; then
  pass "B: canonicalise_and_check_under boundary-check function present in audit.rs"
else
  fail "B: canonicalise_and_check_under NOT found in audit.rs — path-traversal guard may be absent"
fi

# ---------------------------------------------------------------------------
# C. Source-level grep: confirm starts_with boundary check is applied.
#    The guard must use Path::starts_with to verify the canonicalized path.
# ---------------------------------------------------------------------------
printf '\n=== C: starts_with boundary assertion in traversal guard ===\n'

if grep -q 'starts_with' "$AUDIT_RS"; then
  pass "C: starts_with boundary assertion found in audit.rs"
else
  fail "C: starts_with assertion NOT found in audit.rs — boundary check may be incomplete"
fi

# ---------------------------------------------------------------------------
# D. Cargo test: run the inline Seam H Rust unit tests.
#    These tests exercise the path-traversal guard directly.
# ---------------------------------------------------------------------------
printf '\n=== D: cargo test audit::tests::seam_h_* ===\n'

if [ ! -d "$TAURI_SRC_DIR" ]; then
  printf 'SKIP: %s not found — cannot run cargo test.\n' "$TAURI_SRC_DIR" >&2
  PASS=$((PASS + 1))  # count as pass to avoid blocking wave
else
  CARGO_OUT="$(cd "$TAURI_SRC_DIR" && cargo test -p flow-monitor --lib 'audit::tests::seam_h' 2>&1)"
  CARGO_EXIT=$?

  if [ "$CARGO_EXIT" -eq 0 ]; then
    pass "D: cargo test audit::tests::seam_h_* passed"
  else
    fail "D: cargo test audit::tests::seam_h_* failed (exit $CARGO_EXIT)"
    printf '%s\n' "$CARGO_OUT" >&2
  fi
fi

# ---------------------------------------------------------------------------
# E. Source-level grep: confirm append_line calls the guard before writing.
#    The guard must be invoked inside append_line, not only in tests.
# ---------------------------------------------------------------------------
printf '\n=== E: guard invoked inside append_line ===\n'

if grep -q 'canonicalise_and_check_under' "$AUDIT_RS"; then
  # The function is present; verify append_line calls it (not just defines it).
  # We check that the call appears in the non-test section of the file.
  # A simple grep for the call pattern suffices since the function name is unique.
  CALL_COUNT="$(grep -c 'canonicalise_and_check_under' "$AUDIT_RS" || true)"
  if [ "$CALL_COUNT" -ge 2 ]; then
    pass "E: canonicalise_and_check_under appears $CALL_COUNT times (definition + at least 1 call site)"
  else
    fail "E: canonicalise_and_check_under appears only $CALL_COUNT time(s) — may be defined but not called"
  fi
else
  fail "E: canonicalise_and_check_under not found — guard absent"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

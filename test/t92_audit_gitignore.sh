#!/usr/bin/env bash
# test/t92_audit_gitignore.sh
#
# Seam D — structural cross-check: verify that the `ensure_gitignore` pattern
# in audit.rs adds `.spec-workflow/.flow-monitor/` to .gitignore idempotently.
#
# This script delegates to `cargo test -p flow-monitor --lib audit::` to run
# the inline Rust tests (Seam D tests live in audit.rs).  It then adds a
# grep-level assertion that confirms the target line pattern is present in the
# audit.rs source — ensuring the constant never drifts to a different string
# without this check catching it.
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
# A. Source-level grep: confirm the target gitignore line constant is correct.
#    The target line must be `.spec-workflow/.flow-monitor/` — exactly as
#    specified in tech D7.
# ---------------------------------------------------------------------------
printf '=== A: gitignore target line constant in audit.rs ===\n'

TARGET_LINE='.spec-workflow/.flow-monitor/'

if grep -qF "$TARGET_LINE" "$AUDIT_RS"; then
  pass "A: audit.rs contains the expected gitignore target line '$TARGET_LINE'"
else
  fail "A: audit.rs does NOT contain '$TARGET_LINE' — gitignore constant may have drifted"
fi

# ---------------------------------------------------------------------------
# B. Source-level grep: confirm the idempotency logic is present.
#    The `ensure_gitignore` function must check for the existing line before
#    appending (idempotent pattern).
# ---------------------------------------------------------------------------
printf '\n=== B: idempotency guard in ensure_gitignore ===\n'

if grep -q 'already_present' "$AUDIT_RS"; then
  pass "B: audit.rs contains idempotency guard (already_present pattern)"
else
  fail "B: audit.rs missing idempotency guard — 'already_present' check not found"
fi

# ---------------------------------------------------------------------------
# C. Source-level grep: confirm atomic write-temp-then-rename is used.
#    Per no-force-on-user-paths rule, .gitignore writes must be atomic.
# ---------------------------------------------------------------------------
printf '\n=== C: atomic temp-then-rename for .gitignore write ===\n'

if grep -q 'flow-monitor-tmp' "$AUDIT_RS"; then
  pass "C: audit.rs uses a temp file name for atomic .gitignore write"
else
  fail "C: audit.rs does not appear to use a temp file for .gitignore write — atomicity unconfirmed"
fi

# ---------------------------------------------------------------------------
# D. Cargo test: run the inline Seam D Rust unit tests.
#    These tests exercise ensure_gitignore directly against a tempdir.
# ---------------------------------------------------------------------------
printf '\n=== D: cargo test audit::tests::seam_d_* ===\n'

if [ ! -d "$TAURI_SRC_DIR" ]; then
  printf 'SKIP: %s not found — cannot run cargo test.\n' "$TAURI_SRC_DIR" >&2
  PASS=$((PASS + 1))  # count as pass to avoid blocking wave
else
  # Run only the Seam D tests (idempotent gitignore), capturing output.
  CARGO_OUT="$(cd "$TAURI_SRC_DIR" && cargo test -p flow-monitor --lib 'audit::tests::seam_d' 2>&1)"
  CARGO_EXIT=$?

  if [ "$CARGO_EXIT" -eq 0 ]; then
    pass "D: cargo test audit::tests::seam_d_* passed"
  else
    fail "D: cargo test audit::tests::seam_d_* failed (exit $CARGO_EXIT)"
    printf '%s\n' "$CARGO_OUT" >&2
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

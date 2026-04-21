#!/usr/bin/env bash
# test/t2_flag_parsing.sh — T2 verify checks for flag parsing
# Usage: bash test/t2_flag_parsing.sh
# Exits 0 iff all checks pass; non-zero otherwise.

set -u -o pipefail

SCRIPT="/Users/yanghungtw/Tools/specaffold/bin/claude-symlink"
PASS=0
FAIL=0

assert_exit() {
  local description="$1"
  local expected_exit="$2"
  shift 2
  "$@"
  local actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "PASS: $description (exit $actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — expected exit $expected_exit, got $actual_exit"
    FAIL=$((FAIL + 1))
  fi
}

assert_stdout_contains() {
  local description="$1"
  local pattern="$2"
  shift 2
  local output
  output=$("$@" 2>/dev/null)
  if echo "$output" | grep -q "$pattern"; then
    echo "PASS: $description (found: $pattern)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — pattern '$pattern' not found in stdout"
    echo "  stdout was: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_stderr_contains() {
  local description="$1"
  local pattern="$2"
  shift 2
  local err_output
  err_output=$("$@" 2>&1 >/dev/null)
  if echo "$err_output" | grep -q "$pattern"; then
    echo "PASS: $description (found: $pattern)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — pattern '$pattern' not found in stderr"
    echo "  stderr was: $err_output"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== T2 Flag Parsing Tests ==="
echo

# T2 Verify 1: --help exits 0 and prints usage including all 3 subcommands and --dry-run
assert_exit    "1a. --help exits 0"                    0  "$SCRIPT" --help
assert_stdout_contains "1b. --help mentions install"     "install"   "$SCRIPT" --help
assert_stdout_contains "1c. --help mentions uninstall"   "uninstall" "$SCRIPT" --help
assert_stdout_contains "1d. --help mentions update"      "update"    "$SCRIPT" --help
assert_stdout_contains "1e. --help mentions --dry-run"   "\-\-dry-run" "$SCRIPT" --help

# T2 Verify 2: install --dry-run exits 0 and echoes dry-run=1
assert_exit           "2a. install --dry-run exits 0"           0  "$SCRIPT" install --dry-run
assert_stdout_contains "2b. install --dry-run echoes dry-run=1"  "dry-run=1"  "$SCRIPT" install --dry-run

# T2 Verify 3: --dry-run install exits 0 and echoes dry-run=1 (flag before subcommand)
assert_exit           "3a. --dry-run install exits 0"           0  "$SCRIPT" --dry-run install
assert_stdout_contains "3b. --dry-run install echoes dry-run=1"  "dry-run=1"  "$SCRIPT" --dry-run install

# T2 Verify 4: install --force exits 2 with "unknown flag" on stderr
assert_exit           "4a. install --force exits 2"             2  "$SCRIPT" install --force
assert_stderr_contains "4b. install --force says unknown flag"   "unknown flag"  "$SCRIPT" install --force

# T1 regression: no args → exit 2
assert_exit "R1. no args → exit 2" 2 "$SCRIPT"

# T1 regression: install without --dry-run still works (exits 0)
assert_exit "R2. install exits 0" 0 "$SCRIPT" install

# T1 regression: install still prints stub: install
assert_stdout_contains "R3. install prints stub: install" "stub: install" "$SCRIPT" install

# T2 new: install (no flags) prints dry-run=0
assert_stdout_contains "R4. install prints dry-run=0" "dry-run=0" "$SCRIPT" install

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

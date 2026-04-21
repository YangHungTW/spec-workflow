#!/usr/bin/env bash
# test/t3_resolve_path.sh — T3 verify checks for resolve_path, resolve_repo_root, die, __probe
# Usage: bash test/t3_resolve_path.sh
# Exits 0 iff all checks pass; non-zero otherwise.

set -u -o pipefail

WORKTREE="/Users/yanghungtw/Tools/specaffold/.worktrees/symlink-operation-T10"
SCRIPT="$WORKTREE/bin/claude-symlink"
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

assert_stdout_equals() {
  local description="$1"
  local expected="$2"
  shift 2
  local output
  output=$("$@" 2>/dev/null)
  if [ "$output" = "$expected" ]; then
    echo "PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description"
    echo "  expected: $expected"
    echo "  got:      $output"
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
    echo "PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — pattern '$pattern' not found in stdout"
    echo "  stdout was: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit_nonzero() {
  local description="$1"
  shift 1
  "$@"
  local actual_exit=$?
  if [ "$actual_exit" -ne 0 ]; then
    echo "PASS: $description (exit $actual_exit, non-zero as expected)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — expected non-zero exit, got 0"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== T3 resolve_path / resolve_repo_root / die / __probe Tests ==="
echo

EXPECTED_REPO="$WORKTREE"

# T3 Verify 1: __probe from worktree prints REPO=<worktree>
assert_stdout_equals \
  "1. __probe prints REPO=<worktree>" \
  "REPO=$EXPECTED_REPO" \
  env SPECFLOW_PROBE=1 "$SCRIPT" __probe

# T3 Verify 2: __probe from different cwd prints the same REPO
actual_output=$(cd /tmp && SPECFLOW_PROBE=1 "$SCRIPT" __probe 2>/dev/null)
expected_output="REPO=$EXPECTED_REPO"
if [ "$actual_output" = "$expected_output" ]; then
  echo "PASS: 2. __probe from /tmp cwd prints same REPO"
  PASS=$((PASS + 1))
else
  echo "FAIL: 2. __probe from /tmp cwd"
  echo "  expected: $expected_output"
  echo "  got:      $actual_output"
  FAIL=$((FAIL + 1))
fi

# T3 Verify 3: __probe via symlink still prints worktree REPO (not /tmp)
ln -sfn "$SCRIPT" /tmp/cs-link
actual_output=$(SPECFLOW_PROBE=1 /tmp/cs-link __probe 2>/dev/null)
if [ "$actual_output" = "$expected_output" ]; then
  echo "PASS: 3. __probe via symlink prints correct REPO"
  PASS=$((PASS + 1))
else
  echo "FAIL: 3. __probe via symlink"
  echo "  expected: $expected_output"
  echo "  got:      $actual_output"
  FAIL=$((FAIL + 1))
fi
rm -f /tmp/cs-link

# T3 Verify 4: cycle detection — resolve_path exits non-zero on A->B->A
ln -sfn /tmp/cycle_B /tmp/cycle_A 2>/dev/null || true
ln -sfn /tmp/cycle_A /tmp/cycle_B 2>/dev/null || true

# Use __probe resolve subcommand to test cycle detection
# (Script must implement __probe resolve <path> for this check)
assert_exit_nonzero \
  "4. cycle detection: __probe resolve A->B->A exits non-zero" \
  env SPECFLOW_PROBE=1 "$SCRIPT" __probe resolve /tmp/cycle_A

rm -f /tmp/cycle_A /tmp/cycle_B

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

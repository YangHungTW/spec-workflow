#!/usr/bin/env bash
# test/t7_cmd_install.sh — T7 verify checks for cmd_install
# Usage: bash test/t7_cmd_install.sh
# Exits 0 iff all 4 scenarios pass; non-zero otherwise.
#
# Scenario A: Clean install exits 0; every managed target is a symlink
#             with absolute path starting with the repo root (AC10).
# Scenario B: Second install → all verbs are "already"; exit 0; filesystem
#             byte-identical between runs.
# Scenario C: Pre-placed real file at $HOME/.claude/agents/specflow →
#             skipped:real-file for that path; other links still created; exit 1.
# Scenario D: install --dry-run on clean sandbox → every verb is "would-create";
#             zero symlinks on disk afterward (AC9 subset).

set -u -o pipefail

WORKTREE="/Users/yanghungtw/Tools/spec-workflow/.worktrees/symlink-operation-T10"
SCRIPT="$WORKTREE/bin/claude-symlink"
REPO="$WORKTREE"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Preflight: script must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$SCRIPT" ]; then
  echo "ABORT: script not found or not executable: $SCRIPT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Preflight: refuse to run against the real $HOME
# ---------------------------------------------------------------------------
REAL_HOME=$(cd ~ && pwd -P 2>/dev/null || echo "$HOME")

# We create a top-level sandbox and each scenario gets its own sub-sandbox
TOP_SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink-t7')

trap 'rm -rf "$TOP_SANDBOX"' EXIT

echo "=== T7 cmd_install Tests ==="
echo "TOP_SANDBOX=$TOP_SANDBOX"
echo "REPO=$REPO"
echo

# ---------------------------------------------------------------------------
# Helper: fresh sandbox HOME for a scenario
# ---------------------------------------------------------------------------
make_sandbox_home() {
  local scenario_name="$1"
  local sbox="$TOP_SANDBOX/$scenario_name"
  mkdir -p "$sbox/home"
  echo "$sbox/home"
}

# ---------------------------------------------------------------------------
# Helper: record PASS/FAIL
# ---------------------------------------------------------------------------
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$desc"
  else
    fail "$desc — expected '$expected', got '$actual'"
  fi
}

assert_zero() {
  local desc="$1" val="$2"
  if [ "$val" -eq 0 ]; then
    pass "$desc"
  else
    fail "$desc — expected 0, got $val"
  fi
}

assert_nonzero() {
  local desc="$1" val="$2"
  if [ "$val" -ne 0 ]; then
    pass "$desc"
  else
    fail "$desc — expected non-zero, got $val"
  fi
}

# ---------------------------------------------------------------------------
# Helper: collect all managed targets from plan (via __probe plan)
# returns lines of tgt paths
# ---------------------------------------------------------------------------
get_plan_targets() {
  export HOME="$1"
  SPECFLOW_PROBE=1 "$SCRIPT" __probe plan 2>/dev/null | cut -f2
}

# ---------------------------------------------------------------------------
# SCENARIO A — Clean install
# ---------------------------------------------------------------------------
echo "--- Scenario A: Clean install ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_a")
  export HOME="$SANDBOX_HOME"

  # Verify HOME is sandboxed
  if [ "$HOME" = "$REAL_HOME" ]; then
    echo "ABORT: HOME matches real home — refusing to run" >&2
    exit 2
  fi

  output=$("$SCRIPT" install 2>&1)
  exit_code=$?

  assert_zero "A: exit code is 0" "$exit_code"

  # Every managed target must be a symlink
  all_symlinks=1
  all_absolute=1
  while IFS=$'\t' read -r src tgt; do
    if [ ! -L "$tgt" ]; then
      fail "A: $tgt is not a symlink"
      all_symlinks=0
    else
      # readlink should return an absolute path starting with REPO
      link_dest=$(readlink "$tgt")
      case "$link_dest" in
        "$REPO"*) ;;
        *)
          fail "A: $tgt → '$link_dest' does not start with repo root '$REPO'"
          all_absolute=0
          ;;
      esac
    fi
  done < <(SPECFLOW_PROBE=1 "$SCRIPT" __probe plan 2>/dev/null)

  [ "$all_symlinks" -eq 1 ] && pass "A: every managed target is a symlink"
  [ "$all_absolute" -eq 1 ] && pass "A: every symlink target is absolute and starts with repo root"

  # Output should contain "created" verbs and no "already"
  already_count=$(echo "$output" | grep -c '\[already\]' || true)
  created_count=$(echo "$output" | grep -c '\[created\]' || true)
  assert_zero "A: no 'already' verbs on clean install" "$already_count"
  if [ "$created_count" -gt 0 ]; then
    pass "A: has 'created' verbs"
  else
    fail "A: expected at least one 'created' verb, got none. Output: $output"
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO B — Idempotent (second install)
# ---------------------------------------------------------------------------
echo "--- Scenario B: Second install (idempotent) ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_b")
  export HOME="$SANDBOX_HOME"

  # First install
  "$SCRIPT" install > /dev/null 2>&1

  # Snapshot filesystem state before second install
  before_snapshot=$(find "$SANDBOX_HOME" -maxdepth 5 \( -type l -o -type f \) -exec ls -ld {} \; 2>/dev/null | sort)

  # Second install
  output=$("$SCRIPT" install 2>&1)
  exit_code=$?

  assert_zero "B: second install exit code is 0" "$exit_code"

  # All verbs must be "already"
  non_already=$(echo "$output" | grep '^\[' | grep -v '^\[already\]' || true)
  if [ -z "$non_already" ]; then
    pass "B: all verbs are 'already'"
  else
    fail "B: found non-'already' verbs: $non_already"
  fi

  # Filesystem must be byte-identical
  after_snapshot=$(find "$SANDBOX_HOME" -maxdepth 5 \( -type l -o -type f \) -exec ls -ld {} \; 2>/dev/null | sort)
  if [ "$before_snapshot" = "$after_snapshot" ]; then
    pass "B: filesystem byte-identical between runs"
  else
    fail "B: filesystem changed between runs"
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO C — Real-file conflict
# ---------------------------------------------------------------------------
echo "--- Scenario C: Real-file conflict at agents/specflow ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_c")
  export HOME="$SANDBOX_HOME"

  # Pre-place a real file at the agents/specflow managed target
  conflict_path="$SANDBOX_HOME/.claude/agents/specflow"
  mkdir -p "$(dirname "$conflict_path")"
  echo "user content — do not overwrite" > "$conflict_path"

  output=$("$SCRIPT" install 2>&1)
  exit_code=$?

  assert_nonzero "C: exit code is non-zero (conflict present)" "$exit_code"

  # The conflicting path must be skipped
  if echo "$output" | grep -q '\[skipped:real-file\]'; then
    pass "C: 'skipped:real-file' reported for conflict path"
  else
    fail "C: expected '[skipped:real-file]' in output. Got: $output"
  fi

  # The real file must be untouched
  if [ -f "$conflict_path" ] && [ ! -L "$conflict_path" ]; then
    pass "C: real file is untouched"
  else
    fail "C: real file was modified or removed"
  fi

  # Content intact
  content=$(cat "$conflict_path")
  assert_eq "C: real file content intact" "user content — do not overwrite" "$content"

  # Other links (commands/specflow) must still be created
  commands_link="$SANDBOX_HOME/.claude/commands/specflow"
  if [ -L "$commands_link" ]; then
    pass "C: other links (commands/specflow) still created despite conflict"
  else
    fail "C: commands/specflow was not created — install should continue past conflicts"
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO D — dry-run on clean sandbox
# ---------------------------------------------------------------------------
echo "--- Scenario D: dry-run on clean sandbox ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_d")
  export HOME="$SANDBOX_HOME"

  output=$("$SCRIPT" install --dry-run 2>&1)
  exit_code=$?

  assert_zero "D: dry-run exit code is 0" "$exit_code"

  # All verbs must be "would-create"
  non_would_create=$(echo "$output" | grep '^\[' | grep -v '^\[would-create\]' || true)
  if [ -z "$non_would_create" ]; then
    pass "D: all verbs are 'would-create'"
  else
    fail "D: found unexpected verbs: $non_would_create"
  fi

  # Must have at least one would-create
  would_create_count=$(echo "$output" | grep -c '^\[would-create\]' || true)
  if [ "$would_create_count" -gt 0 ]; then
    pass "D: at least one 'would-create' verb emitted"
  else
    fail "D: no 'would-create' verbs found. Output: $output"
  fi

  # Zero symlinks must exist on disk after dry-run
  symlink_count=$(find "$SANDBOX_HOME" -type l 2>/dev/null | wc -l | tr -d ' ')
  assert_zero "D: zero symlinks on disk after dry-run" "$symlink_count"
}

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

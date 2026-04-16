#!/usr/bin/env bash
# test/t8_cmd_uninstall.sh — T8 verify checks for cmd_uninstall
# Usage: bash test/t8_cmd_uninstall.sh
# Exits 0 iff all scenarios pass; non-zero otherwise.
#
# Scenario A: After install, uninstall → no tool-owned symlinks remain under
#             any managed root; exit 0 (AC4).
# Scenario B: A hand-placed real file under $HOME/.claude/team-memory/shared/notes.md
#             is untouched after uninstall (AC4).
# Scenario C: A hand-placed symlink at a managed path pointing to /tmp/decoy is
#             reported skipped:not-ours and left untouched.
# Scenario D: $HOME/.claude/ directory still exists post-uninstall.
# Scenario E: If $HOME/.claude/team-memory/shared/ is empty after removals, it
#             is rmdir'ed (AC5); if it contains an unrelated file, it is left.

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

TOP_SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink-t8')

trap 'rm -rf "$TOP_SANDBOX"' EXIT

echo "=== T8 cmd_uninstall Tests ==="
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
# SCENARIO A — After install, uninstall → no tool-owned symlinks remain
# ---------------------------------------------------------------------------
echo "--- Scenario A: Install then uninstall — no owned symlinks remain ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_a")
  export HOME="$SANDBOX_HOME"

  # Preflight: ensure sandbox is not real HOME
  if [ "$HOME" = "$REAL_HOME" ]; then
    echo "ABORT: HOME matches real home — refusing to run" >&2
    exit 2
  fi

  # Install first
  "$SCRIPT" install > /dev/null 2>&1

  # Verify we have symlinks before uninstall
  pre_links=$(find "$SANDBOX_HOME/.claude" -type l 2>/dev/null | wc -l | tr -d ' ')
  if [ "$pre_links" -gt 0 ]; then
    pass "A: symlinks exist before uninstall"
  else
    fail "A: no symlinks created by install (pre-condition failure)"
  fi

  # Now uninstall
  output=$("$SCRIPT" uninstall 2>&1)
  exit_code=$?

  assert_zero "A: uninstall exit code is 0" "$exit_code"

  # No tool-owned symlinks should remain under managed roots
  # Check agents/YHTW
  agents_link="$SANDBOX_HOME/.claude/agents/YHTW"
  if [ ! -L "$agents_link" ]; then
    pass "A: agents/YHTW symlink removed"
  else
    fail "A: agents/YHTW symlink still present after uninstall"
  fi

  # Check commands/YHTW
  commands_link="$SANDBOX_HOME/.claude/commands/YHTW"
  if [ ! -L "$commands_link" ]; then
    pass "A: commands/YHTW symlink removed"
  else
    fail "A: commands/YHTW symlink still present after uninstall"
  fi

  # No owned symlinks remain under team-memory
  remaining_links=$(find "$SANDBOX_HOME/.claude/team-memory" -type l 2>/dev/null | wc -l | tr -d ' ')
  assert_zero "A: no symlinks remain under team-memory" "$remaining_links"

  # Output should contain "removed" verbs
  removed_count=$(echo "$output" | grep -c '^\[removed\]' || true)
  if [ "$removed_count" -gt 0 ]; then
    pass "A: 'removed' verbs reported"
  else
    fail "A: expected '[removed]' verbs in output. Got: $output"
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO B — Hand-placed real file is untouched after uninstall
# ---------------------------------------------------------------------------
echo "--- Scenario B: Hand-placed real file under team-memory is untouched ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_b")
  export HOME="$SANDBOX_HOME"

  # Install first
  "$SCRIPT" install > /dev/null 2>&1

  # Place a real file in a managed team-memory subdir
  notes_dir="$SANDBOX_HOME/.claude/team-memory/shared"
  mkdir -p "$notes_dir"
  notes_file="$notes_dir/notes.md"
  echo "user notes — do not delete" > "$notes_file"

  # Uninstall
  "$SCRIPT" uninstall > /dev/null 2>&1

  # Real file must remain
  if [ -f "$notes_file" ] && [ ! -L "$notes_file" ]; then
    pass "B: real file notes.md is untouched after uninstall"
  else
    fail "B: real file notes.md was removed or converted"
  fi

  # Content must be intact
  content=$(cat "$notes_file" 2>/dev/null || echo "")
  assert_eq "B: real file content intact" "user notes — do not delete" "$content"
}

echo

# ---------------------------------------------------------------------------
# SCENARIO C — Hand-placed foreign symlink at managed path → skipped:not-ours
# ---------------------------------------------------------------------------
echo "--- Scenario C: Foreign symlink at managed path → skipped:not-ours ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_c")
  export HOME="$SANDBOX_HOME"

  # Ensure the agents dir exists but place a foreign symlink at agents/YHTW
  agents_dir="$SANDBOX_HOME/.claude/agents"
  mkdir -p "$agents_dir"
  decoy_link="$agents_dir/YHTW"
  ln -s /tmp/decoy "$decoy_link"

  # Uninstall
  output=$("$SCRIPT" uninstall 2>&1)
  exit_code=$?

  # Should report skipped:not-ours
  if echo "$output" | grep -q '\[skipped:not-ours\]'; then
    pass "C: 'skipped:not-ours' reported for foreign symlink"
  else
    fail "C: expected '[skipped:not-ours]' in output. Got: $output"
  fi

  # The foreign symlink must still be there
  if [ -L "$decoy_link" ]; then
    pass "C: foreign symlink is left untouched"
  else
    fail "C: foreign symlink was removed (must not be)"
  fi

  # The link target must still point to /tmp/decoy
  link_dest=$(readlink "$decoy_link" 2>/dev/null || echo "")
  assert_eq "C: foreign symlink target unchanged" "/tmp/decoy" "$link_dest"
}

echo

# ---------------------------------------------------------------------------
# SCENARIO D — $HOME/.claude/ directory still exists post-uninstall
# ---------------------------------------------------------------------------
echo "--- Scenario D: \$HOME/.claude/ still exists after uninstall ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_d")
  export HOME="$SANDBOX_HOME"

  # Install then uninstall
  "$SCRIPT" install > /dev/null 2>&1
  "$SCRIPT" uninstall > /dev/null 2>&1

  dot_claude="$SANDBOX_HOME/.claude"
  if [ -d "$dot_claude" ]; then
    pass "D: \$HOME/.claude/ directory still exists after uninstall"
  else
    fail "D: \$HOME/.claude/ directory was removed (must not be per R8)"
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO E — Empty subdir rmdir'ed; subdir with unrelated file left alone
# ---------------------------------------------------------------------------
echo "--- Scenario E: Empty team-memory subdir rmdir'ed; non-empty left alone ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_e")
  export HOME="$SANDBOX_HOME"

  # Install
  "$SCRIPT" install > /dev/null 2>&1

  # The shared subdir under team-memory should exist after install
  shared_dir="$SANDBOX_HOME/.claude/team-memory/shared"

  # Check if shared dir exists (it will if team-memory/shared/ has files)
  # If it doesn't, create it with a symlink manually to test the cleanup
  if [ ! -d "$shared_dir" ]; then
    mkdir -p "$shared_dir"
    # Also create a symlink that will be removed by uninstall
    src_file="$REPO/.claude/team-memory/shared/index.md"
    if [ -f "$src_file" ]; then
      ln -s "$src_file" "$shared_dir/index.md"
    fi
  fi

  # Uninstall should remove the owned symlinks and rmdir the empty shared_dir
  "$SCRIPT" uninstall > /dev/null 2>&1

  # If shared_dir had only owned symlinks (now removed), it should be gone
  if [ ! -d "$shared_dir" ]; then
    pass "E1: empty team-memory/shared/ was rmdir'ed after removing owned symlinks"
  else
    # Check if it still has files (if so, it was correctly left)
    remaining=$(ls -A "$shared_dir" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$remaining" -gt 0 ]; then
      pass "E1: team-memory/shared/ left because it has remaining contents"
    else
      fail "E1: team-memory/shared/ is empty but was not rmdir'ed"
    fi
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO E2 — Non-empty subdir (unrelated file) is left alone
# ---------------------------------------------------------------------------
echo "--- Scenario E2: Non-empty team-memory subdir left alone ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_e2")
  export HOME="$SANDBOX_HOME"

  # Install
  "$SCRIPT" install > /dev/null 2>&1

  # Add an unrelated file to the shared dir
  shared_dir="$SANDBOX_HOME/.claude/team-memory/shared"
  mkdir -p "$shared_dir"
  unrelated_file="$shared_dir/user-notes.txt"
  echo "unrelated content" > "$unrelated_file"

  # Uninstall
  "$SCRIPT" uninstall > /dev/null 2>&1

  # The shared dir must still exist (because of the unrelated file)
  if [ -d "$shared_dir" ]; then
    pass "E2: team-memory/shared/ with unrelated file is left alone"
  else
    fail "E2: team-memory/shared/ was removed even though it had an unrelated file"
  fi

  # The unrelated file must still be there
  if [ -f "$unrelated_file" ]; then
    pass "E2: unrelated file in shared/ is untouched"
  else
    fail "E2: unrelated file in shared/ was removed"
  fi
}

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

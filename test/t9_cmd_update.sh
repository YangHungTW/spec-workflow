#!/usr/bin/env bash
# test/t9_cmd_update.sh — T9 verify checks for cmd_update
# Usage: bash test/t9_cmd_update.sh
# Exits 0 iff all 4 scenarios pass; non-zero otherwise.
#
# Scenario A: After install, add a new source file to .claude/team-memory/shared/
#             → update reports "created" only for that path, "already" for the rest,
#             exit 0 (AC6). New file is cleaned up via trap EXIT.
#
# Scenario B: After install, delete a source file that was linked
#             → update reports "removed:orphan" for the stranded link, exits 0 (AC7).
#
# Scenario C: A foreign broken symlink under team-memory is left alone and not
#             reported as ours (AC7).
#
# Scenario D: Real-file conflict at a managed path → update skips that path,
#             still reconciles others, exits 1 (AC8).

set -u -o pipefail

WORKTREE="/Users/yanghungtw/Tools/specaffold/.worktrees/symlink-operation-T10"
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

TOP_SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink-t9')

trap 'rm -rf "$TOP_SANDBOX"' EXIT

echo "=== T9 cmd_update Tests ==="
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
# SCENARIO A — New source file in team-memory → update creates it; others "already"
# ---------------------------------------------------------------------------
echo "--- Scenario A: update adds newly created team-memory file ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_a")
  export HOME="$SANDBOX_HOME"

  # Preflight: ensure sandbox is not real HOME
  if [ "$HOME" = "$REAL_HOME" ]; then
    echo "ABORT: HOME matches real home — refusing to run" >&2
    exit 2
  fi

  # The new source file to add; cleaned up by trap at the end of this block
  NEW_SRC="$REPO/.claude/team-memory/shared/glossary.md"
  NEW_TGT="$SANDBOX_HOME/.claude/team-memory/shared/glossary.md"

  # Ensure the file doesn't already exist (leftover from a previous run)
  rm -f "$NEW_SRC"

  # Install baseline (without the new file)
  "$SCRIPT" install > /dev/null 2>&1
  install_exit=$?
  assert_zero "A: baseline install succeeded" "$install_exit"

  # Add the new source file — trap ensures it's removed even if we fail
  trap 'rm -f "$NEW_SRC"' RETURN 2>/dev/null || true
  echo "# Glossary" > "$NEW_SRC"

  # Run update
  output=$("$SCRIPT" update 2>&1)
  exit_code=$?

  # Remove new source file now (before any assertions that might return early)
  rm -f "$NEW_SRC"

  # Exit code must be 0
  assert_zero "A: update exits 0 after adding new source file" "$exit_code"

  # The new target must be a symlink pointing to the new source
  if [ -L "$NEW_TGT" ]; then
    pass "A: new target is a symlink"
  else
    fail "A: new target is not a symlink: $NEW_TGT"
  fi

  # Output must include "created" for the new target
  if echo "$output" | grep -q '\[created\]'; then
    pass "A: 'created' verb reported for new file"
  else
    fail "A: expected '[created]' in output. Output: $output"
  fi

  # Output must include "already" for existing targets
  if echo "$output" | grep -q '\[already\]'; then
    pass "A: 'already' verb reported for existing files"
  else
    fail "A: expected '[already]' in output. Output: $output"
  fi

  # No orphan removals should occur
  orphan_count=$(echo "$output" | grep -c '\[removed:orphan\]' || true)
  assert_zero "A: no orphan removals reported" "$orphan_count"
}

echo

# ---------------------------------------------------------------------------
# SCENARIO B — Delete a source file → update reports removed:orphan
# ---------------------------------------------------------------------------
echo "--- Scenario B: deleted source file → orphan pruning ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_b")
  export HOME="$SANDBOX_HOME"

  # Install baseline
  "$SCRIPT" install > /dev/null 2>&1

  # Pick a team-memory file to remove temporarily.
  # We move the source file out, run update, then restore it.
  VICTIM_SRC="$REPO/.claude/team-memory/shared/index.md"
  VICTIM_TGT="$SANDBOX_HOME/.claude/team-memory/shared/index.md"
  VICTIM_BACKUP="$TOP_SANDBOX/victim_b_backup.md"

  if [ ! -f "$VICTIM_SRC" ]; then
    fail "B: pre-condition: victim source file does not exist: $VICTIM_SRC"
  else
    pass "B: pre-condition: victim source file exists"
  fi

  if [ -L "$VICTIM_TGT" ]; then
    pass "B: victim target symlink exists before source deletion"
  else
    fail "B: victim target symlink missing before source deletion"
  fi

  # Move the source file away; restore it when done
  cp "$VICTIM_SRC" "$VICTIM_BACKUP"
  rm "$VICTIM_SRC"

  # Run update
  output=$("$SCRIPT" update 2>&1)
  exit_code=$?

  # Restore source file immediately (before any assertions that might exit early)
  cp "$VICTIM_BACKUP" "$VICTIM_SRC"

  # Exit 0: orphan removal is reconciliation, not a conflict
  assert_zero "B: update exits 0 after removing orphan" "$exit_code"

  # The orphan link must be reported as removed:orphan
  if echo "$output" | grep -q '\[removed:orphan\]'; then
    pass "B: 'removed:orphan' verb reported"
  else
    fail "B: expected '[removed:orphan]' in output. Output: $output"
  fi

  # The orphan link must be gone from disk
  if [ ! -L "$VICTIM_TGT" ] && [ ! -e "$VICTIM_TGT" ]; then
    pass "B: orphan link removed from disk"
  else
    fail "B: orphan link still exists: $VICTIM_TGT"
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO C — Foreign broken symlink under team-memory is left alone
# ---------------------------------------------------------------------------
echo "--- Scenario C: foreign broken symlink under team-memory is left alone ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_c")
  export HOME="$SANDBOX_HOME"

  # Create the team-memory dir structure
  tm_shared="$SANDBOX_HOME/.claude/team-memory/shared"
  mkdir -p "$tm_shared"

  # Place a foreign broken symlink (points to a nonexistent path outside the repo)
  FOREIGN_LINK="$tm_shared/foreign-broken.md"
  ln -s "/tmp/nonexistent-foreign-target-$$" "$FOREIGN_LINK"

  # Verify it is actually broken
  if [ -L "$FOREIGN_LINK" ] && [ ! -e "$FOREIGN_LINK" ]; then
    pass "C: pre-condition: foreign broken symlink in place"
  else
    fail "C: pre-condition: foreign broken symlink setup failed"
  fi

  # Run update
  output=$("$SCRIPT" update 2>&1)
  exit_code=$?

  # Exit code should be 0 (foreign link is silently ignored)
  assert_zero "C: update exits 0 when foreign broken symlink present" "$exit_code"

  # The foreign link must still be there
  if [ -L "$FOREIGN_LINK" ]; then
    pass "C: foreign broken symlink is untouched"
  else
    fail "C: foreign broken symlink was removed (must not be)"
  fi

  # The foreign link must NOT be reported in the output
  if echo "$output" | grep -q "$FOREIGN_LINK"; then
    fail "C: foreign broken symlink was reported in output (should be silent)"
  else
    pass "C: foreign broken symlink is not mentioned in output"
  fi
}

echo

# ---------------------------------------------------------------------------
# SCENARIO D — Real-file conflict → skipped, others reconciled, exit 1
# ---------------------------------------------------------------------------
echo "--- Scenario D: real-file conflict → skip conflicted path, reconcile others, exit 1 ---"
{
  SANDBOX_HOME=$(make_sandbox_home "scenario_d")
  export HOME="$SANDBOX_HOME"

  # Pre-place a real file at the agents/scaff managed target
  conflict_path="$SANDBOX_HOME/.claude/agents/scaff"
  mkdir -p "$(dirname "$conflict_path")"
  echo "user content — do not overwrite" > "$conflict_path"

  # Run update
  output=$("$SCRIPT" update 2>&1)
  exit_code=$?

  # Must exit non-zero (conflict → exit 1)
  assert_nonzero "D: update exits non-zero when real-file conflict present" "$exit_code"

  # The conflict must be reported as skipped
  if echo "$output" | grep -q '\[skipped:real-file\]'; then
    pass "D: 'skipped:real-file' reported for conflict path"
  else
    fail "D: expected '[skipped:real-file]' in output. Output: $output"
  fi

  # The real file must be untouched
  if [ -f "$conflict_path" ] && [ ! -L "$conflict_path" ]; then
    pass "D: real file is untouched"
  else
    fail "D: real file was modified or removed"
  fi

  # Other links must still be created (commands/scaff should exist as a symlink)
  commands_link="$SANDBOX_HOME/.claude/commands/scaff"
  if [ -L "$commands_link" ]; then
    pass "D: other links (commands/scaff) reconciled despite conflict"
  else
    fail "D: commands/scaff was not created — update should continue past conflicts"
  fi
}

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

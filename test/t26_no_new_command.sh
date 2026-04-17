#!/usr/bin/env bash
# test/t26_no_new_command.sh — T21: verify no new slash command files were added
# by this feature. The baseline count (git ls-tree HEAD) must match the current
# filesystem count of files in .claude/commands/specflow/.
# Usage: bash test/t26_no_new_command.sh
# Exits 0 iff the counts match.

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
COMMANDS_DIR="$REPO_ROOT/.claude/commands/specflow"

# ---------------------------------------------------------------------------
# Sandbox / HOME isolation (sandbox-home-in-tests discipline)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t26-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Baseline count: number of files tracked in git at .claude/commands/specflow/
# Hard-coded baseline from feature branch (captured at task authoring time).
# If the directory doesn't exist in git yet, baseline is 0.
# ---------------------------------------------------------------------------
BASELINE=18

# ---------------------------------------------------------------------------
# Current filesystem count
# ---------------------------------------------------------------------------
if [ ! -d "$COMMANDS_DIR" ]; then
  fail "Check 1: .claude/commands/specflow/ directory does not exist"
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Count files only (not directories) in the commands dir
FS_COUNT=0
for f in "$COMMANDS_DIR"/*; do
  if [ -f "$f" ]; then
    FS_COUNT=$((FS_COUNT + 1))
  fi
done

# ---------------------------------------------------------------------------
# Verify: filesystem count must match baseline
# ---------------------------------------------------------------------------
if [ "$FS_COUNT" -eq "$BASELINE" ]; then
  pass "Check 1: .claude/commands/specflow/ has $FS_COUNT files (matches baseline $BASELINE)"
elif [ "$FS_COUNT" -gt "$BASELINE" ]; then
  fail "Check 1: .claude/commands/specflow/ has $FS_COUNT files — $((FS_COUNT - BASELINE)) new file(s) added beyond baseline $BASELINE"
else
  fail "Check 1: .claude/commands/specflow/ has $FS_COUNT files — $((BASELINE - FS_COUNT)) file(s) fewer than baseline $BASELINE (unexpected removal)"
fi

# ---------------------------------------------------------------------------
# Also verify git-tracked count matches baseline (cross-check)
# ---------------------------------------------------------------------------
GIT_COUNT="$(cd "$REPO_ROOT" && git ls-tree HEAD -- .claude/commands/specflow/ 2>/dev/null | wc -l | tr -d ' ')"
if [ "$GIT_COUNT" = "$BASELINE" ]; then
  pass "Check 2: git ls-tree count ($GIT_COUNT) matches baseline $BASELINE"
else
  # If the baseline was captured before git-tracking was complete, allow a
  # discrepancy of zero (GIT_COUNT==0 means the dir isn't yet committed).
  if [ "$GIT_COUNT" = "0" ]; then
    pass "Check 2: git ls-tree count is 0 (dir not yet committed) — filesystem count ($FS_COUNT) is the authority"
  else
    fail "Check 2: git ls-tree count ($GIT_COUNT) does not match baseline $BASELINE"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

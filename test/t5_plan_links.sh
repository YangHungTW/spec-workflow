#!/usr/bin/env bash
# test/t5_plan_links.sh — T5 verify checks for plan_links and __probe plan
# Usage: bash test/t5_plan_links.sh
# Exits 0 iff all checks pass; non-zero otherwise.

set -u -o pipefail

WORKTREE="/Users/yanghungtw/Tools/specaffold/.worktrees/symlink-operation-T10"
SCRIPT="$WORKTREE/bin/claude-symlink"
REPO="$WORKTREE"
PASS=0
FAIL=0

# Preflight: script must exist and be executable
if [ ! -x "$SCRIPT" ]; then
  echo "ABORT: script not found or not executable: $SCRIPT" >&2
  exit 2
fi

# Preflight: must not be running against a real HOME
if [ "${HOME:-}" = "/Users/yanghungtw" ] || [ "${HOME:-}" = "$HOME" ] && echo "${HOME:-}" | grep -qv '/tmp/'; then
  : # allow; we set FAKE_HOME ourselves below
fi

FAKE_HOME="/tmp/fakehome"

echo "=== T5 plan_links / __probe plan Tests ==="
echo "REPO=$REPO"
echo "FAKE_HOME=$FAKE_HOME"
echo

# -----------------------------------------------------------------------
# Case 1: line count equals 2 + (number of team-memory files)
# -----------------------------------------------------------------------
expected_tm_files=$(find "$REPO/.claude/team-memory" -type f | wc -l | tr -d ' ')
expected_lines=$((2 + expected_tm_files))

actual_lines=$(HOME="$FAKE_HOME" SPECFLOW_PROBE=1 "$SCRIPT" __probe plan 2>/dev/null | wc -l | tr -d ' ')

if [ "$actual_lines" -eq "$expected_lines" ]; then
  echo "PASS: 1. line count = 2 + team-memory file count ($actual_lines lines, expected $expected_lines)"
  PASS=$((PASS + 1))
else
  echo "FAIL: 1. line count — expected $expected_lines (2+$expected_tm_files), got $actual_lines"
  FAIL=$((FAIL + 1))
fi

# -----------------------------------------------------------------------
# Case 2: first two lines end with expected targets
# -----------------------------------------------------------------------
first_line=$(HOME="$FAKE_HOME" SPECFLOW_PROBE=1 "$SCRIPT" __probe plan 2>/dev/null | sed -n '1p')
second_line=$(HOME="$FAKE_HOME" SPECFLOW_PROBE=1 "$SCRIPT" __probe plan 2>/dev/null | sed -n '2p')

# Extract target (second tab-separated field)
first_tgt=$(printf '%s' "$first_line" | cut -f2)
second_tgt=$(printf '%s' "$second_line" | cut -f2)

expected_first_tgt="$FAKE_HOME/.claude/agents/scaff"
expected_second_tgt="$FAKE_HOME/.claude/commands/scaff"

if [ "$first_tgt" = "$expected_first_tgt" ]; then
  echo "PASS: 2a. first line target = $expected_first_tgt"
  PASS=$((PASS + 1))
else
  echo "FAIL: 2a. first line target — expected '$expected_first_tgt', got '$first_tgt'"
  FAIL=$((FAIL + 1))
fi

if [ "$second_tgt" = "$expected_second_tgt" ]; then
  echo "PASS: 2b. second line target = $expected_second_tgt"
  PASS=$((PASS + 1))
else
  echo "FAIL: 2b. second line target — expected '$expected_second_tgt', got '$second_tgt'"
  FAIL=$((FAIL + 1))
fi

# -----------------------------------------------------------------------
# Case 3: every target after line 2 starts with $FAKE_HOME/.claude/team-memory/
# -----------------------------------------------------------------------
bad_tm_targets=0
while IFS= read -r line; do
  tgt=$(printf '%s' "$line" | cut -f2)
  case "$tgt" in
    "$FAKE_HOME/.claude/team-memory/"*) : ;;
    *)
      echo "  BAD team-memory target: $tgt"
      bad_tm_targets=$((bad_tm_targets + 1))
      ;;
  esac
done < <(HOME="$FAKE_HOME" SPECFLOW_PROBE=1 "$SCRIPT" __probe plan 2>/dev/null | tail -n +"$((2 + 1))")

if [ "$bad_tm_targets" -eq 0 ]; then
  echo "PASS: 3. all team-memory targets start with $FAKE_HOME/.claude/team-memory/"
  PASS=$((PASS + 1))
else
  echo "FAIL: 3. $bad_tm_targets team-memory targets did not start with $FAKE_HOME/.claude/team-memory/"
  FAIL=$((FAIL + 1))
fi

# -----------------------------------------------------------------------
# Case 4: all sources are absolute and begin with REPO
# -----------------------------------------------------------------------
bad_srcs=0
while IFS= read -r line; do
  src=$(printf '%s' "$line" | cut -f1)
  case "$src" in
    "$REPO/"*) : ;;
    *)
      echo "  BAD source: $src"
      bad_srcs=$((bad_srcs + 1))
      ;;
  esac
done < <(HOME="$FAKE_HOME" SPECFLOW_PROBE=1 "$SCRIPT" __probe plan 2>/dev/null)

if [ "$bad_srcs" -eq 0 ]; then
  echo "PASS: 4. all sources are absolute and start with $REPO"
  PASS=$((PASS + 1))
else
  echo "FAIL: 4. $bad_srcs sources did not start with $REPO"
  FAIL=$((FAIL + 1))
fi

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

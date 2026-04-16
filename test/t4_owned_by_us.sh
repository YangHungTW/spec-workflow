#!/usr/bin/env bash
# test/t4_owned_by_us.sh — T4 verify checks for owned_by_us
# Usage: bash test/t4_owned_by_us.sh
# Exits 0 iff all checks pass; non-zero otherwise.
#
# Uses __probe owned <path> to call owned_by_us from outside the script.
# Returns 0 (ours) or 1 (not ours); caller checks $?.

set -u -o pipefail

WORKTREE="/Users/yanghungtw/Tools/spec-workflow/.worktrees/symlink-operation-T10"
SCRIPT="$WORKTREE/bin/claude-symlink"
PASS=0
FAIL=0

# Preflight: script must exist and be executable
if [ ! -x "$SCRIPT" ]; then
  echo "ABORT: script not found or not executable: $SCRIPT" >&2
  exit 2
fi

# Setup: mktemp sandbox for symlinks
SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink-t4')
trap 'rm -rf "$SANDBOX"' EXIT

echo "=== T4 owned_by_us Tests ==="
echo "SANDBOX=$SANDBOX"
echo "REPO=$WORKTREE"
echo

# Helper: assert that __probe owned <path> returns the expected exit code
assert_owned() {
  local description="$1"
  local expected_exit="$2"
  local path="$3"
  YHTW_PROBE=1 "$SCRIPT" __probe owned "$path"
  local actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "PASS: $description (exit $actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — expected exit $expected_exit, got $actual_exit"
    FAIL=$((FAIL + 1))
  fi
}

# Case 1: Symlink whose target is inside $REPO/.claude/agents/YHTW → returns 0 (ours)
# We create a real directory to point to, then a symlink pointing at it.
mkdir -p "$WORKTREE/.claude/agents/YHTW"
LINK1="$SANDBOX/link_ours"
ln -s "$WORKTREE/.claude/agents/YHTW" "$LINK1"
assert_owned \
  "1. symlink into repo .claude/agents/YHTW → owned (exit 0)" \
  0 \
  "$LINK1"

# Case 2: Symlink whose target is /tmp/fake/.claude/agents/YHTW → returns 1 (foreign)
# The target doesn't need to exist; owned_by_us checks the path prefix only.
LINK2="$SANDBOX/link_foreign"
ln -s "/tmp/fake/.claude/agents/YHTW" "$LINK2"
assert_owned \
  "2. symlink into /tmp/fake/.claude/agents/YHTW → foreign (exit 1)" \
  1 \
  "$LINK2"

# Case 3: Sibling-repo path — shares string prefix WITHOUT trailing slash boundary
# e.g. ${REPO}-fork/.claude/agents/YHTW. With trailing slash this must NOT match.
SIBLING_TARGET="${WORKTREE}-fork/.claude/agents/YHTW"
LINK3="$SANDBOX/link_sibling"
ln -s "$SIBLING_TARGET" "$LINK3"
assert_owned \
  "3. symlink into sibling-repo fork (prefix without trailing slash) → foreign (exit 1)" \
  1 \
  "$LINK3"

# Case 4: Real file (not a symlink) → returns 1
REAL_FILE="$SANDBOX/realfile"
echo "not a symlink" > "$REAL_FILE"
assert_owned \
  "4. real file (not a symlink) → not owned (exit 1)" \
  1 \
  "$REAL_FILE"

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

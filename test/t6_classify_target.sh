#!/usr/bin/env bash
# test/t6_classify_target.sh — T6 verify checks for classify_target
# Usage: bash test/t6_classify_target.sh
# Exits 0 iff all 8 assertions pass; non-zero otherwise.
#
# Sets up each of the 8 states in a mktemp -d sandbox and asserts the
# echoed classification matches expectation.
# Sandbox uses HOME=$(mktemp -d)/home; refuses to run against the real $HOME.

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
SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink-t6')
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

if [ "$HOME" = "$REAL_HOME" ] || [ "${HOME#"$SANDBOX"}" = "$HOME" ]; then
  echo "ABORT: HOME ($HOME) does not look like a sandbox path — refusing to run" >&2
  rm -rf "$SANDBOX"
  exit 2
fi

trap 'rm -rf "$SANDBOX"' EXIT

echo "=== T6 classify_target Tests ==="
echo "SANDBOX=$SANDBOX"
echo "HOME=$HOME"
echo "REPO=$REPO"
echo

# ---------------------------------------------------------------------------
# Helper: call classify_target via __probe classify <tgt> <expected_src>
# and assert the output matches expected_class.
# ---------------------------------------------------------------------------
assert_classify() {
  local description="$1"
  local expected_class="$2"
  local tgt="$3"
  local expected_src="$4"

  local actual_class
  actual_class=$(YHTW_PROBE=1 "$SCRIPT" __probe classify "$tgt" "$expected_src" 2>/dev/null)
  local exit_code=$?

  if [ "$actual_class" = "$expected_class" ]; then
    echo "PASS: $description → '$actual_class'"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — expected '$expected_class', got '$actual_class' (exit $exit_code)"
    FAIL=$((FAIL + 1))
  fi
}

# We need a real source path inside REPO/.claude/ for "ours" tests.
# Use a real file/dir that exists (team-memory is walked by plan_links, so it exists).
OUR_SRC="$REPO/.claude/agents/YHTW"
# An expected_src that is ours but different from what the link actually points to
OUR_ALT_SRC="$REPO/.claude/commands/YHTW"
# A foreign source (not inside this repo's .claude/)
FOREIGN_SRC="/tmp/foreign-target-$$"

# ---------------------------------------------------------------------------
# State 1: missing — tgt does not exist at all (not even a broken symlink)
# ---------------------------------------------------------------------------
MISSING_TGT="$HOME/state1_missing_path"
assert_classify \
  "1. missing (path does not exist)" \
  "missing" \
  "$MISSING_TGT" \
  "$OUR_SRC"

# ---------------------------------------------------------------------------
# State 2: ok — tgt is a symlink pointing exactly to expected_src
# ---------------------------------------------------------------------------
OK_TGT="$HOME/state2_ok_link"
ln -s "$OUR_SRC" "$OK_TGT"
assert_classify \
  "2. ok (symlink to expected_src)" \
  "ok" \
  "$OK_TGT" \
  "$OUR_SRC"

# ---------------------------------------------------------------------------
# State 3: wrong-link-ours — tgt is a symlink owned by us but pointing to
#          a different source than expected_src
# ---------------------------------------------------------------------------
WRONG_OURS_TGT="$HOME/state3_wrong_link_ours"
ln -s "$OUR_ALT_SRC" "$WRONG_OURS_TGT"
assert_classify \
  "3. wrong-link-ours (symlink owned-by-us, wrong target)" \
  "wrong-link-ours" \
  "$WRONG_OURS_TGT" \
  "$OUR_SRC"

# ---------------------------------------------------------------------------
# State 4: wrong-link-foreign — tgt is a symlink NOT owned by us, pointing
#          somewhere that exists but is not our expected_src
# ---------------------------------------------------------------------------
# Create a real target for the foreign link so it is not broken
FOREIGN_REAL_TGT=$(mktemp "$SANDBOX/foreign_real_XXXXXX")
WRONG_FOREIGN_TGT="$HOME/state4_wrong_link_foreign"
ln -s "$FOREIGN_REAL_TGT" "$WRONG_FOREIGN_TGT"
assert_classify \
  "4. wrong-link-foreign (symlink to existing foreign path, not our expected_src)" \
  "wrong-link-foreign" \
  "$WRONG_FOREIGN_TGT" \
  "$OUR_SRC"

# ---------------------------------------------------------------------------
# State 5: broken-ours — tgt is a broken symlink pointing into our repo
#          (the link target path does not exist)
# ---------------------------------------------------------------------------
BROKEN_OURS_TGT="$HOME/state5_broken_ours"
ln -s "$REPO/.claude/nonexistent_path_$$" "$BROKEN_OURS_TGT"
assert_classify \
  "5. broken-ours (broken symlink pointing into our repo .claude/)" \
  "broken-ours" \
  "$BROKEN_OURS_TGT" \
  "$OUR_SRC"

# ---------------------------------------------------------------------------
# State 6: broken-foreign — tgt is a broken symlink NOT pointing into our repo
# ---------------------------------------------------------------------------
BROKEN_FOREIGN_TGT="$HOME/state6_broken_foreign"
ln -s "/tmp/nonexistent_foreign_path_$$" "$BROKEN_FOREIGN_TGT"
assert_classify \
  "6. broken-foreign (broken symlink pointing nowhere in our repo)" \
  "broken-foreign" \
  "$BROKEN_FOREIGN_TGT" \
  "$OUR_SRC"

# ---------------------------------------------------------------------------
# State 7: real-file — tgt is a regular file (not a symlink)
# ---------------------------------------------------------------------------
REAL_FILE_TGT="$HOME/state7_real_file"
echo "real content" > "$REAL_FILE_TGT"
assert_classify \
  "7. real-file (regular file)" \
  "real-file" \
  "$REAL_FILE_TGT" \
  "$OUR_SRC"

# ---------------------------------------------------------------------------
# State 8: real-dir — tgt is a real directory (not a symlink)
# ---------------------------------------------------------------------------
REAL_DIR_TGT="$HOME/state8_real_dir"
mkdir -p "$REAL_DIR_TGT"
assert_classify \
  "8. real-dir (real directory)" \
  "real-dir" \
  "$REAL_DIR_TGT" \
  "$OUR_SRC"

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

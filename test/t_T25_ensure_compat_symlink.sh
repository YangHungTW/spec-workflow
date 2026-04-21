#!/usr/bin/env bash
# test/t_T25_ensure_compat_symlink.sh — T25 unit tests for ensure_compat_symlink()
# Usage: bash test/t_T25_ensure_compat_symlink.sh
# Exits 0 iff all assertions pass; non-zero otherwise.
#
# Tests the six-state classifier and dispatch table in ensure_compat_symlink.
# Uses mktemp -d sandbox with HOME isolation per sandbox-home-in-tests.md rule.

set -u -o pipefail

WORKTREE="/Users/yanghungtw/Tools/spec-workflow/.worktrees/20260421-rename-to-specaffold-T25"
SCRIPT="$WORKTREE/bin/scaff-seed"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Preflight: script must exist
# ---------------------------------------------------------------------------
if [ ! -f "$SCRIPT" ]; then
  echo "ABORT: script not found: $SCRIPT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Preflight: function must be defined in the script
# ---------------------------------------------------------------------------
if ! grep -q 'ensure_compat_symlink()' "$SCRIPT"; then
  echo "FAIL: ensure_compat_symlink() not defined in $SCRIPT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox HOME
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

echo "=== T25 ensure_compat_symlink Tests ==="
echo "SANDBOX=$SANDBOX"
echo ""

# ---------------------------------------------------------------------------
# Source the script in a restricted way — we only want the function definitions.
# We temporarily stub out the main dispatcher by sourcing with a guard.
# ---------------------------------------------------------------------------
# Extract just the function body by sourcing and exporting in a subshell.
# We set BASH_ENV guard: set positional to prevent the main dispatcher from
# running by unsetting the positional args and ensuring _cmd is empty.
#
# Strategy: source the script in a subshell after disabling its main entry point
# by overriding the _cmd variable detection. scaff-seed reads _cmd from "$1"
# so as long as we provide no args, the dispatcher hits the --help branch
# (usage + exit 0) — we cannot source it that way.
#
# Instead, use __probe compat subcommand to exercise the function from outside.
# Expose the function via a new __probe verb: "compat-classify" and "compat-run".
#
# Since T25 is FUNCTION DEFINITION ONLY and T26 wires the probe verb, we
# exercise the function by sourcing the script into a helper subshell that
# suppresses the main dispatcher, then calling the function directly.
# ---------------------------------------------------------------------------

# We source the file with stdin as /dev/null to suppress the main dispatcher
# (the dispatcher at the bottom only runs when the file is executed, not sourced).
# Actually bash sources execute top-level code, so the case "$_cmd" block WILL run.
# We need a safer approach: wrap in a function-only extraction.

# Safest approach for bash-3.2-portable function testing:
# Write a thin wrapper script that sources scaff-seed and calls the function.

HELPER="$SANDBOX/run_compat.sh"
cat > "$HELPER" <<'HELPEREOF'
#!/usr/bin/env bash
set -u -o pipefail
# Args: <verb> <repo_root>
# verb=classify   → call classify_compat_symlink <repo_root>; print state
# verb=run        → call ensure_compat_symlink <repo_root>; print exit code
VERB="$1"
REPO_ROOT="$2"

# Source scaff-seed with a fake first arg that causes usage() + exit 0 normally,
# but we intercept by providing no args and wrapping in a function guard.
# We define _SOURCED_FOR_TEST=1 so scaff-seed can skip the dispatcher block.
# (This requires scaff-seed to check _SOURCED_FOR_TEST — which it doesn't yet.)
#
# Alternative that works WITHOUT modifying scaff-seed:
# Run scaff-seed with __probe compat-classify once T26 wires it.
#
# For T25 (function definition only), verify the function is syntactically
# present and callable via a sourced wrapper that skips the main dispatcher
# by redefining the case block handler.
#
# We extract ensure_compat_symlink via awk to a temp file and source it.
FUNC_TMP="$(mktemp)"
awk '/^ensure_compat_symlink\(\)/{found=1} found{print} found && /^\}$/{exit}' \
  "$3" > "$FUNC_TMP"

# Also need classify_compat_symlink (inner classifier)
CLASSIFY_TMP="$(mktemp)"
awk '/^classify_compat_symlink\(\)/{found=1} found{print} found && /^\}$/{exit}' \
  "$3" > "$CLASSIFY_TMP"

# Source any required helpers (die is needed by some functions)
die() { echo "scaff-seed: $1" >&2; exit 2; }

# shellcheck disable=SC1090
source "$CLASSIFY_TMP"
source "$FUNC_TMP"
rm -f "$FUNC_TMP" "$CLASSIFY_TMP"

case "$VERB" in
  classify)
    classify_compat_symlink "$REPO_ROOT"
    ;;
  run)
    ensure_compat_symlink "$REPO_ROOT"
    echo "exit:$?"
    ;;
esac
HELPEREOF
chmod +x "$HELPER"

# ---------------------------------------------------------------------------
# Helper: assert classifier state
# ---------------------------------------------------------------------------
assert_state() {
  local description="$1"
  local expected_state="$2"
  local repo_root="$3"
  local actual_state
  actual_state=$(bash "$HELPER" classify "$repo_root" "$SCRIPT" 2>/dev/null)
  if [ "$actual_state" = "$expected_state" ]; then
    echo "PASS: $description → '$actual_state'"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description — expected '$expected_state', got '$actual_state'"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Helper: assert ensure_compat_symlink behaviour
# ---------------------------------------------------------------------------
assert_run() {
  local description="$1"
  local repo_root="$2"
  local check_fn="$3"   # function name to call for post-run assertion
  local stderr_file
  stderr_file="$(mktemp)"
  bash "$HELPER" run "$repo_root" "$SCRIPT" 2>"$stderr_file"
  local run_rc=$?
  if $check_fn "$repo_root" "$stderr_file" "$run_rc"; then
    echo "PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description (rc=$run_rc stderr=$(cat "$stderr_file"))"
    FAIL=$((FAIL + 1))
  fi
  rm -f "$stderr_file"
}

# ---------------------------------------------------------------------------
# State 1: missing — neither .spec-workflow link nor anything exists
# ---------------------------------------------------------------------------
REPO1="$SANDBOX/repo1"
mkdir -p "$REPO1/.specaffold"   # canonical target exists
assert_state "1. missing (nothing at .spec-workflow)" "missing" "$REPO1"

check_missing_creates_symlink() {
  local rr="$1"
  local link_path="${rr}/.spec-workflow"
  local target_path="${rr}/.specaffold"
  # symlink must now exist and point to an absolute path matching target
  [ -L "$link_path" ] || { echo "link not created" >&2; return 1; }
  local dest
  dest="$(readlink "$link_path")"
  [ "$dest" = "$target_path" ] || { echo "link target '$dest' != '$target_path'" >&2; return 1; }
  # Verify absolute (starts with /)
  case "$dest" in /*) ;; *) echo "target not absolute: $dest" >&2; return 1;; esac
  return 0
}
assert_run "1b. missing → creates absolute symlink" "$REPO1" "check_missing_creates_symlink"

# ---------------------------------------------------------------------------
# State 2: ok-ours — .spec-workflow already symlinks to .specaffold (absolute)
# ---------------------------------------------------------------------------
REPO2="$SANDBOX/repo2"
mkdir -p "$REPO2/.specaffold"
ln -s "$REPO2/.specaffold" "$REPO2/.spec-workflow"
assert_state "2. ok-ours (symlink points to .specaffold)" "ok-ours" "$REPO2"

check_ok_ours_noop() {
  local rr="$1"
  local link_path="${rr}/.spec-workflow"
  # link must still exist; dest must remain unchanged
  [ -L "$link_path" ] || return 1
  local dest
  dest="$(readlink "$link_path")"
  [ "$dest" = "${rr}/.specaffold" ] || return 1
  return 0
}
assert_run "2b. ok-ours → no-op (idempotent)" "$REPO2" "check_ok_ours_noop"

# ---------------------------------------------------------------------------
# State 3: foreign-symlink — .spec-workflow is a symlink pointing elsewhere
# ---------------------------------------------------------------------------
REPO3="$SANDBOX/repo3"
mkdir -p "$REPO3/.specaffold"
# Foreign target must exist so the symlink is not broken (broken-symlink is a separate state)
FOREIGN_EXISTING="$SANDBOX/foreign-existing-dir"
mkdir -p "$FOREIGN_EXISTING"
ln -s "$FOREIGN_EXISTING" "$REPO3/.spec-workflow"
assert_state "3. foreign-symlink (points elsewhere)" "foreign-symlink" "$REPO3"

check_foreign_skipped() {
  local rr="$1" stderr_file="$2"
  # Link must remain unchanged (skip)
  local dest
  dest="$(readlink "${rr}/.spec-workflow")"
  [ "$dest" = "$FOREIGN_EXISTING" ] || { echo "link was modified" >&2; return 1; }
  # Stderr must contain a warning
  grep -q "WARN" "$stderr_file" || grep -q "warn" "$stderr_file" || \
    grep -q "skip" "$stderr_file" || grep -q "foreign" "$stderr_file" || \
    { echo "no warning on stderr" >&2; return 1; }
  return 0
}
assert_run "3b. foreign-symlink → warn+skip" "$REPO3" "check_foreign_skipped"

# ---------------------------------------------------------------------------
# State 4: real-dir — .spec-workflow is an actual directory
# ---------------------------------------------------------------------------
REPO4="$SANDBOX/repo4"
mkdir -p "$REPO4/.specaffold" "$REPO4/.spec-workflow"
assert_state "4. real-dir (actual directory)" "real-dir" "$REPO4"

check_real_dir_skipped() {
  local rr="$1" stderr_file="$2"
  [ -d "${rr}/.spec-workflow" ] && [ ! -L "${rr}/.spec-workflow" ] || return 1
  grep -q "WARN\|warn\|skip\|real-dir" "$stderr_file" || \
    { echo "no warning on stderr" >&2; return 1; }
  return 0
}
assert_run "4b. real-dir → warn+skip" "$REPO4" "check_real_dir_skipped"

# ---------------------------------------------------------------------------
# State 5: real-file — .spec-workflow is a regular file
# ---------------------------------------------------------------------------
REPO5="$SANDBOX/repo5"
mkdir -p "$REPO5/.specaffold"
echo "legacy" > "$REPO5/.spec-workflow"
assert_state "5. real-file (regular file)" "real-file" "$REPO5"

check_real_file_skipped() {
  local rr="$1" stderr_file="$2"
  [ -f "${rr}/.spec-workflow" ] && [ ! -L "${rr}/.spec-workflow" ] || return 1
  grep -q "WARN\|warn\|skip\|real-file" "$stderr_file" || \
    { echo "no warning on stderr" >&2; return 1; }
  return 0
}
assert_run "5b. real-file → warn+skip" "$REPO5" "check_real_file_skipped"

# ---------------------------------------------------------------------------
# State 6: broken-symlink — .spec-workflow is a symlink whose target doesn't exist
# ---------------------------------------------------------------------------
REPO6="$SANDBOX/repo6"
mkdir -p "$REPO6/.specaffold"
ln -s "${REPO6}/.spec-workflow-nonexistent" "$REPO6/.spec-workflow"
assert_state "6. broken-symlink (target doesn't exist)" "broken-symlink" "$REPO6"

check_broken_skipped() {
  local rr="$1" stderr_file="$2"
  [ -L "${rr}/.spec-workflow" ] || return 1
  grep -q "WARN\|warn\|skip\|broken" "$stderr_file" || \
    { echo "no warning on stderr" >&2; return 1; }
  return 0
}
assert_run "6b. broken-symlink → warn+skip" "$REPO6" "check_broken_skipped"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

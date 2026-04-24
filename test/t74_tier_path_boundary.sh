#!/usr/bin/env bash
# test/t74_tier_path_boundary.sh
#
# Security test — path-traversal boundary guard in get_tier and set_tier.
#
# Verifies that both get_tier and set_tier resolve feature_dir to a real
# absolute path and reject paths that lie outside REPO_ROOT.  A caller
# supplying "../../../etc" (or a symlink escaping the tree) must receive
# a clear error, not a silent read/write outside the repo boundary.
#
# Requirements: security/path-traversal rule (reviewer/security.md check 2).
# Depends on: T2 (bin/scaff-tier).

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script (developer/test-script-path-convention)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TIER_LIB="$REPO_ROOT/bin/scaff-tier"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (mandatory per sandbox-home-in-tests rule).
# Also used as the "outside" tree for path-traversal tests.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t74-tier-boundary)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sanity: library must exist and be parseable
# ---------------------------------------------------------------------------
if [ ! -f "$TIER_LIB" ]; then
  echo "FAIL: bin/scaff-tier not found: $TIER_LIB" >&2
  exit 1
fi

if ! bash -n "$TIER_LIB" 2>/dev/null; then
  echo "FAIL: bash -n reports syntax error in $TIER_LIB" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

# Build a valid STATUS.md fixture inside a given dir.
make_status_md() {
  local dir="$1" tier="${2:-standard}"
  mkdir -p "$dir"
  cat > "$dir/STATUS.md" <<EOF
- **slug**: test-feature
- **has-ui**: false
- **tier**: $tier
- **stage**: plan
EOF
}

# Source the library into a subshell so SCAFF_TIER_LOADED resets between
# test cases.  Returns the exit code of the subshell.
run_get_tier() {
  local dir="$1"
  # shellcheck disable=SC1090
  ( SCAFF_TIER_LOADED=0
    # Export REPO_ROOT so the boundary guard can reference it.
    export REPO_ROOT
    . "$TIER_LIB"
    get_tier "$dir"
  )
}

run_set_tier() {
  local dir="$1" tier="${2:-standard}" role="${3:-developer}" reason="${4:-test}"
  # We need to capture stderr separately; use a file.
  local stderr_file="$SANDBOX/stderr_$$.txt"
  local rc=0
  ( SCAFF_TIER_LOADED=0
    export REPO_ROOT
    . "$TIER_LIB"
    # First seed the file with tier: tiny so the transition tiny→standard is valid.
    make_status_md "$dir" "tiny"
    set_tier "$dir" "$tier" "$role" "$reason"
  ) 2>"$stderr_file" || rc=$?
  _LAST_STDERR="$(cat "$stderr_file")"
  return $rc
}
_LAST_STDERR=""

# ---------------------------------------------------------------------------
# Setup: a valid feature dir INSIDE REPO_ROOT
# ---------------------------------------------------------------------------
VALID_FEATURE="$REPO_ROOT/.specaffold/features/_t74_test_fixture"
make_status_md "$VALID_FEATURE" "tiny"
trap 'rm -rf "$SANDBOX" "$REPO_ROOT/.specaffold/features/_t74_test_fixture"' EXIT

# ---------------------------------------------------------------------------
# Check 1: get_tier succeeds for a path inside REPO_ROOT
# ---------------------------------------------------------------------------
result=$(run_get_tier "$VALID_FEATURE" 2>/dev/null)
if [ "$result" = "tiny" ]; then
  pass "Check 1: get_tier succeeds for path inside REPO_ROOT (result=$result)"
else
  fail "Check 1: get_tier returned '$result' for valid path (expected 'tiny')"
fi

# ---------------------------------------------------------------------------
# Check 2: get_tier rejects a path outside REPO_ROOT (exit non-zero + stderr)
# ---------------------------------------------------------------------------
OUTSIDE_DIR="$SANDBOX/outside-feature"
make_status_md "$OUTSIDE_DIR" "standard"

stderr_file2="$SANDBOX/check2_err.txt"
result2=$(SCAFF_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; get_tier '$OUTSIDE_DIR'" 2>"$stderr_file2") || true
rc2=$?
stderr2="$(cat "$stderr_file2")"

# Boundary guard must either exit non-zero OR emit an error to stderr.
# A silent success (returning a tier value) with no error is a failure.
if [ "$rc2" -ne 0 ] || [ -n "$stderr2" ]; then
  pass "Check 2: get_tier rejected outside-REPO_ROOT path (rc=$rc2, stderr non-empty=$([ -n "$stderr2" ] && echo yes || echo no))"
else
  fail "Check 2: get_tier silently accepted path outside REPO_ROOT (result='$result2', stderr empty)"
fi

# ---------------------------------------------------------------------------
# Check 3: set_tier rejects a path outside REPO_ROOT (exit non-zero)
# ---------------------------------------------------------------------------
OUTSIDE_DIR2="$SANDBOX/outside-set-feature"
make_status_md "$OUTSIDE_DIR2" "tiny"

stderr_file3="$SANDBOX/check3_err.txt"
SCAFF_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; set_tier '$OUTSIDE_DIR2' standard developer retrytest" \
  >"$SANDBOX/check3_out.txt" 2>"$stderr_file3"
rc3=$?
stderr3="$(cat "$stderr_file3")"

if [ "$rc3" -ne 0 ]; then
  pass "Check 3: set_tier rejected outside-REPO_ROOT path (rc=$rc3)"
else
  fail "Check 3: set_tier accepted path outside REPO_ROOT without error (rc=$rc3; stderr='$stderr3')"
fi

# ---------------------------------------------------------------------------
# Check 4: set_tier rejects a non-existent / unresolvable path
# ---------------------------------------------------------------------------
NON_EXISTENT="$SANDBOX/does-not-exist"

stderr_file4="$SANDBOX/check4_err.txt"
SCAFF_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; set_tier '$NON_EXISTENT' standard developer retrytest" \
  >"$SANDBOX/check4_out.txt" 2>"$stderr_file4"
rc4=$?

if [ "$rc4" -ne 0 ]; then
  pass "Check 4: set_tier rejected non-existent path (rc=$rc4)"
else
  fail "Check 4: set_tier accepted non-existent path without error (rc=$rc4)"
fi

# ---------------------------------------------------------------------------
# Check 5: get_tier rejects a non-existent / unresolvable path
# (distinct from missing STATUS.md — the directory itself must not exist outside root)
# The guard fires before the file-existence check.
# ---------------------------------------------------------------------------
stderr_file5="$SANDBOX/check5_err.txt"
result5=$(SCAFF_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; get_tier '$NON_EXISTENT'" 2>"$stderr_file5") || true
rc5=$?
stderr5="$(cat "$stderr_file5")"

# get_tier must reject an unresolvable outside path — it may return
# 'missing' for an absent STATUS.md inside the repo, but a path that
# doesn't exist AND is outside REPO_ROOT should fail loudly.
# Because NON_EXISTENT is under SANDBOX (outside REPO_ROOT), the boundary
# guard should fire (rc non-zero or stderr non-empty).
if [ "$rc5" -ne 0 ] || [ -n "$stderr5" ]; then
  pass "Check 5: get_tier rejected unresolvable outside path (rc=$rc5, stderr=$([ -n "$stderr5" ] && echo non-empty || echo empty))"
else
  fail "Check 5: get_tier silently accepted unresolvable outside path (result='$result5')"
fi

# ---------------------------------------------------------------------------
# Check 6: set_tier succeeds for a valid inside-REPO_ROOT path
# (regression guard — the fix must not break the happy path)
# ---------------------------------------------------------------------------
VALID_SET_DIR="$REPO_ROOT/.specaffold/features/_t74_set_test"
make_status_md "$VALID_SET_DIR" "tiny"
trap 'rm -rf "$SANDBOX" "$REPO_ROOT/.specaffold/features/_t74_test_fixture" "$REPO_ROOT/.specaffold/features/_t74_set_test"' EXIT

stderr_file6="$SANDBOX/check6_err.txt"
SCAFF_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; set_tier '$VALID_SET_DIR' standard developer retrytest" \
  >"$SANDBOX/check6_out.txt" 2>"$stderr_file6"
rc6=$?

if [ "$rc6" -eq 0 ]; then
  pass "Check 6: set_tier succeeded for valid inside-REPO_ROOT path (rc=$rc6)"
else
  fail "Check 6: set_tier unexpectedly rejected valid inside-REPO_ROOT path (rc=$rc6; stderr='$(cat "$stderr_file6")')"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]

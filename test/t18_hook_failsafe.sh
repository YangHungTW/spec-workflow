#!/usr/bin/env bash
# test/t18_hook_failsafe.sh — hook failsafe test
# Invokes session-start.sh from a directory with NO .claude/rules present.
# Asserts: exit 0, at least one WARN line on stderr.

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HOOK="$REPO_ROOT/.claude/hooks/session-start.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (discipline per sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t18-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Sanity: hook must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$HOOK" ]; then
  fail "hook not executable: $HOOK"
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Setup: create a work dir with NO .claude/rules
# ---------------------------------------------------------------------------
WORKDIR="$SANDBOX/work"
mkdir -p "$WORKDIR"

# ---------------------------------------------------------------------------
# Check 1: hook exits 0 even when .claude/rules is missing
# ---------------------------------------------------------------------------
STDERR_FILE="$SANDBOX/stderr.txt"
JSON_OUT=$(cd "$WORKDIR" && "$HOOK" < /dev/null 2>"$STDERR_FILE")
RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0 (no rules dir)"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stderr contains at least one WARN line
# ---------------------------------------------------------------------------
WARN_COUNT=$(grep -c 'WARN' "$STDERR_FILE" 2>/dev/null || echo "0")
if [ "$WARN_COUNT" -ge 1 ]; then
  pass "Check 2: stderr contains WARN line (count: $WARN_COUNT)"
else
  fail "Check 2: stderr has no WARN line (got: $(cat "$STDERR_FILE"))"
fi

# ---------------------------------------------------------------------------
# Check 3: stdout is still valid JSON (fail-safe pattern)
# ---------------------------------------------------------------------------
if python3 -c "import json,sys; json.loads(sys.argv[1])" "$JSON_OUT" 2>/dev/null; then
  pass "Check 3: stdout is valid JSON even in failsafe path"
else
  fail "Check 3: stdout is not valid JSON in failsafe path (got: $JSON_OUT)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

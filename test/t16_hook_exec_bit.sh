#!/usr/bin/env bash
# test/t16_hook_exec_bit.sh — verify .claude/hooks/session-start.sh exists and is executable
# Usage: bash test/t16_hook_exec_bit.sh
# Exits 0 iff all checks pass.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox / HOME preflight (template discipline)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t scaff-t16)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

HOOK="$REPO_ROOT/.claude/hooks/session-start.sh"

echo "=== t16_hook_exec_bit ==="

# Check 1: hook file exists
if [ -f "$HOOK" ]; then
  pass "Check 1: .claude/hooks/session-start.sh exists"
else
  fail "Check 1: .claude/hooks/session-start.sh not found at $HOOK"
fi

# Check 2: hook is executable
if [ -x "$HOOK" ]; then
  pass "Check 2: .claude/hooks/session-start.sh is executable"
else
  fail "Check 2: .claude/hooks/session-start.sh is NOT executable"
fi

# Check 3: hook passes bash -n syntax check
if bash -n "$HOOK" 2>/dev/null; then
  pass "Check 3: bash -n syntax check passes"
else
  fail "Check 3: bash -n reported syntax error"
fi

# Check 4: hook exits 0 when run with /dev/null stdin
"$HOOK" < /dev/null >/dev/null 2>&1
RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Check 4: hook exits 0 with /dev/null stdin"
else
  fail "Check 4: hook exited $RC (expected 0)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

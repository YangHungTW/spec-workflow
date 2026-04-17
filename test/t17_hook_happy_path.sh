#!/usr/bin/env bash
# test/t17_hook_happy_path.sh — hook happy-path integration test
# Invokes session-start.sh from the repo root (real .claude/rules present).
# Asserts: exit 0, stdout is valid JSON, additionalContext contains classify-before-mutate.

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t17-test)"
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
# Check 1: hook exits 0
# ---------------------------------------------------------------------------
JSON_OUT=$("$HOOK" < /dev/null 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout is valid JSON (python3 parse)
# ---------------------------------------------------------------------------
if python3 -c "import json,sys; json.loads(sys.argv[1])" "$JSON_OUT" 2>/dev/null; then
  pass "Check 2: stdout is valid JSON"
else
  fail "Check 2: stdout is not valid JSON (got: $JSON_OUT)"
fi

# ---------------------------------------------------------------------------
# Check 3: JSON contains hookSpecificOutput key
# ---------------------------------------------------------------------------
HAS_KEY=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print('yes' if 'hookSpecificOutput' in d else 'no')
" "$JSON_OUT" 2>/dev/null)
if [ "$HAS_KEY" = "yes" ]; then
  pass "Check 3: JSON contains hookSpecificOutput"
else
  fail "Check 3: JSON missing hookSpecificOutput"
fi

# ---------------------------------------------------------------------------
# Check 4: additionalContext is non-empty
# ---------------------------------------------------------------------------
CONTEXT=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('hookSpecificOutput', {}).get('additionalContext', ''))
" "$JSON_OUT" 2>/dev/null)
if [ -n "$CONTEXT" ]; then
  pass "Check 4: additionalContext is non-empty"
else
  fail "Check 4: additionalContext is empty"
fi

# ---------------------------------------------------------------------------
# Check 5: additionalContext contains classify-before-mutate (exemplar rule)
# ---------------------------------------------------------------------------
case "$CONTEXT" in
  *classify-before-mutate*)
    pass "Check 5: additionalContext contains classify-before-mutate"
    ;;
  *)
    fail "Check 5: additionalContext missing classify-before-mutate (got: $CONTEXT)"
    ;;
esac

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
